"""Storage safety checks, preparation and cleanup."""

import json
import os
import re
import shutil
import subprocess
import sys
from collections.abc import Callable, Generator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from nixos_setup.common import (
    HOSTS,
    INSTALL_ROOT,
    MAPPER,
    MIB,
    SUBVOLUMES,
    Plan,
    PreparedStorage,
    StoragePlan,
    run_command,
)
from nixos_setup.planning import discover_disks, plan_storage, swap_error


def storage_preflight(plan: Plan) -> None:
    if plan.host not in HOSTS:
        raise ValueError("Unknown installation host.")
    storage = plan.storage
    disk = storage.disk
    if storage.mode != "erase":
        raise ValueError("Preserve installation is not implemented.")
    if storage != plan_storage(disk, "erase"):
        raise ValueError("Storage layout does not match the reviewed plan.")
    if swap_error(str(plan.swap_gib), storage.capacity):
        raise ValueError("Invalid swap size.")
    if os.geteuid() != 0:
        raise PermissionError("Disk preparation requires a root console.")
    if not Path("/sys/firmware/efi").is_dir():
        raise ValueError("Installation requires UEFI boot.")
    for tool in (
        "lsblk",
        "wipefs",
        "parted",
        "udevadm",
        "mkfs.fat",
        "cryptsetup",
        "mkfs.btrfs",
        "btrfs",
        "mount",
        "umount",
    ):
        if shutil.which(tool) is None:
            raise ValueError(f"Missing installation tool: {tool}")
    if not re.fullmatch(r"[0-9]+:[0-9]+", disk.identity[0]) or not any(
        disk.identity[1:]
    ):
        raise ValueError(
            "Disk identity requires a device number and serial/WWN."
        )
    current = next((d for d in discover_disks() if d.path == disk.path), None)
    if current != disk:
        raise ValueError("Disk changed since review. Run the wizard again.")
    if not Path(disk.path).is_block_device():
        raise ValueError("Target is not a block device.")
    sys_disk = Path("/sys/class/block") / Path(disk.path).name
    for path in (disk.path, *disk.partition_paths):
        node = Path("/sys/class/block") / Path(path).name
        if any((node / "holders").iterdir()):
            raise ValueError("Disk has active device mappings.")
        if path != disk.path and (
            not Path(path).is_block_device()
            or not (node / "partition").is_file()
            or node.resolve().parent != sys_disk.resolve()
        ):
            raise ValueError("Partition does not belong to the target disk.")
    if Path(MAPPER).exists() or Path(MAPPER).is_symlink():
        raise ValueError("cryptroot mapping already exists; refusing reuse.")
    if INSTALL_ROOT.is_symlink() or os.path.ismount(INSTALL_ROOT):
        raise ValueError("Installation mount point is already in use.")
    if INSTALL_ROOT.exists() and (
        not INSTALL_ROOT.is_dir() or any(INSTALL_ROOT.iterdir())
    ):
        raise ValueError("Installation directory is not empty.")


def partition_devices(storage: StoragePlan) -> tuple[str, str]:
    output = subprocess.check_output(
        [
            "lsblk",
            "--json",
            "--bytes",
            "--paths",
            "--tree",
            "--output",
            "NAME,TYPE,RO,PTTYPE,PARTN,PARTLABEL,START,SIZE,PKNAME,"
            "MAJ:MIN,SERIAL,WWN,MOUNTPOINTS",
            "--",
            storage.disk.path,
        ],
        text=True,
        timeout=10,
    )
    devices = json.loads(output)["blockdevices"]
    if len(devices) != 1:
        raise ValueError("Could not identify the partitioned disk.")
    disk = devices[0]
    identity = (
        disk.get("maj:min") or "",
        disk.get("serial") or "",
        disk.get("wwn") or "",
    )
    if (
        disk["name"] != storage.disk.path
        or disk["type"] != "disk"
        or disk["ro"] is not False
        or disk["pttype"] != "gpt"
        or disk["size"] != storage.disk.size
        or identity != storage.disk.identity
    ):
        raise ValueError("Partitioned disk identity does not match the plan.")
    parts = disk.get("children", [])
    if len(parts) != 2:
        raise ValueError("Expected exactly two new partitions.")
    paths: list[str] = []
    efi_end = storage.start + storage.efi_size
    for number, label, start, end in (
        (1, "ESP", storage.start, efi_end),
        (2, "cryptroot", efi_end, storage.end),
    ):
        part = next((p for p in parts if p.get("partn") == number), None)
        if part is None or (
            part["type"] != "part"
            or part["ro"] is not False
            or any(part.get("mountpoints") or ())
            or part["pkname"] != storage.disk.path
            or part["partlabel"] != label
            or part["start"] * 512 != start
            or part["size"] != end - start
            or part.get("children")
            or not Path(part["name"]).is_block_device()
        ):
            raise ValueError("New partition does not match the reviewed plan.")
        paths.append(part["name"])
    if paths[0] == paths[1]:
        raise ValueError("New partitions must have different device paths.")
    return paths[0], paths[1]


@contextmanager
def prepare_storage(
    plan: Plan,
    *,
    password_fd: int,
    confirmation: str,
    before_write: Callable[[], None] | None = None,
) -> Generator[PreparedStorage]:
    """Prepare storage; keep it mounted for the caller, then clean up."""
    storage_preflight(plan)
    if confirmation != plan.storage.disk.path:
        raise ValueError("Disk confirmation did not match. No changes made.")
    if password_fd < 0 or os.fstat(password_fd).st_size == 0:
        raise ValueError("Missing shared installation password.")
    storage = plan.storage
    mounts: list[Path] = []
    opened = False
    modified = False

    def run(command: list[str], **kwargs: Any) -> None:
        run_command(command, **kwargs)

    def mount(device: str, target: Path, options: str) -> None:
        if target.is_symlink() or os.path.ismount(target):
            raise ValueError(f"Mount point is already in use: {target}")
        target.mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", options, "--", device, str(target)])
        mounts.append(target)

    try:
        # Review and cloning can take time; recheck immediately before erasure.
        storage_preflight(plan)
        print("Preparing encrypted storage...")
        modified = True
        if before_write is not None:
            before_write()
        run(
            [
                "wipefs",
                "--all",
                "--lock=yes",
                "--",
                *storage.disk.partition_paths,
                storage.disk.path,
            ]
        )
        efi_end = storage.start + storage.efi_size
        run(
            [
                "parted",
                "--script",
                "--align",
                "optimal",
                storage.disk.path,
                "mklabel",
                "gpt",
                "mkpart",
                "ESP",
                "fat32",
                f"{storage.start // MIB}MiB",
                f"{efi_end // MIB}MiB",
                "set",
                "1",
                "esp",
                "on",
                "mkpart",
                "cryptroot",
                f"{efi_end // MIB}MiB",
                f"{storage.end // MIB}MiB",
            ]
        )
        run(["udevadm", "settle", "--timeout=10"])
        efi, luks = partition_devices(storage)
        run(["mkfs.fat", "-F", "32", "-n", "BOOT", efi])
        key_file = f"/proc/self/fd/{password_fd}"
        run(
            [
                "cryptsetup",
                "luksFormat",
                "--type",
                "luks2",
                "--batch-mode",
                "--key-file",
                key_file,
                luks,
            ],
            pass_fds=(password_fd,),
        )
        run(
            ["cryptsetup", "open", "--key-file", key_file, luks, "cryptroot"],
            pass_fds=(password_fd,),
        )
        opened = True
        run(["mkfs.btrfs", "-L", "nixos", MAPPER])
        print("Creating Btrfs subvolumes...")
        mount(MAPPER, INSTALL_ROOT, "subvolid=5")
        run(
            [
                "btrfs",
                "subvolume",
                "create",
                *(str(INSTALL_ROOT / name) for name, _ in SUBVOLUMES),
                # The Windows VM's disk; windows-vm.nix mounts it, so the
                # installed system does not need it in its hardware settings.
                str(INSTALL_ROOT / "windows"),
            ]
        )
        (INSTALL_ROOT / "snapshots").chmod(0o700)
        run(["umount", "--", str(INSTALL_ROOT)])
        mounts.pop()
        print("Mounting the installation layout...")
        for name, path in SUBVOLUMES:
            mount(
                MAPPER,
                INSTALL_ROOT / path.lstrip("/"),
                f"subvol={name},compress=zstd",
            )
        mount(efi, INSTALL_ROOT / "boot", "umask=077")
        print(
            f"Creating {plan.swap_gib} GiB swap and measuring resume offset..."
        )
        swapfile = str(INSTALL_ROOT / "var/swap/swapfile")
        run(
            [
                "btrfs",
                "filesystem",
                "mkswapfile",
                "--size",
                f"{plan.swap_gib}G",
                "--uuid",
                "clear",
                swapfile,
            ]
        )
        offset = int(
            subprocess.check_output(
                ["btrfs", "inspect-internal", "map-swapfile", "-r", swapfile],
                text=True,
                timeout=10,
            ).strip()
        )
        if offset < 0:
            raise ValueError("Invalid swap resume offset.")
        yield PreparedStorage(
            INSTALL_ROOT, efi, luks, MAPPER, offset, password_fd
        )
    finally:
        failed = sys.exception() is not None
        if failed and modified:
            print(
                "Installation stopped. The disk was modified.",
                file=sys.stderr,
            )
        cleanup_errors: list[str] = []
        for target in reversed(mounts):
            try:
                run(["umount", "--", str(target)])
            except (OSError, subprocess.SubprocessError) as error:
                cleanup_errors.append(str(error))
        if opened and not cleanup_errors:
            try:
                run(["cryptsetup", "close", "cryptroot"])
            except (OSError, subprocess.SubprocessError) as error:
                cleanup_errors.append(str(error))
        if cleanup_errors:
            print(
                "Storage cleanup failed; the disk was modified. "
                "Check remaining mounts/mappings.",
                file=sys.stderr,
            )
            for error in cleanup_errors:
                print(error, file=sys.stderr)
            if not failed:
                raise RuntimeError("Storage cleanup failed.")

"""NixOS installation wizard with a read-only dry-run."""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from collections.abc import Callable, Generator, Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any

import questionary

MIB = 1024**2
GIB = 1024**3
INSTALL_ROOT = Path("/mnt")
MAPPER = "/dev/mapper/cryptroot"
SOURCE_FLAKE = "github:Furyfree/nix/main"
SUBVOLUMES = (
    ("root", "/"),
    ("home", "/home"),
    ("snapshots", "/.snapshots"),
    ("log", "/var/log"),
    ("cache", "/var/cache"),
    ("swapfile", "/var/swap"),
    ("flatpak", "/var/lib/flatpak"),
    ("docker", "/var/lib/docker"),
    ("containerd", "/var/lib/containerd"),
)


@dataclass(frozen=True)
class Disk:
    path: str
    size: int
    table: str | None
    model: str
    mounted: bool
    partitions: tuple[tuple[int, int], ...]
    identity: tuple[str, str, str] = ("", "", "")
    busy: bool = False
    partition_paths: tuple[str, ...] = ()


@dataclass(frozen=True)
class StoragePlan:
    disk: Disk
    mode: str
    start: int
    end: int
    efi_size: int

    @property
    def capacity(self) -> int:
        return self.end - self.start - self.efi_size


@dataclass(frozen=True)
class Plan:
    host: str
    username: str
    ssh_key: str
    fingerprint: str
    storage: StoragePlan
    ram: int
    swap_gib: int


@dataclass(frozen=True)
class PreparedStorage:
    root: Path
    efi_device: str
    luks_device: str
    resume_device: str
    resume_offset: int


def device_tree(device: dict[str, Any]) -> Iterator[dict[str, Any]]:
    yield device
    for child in device.get("children", []):
        yield from device_tree(child)


def parse_disks(data: dict[str, Any]) -> tuple[Disk, ...]:
    disks: list[Disk] = []
    for device in data["blockdevices"]:
        if (
            device["type"] != "disk"
            or device["ro"] is not False
            or device["name"].startswith("/dev/zram")
        ):
            continue
        size = device["size"]
        if type(size) is not int or size <= 0:
            raise ValueError("Invalid disk size.")
        nodes = tuple(device_tree(device))
        partitions: list[tuple[int, int]] = []
        for node in nodes:
            if node["type"] != "part":
                continue
            sector, length = node["start"], node["size"]
            if (
                type(sector) is not int
                or sector < 0
                or type(length) is not int
                or length <= 0
            ):
                raise ValueError("Invalid partition metadata.")
            # Linux START uses 512-byte units even on 4K-sector disks.
            start = sector * 512
            partitions.append((start, start + length))
        disks.append(
            Disk(
                device["name"],
                size,
                device.get("pttype"),
                device.get("model") or "",
                any(
                    point
                    for n in nodes
                    for point in (n.get("mountpoints") or ())
                ),
                tuple(sorted(partitions)),
                (
                    device.get("maj:min") or "",
                    device.get("serial") or "",
                    device.get("wwn") or "",
                ),
                any(n["type"] not in {"disk", "part"} for n in nodes),
                tuple(n["name"] for n in nodes if n["type"] == "part"),
            )
        )
    return tuple(disks)


def discover_disks() -> tuple[Disk, ...]:
    output = subprocess.check_output(
        [
            "lsblk",
            "--json",
            "--bytes",
            "--paths",
            "--tree",
            "--output",
            "NAME,SIZE,TYPE,RO,PTTYPE,START,MOUNTPOINTS,MODEL,"
            "MAJ:MIN,SERIAL,WWN",
        ],
        text=True,
        timeout=10,
    )
    return parse_disks(json.loads(output))


def detect_ram() -> int:
    for line in Path("/proc/meminfo").read_text().splitlines():
        if line.startswith("MemTotal:"):
            ram = int(line.split()[1]) * 1024
            if ram > 0:
                return ram
    raise ValueError("Could not detect RAM.")


def suggested_swap(ram: int) -> int:
    if ram <= 0:
        raise ValueError("RAM must be positive.")
    return (ram * 3 + 2 * GIB - 1) // (2 * GIB)


def plan_storage(disk: Disk, mode: str) -> StoragePlan:
    if disk.mounted:
        raise ValueError("Disk is mounted or has active swap.")
    if disk.busy:
        raise ValueError("Disk has active LVM, RAID or encryption mappings.")
    limit = (disk.size - MIB) // MIB * MIB
    efi_size = 0
    if mode == "erase":
        start, end = MIB, limit
        efi_size = 4 * GIB
    elif mode == "preserve":
        if disk.table != "gpt":
            raise ValueError("Preserve preview currently requires a GPT disk.")
        gaps: list[tuple[int, int]] = []
        cursor = MIB
        previous_end = 0
        for begin, end in disk.partitions:
            if begin < previous_end or end > disk.size or end <= begin:
                raise ValueError("Invalid or overlapping partition metadata.")
            gaps.append((cursor, begin))
            cursor = max(cursor, end)
            previous_end = end
        gaps.append((cursor, limit))
        aligned = (
            ((begin + MIB - 1) // MIB * MIB, min(end // MIB * MIB, limit))
            for begin, end in gaps
        )
        start, end = max(aligned, key=lambda gap: gap[1] - gap[0])
    else:
        raise ValueError("Unknown storage mode.")
    storage = StoragePlan(disk, mode, start, end, efi_size)
    if storage.capacity <= GIB:
        raise ValueError("Insufficient space for swap and the storage layout.")
    return storage


def username_error(value: str) -> str | None:
    if value == "root" or not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", value):
        return "Use a non-root username starting with a lowercase letter or _."
    return None


def swap_error(value: str, capacity: int) -> str | None:
    maximum = (capacity - 1) // GIB
    if (
        not re.fullmatch(r"[1-9][0-9]*", value)
        or len(value) > len(str(maximum))
        or int(value) > maximum
    ):
        return f"Choose a whole number from 1 to {maximum} GiB."
    return None


def key_fingerprint(key: str) -> str:
    if not key:
        return "none"
    if "\n" in key or "\r" in key:
        raise ValueError("Enter one SSH public key, not a private key.")
    try:
        return subprocess.check_output(
            ["ssh-keygen", "-lf", "/dev/stdin"],
            input=key + "\n",
            text=True,
            stderr=subprocess.DEVNULL,
            env={**os.environ, "LC_ALL": "C"},
            timeout=10,
        ).strip()
    except subprocess.CalledProcessError as error:
        raise ValueError("Enter one valid SSH public key.") from error


def ask(question: questionary.Question) -> Any:
    answer = question.unsafe_ask()
    if answer is None:
        raise KeyboardInterrupt
    return answer


def collect_plan() -> Plan:
    host = ask(
        questionary.select(
            "Target host",
            choices=[
                "desktop",
                "laptop",
                "nixos-test",
            ],
        )
    )
    disks = discover_disks()
    if not disks:
        raise ValueError("No writable disks found.")
    disk = ask(
        questionary.select(
            "Target disk",
            choices=[
                questionary.Choice(
                    f"{d.path} — {d.size / GIB:.1f} GiB — {d.model}",
                    value=d,
                )
                for d in disks
            ],
        )
    )
    mode = ask(
        questionary.select(
            "Storage mode",
            choices=["erase", "preserve"],
        )
    )
    storage = plan_storage(disk, mode)

    def validate_username(text: str) -> str | bool:
        return username_error(text) or True

    username = ask(
        questionary.text("Installed username", validate=validate_username)
    )
    while True:
        ssh_key = ask(questionary.text("SSH public key (optional)"))
        try:
            fingerprint = key_fingerprint(ssh_key)
            break
        except ValueError as error:
            print(error)
    ram = detect_ram()
    suggestion = suggested_swap(ram)
    print(f"\nDetected usable RAM: {ram / GIB:.1f} GiB")
    print(f"Suggested swap: {suggestion} GiB")
    print(f"Candidate NixOS space: {storage.capacity / GIB:.1f} GiB")
    if mode == "preserve":
        print("Estimate is an upper bound: EFI allocation is unresolved.")
    if swap_error(str(suggestion), storage.capacity):
        print("Suggested swap will not fit. Choose a smaller size or cancel.")
    else:
        fraction = suggestion * GIB / storage.capacity
        remaining = storage.capacity / GIB - suggestion
        print(f"Suggestion uses {fraction:.1%}, leaving {remaining:.1f} GiB.")

    def validate_swap(text: str) -> str | bool:
        return swap_error(text, storage.capacity) or True

    swap = ask(
        questionary.text(
            "Swap size in whole GiB",
            default=str(suggestion),
            validate=validate_swap,
        )
    )
    return Plan(host, username, ssh_key, fingerprint, storage, ram, int(swap))


def show_plan(plan: Plan) -> None:
    storage = plan.storage
    print("\n--- Installation preview ---")
    print(f"Host: {plan.host}\nUser: {plan.username}")
    print(f"SSH key: {plan.fingerprint}")
    print(f"Disk: {storage.disk.path} ({storage.disk.size / GIB:.1f} GiB)")
    if storage.disk.identity[1]:
        print(f"Disk serial: {storage.disk.identity[1]}")
    if storage.disk.identity[2]:
        print(f"Disk WWN: {storage.disk.identity[2]}")
    print(f"Mode: {storage.mode}")
    if storage.mode == "erase":
        print("Would replace the disk layout: 4 GiB FAT32 EFI at /boot,")
        print("then LUKS2-encrypted Btrfs.")
    else:
        print(f"Aligned free extent: [{storage.start}, {storage.end}) bytes.")
        print(
            "Existing partitions stay untouched. EFI handling is UNRESOLVED."
        )
    print("Btrfs subvolumes: " + ", ".join(name for name, _ in SUBVOLUMES))
    print("/nix stays inside root. Windows VM storage is deferred.")
    print("Swap is encrypted at /var/swap/swapfile.")
    fraction = plan.swap_gib * GIB / storage.capacity
    remaining = storage.capacity / GIB - plan.swap_gib
    print(f"Swap: {plan.swap_gib} GiB ({fraction:.1%} of candidate space)")
    print(f"Space after swap: {remaining:.1f} GiB, before overhead/packages.")
    if plan.swap_gib < suggested_swap(plan.ram):
        print("WARNING: Swap is below the suggestion; hibernation may fail.")
    print("UUIDs, passwords and resume offset are set during installation.")
    print("This preview does not prove that an installation will fit or boot.")
    if storage.mode == "erase":
        print("\nDisk preparation stages (not executed in this preview):")
        print("1. Check disk identity and usage; require typed confirmation.")
        print("2. Erase old signatures; create GPT and 4 GiB EFI partitions.")
        print("3. Format EFI; cryptsetup prompts for the LUKS2 passphrase.")
        print("4. Create Btrfs and the nine subvolumes; mount the layout.")
        print(
            f"5. Create {plan.swap_gib} GiB swap; measure its resume offset."
        )
    print("\nConfiguration stages (not executed in this preview):")
    print(f"Clone latest main: {SOURCE_FLAKE}; keep its flake.lock.")
    print(f"Installed checkout: /home/{plan.username}/Projects/nix")
    if plan.host != "nixos-test" or storage.mode != "erase":
        print(
            "BLOCKED: configuration generation supports nixos-test erase only."
        )
    print("Check the checkout and chosen settings before disk erasure.")
    print(
        f"Generate hosts/{plan.host}/hardware-configuration.nix from mounts."
    )
    print(f"Generate hosts/{plan.host}/installation.nix with user/key/swap.")
    print("Keep configuration.nix and home.nix; measure fresh UUIDs/offset.")
    print("Evaluate the configuration; passwords stay outside Nix files.")
    print("\nInstallation stages (not executed in this review):")
    print("Install the generated flake; nixos-install asks for root password.")
    print("Set the user password with native passwd; give them the checkout.")
    print("Check the installed system, EFI files and swap/resume settings.")
    print("Release mounts/mapping, then offer reboot (default: no).")


def nix_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False).replace("${", r"\${")


def render_installation(plan: Plan, resume_offset: int) -> str:
    if plan.host != "nixos-test" or plan.storage.mode != "erase":
        raise ValueError("Only nixos-test erase installation is supported.")
    if username_error(plan.username) or swap_error(
        str(plan.swap_gib), plan.storage.capacity
    ):
        raise ValueError("Invalid installation user or swap size.")
    if type(resume_offset) is not int or resume_offset < 0:
        raise ValueError("Invalid swap resume offset.")
    key_fingerprint(plan.ssh_key)
    user = nix_string(plan.username)
    key = nix_string(plan.ssh_key)
    keys = f"[ {key} ]" if plan.ssh_key else "[ ]"
    compression = "\n".join(
        f'  fileSystems.{nix_string(path)}.options = [ "compress=zstd" ];'
        for _, path in SUBVOLUMES
        if path != "/"
    )
    return f"""{{ ... }}:

{{
  imports = [ (import ../../components/swap.nix {{
    sizeGiB = {plan.swap_gib};
  }}) ];

  programs.git.enable = true;
  users.users.{user} = {{
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = {keys};
  }};
  home-manager.users.{user} = import ./home.nix;

{compression}
  boot.resumeDevice = {nix_string(MAPPER)};
  boot.kernelParams = [ "resume_offset={resume_offset}" ];
}}
"""


def evaluate_configuration(
    repo: Path, plan: Plan, offset: int
) -> dict[str, Any]:
    user = nix_string(plan.username)
    expression = f"""c: {{
      toplevel = c.system.build.toplevel.drvPath;
      system = c.system.build.toplevel.outPath;
      mutable = c.users.mutableUsers;
      git = c.programs.git.enable;
      efi = c.boot.loader.efi.efiSysMountPoint;
      limine = c.boot.loader.limine.enable && c.boot.loader.limine.efiSupport;
      removable = c.boot.loader.limine.efiInstallAsRemovable;
      host = c.networking.hostName;
      user = c.users.users.{user}.isNormalUser;
      groups = c.users.users.{user}.extraGroups;
      keys = c.users.users.{user}.openssh.authorizedKeys.keys;
      home = c.home-manager.users.{user}.home.homeDirectory;
      swaps = map (s: {{ inherit (s) device size; }}) c.swapDevices;
      resume = c.boot.resumeDevice;
      params = c.boot.kernelParams;
      filesystems = builtins.mapAttrs (_: f:
        {{ inherit (f) device fsType options; }}) c.fileSystems;
      luks = c.boot.initrd.luks.devices.cryptroot.device;
      failures = map (a: a.message)
        (builtins.filter (a: !a.assertion) c.assertions);
    }}"""
    result = json.loads(
        subprocess.check_output(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "eval",
                "--json",
                "--no-write-lock-file",
                "--no-update-lock-file",
                f"path:{repo}#nixosConfigurations.{plan.host}.config",
                "--apply",
                expression,
            ],
            text=True,
            timeout=300,
        )
    )
    if (
        result["failures"]
        or result["mutable"] is not True
        or result["git"] is not True
        or result["efi"] != "/boot"
        or result["limine"] is not True
        or result["host"] != plan.host
        or result["user"] is not True
        or not {"wheel", "networkmanager"} <= set(result["groups"])
        or result["keys"] != ([plan.ssh_key] if plan.ssh_key else [])
        or result["home"] != f"/home/{plan.username}"
        or result["swaps"]
        != [
            {
                "device": "/var/swap/swapfile",
                "size": plan.swap_gib * 1024,
            }
        ]
        or result["resume"] != MAPPER
        or [p for p in result["params"] if p.startswith("resume_offset=")]
        != [f"resume_offset={offset}"]
    ):
        raise ValueError(
            "Generated host configuration does not match the plan."
        )
    for name, path in SUBVOLUMES:
        fs = result["filesystems"].get(path, {})
        if (
            fs.get("fsType") != "btrfs"
            or fs.get("device") != MAPPER
            or f"subvol={name}" not in fs.get("options", [])
            or "compress=zstd" not in fs.get("options", [])
        ):
            raise ValueError(
                f"Generated mount does not match the plan: {path}"
            )
    return result


@contextmanager
def prepare_checkout(plan: Plan) -> Generator[Path]:
    """Clone and validate before erasure, keeping the lock unchanged."""
    provisional = render_installation(plan, 0)
    for tool in ("nix", "git", "nixos-generate-config", "blkid", "cryptsetup"):
        if shutil.which(tool) is None:
            raise ValueError(f"Missing installation tool: {tool}")
    with TemporaryDirectory(prefix="nixos-setup-") as directory:
        repo = Path(directory) / "nix"
        print(f"Cloning latest main from {SOURCE_FLAKE}...")
        subprocess.run(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "flake",
                "clone",
                SOURCE_FLAKE,
                "--dest",
                str(repo),
            ],
            check=True,
            timeout=180,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )
        host = repo / "hosts" / plan.host
        for path in (
            repo,
            repo / ".git",
            repo / "hosts",
            host,
            repo / "components",
        ):
            if path.is_symlink() or not path.is_dir():
                raise ValueError("Clone is not a standalone Git checkout.")
        for path in (
            repo / "flake.nix",
            repo / "flake.lock",
            host / "configuration.nix",
            host / "hardware-configuration.nix",
            host / "home.nix",
            repo / "components" / "swap.nix",
        ):
            if path.is_symlink() or not path.is_file():
                raise ValueError(
                    f"Missing or unsafe configuration file: {path}"
                )
        installation = host / "installation.nix"
        if installation.is_symlink():
            raise ValueError("Installation settings must not be a symlink.")
        lock = (repo / "flake.lock").read_bytes()
        installation.write_text(provisional)
        print("Checking chosen settings with the repo's existing hardware...")
        evaluate_configuration(repo, plan, 0)
        if (repo / "flake.lock").read_bytes() != lock:
            raise ValueError("Configuration evaluation changed flake.lock.")
        yield repo


def generate_configuration(
    plan: Plan,
    storage: PreparedStorage,
    checkout: Path,
) -> Path:
    """Keep custom config and Git history; replace hardware/install data."""
    settings = render_installation(plan, storage.resume_offset)
    if (
        not storage.root.is_absolute()
        or storage.root == Path("/")
        or storage.resume_device != MAPPER
    ):
        raise ValueError(
            "Invalid prepared installation root or resume device."
        )
    target = storage.root / "home" / plan.username / "Projects" / "nix"
    for path in (target, *target.parents):
        if path.is_symlink():
            raise ValueError(
                f"Installation path must not be a symlink: {path}"
            )
    if target.exists():
        raise ValueError("Target checkout already exists; refusing overwrite.")
    host = checkout / "hosts" / plan.host
    preserved = {
        path: path.read_bytes()
        for path in (
            checkout / "flake.lock",
            host / "configuration.nix",
            host / "home.nix",
        )
    }
    print("Generating hardware settings from the mounted installation...")
    subprocess.run(
        [
            "nixos-generate-config",
            "--root",
            str(storage.root),
            "--dir",
            str(host),
        ],
        check=True,
        timeout=120,
    )
    (host / "installation.nix").write_text(settings)
    result = evaluate_configuration(checkout, plan, storage.resume_offset)
    luks_uuid = subprocess.check_output(
        ["cryptsetup", "luksUUID", storage.luks_device],
        text=True,
        timeout=10,
    ).strip()
    efi_uuid = subprocess.check_output(
        ["blkid", "-s", "UUID", "-o", "value", storage.efi_device],
        text=True,
        timeout=10,
    ).strip()
    if (
        not luks_uuid
        or not efi_uuid
        or result["luks"] != f"/dev/disk/by-uuid/{luks_uuid}"
        or result["filesystems"]["/boot"]["device"]
        != f"/dev/disk/by-uuid/{efi_uuid}"
        or result["filesystems"]["/boot"]["fsType"] != "vfat"
    ):
        raise ValueError("Generated hardware uses the wrong disk identifiers.")
    if any(path.read_bytes() != data for path, data in preserved.items()):
        raise ValueError("Generation changed custom settings or flake.lock.")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(checkout, target, symlinks=True)
    print(f"Configuration ready at {target}; ownership follows installation.")
    return target


def storage_preflight(plan: Plan) -> None:
    if plan.host != "nixos-test":
        raise ValueError("Only nixos-test installation is supported.")
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
    before_write: Callable[[], None] | None = None,
) -> Generator[PreparedStorage]:
    """Prepare storage; keep it mounted for the caller, then clean up."""
    storage_preflight(plan)
    confirmation = ask(
        questionary.text(
            f"Erase {plan.storage.disk.path}? Type its full device path"
        )
    )
    if confirmation != plan.storage.disk.path:
        raise ValueError("Disk confirmation did not match. No changes made.")
    storage_preflight(plan)
    storage = plan.storage
    mounts: list[Path] = []
    opened = False
    modified = False

    def run(command: list[str]) -> None:
        subprocess.run(command, check=True)

    def mount(device: str, target: Path, options: str) -> None:
        if target.is_symlink() or os.path.ismount(target):
            raise ValueError(f"Mount point is already in use: {target}")
        target.mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", options, "--", device, str(target)])
        mounts.append(target)

    try:
        print("Preparing GPT and EFI partitions...")
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
        print("Creating LUKS2; cryptsetup will ask for the disk passphrase.")
        run(["cryptsetup", "luksFormat", "--type", "luks2", luks])
        run(["cryptsetup", "open", luks, "cryptroot"])
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
        yield PreparedStorage(INSTALL_ROOT, efi, luks, MAPPER, offset)
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


def enter_command(storage: PreparedStorage, *command: str) -> list[str]:
    return ["nixos-enter", "--root", str(storage.root), "--", *command]


def finish_installation(
    plan: Plan, storage: PreparedStorage, repo: Path
) -> None:
    expected_repo = storage.root / "home" / plan.username / "Projects/nix"
    if repo != expected_repo:
        raise ValueError("Installation checkout is outside the chosen home.")
    before = (repo / "flake.lock").read_bytes()
    expected = evaluate_configuration(repo, plan, storage.resume_offset)
    print("Installing NixOS; nixos-install will ask for the root password...")
    subprocess.run(
        [
            "nixos-install",
            "--root",
            str(storage.root),
            "--flake",
            f"path:{repo}#{plan.host}",
            "--no-channel-copy",
            "--no-write-lock-file",
            "--no-update-lock-file",
        ],
        check=True,
        timeout=3600,
    )
    bin_path = "/nix/var/nix/profiles/system/sw/bin/"

    def query(*command: str) -> str:
        return subprocess.check_output(
            enter_command(storage, *command),
            text=True,
            timeout=60,
            env={**os.environ, "LC_ALL": "C"},
        ).strip()

    def password_set(user: str) -> None:
        status = query(bin_path + "passwd", "--status", user).split()
        if len(status) < 2 or status[:2] != [user, "P"]:
            raise ValueError(f"Password is not set for {user}.")

    password_set("root")
    print(f"Set the password for {plan.username} with native passwd...")
    subprocess.run(
        enter_command(storage, bin_path + "passwd", plan.username),
        check=True,
    )
    password_set(plan.username)
    uid = int(query(bin_path + "id", "-u", plan.username))
    gid = int(query(bin_path + "id", "-g", plan.username))
    if uid <= 0 or gid < 0:
        raise ValueError("Installed user has an invalid account identity.")
    home = f"/home/{plan.username}"
    owner = f"{uid}:{gid}"
    for arguments in (
        ["--no-dereference", "--", owner, home, home + "/Projects"],
        ["-R", "--no-dereference", "--", owner, home + "/Projects/nix"],
    ):
        subprocess.run(
            enter_command(storage, bin_path + "chown", *arguments),
            check=True,
            timeout=120,
        )
    print("Checking the installed system and checkout...")
    system = query(bin_path + "readlink", "-f", "/nix/var/nix/profiles/system")
    if system != expected["system"]:
        raise ValueError(
            "Installed system does not match the generated flake."
        )
    subprocess.run(
        enter_command(storage, bin_path + "test", "-x", system + "/init"),
        check=True,
        timeout=60,
    )
    for path in (
        storage.root / "home" / plan.username,
        repo.parent,
        repo,
        repo / ".git",
    ):
        stat = path.stat()
        if (stat.st_uid, stat.st_gid) != (uid, gid):
            raise ValueError(f"Installed user does not own {path}.")
    git = subprocess.check_output(
        [
            "git",
            "-c",
            f"safe.directory={repo}",
            "-C",
            str(repo),
            "rev-parse",
            "--is-inside-work-tree",
        ],
        text=True,
        timeout=10,
    ).strip()
    if git != "true" or (repo / "flake.lock").read_bytes() != before:
        raise ValueError(
            "Installed checkout or lock file changed unexpectedly."
        )
    boot = storage.root / "boot"
    efi = boot / "efi" / ("boot" if expected["removable"] else "limine")
    loader = efi / "BOOTX64.EFI"
    if not loader.is_file() or loader.stat().st_size == 0:
        raise ValueError(
            "Installed Limine EFI executable is missing or empty."
        )
    entries = (boot / "limine/limine.conf").read_text()
    if (
        system + "/init" not in entries
        or f"resume_offset={storage.resume_offset}" not in entries
    ):
        raise ValueError("Limine entries do not match the installed system.")
    swap = storage.root / "var/swap/swapfile"
    offset = int(
        subprocess.check_output(
            ["btrfs", "inspect-internal", "map-swapfile", "-r", str(swap)],
            text=True,
            timeout=10,
        ).strip()
    )
    if (
        swap.stat().st_size != plan.swap_gib * GIB
        or offset != storage.resume_offset
    ):
        raise ValueError("Installed swap size or resume offset changed.")
    print("Installation checked. Boot and hibernation still need a real test.")


def install(plan: Plan) -> int:
    modified = False

    def mark_modified() -> None:
        nonlocal modified
        modified = True

    try:
        if not sys.stdin.isatty():
            raise ValueError(
                "Installation requires an interactive root console."
            )
        storage_preflight(plan)
        for tool in ("nixos-install", "nixos-enter", "systemctl"):
            if shutil.which(tool) is None:
                raise ValueError(f"Missing installation tool: {tool}")
        with prepare_checkout(plan) as checkout:
            with prepare_storage(plan, before_write=mark_modified) as storage:
                repo = generate_configuration(plan, storage, checkout)
                finish_installation(plan, storage, repo)
    except KeyboardInterrupt, EOFError:
        if modified:
            print(
                "\nInstallation cancelled. The disk was modified.",
                file=sys.stderr,
            )
            return 1
        print("\nInstallation cancelled. No disk changes made.")
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        RuntimeError,
        subprocess.SubprocessError,
    ) as error:
        state = (
            "The disk was modified." if modified else "No disk changes made."
        )
        print(f"Installation failed: {error}\n{state}", file=sys.stderr)
        return 1
    print(
        f"Installation complete. Checkout: /home/{plan.username}/Projects/nix"
    )
    try:
        reboot = ask(questionary.confirm("Reboot now?", default=False))
        if reboot:
            subprocess.run(["systemctl", "reboot"], check=True, timeout=30)
    except KeyboardInterrupt, EOFError:
        print("Reboot cancelled; installation is complete.")
    except (OSError, subprocess.SubprocessError) as error:
        print(
            f"Installation is complete, but reboot failed: {error}",
            file=sys.stderr,
        )
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="nixos-setup", description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run the wizard and preview without making changes.",
    )
    args = parser.parse_args(argv)
    if args.dry_run:
        print("NixOS setup — dry run. Ctrl+C cancels; no changes are made.")
    else:
        print("NixOS setup. Erasure follows typed disk confirmation.")
        print(
            "Ctrl+C stops installation; changes already made cannot be undone."
        )
    try:
        plan = collect_plan()
        show_plan(plan)
        if not args.dry_run:
            return install(plan)
        if not ask(
            questionary.confirm(
                "Finish this preview? No installation will run.",
                default=False,
            )
        ):
            raise KeyboardInterrupt
    except KeyboardInterrupt, EOFError:
        print("\nPlanning cancelled. No changes made.")
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        subprocess.SubprocessError,
    ) as error:
        print(f"Planning failed: {error}\nNo changes made.", file=sys.stderr)
        return 1
    print("Preview complete. Nothing saved or changed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

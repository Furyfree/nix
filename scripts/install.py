"""Preview a NixOS installation without writing disks or configuration."""

import json
import os
import re
import subprocess
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import questionary

MIB = 1024**2
GIB = 1024**3


@dataclass(frozen=True)
class Disk:
    path: str
    size: int
    table: str | None
    model: str
    mounted: bool
    partitions: tuple[tuple[int, int], ...]


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
                    point for n in nodes for point in n.get("mountpoints", [])
                ),
                tuple(sorted(partitions)),
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
            "NAME,SIZE,TYPE,RO,PTTYPE,START,MOUNTPOINTS,MODEL",
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
            "Target disk (preview only)",
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
            "Storage mode (preview only)",
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
    print(f"Mode: {storage.mode}")
    if storage.mode == "erase":
        print("Would replace the disk layout: 4 GiB FAT32 EFI at /boot,")
        print("then LUKS2-encrypted Btrfs.")
    else:
        print(f"Aligned free extent: [{storage.start}, {storage.end}) bytes.")
        print(
            "Existing partitions stay untouched. EFI handling is UNRESOLVED."
        )
    print("Btrfs subvolumes: root, home, snapshots, log, cache, swapfile,")
    print("flatpak, docker, containerd, windows. /nix stays inside root.")
    print("Swap is encrypted at /var/swap/swapfile.")
    fraction = plan.swap_gib * GIB / storage.capacity
    remaining = storage.capacity / GIB - plan.swap_gib
    print(f"Swap: {plan.swap_gib} GiB ({fraction:.1%} of candidate space)")
    print(f"Space after swap: {remaining:.1f} GiB, before overhead/packages.")
    if plan.swap_gib < suggested_swap(plan.ram):
        print("WARNING: Swap is below the suggestion; hibernation may fail.")
    print("UUIDs, passwords and resume offset are set during installation.")
    print("This preview does not prove that an installation will fit or boot.")


def main() -> int:
    print("NixOS setup — plan only. Ctrl+C cancels; no changes are made.")
    try:
        plan = collect_plan()
        show_plan(plan)
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
    print(
        "Preview complete. Nothing saved or changed. "
        "Installation is not implemented yet."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

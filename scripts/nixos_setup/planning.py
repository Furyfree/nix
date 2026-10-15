"""Disk discovery and storage planning."""

import json
import os
import re
import subprocess
from collections.abc import Iterator
from pathlib import Path
from typing import Any

from nixos_setup.common import GIB, MIB, Disk, StoragePlan


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

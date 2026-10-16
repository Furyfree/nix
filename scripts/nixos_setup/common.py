"""Shared constants, plan records and command helpers."""

import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryFile
from typing import Any

MIB = 1024**2


GIB = 1024**3


INSTALL_ROOT = Path("/mnt")


MAPPER = "/dev/mapper/cryptroot"


SOURCE_FLAKE = "github:Furyfree/nix/main"


HOSTS = ("desktop", "laptop", "nixos-test")


# GPT partition type of an EFI system partition.
ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"


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
    # GPT partition GUID of a Windows EFI partition on another disk, if any.
    windows: str = ""


@dataclass(frozen=True)
class PreparedStorage:
    root: Path
    efi_device: str
    luks_device: str
    resume_device: str
    resume_offset: int
    password_fd: int = -1


def run_command(command: list[str], **kwargs: Any) -> None:
    """Keep routine output quiet; show diagnostics if a command fails."""
    with TemporaryFile() as output:
        try:
            subprocess.run(
                command,
                check=True,
                stdout=output,
                stderr=subprocess.STDOUT,
                **kwargs,
            )
        except BaseException:
            output.seek(0)
            print(
                output.read().decode(errors="replace"), end="", file=sys.stderr
            )
            raise


def command_output(command: list[str], **kwargs: Any) -> str:
    with TemporaryFile() as errors:
        try:
            return subprocess.check_output(
                command, text=True, stderr=errors, **kwargs
            )
        except BaseException:
            errors.seek(0)
            print(
                errors.read().decode(errors="replace"), end="", file=sys.stderr
            )
            raise


def nix_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False).replace("${", r"\${")


def enter_command(storage: PreparedStorage, *command: str) -> list[str]:
    return ["nixos-enter", "--root", str(storage.root), "--", *command]

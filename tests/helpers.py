"""Shared fixtures for the installer tests."""

import base64
import struct
from typing import Any

from nixos_setup import planning

MIB = 1024**2
GIB = 1024**3


def device(**changes: Any) -> dict[str, Any]:
    return {
        "name": "/dev/fixture0",
        "size": 200 * GIB,
        "type": "disk",
        "ro": False,
        "pttype": "gpt",
        "start": None,
        "mountpoints": [],
        "model": "Fixture drive",
        "maj:min": "259:7",
        "serial": "fixture-serial",
        "wwn": "fixture-wwn",
        "children": [],
        **changes,
    }


def partition(sector: int | None, size: int, **changes: Any) -> dict[str, Any]:
    return device(type="part", start=sector, size=size, **changes)


def disk(**changes: Any) -> Any:
    return planning.parse_disks({"blockdevices": [device(**changes)]})[0]


def public_key(comment: str = "fixture") -> str:
    kind = b"ssh-ed25519"
    wire = (
        struct.pack(">I", len(kind))
        + kind
        + struct.pack(">I", 32)
        + bytes(range(32))
    )
    return "ssh-ed25519 " + base64.b64encode(wire).decode() + " " + comment

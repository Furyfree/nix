"""Disk discovery and storage planning."""

import base64
import struct
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from helpers import GIB, MIB, device, disk, partition
from nixos_setup import common, planning


class PlanningTests(unittest.TestCase):
    def test_swap_is_one_and_a_half_times_ram_rounded_up(self):
        for ram, expected in [
            (16 * GIB, 24),
            (64 * GIB, 96),
            (15 * GIB + 1024, 23),
        ]:
            with self.subTest(ram=ram):
                self.assertEqual(planning.suggested_swap(ram), expected)
        with self.assertRaises(ValueError):
            planning.suggested_swap(0)

    def test_ram_detection_converts_kernel_kib_to_bytes(self):
        with patch.object(
            Path,
            "read_text",
            return_value=(
                "Other: 123 kB\nMemTotal: 15728641 kB\nMemFree: 999 kB\n"
            ),
        ):
            self.assertEqual(planning.detect_ram(), 15 * GIB + 1024)
        for value in ["", "MemTotal: 0 kB\n", "MemTotal: unknown kB\n"]:
            with self.subTest(value=value):
                with patch.object(Path, "read_text", return_value=value):
                    with self.assertRaises(ValueError):
                        planning.detect_ram()

    def test_erase_reserves_efi_and_partition_metadata(self):
        storage = planning.plan_storage(disk(), "erase")
        self.assertEqual(storage.capacity, 196 * GIB - 2 * MIB)
        self.assertEqual(storage.efi_size, 4 * GIB)

    def test_preserve_uses_largest_contiguous_gap_not_sum(self):
        target = disk(
            children=[
                partition(2048, 9663676416),
                partition(335544320, 42948624384),
                partition(67108864, 68719476736),
            ]
        )
        before = target.partitions
        storage = planning.plan_storage(target, "preserve")
        self.assertEqual(
            (storage.start, storage.end), (103079215104, 171798691840)
        )
        self.assertEqual(storage.capacity, 64 * GIB)
        self.assertEqual(target.partitions, before)
        self.assertEqual(storage.efi_size, 0)  # EFI is not yet resolved.

    def test_preserve_rounds_gaps_inward_to_mib_boundaries(self):
        storage = planning.plan_storage(
            disk(
                size=10 * GIB,
                children=[
                    partition(2049, GIB - MIB + 123),
                    partition(8388609, 6 * GIB - MIB - 512),
                ],
            ),
            "preserve",
        )
        self.assertEqual(storage.start, GIB + MIB)
        self.assertEqual(storage.end, 4 * GIB)

    def test_insufficient_space_is_rejected(self):
        examples = [
            (disk(size=4 * GIB), "erase"),
            (
                disk(children=[partition(2048, 200 * GIB - 2 * MIB)]),
                "preserve",
            ),
        ]
        for target, mode in examples:
            with self.subTest(mode=mode):
                with self.assertRaisesRegex(ValueError, "Insufficient space"):
                    planning.plan_storage(target, mode)

    def test_preserve_requires_gpt_and_valid_nonoverlapping_extents(self):
        with self.assertRaisesRegex(ValueError, "GPT"):
            planning.plan_storage(disk(pttype="dos"), "preserve")
        for parts in [
            [partition(2048, 10 * GIB), partition(4096, 10 * GIB)],
            [partition(2048, 200 * GIB)],
        ]:
            with self.subTest(parts=parts):
                with self.assertRaisesRegex(ValueError, "partition metadata"):
                    planning.plan_storage(disk(children=parts), "preserve")
        for sector, size in [(None, GIB), (-1, GIB), (2048, 0)]:
            with self.subTest(sector=sector, size=size):
                with self.assertRaisesRegex(ValueError, "partition metadata"):
                    disk(children=[partition(sector, size)])

    def test_discovery_excludes_readonly_disks_zram_and_nondisks(self):
        disks = planning.parse_disks(
            {
                "blockdevices": [
                    device(),
                    device(name="/dev/readonly", ro=True),
                    device(name="/dev/zram0"),
                    device(type="loop"),
                ]
            }
        )
        self.assertEqual([d.path for d in disks], ["/dev/fixture0"])
        for size in [0, -1, None]:
            with self.subTest(size=size):
                with self.assertRaisesRegex(ValueError, "disk size"):
                    disk(size=size)

    def test_mounts_and_swap_on_nested_devices_block_both_modes(self):
        for mount in ["/iso", "[SWAP]"]:
            for nested in [False, True]:
                changes: dict[str, Any] = {"mountpoints": [mount]}
                if nested:
                    changes = {
                        "children": [
                            partition(
                                2048,
                                10 * GIB,
                                children=[
                                    device(type="crypt", mountpoints=[mount])
                                ],
                            )
                        ]
                    }
                target = disk(**changes)
                for mode in ["erase", "preserve"]:
                    with self.subTest(mount=mount, nested=nested, mode=mode):
                        with self.assertRaisesRegex(ValueError, "mounted"):
                            planning.plan_storage(target, mode)

    def test_unmounted_device_mappings_block_both_storage_modes(self):
        for kind in ["lvm", "crypt", "raid1", "mpath"]:
            target = disk(
                children=[
                    partition(2048, 10 * GIB, children=[device(type=kind)])
                ]
            )
            for mode in ["erase", "preserve"]:
                with self.subTest(kind=kind, mode=mode):
                    self.assertFalse(target.mounted)
                    with self.assertRaisesRegex(ValueError, "active"):
                        planning.plan_storage(target, mode)

    def test_username_validation(self):
        for name in ["river", "delta_bot", "_worker", "a" * 32]:
            self.assertIsNone(planning.username_error(name))
        for name in ["root", "River", "", "a" * 33, "user/name"]:
            with self.subTest(name=name):
                self.assertIsNotNone(planning.username_error(name))

    def test_swap_override_must_leave_space_and_be_a_positive_whole_gib(self):
        self.assertIsNone(planning.swap_error("15", 16 * GIB))
        self.assertIsNone(planning.swap_error("16", 16 * GIB + 1))
        for value in ["16", "0", "-1", "08", "1.5", "swap", "١", "9" * 100]:
            with self.subTest(value=value):
                self.assertIsNotNone(planning.swap_error(value, 16 * GIB))

    def test_key_validation_uses_real_openssh_without_private_keys(self):
        key_type = b"ssh-ed25519"
        wire = (
            struct.pack(">I", len(key_type))
            + key_type
            + struct.pack(">I", 32)
            + bytes(range(32))
        )
        key = "ssh-ed25519 " + base64.b64encode(wire).decode() + " fixture"
        self.assertRegex(planning.key_fingerprint(key), r"^256 SHA256:")
        self.assertEqual(planning.key_fingerprint(""), "none")
        for invalid in [
            "not a key",
            key + "\n" + key,
            "-----BEGIN OPENSSH PRIVATE KEY-----",
        ]:
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValueError):
                    planning.key_fingerprint(invalid)

    def test_windows_candidates_are_efi_partitions_on_other_disks(self):
        guid = "0f2c9a4e-1b7d-4c3a-9e8f-5a6b7c8d9e0f"

        def esp(name: str, **changes: Any) -> dict[str, Any]:
            return partition(
                2048,
                GIB,
                name=name,
                **{"parttype": common.ESP_TYPE, "partuuid": guid, **changes},
            )

        data = {
            "blockdevices": [
                device(children=[esp("/dev/fixture0p1")]),
                device(
                    name="/dev/fixture1",
                    children=[
                        esp(
                            "/dev/fixture1p1", mountpoints=["/boot/efi", None]
                        ),
                        esp(
                            "/dev/fixture1p2",
                            parttype="0fc63daf-8483-4772-8e79-3d69d8477de4",
                        ),
                        esp("/dev/fixture1p3", partuuid="not-a-guid"),
                    ],
                ),
                device(name="/dev/zram0", type="disk"),
            ]
        }
        self.assertEqual(
            planning.esp_candidates(data, "/dev/fixture0"),
            (("/dev/fixture1p1", guid, ("/boot/efi",)),),
        )


if __name__ == "__main__":
    unittest.main()

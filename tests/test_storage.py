"""Storage preparation and cleanup."""

import io
import json
import os
import shutil
import subprocess
import unittest
from collections.abc import Generator
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from typing import Any, final
from unittest.mock import Mock, patch

import questionary
from helpers import GIB, MIB, device, disk, partition
from nixos_setup import common, credentials, installation, planning, storage


@final
class StorageExecutionTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.target = disk()
        password_file = credentials.memory_file()
        password_fd = password_file.__enter__()
        self.addCleanup(password_file.__exit__, None, None, None)
        os.write(password_fd, b"disposable storage fixture")
        self.storage_args: dict[str, Any] = {
            "password_fd": password_fd,
            "confirmation": self.target.path,
        }
        self.plan = common.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            planning.plan_storage(self.target, "erase"),
            32 * GIB,
            48,
        )
        self.commands: list[list[str]] = []
        self.output = io.StringIO()
        self.new_devices = {
            "blockdevices": [
                device(
                    children=[
                        partition(
                            2048,
                            4 * GIB,
                            name="/dev/fixture-efi",
                            partn=1,
                            partlabel="ESP",
                            pkname="/dev/fixture0",
                        ),
                        partition(
                            8390656,
                            196 * GIB - 2 * MIB,
                            name="/dev/fixture-system",
                            partn=2,
                            partlabel="cryptroot",
                            pkname="/dev/fixture0",
                        ),
                    ]
                )
            ]
        }

    @contextmanager
    def environment(self) -> Generator[tuple[Mock, Mock]]:
        def run(command: list[str], **kwargs: Any) -> Any:
            self.assertTrue(kwargs["check"])
            self.commands.append(command)
            return subprocess.CompletedProcess[str](command, 0)

        def probe(command: list[str], **_kwargs: Any) -> str:
            if command[0] == "lsblk":
                return json.dumps(self.new_devices)
            self.assertEqual(
                command,
                [
                    "btrfs",
                    "inspect-internal",
                    "map-swapfile",
                    "-r",
                    "/mnt/var/swap/swapfile",
                ],
            )
            return "12345\n"

        def resolve(path: Path) -> Path:
            if path.name == "fixture0":
                return Path("/sys/devices/fixture0")
            if path.name.startswith("fixture0p"):
                return Path("/sys/devices/fixture0") / path.name
            return path

        with (
            redirect_stdout(self.output),
            redirect_stderr(self.output),
            patch.object(os, "geteuid", return_value=0),
            patch.object(shutil, "which", return_value="/fixture"),
            patch.object(
                storage, "discover_disks", return_value=(self.target,)
            ) as discover,
            patch.object(Path, "is_block_device", return_value=True),
            patch.object(Path, "is_dir", return_value=True),
            patch.object(Path, "is_file", return_value=True),
            patch.object(Path, "exists", return_value=False),
            patch.object(Path, "is_symlink", return_value=False),
            patch.object(
                Path, "iterdir", autospec=True, return_value=iter(())
            ),
            patch.object(Path, "resolve", autospec=True, side_effect=resolve),
            patch.object(os.path, "ismount", return_value=False),
            patch.object(Path, "mkdir"),
            patch.object(Path, "chmod"),
            patch.object(
                questionary.Question,
                "unsafe_ask",
                side_effect=AssertionError(
                    "Storage preparation asked a question"
                ),
            ),
            patch.object(subprocess, "check_output", side_effect=probe),
            patch.object(subprocess, "run", side_effect=run) as execute,
            patch.object(
                installation,
                "native_password",
                side_effect=AssertionError(
                    "Storage preparation asked for a password"
                ),
            ),
            patch.object(
                subprocess,
                "Popen",
                side_effect=AssertionError(
                    "Storage tests must not launch real commands"
                ),
            ),
        ):
            yield discover, execute

    def test_storage_builds_reviewed_layout_and_releases_owned_resources(self):
        with self.environment():
            with storage.prepare_storage(
                self.plan, **self.storage_args
            ) as prepared:
                self.assertEqual(prepared.root, Path("/mnt"))
                self.assertEqual(prepared.efi_device, "/dev/fixture-efi")
                self.assertEqual(prepared.luks_device, "/dev/fixture-system")
                self.assertEqual(
                    prepared.resume_device, "/dev/mapper/cryptroot"
                )
                self.assertEqual(prepared.resume_offset, 12345)
                self.assertNotIn(
                    ["cryptsetup", "close", "cryptroot"], self.commands
                )
        self.assertIn(
            [
                "parted",
                "--script",
                "--align",
                "optimal",
                "/dev/fixture0",
                "mklabel",
                "gpt",
                "mkpart",
                "ESP",
                "fat32",
                "1MiB",
                "4097MiB",
                "set",
                "1",
                "esp",
                "on",
                "mkpart",
                "cryptroot",
                "4097MiB",
                "204799MiB",
            ],
            self.commands,
        )
        self.assertIn(
            ["mkfs.fat", "-F", "32", "-n", "BOOT", "/dev/fixture-efi"],
            self.commands,
        )
        encryption = next(
            c for c in self.commands if c[:2] == ["cryptsetup", "luksFormat"]
        )
        self.assertIn("--batch-mode", encryption)
        self.assertEqual(encryption[-1], "/dev/fixture-system")
        key = encryption[encryption.index("--key-file") + 1]
        self.assertTrue(key.startswith("/proc/self/fd/"))
        opening = next(
            c for c in self.commands if c[:2] == ["cryptsetup", "open"]
        )
        self.assertEqual(opening[opening.index("--key-file") + 1], key)
        self.assertIn(
            [
                "btrfs",
                "filesystem",
                "mkswapfile",
                "--size",
                "48G",
                "--uuid",
                "clear",
                "/mnt/var/swap/swapfile",
            ],
            self.commands,
        )
        created = next(
            c[3:]
            for c in self.commands
            if c[:3] == ["btrfs", "subvolume", "create"]
        )
        self.assertEqual(
            set(created),
            {
                "/mnt/root",
                "/mnt/home",
                "/mnt/snapshots",
                "/mnt/log",
                "/mnt/cache",
                "/mnt/swapfile",
                "/mnt/flatpak",
                "/mnt/docker",
                "/mnt/containerd",
            },
        )
        mounted = [c[-1] for c in self.commands if c[0] == "mount"]
        unmounted = [c[-1] for c in self.commands if c[0] == "umount"]
        self.assertEqual(unmounted, ["/mnt", *reversed(mounted[1:])])
        self.assertEqual(
            self.commands[-1], ["cryptsetup", "close", "cryptroot"]
        )
        self.assertFalse(
            any(c[0] in {"swapon", "reboot"} for c in self.commands)
        )

    def test_write_marker_runs_before_the_first_destructive_command(self):
        marker = Mock()
        with self.environment() as mocks:
            _, execute = mocks
            original = execute.side_effect

            def run(command: list[str], **kwargs: Any) -> Any:
                if command[0] == "wipefs":
                    marker.assert_called_once_with()
                    raise subprocess.CalledProcessError(1, command)
                return original(command, **kwargs)

            execute.side_effect = run
            with self.assertRaises(subprocess.CalledProcessError):
                with storage.prepare_storage(
                    self.plan, **self.storage_args, before_write=marker
                ):
                    self.fail("Failed wipe should stop preparation")
        marker.assert_called_once_with()
        self.assertIn("disk was modified", self.output.getvalue())

    def test_signature_wipe_targets_only_selected_disk_and_its_partitions(
        self,
    ):
        self.target = disk(
            children=[partition(2048, 10 * GIB, name="/dev/fixture0p1")]
        )
        self.plan = common.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            planning.plan_storage(self.target, "erase"),
            32 * GIB,
            48,
        )
        with self.environment():
            with storage.prepare_storage(self.plan, **self.storage_args):
                pass
        self.assertEqual(
            self.commands[0],
            [
                "wipefs",
                "--all",
                "--lock=yes",
                "--",
                "/dev/fixture0p1",
                "/dev/fixture0",
            ],
        )
        self.assertFalse(any("/dev/other" in c for c in self.commands))

    def test_root_uefi_and_tool_checks_stop_before_writes(self):
        for name in ["root", "uefi", "tool"]:
            self.commands.clear()
            with self.subTest(check=name), self.environment():
                change = {
                    "root": patch.object(os, "geteuid", return_value=1000),
                    "uefi": patch.object(Path, "is_dir", return_value=False),
                    "tool": patch.object(shutil, "which", return_value=None),
                }[name]
                with change, self.assertRaises((PermissionError, ValueError)):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        self.fail("Unsafe storage preparation was allowed")
                self.assertFalse(self.commands)

    def test_unsupported_plans_and_invalid_swap_never_reach_writes(self):
        plans = [
            replace(self.plan, host="desktop"),
            replace(self.plan, host="laptop"),
            common.Plan(
                "nixos-test",
                "river",
                "",
                "none",
                planning.plan_storage(self.target, "preserve"),
                32 * GIB,
                48,
            ),
            common.Plan(
                "nixos-test",
                "river",
                "",
                "none",
                self.plan.storage,
                32 * GIB,
                197,
            ),
        ]
        for plan in plans:
            with self.subTest(plan=plan), self.environment():
                with self.assertRaises(ValueError):
                    with storage.prepare_storage(plan, **self.storage_args):
                        self.fail("Unsafe storage preparation was allowed")
                self.assertFalse(self.commands)

    def test_missing_stable_disk_identity_prevents_erasure(self):
        for target in [disk(serial=None, wwn=None), disk(**{"maj:min": None})]:
            self.target = target
            self.plan = common.Plan(
                "nixos-test",
                "river",
                "",
                "none",
                planning.plan_storage(target, "erase"),
                32 * GIB,
                48,
            )
            with self.subTest(target=target), self.environment():
                with self.assertRaisesRegex(ValueError, "identity"):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        self.fail("Disk without stable identity was accepted")
                self.assertFalse(self.commands)

    def test_disk_change_after_confirmation_stops_before_writes(self):
        for changed in [
            disk(serial="different-disk"),
            disk(mountpoints=["/iso"]),
            disk(size=100 * GIB),
        ]:
            with self.subTest(changed=changed), self.environment() as mocks:
                discover, _ = mocks
                discover.side_effect = [(self.target,), (changed,)]
                with self.assertRaisesRegex(ValueError, "changed"):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        self.fail("Changed disk was accepted")
                self.assertFalse(self.commands)

    def test_missing_shared_password_stops_before_writes(self):
        with credentials.memory_file() as empty:
            for fd in [-1, empty]:
                with self.subTest(fd=fd), self.environment():
                    arguments: dict[str, Any] = {
                        **self.storage_args,
                        "password_fd": fd,
                    }
                    with self.assertRaisesRegex(ValueError, "password"):
                        with storage.prepare_storage(self.plan, **arguments):
                            self.fail(
                                "Storage preparation accepted no password"
                            )
                    self.assertFalse(self.commands)

    def test_active_kernel_holders_and_foreign_resources_are_not_touched(self):
        for name in ["holders", "mapper", "mount"]:
            with self.subTest(resource=name), self.environment():
                change = {
                    "holders": patch.object(
                        Path,
                        "iterdir",
                        return_value=iter([Path("/sys/dm-fixture")]),
                    ),
                    "mapper": patch.object(Path, "exists", return_value=True),
                    "mount": patch.object(
                        os.path, "ismount", return_value=True
                    ),
                }[name]
                with change, self.assertRaises(ValueError):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        self.fail("Foreign resource was accepted")
                self.assertFalse(self.commands)

    def test_foreign_partition_is_rejected_before_signature_wipe(self):
        self.target = disk(
            children=[partition(2048, 10 * GIB, name="/dev/otherp1")]
        )
        self.plan = common.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            planning.plan_storage(self.target, "erase"),
            32 * GIB,
            48,
        )
        with self.environment(), self.assertRaisesRegex(ValueError, "belong"):
            with storage.prepare_storage(self.plan, **self.storage_args):
                self.fail("Foreign partition was accepted")
        self.assertFalse(self.commands)

    def test_confirmation_mismatch_makes_no_changes(self):
        for answer in ["", "/dev/other"]:
            with self.subTest(answer=answer), self.environment():
                arguments: dict[str, Any] = {
                    **self.storage_args,
                    "confirmation": answer,
                }
                with self.assertRaisesRegex(ValueError, "confirmation"):
                    with storage.prepare_storage(self.plan, **arguments):
                        self.fail("Unconfirmed erasure was allowed")
                self.assertFalse(self.commands)
                self.assertNotIn("disk was modified", self.output.getvalue())

    def test_unexpected_partition_layout_stops_before_formatting(self):
        changes = [
            {"partlabel": "wrong"},
            {"start": 2049},
            {"pkname": "/dev/other"},
            {"partn": 3},
            {"size": 3 * GIB},
            {"ro": True},
            {"mountpoints": ["/foreign"]},
        ]
        for change in changes:
            self.commands.clear()
            with self.subTest(change=change), self.environment():
                part = self.new_devices["blockdevices"][0]["children"][0]
                before = dict(part)
                part.update(change)
                try:
                    with self.assertRaises(ValueError):
                        with storage.prepare_storage(
                            self.plan, **self.storage_args
                        ):
                            self.fail("Unexpected partition was accepted")
                    self.assertFalse(
                        any(c[0].startswith("mkfs") for c in self.commands)
                    )
                finally:
                    part.clear()
                    part.update(before)

    def test_each_command_failure_stops_and_cleans_only_acquired_resources(
        self,
    ):
        with self.environment():
            with storage.prepare_storage(self.plan, **self.storage_args):
                steps = list(self.commands)
        for index, failed_command in enumerate(steps):
            self.commands.clear()
            with (
                self.subTest(command=failed_command),
                self.environment() as mocks,
            ):
                _, execute = mocks
                original = execute.side_effect

                def fail_step(
                    command: list[str],
                    original: Any = original,
                    index: int = index,
                    **kwargs: Any,
                ) -> Any:
                    result = original(command, **kwargs)
                    if len(self.commands) == index + 1:
                        raise subprocess.CalledProcessError(9, command)
                    return result

                execute.side_effect = fail_step
                with self.assertRaises(subprocess.CalledProcessError):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        self.fail("Failed command did not stop preparation")
                self.assertEqual(
                    self.commands[: index + 1], steps[: index + 1]
                )
                mounts: list[str] = []
                opened = False
                for command in steps[:index]:
                    if command[0] == "mount":
                        mounts.append(command[-1])
                    elif command[0] == "umount":
                        mounts.remove(command[-1])
                    elif command[:2] == ["cryptsetup", "open"]:
                        opened = True
                cleanup = [["umount", "--", path] for path in reversed(mounts)]
                if opened:
                    cleanup.append(["cryptsetup", "close", "cryptroot"])
                self.assertEqual(self.commands[index + 1 :], cleanup)
                self.assertIn("disk was modified", self.output.getvalue())

    def test_invalid_resume_offset_releases_storage_without_returning_it(self):
        for offset in ["-1", "not-an-offset"]:
            self.commands.clear()
            with self.subTest(offset=offset), self.environment():
                with patch.object(
                    subprocess,
                    "check_output",
                    side_effect=[
                        json.dumps(self.new_devices),
                        offset,
                    ],
                ):
                    with self.assertRaises(ValueError):
                        with storage.prepare_storage(
                            self.plan, **self.storage_args
                        ):
                            self.fail("Invalid resume offset was accepted")
                self.assertEqual(
                    self.commands[-1], ["cryptsetup", "close", "cryptroot"]
                )

    def test_new_foreign_mount_is_not_overmounted_or_unmounted(self):
        def foreign_mount(path: Path) -> bool:
            return path == Path("/mnt/home")

        with self.environment():
            with patch.object(
                os.path,
                "ismount",
                side_effect=foreign_mount,
            ):
                with self.assertRaisesRegex(ValueError, "already in use"):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        self.fail("Foreign mount was overmounted")
        self.assertNotIn(["umount", "--", "/mnt/home"], self.commands)
        self.assertNotIn(
            "/mnt/home", [c[-1] for c in self.commands if c[0] == "mount"]
        )

    def test_later_stage_failure_and_cancel_release_resources(self):
        for error in [ValueError("later stage failed"), KeyboardInterrupt()]:
            self.commands.clear()
            with self.subTest(error=error), self.environment():
                with self.assertRaises(type(error)):
                    with storage.prepare_storage(
                        self.plan, **self.storage_args
                    ):
                        raise error
                self.assertEqual(
                    self.commands[-1], ["cryptsetup", "close", "cryptroot"]
                )
                self.assertIn("disk was modified", self.output.getvalue())

    def test_cleanup_failure_keeps_mapping_open_and_reports_failure(self):
        with self.environment() as mocks:
            _, execute = mocks
            original = execute.side_effect

            def fail_unmount(command: list[str], **kwargs: Any) -> Any:
                result = original(command, **kwargs)
                if command == ["umount", "--", "/mnt/home"]:
                    raise subprocess.CalledProcessError(9, command)
                return result

            execute.side_effect = fail_unmount
            with self.assertRaisesRegex(RuntimeError, "cleanup"):
                with storage.prepare_storage(self.plan, **self.storage_args):
                    pass
        self.assertNotIn(["cryptsetup", "close", "cryptroot"], self.commands)
        self.assertIn("cleanup failed", self.output.getvalue())

    def test_repeating_a_stale_plan_cannot_erase_again(self):
        with self.environment():
            with storage.prepare_storage(self.plan, **self.storage_args):
                pass
        self.commands.clear()
        changed = planning.parse_disks(self.new_devices)[0]
        with self.environment() as mocks:
            discover, _ = mocks
            discover.return_value = (changed,)
            with self.assertRaisesRegex(ValueError, "changed"):
                with storage.prepare_storage(self.plan, **self.storage_args):
                    self.fail("Stale plan was reused")
        self.assertFalse(self.commands)


if __name__ == "__main__":
    unittest.main()

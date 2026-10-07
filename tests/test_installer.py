"""Controlled planner examples; no disks are written or installed."""

import base64
import importlib.util
import io
import json
import struct
import subprocess
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any
from unittest.mock import Mock, patch

import questionary
from prompt_toolkit.input import create_pipe_input
from prompt_toolkit.output import DummyOutput

spec = importlib.util.spec_from_file_location(
    "installer", Path(__file__).resolve().parents[1] / "scripts/install.py"
)
assert spec is not None and spec.loader is not None
installer = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = installer
spec.loader.exec_module(installer)

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
        "children": [],
        **changes,
    }


def partition(sector: int | None, size: int, **changes: Any) -> dict[str, Any]:
    return device(type="part", start=sector, size=size, **changes)


def disk(**changes: Any) -> Any:
    return installer.parse_disks({"blockdevices": [device(**changes)]})[0]


class PlanningTests(unittest.TestCase):
    def test_swap_is_one_and_a_half_times_ram_rounded_up(self):
        for ram, expected in [
            (16 * GIB, 24),
            (64 * GIB, 96),
            (15 * GIB + 1024, 23),
        ]:
            with self.subTest(ram=ram):
                self.assertEqual(installer.suggested_swap(ram), expected)
        with self.assertRaises(ValueError):
            installer.suggested_swap(0)

    def test_ram_detection_converts_kernel_kib_to_bytes(self):
        with patch.object(
            Path,
            "read_text",
            return_value=(
                "Other: 123 kB\nMemTotal: 15728641 kB\nMemFree: 999 kB\n"
            ),
        ):
            self.assertEqual(installer.detect_ram(), 15 * GIB + 1024)
        for value in ["", "MemTotal: 0 kB\n", "MemTotal: unknown kB\n"]:
            with self.subTest(value=value):
                with patch.object(Path, "read_text", return_value=value):
                    with self.assertRaises(ValueError):
                        installer.detect_ram()

    def test_erase_reserves_efi_and_partition_metadata(self):
        storage = installer.plan_storage(disk(), "erase")
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
        storage = installer.plan_storage(target, "preserve")
        self.assertEqual(
            (storage.start, storage.end), (103079215104, 171798691840)
        )
        self.assertEqual(storage.capacity, 64 * GIB)
        self.assertEqual(target.partitions, before)
        self.assertEqual(storage.efi_size, 0)  # EFI is not yet resolved.

    def test_preserve_rounds_gaps_inward_to_mib_boundaries(self):
        storage = installer.plan_storage(
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
                    installer.plan_storage(target, mode)

    def test_preserve_requires_gpt_and_valid_nonoverlapping_extents(self):
        with self.assertRaisesRegex(ValueError, "GPT"):
            installer.plan_storage(disk(pttype="dos"), "preserve")
        for parts in [
            [partition(2048, 10 * GIB), partition(4096, 10 * GIB)],
            [partition(2048, 200 * GIB)],
        ]:
            with self.subTest(parts=parts):
                with self.assertRaisesRegex(ValueError, "partition metadata"):
                    installer.plan_storage(disk(children=parts), "preserve")
        for sector, size in [(None, GIB), (-1, GIB), (2048, 0)]:
            with self.subTest(sector=sector, size=size):
                with self.assertRaisesRegex(ValueError, "partition metadata"):
                    disk(children=[partition(sector, size)])

    def test_discovery_excludes_readonly_disks_zram_and_nondisks(self):
        disks = installer.parse_disks(
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
                            installer.plan_storage(target, mode)

    def test_username_validation(self):
        for name in ["river", "delta_bot", "_worker", "a" * 32]:
            self.assertIsNone(installer.username_error(name))
        for name in ["root", "River", "", "a" * 33, "user/name"]:
            with self.subTest(name=name):
                self.assertIsNotNone(installer.username_error(name))

    def test_swap_override_must_leave_space_and_be_a_positive_whole_gib(self):
        self.assertIsNone(installer.swap_error("15", 16 * GIB))
        self.assertIsNone(installer.swap_error("16", 16 * GIB + 1))
        for value in ["16", "0", "-1", "08", "1.5", "swap", "١", "9" * 100]:
            with self.subTest(value=value):
                self.assertIsNotNone(installer.swap_error(value, 16 * GIB))

    def test_key_validation_uses_real_openssh_without_private_keys(self):
        key_type = b"ssh-ed25519"
        wire = (
            struct.pack(">I", len(key_type))
            + key_type
            + struct.pack(">I", 32)
            + bytes(range(32))
        )
        key = "ssh-ed25519 " + base64.b64encode(wire).decode() + " fixture"
        self.assertRegex(installer.key_fingerprint(key), r"^256 SHA256:")
        self.assertEqual(installer.key_fingerprint(""), "none")
        for invalid in [
            "not a key",
            key + "\n" + key,
            "-----BEGIN OPENSSH PRIVATE KEY-----",
        ]:
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValueError):
                    installer.key_fingerprint(invalid)


class WizardTests(unittest.TestCase):
    def run_preview(
        self,
        answers: list[Any],
        metadata: dict[str, Any] | None = None,
        failure: Exception | None = None,
    ) -> tuple[int, str, Mock, list[list[str]]]:
        output = io.StringIO()
        calls: list[list[str]] = []

        def discovery(command: list[str], **_kwargs: Any) -> str:
            self.assertEqual(
                command[0], "lsblk", "Preview launched another tool"
            )
            calls.append(command)
            if failure:
                raise failure
            return json.dumps(metadata or {"blockdevices": [device()]})

        # Replace machine metadata and keyboard answers, not planning logic.
        # All other child processes are forbidden in these preview examples.
        with (
            redirect_stdout(output),
            redirect_stderr(output),
            patch.object(
                questionary.Question, "unsafe_ask", side_effect=answers
            ),
            patch.object(subprocess, "check_output", side_effect=discovery),
            patch.object(
                subprocess,
                "Popen",
                side_effect=AssertionError(
                    "Preview launched an unexpected child process"
                ),
            ),
            patch.object(
                Path, "read_text", return_value="MemTotal: 33554432 kB\n"
            ),
            patch.object(questionary, "text", wraps=questionary.text) as texts,
        ):
            status = installer.main()
        return status, output.getvalue(), texts, calls

    def test_preview_keeps_user_choices_and_makes_no_installation_calls(self):
        status, output, _, calls = self.run_preview(
            [
                "laptop",
                disk(),
                "erase",
                "river",
                "",
                "20",
                True,
            ]
        )
        self.assertEqual(status, 0)
        for text in [
            "Host: laptop",
            "User: river",
            "Swap: 20 GiB",
            "hibernation may fail",
            "Preview complete",
            "Nothing saved",
        ]:
            self.assertIn(text, output)
        self.assertTrue(calls)

    def test_oversized_suggestion_is_not_silently_capped(self):
        status, output, texts, _ = self.run_preview(
            [
                "desktop",
                disk(size=16 * GIB),
                "erase",
                "river",
                "",
                "6",
                True,
            ],
            metadata={"blockdevices": [device(size=16 * GIB)]},
        )
        self.assertEqual(status, 0)
        self.assertIn("Suggested swap: 48 GiB", output)
        self.assertIn("will not fit", output)
        self.assertEqual(texts.call_args.kwargs["default"], "48")
        self.assertIn("Swap: 6 GiB", output)

    def test_cancellation_at_every_prompt_exits_without_completing(self):
        answers = ["desktop", disk(), "erase", "river", "", "48", True]
        for index in range(len(answers)):
            with self.subTest(prompt=index):
                status, output, _, _ = self.run_preview(
                    answers[:index] + [KeyboardInterrupt()]
                )
                self.assertEqual(status, 0)
                self.assertIn("Planning cancelled", output)
                self.assertNotIn("Preview complete", output)
        for final in [False, None, EOFError()]:
            status, output, _, _ = self.run_preview(answers[:-1] + [final])
            self.assertEqual(status, 0)
            self.assertIn("Planning cancelled", output)
            self.assertNotIn("Preview complete", output)

    def test_discovery_errors_stop_before_a_preview(self):
        examples: list[tuple[dict[str, Any] | None, Exception | None]] = [
            ({"blockdevices": []}, None),
            (None, subprocess.CalledProcessError(3, "lsblk")),
        ]
        for metadata, failure in examples:
            with self.subTest(metadata=metadata, failure=failure):
                status, output, _, _ = self.run_preview(
                    ["desktop"],
                    metadata,
                    failure,
                )
                self.assertEqual(status, 1)
                self.assertIn("No changes made", output)
                self.assertNotIn("Preview complete", output)

    def test_real_questionary_rejects_invalid_username_before_returning(self):
        def validate(value: str) -> str | bool:
            return installer.username_error(value) or True

        with create_pipe_input() as keyboard:
            keyboard.send_text("root\r\x15river\r")
            answer = installer.ask(
                questionary.text(
                    "Username",
                    validate=validate,
                    input=keyboard,
                    output=DummyOutput(),
                )
            )
        self.assertEqual(answer, "river")

    def test_real_questionary_checks_swap_bounds(self):
        def validate(value: str) -> str | bool:
            return installer.swap_error(value, 16 * GIB) or True

        with create_pipe_input() as keyboard:
            keyboard.send_text("16\r\x1515\r")
            answer = installer.ask(
                questionary.text(
                    "Swap",
                    validate=validate,
                    input=keyboard,
                    output=DummyOutput(),
                )
            )
        self.assertEqual(answer, "15")

    def test_real_questionary_arrow_selection_and_ctrl_c(self):
        with create_pipe_input() as keyboard:
            keyboard.send_text("\x1b[B\r")
            self.assertEqual(
                installer.ask(
                    questionary.select(
                        "Host",
                        choices=["first", "second"],
                        input=keyboard,
                        output=DummyOutput(),
                    )
                ),
                "second",
            )
        with create_pipe_input() as keyboard:
            keyboard.send_text("\x03")
            with self.assertRaises(KeyboardInterrupt):
                installer.ask(
                    questionary.select(
                        "Host",
                        choices=["first", "second"],
                        input=keyboard,
                        output=DummyOutput(),
                    )
                )


if __name__ == "__main__":
    unittest.main()

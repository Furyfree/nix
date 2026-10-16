"""Wizard prompts, review and the launcher."""

import io
import json
import os
import subprocess
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any
from unittest.mock import Mock, patch

import install as launcher
import questionary
from helpers import GIB, device, disk, partition, public_key
from nixos_setup import common, planning, wizard
from prompt_toolkit.input import create_pipe_input
from prompt_toolkit.output import DummyOutput


class WizardTests(unittest.TestCase):
    def run_preview(
        self,
        answers: list[Any],
        metadata: dict[str, Any] | None = None,
        failure: Exception | None = None,
        argv: list[str] | None = None,
    ) -> tuple[int, str, Mock, list[list[str]]]:
        output = io.StringIO()
        calls: list[list[str]] = []
        open_file = io.open

        def read_only_open(
            file: Any, mode: str = "r", *args: Any, **kwargs: Any
        ) -> Any:
            self.assertFalse(
                any(flag in mode for flag in "wax+"),
                "Wizard opened a file for writing",
            )
            return open_file(file, mode, *args, **kwargs)

        def discovery(command: list[str], **_kwargs: Any) -> str:
            self.assertEqual(
                command[0], "lsblk", "Preview launched another tool"
            )
            calls.append(command)
            if failure:
                raise failure
            return json.dumps(metadata or {"blockdevices": [device()]})

        # Replace machine metadata and keyboard answers, not planning logic.
        # File writes and all other child processes are forbidden here.
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
            patch("builtins.open", side_effect=read_only_open),
            patch.object(io, "open", side_effect=read_only_open),
            patch.object(questionary, "text", wraps=questionary.text) as texts,
            patch.object(
                os,
                "memfd_create",
                side_effect=AssertionError(
                    "Preview created a credential file"
                ),
            ),
        ):
            status = launcher.main(["--dry-run"] if argv is None else argv)
        return status, output.getvalue(), texts, calls

    def test_preview_uses_defaults_without_asking_for_optional_settings(self):
        status, output, texts, calls = self.run_preview(
            ["nixos-test", disk(), "river", "Finish preview"]
        )
        self.assertEqual(status, 0)
        self.assertEqual(texts.call_count, 1)
        for text in [
            "Host: nixos-test",
            "User: river",
            "Swap: 48 GiB",
            "ERASE",
            "Preview complete",
            "Nothing saved",
            "latest main",
            "/home/river/Projects/nix",
            "root and your user",
        ]:
            self.assertIn(text, output)
        self.assertTrue(calls)

    def test_machine_choice_and_windows_on_another_disk_reach_the_plan(self):
        guid = "0f2c9a4e-1b7d-4c3a-9e8f-5a6b7c8d9e0f"
        with TemporaryDirectory(prefix="windows-esp-") as esp:
            loader = Path(esp).joinpath(*planning.WINDOWS_LOADER)
            loader.parent.mkdir(parents=True)
            loader.write_bytes(b"fixture loader")
            windows_disk = device(
                name="/dev/fixture1",
                children=[
                    partition(
                        2048,
                        GIB,
                        name="/dev/fixture1p1",
                        parttype=common.ESP_TYPE,
                        partuuid=guid.upper(),
                        mountpoints=[esp],
                    )
                ],
            )
            reviewed: list[Any] = []

            def install(plan: Any) -> int:
                reviewed.append(wizard.review_plan(plan, dry_run=False))
                return 0

            with patch.object(launcher, "install", side_effect=install):
                status, output, _, _ = self.run_preview(
                    [
                        "nixos-test",
                        disk(),
                        "river",
                        "Change settings",
                        "Machine",
                        "desktop",
                        "Continue to installation",
                    ],
                    metadata={"blockdevices": [device(), windows_disk]},
                    argv=[],
                )
        self.assertEqual(status, 0)
        self.assertEqual(
            (reviewed[0].host, reviewed[0].windows), ("desktop", guid)
        )
        self.assertIn("Host: desktop", output)
        self.assertIn(f"Windows: boot menu entry for partition {guid}", output)

    def test_changed_settings_survive_review_and_reach_the_installer(self):
        answers = [
            "nixos-test",
            disk(),
            "river",
            "Change settings",
            "Swap size",
            "20",
            "Change settings",
            "Username",
            "delta_bot",
            "Continue to installation",
        ]
        reviewed: list[Any] = []

        def install(plan: Any) -> int:
            reviewed.append(wizard.review_plan(plan, dry_run=False))
            return 0

        with patch.object(launcher, "install", side_effect=install):
            status, output, _, _ = self.run_preview(answers, argv=[])
        self.assertEqual(status, 0)
        plan = reviewed[0]
        self.assertEqual((plan.username, plan.swap_gib), ("delta_bot", 20))
        self.assertIn("hibernation may fail", output)
        self.assertIn("/home/delta_bot/Projects/nix", output)

    def test_public_key_changes_are_validated_and_retained(self):
        key = public_key()
        reviewed: list[Any] = []

        def install(plan: Any) -> int:
            reviewed.append(wizard.review_plan(plan, dry_run=False))
            return 0

        with patch.object(
            wizard,
            "key_fingerprint",
            side_effect=[ValueError("invalid key"), "fixture fingerprint"],
        ):
            with patch.object(launcher, "install", side_effect=install):
                status, output, _, _ = self.run_preview(
                    [
                        "nixos-test",
                        disk(),
                        "river",
                        "Change settings",
                        "SSH public key",
                        "invalid",
                        key,
                        "Continue to installation",
                    ],
                    argv=[],
                )
        self.assertEqual(status, 0)
        self.assertIn("invalid key", output)
        self.assertEqual(reviewed[0].ssh_key, key)
        self.assertEqual(reviewed[0].fingerprint, "fixture fingerprint")

    def test_default_installation_refuses_unsafe_environment_without_writes(
        self,
    ):
        status, output, _, calls = self.run_preview(
            ["nixos-test", disk(), "river"],
            argv=[],
        )
        self.assertEqual(status, 1)
        self.assertIn("Installation failed", output)
        self.assertIn("No disk changes made", output)
        self.assertNotIn("Preview complete", output)
        self.assertTrue(calls)

    def test_default_mode_dispatches_to_install_but_dry_run_does_not(self):
        with patch.object(launcher, "install", return_value=0) as install:
            status, _, _, _ = self.run_preview(
                ["nixos-test", disk(), "river", "Continue to installation"],
                argv=[],
            )
            self.assertEqual(status, 0)
            self.assertEqual(install.call_args.args[0].username, "river")
            install.reset_mock()
            status, _, _, _ = self.run_preview(
                ["nixos-test", disk(), "river", "Finish preview"],
            )
            self.assertEqual(status, 0)
            install.assert_not_called()

    def test_help_and_invalid_flags_stop_before_the_wizard(self):
        for argv, status in [
            (["--help"], 0),
            (["--dry-rnu"], 2),
            (["--dry-run", "--unknown"], 2),
        ]:
            with (
                self.subTest(argv=argv),
                redirect_stdout(io.StringIO()),
                redirect_stderr(io.StringIO()),
                patch.object(launcher, "collect_plan") as collect,
            ):
                with self.assertRaises(SystemExit) as error:
                    launcher.main(argv)
                self.assertEqual(error.exception.code, status)
                collect.assert_not_called()

    def test_oversized_suggestion_is_not_silently_capped(self):
        status, output, texts, _ = self.run_preview(
            [
                "nixos-test",
                disk(size=16 * GIB),
                "river",
                "6",
                "Finish preview",
            ],
            metadata={"blockdevices": [device(size=16 * GIB)]},
        )
        self.assertEqual(status, 0)
        self.assertIn("Suggested swap (48 GiB)", output)
        self.assertIn("will not fit", output)
        self.assertEqual(texts.call_args.kwargs["default"], "48")
        self.assertIn("Swap: 6 GiB", output)

    def test_cancellation_at_every_prompt_exits_without_completing(self):
        answers = [
            "nixos-test",
            disk(),
            "river",
            "Change settings",
            "Swap size",
            "20",
            "Change settings",
            "Username",
            "delta_bot",
            "Finish preview",
        ]
        modes: list[list[str] | None] = [None, []]
        for argv in modes:
            prompts = answers if argv is None else answers[:3]
            for index in range(len(prompts)):
                for error in [KeyboardInterrupt(), EOFError(), None]:
                    with self.subTest(
                        argv=argv, prompt=index, error=type(error)
                    ):
                        status, output, _, _ = self.run_preview(
                            prompts[:index] + [error], argv=argv
                        )
                        self.assertEqual(status, 0)
                        self.assertIn("Planning cancelled", output)
                        self.assertNotIn("Preview complete", output)
        status, output, _, _ = self.run_preview(
            ["nixos-test", disk(), "river", "Cancel"]
        )
        self.assertEqual(status, 0)
        self.assertIn("Planning cancelled", output)

    def test_disk_change_requires_a_swap_override_when_it_no_longer_fits(self):
        small = disk(size=16 * GIB)
        reviewed: list[Any] = []

        def install(plan: Any) -> int:
            reviewed.append(wizard.review_plan(plan, dry_run=False))
            return 0

        with patch.object(launcher, "install", side_effect=install):
            status, _, _, _ = self.run_preview(
                [
                    "nixos-test",
                    disk(),
                    "river",
                    "Change settings",
                    "Disk",
                    small,
                    "6",
                    "Continue to installation",
                ],
                argv=[],
            )
        self.assertEqual(status, 0)
        self.assertEqual(reviewed[0].storage.disk, small)
        self.assertEqual(reviewed[0].swap_gib, 6)

    def test_discovery_errors_stop_before_a_preview(self):
        examples: list[tuple[dict[str, Any] | None, Exception | None]] = [
            ({"blockdevices": []}, None),
            (None, subprocess.CalledProcessError(3, "lsblk")),
        ]
        for metadata, failure in examples:
            with self.subTest(metadata=metadata, failure=failure):
                status, output, _, _ = self.run_preview(
                    ["nixos-test"],
                    metadata,
                    failure,
                )
                self.assertEqual(status, 1)
                self.assertIn("No changes made", output)
                self.assertNotIn("Preview complete", output)

    def test_real_questionary_rejects_invalid_username_before_returning(self):
        def validate(value: str) -> str | bool:
            return planning.username_error(value) or True

        with create_pipe_input() as keyboard:
            keyboard.send_text("root\r\x15river\r")
            answer = wizard.ask(
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
            return planning.swap_error(value, 16 * GIB) or True

        with create_pipe_input() as keyboard:
            keyboard.send_text("16\r\x1515\r")
            answer = wizard.ask(
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
                wizard.ask(
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
                wizard.ask(
                    questionary.select(
                        "Host",
                        choices=["first", "second"],
                        input=keyboard,
                        output=DummyOutput(),
                    )
                )


if __name__ == "__main__":
    unittest.main()

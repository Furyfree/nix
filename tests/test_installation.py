"""Native installation and the install flow."""

import io
import os
import shutil
import subprocess
import sys
import unittest
from collections.abc import Generator
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from typing import Any, final
from unittest.mock import Mock, patch

import questionary
from helpers import GIB, disk
from nixos_setup import common, credentials, installation, planning


@final
class InstallationTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.directory = TemporaryDirectory(prefix="installer-finish-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name) / "target"
        password_file = credentials.memory_file()
        self.password_fd = password_file.__enter__()
        self.addCleanup(password_file.__exit__, None, None, None)
        os.write(self.password_fd, b"disposable fixture")
        self.plan = common.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            planning.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        self.storage = common.PreparedStorage(
            self.root,
            "/dev/fixture-efi",
            "/dev/fixture-luks",
            "/dev/mapper/cryptroot",
            24680,
            self.password_fd,
        )
        self.repo = self.root / "home/river/Projects/nix"
        (self.repo / ".git").mkdir(parents=True)
        (self.repo / "flake.lock").write_text("unchanged lock")
        (self.root / "boot/efi/limine").mkdir(parents=True)
        (self.root / "boot/efi/limine/BOOTX64.EFI").write_bytes(b"efi fixture")
        (self.root / "boot/limine").mkdir()
        (self.root / "boot/limine/limine.conf").write_text(
            "cmdline: init=/nix/store/fixture-system/init "
            "resume_offset=24680\n"
        )
        (self.root / "var/swap").mkdir(parents=True)
        (self.root / "var/swap/swapfile").write_text("fixture swap")
        self.commands: list[list[str]] = []
        self.output = io.StringIO()
        self.uid, self.gid = 4321, 5678
        self.password_status = "P"
        self.installed_system = "/nix/store/fixture-system"
        self.swap_size, self.offset = 48 * GIB, 24680
        self.git_result = "true"

    @contextmanager
    def environment(self) -> Generator[Mock]:
        original_stat = Path.stat

        def stat(path: Path, **kwargs: Any) -> Any:
            actual = original_stat(path, **kwargs)
            return SimpleNamespace(
                st_mode=actual.st_mode,
                st_uid=self.uid,
                st_gid=self.gid,
                st_size=(
                    self.swap_size
                    if path.name == "swapfile"
                    else actual.st_size
                ),
            )

        def run(command: list[str], **kwargs: Any) -> Any:
            self.assertTrue(kwargs["check"])
            for key in ["input", "capture_output"]:
                self.assertNotIn(
                    key, kwargs, "Password text must stay outside Python"
                )
            self.commands.append(command)
            return subprocess.CompletedProcess[str](command, 0)

        def probe(command: list[str], **_kwargs: Any) -> str:
            self.commands.append(command)
            if command[0] == "git":
                return self.git_result
            if command[0] == "btrfs":
                return str(self.offset)
            self.assertEqual(
                command[:4], ["nixos-enter", "--root", str(self.root), "--"]
            )
            tool = Path(command[4]).name
            if tool == "passwd":
                return f"{command[-1]} {self.password_status} 2026-01-01"
            if tool == "id":
                return str(self.uid if command[5] == "-u" else self.gid)
            self.assertEqual(tool, "readlink")
            return self.installed_system

        def passwords(_plan: Any, storage: Any) -> None:
            subprocess.run(
                common.enter_command(
                    storage, "/nix/var/nix/profiles/system/sw/bin/chpasswd"
                ),
                check=True,
            )

        with (
            redirect_stdout(self.output),
            redirect_stderr(self.output),
            patch.object(Path, "stat", autospec=True, side_effect=stat),
            patch.object(subprocess, "run", side_effect=run) as execute,
            patch.object(subprocess, "check_output", side_effect=probe),
            patch.object(
                installation,
                "set_passwords",
                side_effect=passwords,
            ),
            patch.object(
                installation,
                "evaluate_configuration",
                return_value={
                    "system": "/nix/store/fixture-system",
                    "removable": False,
                },
            ),
            patch.object(
                subprocess,
                "Popen",
                side_effect=AssertionError(
                    "Installation tests must not launch real processes"
                ),
            ),
        ):
            yield execute

    def test_native_install_passwords_and_real_account_ids_are_used(self):
        with self.environment():
            installation.finish_installation(
                self.plan, self.storage, self.repo
            )
        install = self.commands[0]
        self.assertEqual(install[0], "nixos-install")
        self.assertIn(f"path:{self.repo}#nixos-test", install)
        self.assertIn("--no-channel-copy", install)
        self.assertIn("--no-write-lock-file", install)
        self.assertIn("--no-update-lock-file", install)
        self.assertIn("--no-root-password", install)
        self.assertNotIn("--no-bootloader", install)
        self.assertTrue(
            any(
                Path(c[4]).name == "chpasswd"
                for c in self.commands
                if c[0] == "nixos-enter"
            )
        )
        ownership = [
            c
            for c in self.commands
            if c[0] == "nixos-enter" and Path(c[4]).name == "chown"
        ]
        self.assertEqual(len(ownership), 2)
        for command in ownership:
            self.assertIn("4321:5678", command)
            self.assertIn("--no-dereference", command)
        self.assertNotIn("systemctl", [c[0] for c in self.commands])
        self.assertEqual(
            (self.repo / "flake.lock").read_text(), "unchanged lock"
        )

    def test_native_command_failure_stops_without_retry(self):
        with self.environment():
            installation.finish_installation(
                self.plan, self.storage, self.repo
            )
        steps = [
            c
            for c in self.commands
            if c[0] == "nixos-install"
            or c[0] == "nixos-enter"
            and Path(c[4]).name in {"chpasswd", "chown", "test"}
            and "--status" not in c
        ]
        for failed in steps:
            self.commands.clear()
            with self.subTest(command=failed), self.environment() as execute:
                original = execute.side_effect

                def run(
                    command: list[str],
                    failed: list[str] = failed,
                    original: Any = original,
                    **kwargs: Any,
                ) -> Any:
                    result = original(command, **kwargs)
                    if command == failed:
                        raise subprocess.CalledProcessError(1, command)
                    return result

                execute.side_effect = run
                with self.assertRaises(subprocess.CalledProcessError):
                    installation.finish_installation(
                        self.plan, self.storage, self.repo
                    )
                self.assertEqual(self.commands[-1], failed)
                self.assertEqual(self.commands.count(failed), 1)

    def test_missing_password_or_postinstall_mismatch_rejects_completion(self):
        for field, value in [
            ("password_status", "L"),
            ("installed_system", "/nix/store/wrong"),
            ("uid", 0),
            ("swap_size", 24 * GIB),
            ("offset", 13579),
            ("git_result", "false"),
        ]:
            previous = getattr(self, field)
            setattr(self, field, value)
            try:
                with self.subTest(field=field), self.environment():
                    with self.assertRaises(ValueError):
                        installation.finish_installation(
                            self.plan, self.storage, self.repo
                        )
            finally:
                setattr(self, field, previous)
        (self.root / "boot/efi/limine/BOOTX64.EFI").unlink()
        with self.environment(), self.assertRaisesRegex(ValueError, "EFI"):
            installation.finish_installation(
                self.plan, self.storage, self.repo
            )

    def test_wrong_checkout_refuses_native_install(self):
        with self.environment(), self.assertRaisesRegex(ValueError, "home"):
            installation.finish_installation(
                self.plan, self.storage, self.root / "wrong"
            )
        self.assertFalse(self.commands)


@final
class InstallFlowTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.plan = common.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            planning.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        self.output = io.StringIO()
        self.events: list[str] = []
        self.error: BaseException | None = None
        self.phase = ""
        self.reboot = False
        self.confirmation = self.plan.storage.disk.path
        self.reviewed_plan = self.plan
        self.password_fd = -1

    @contextmanager
    def environment(self) -> Generator[Mock]:
        @contextmanager
        def password() -> Generator[int]:
            self.events.append("password")
            if self.phase == "password" and self.error:
                raise self.error
            with credentials.memory_file() as fd:
                os.write(fd, b"disposable flow fixture")
                self.password_fd = fd
                try:
                    yield fd
                finally:
                    self.events.append("password-cleanup")

        def review(_plan: Any, *, dry_run: bool) -> Any:
            self.events.append("review")
            self.assertFalse(dry_run)
            self.assertGreater(os.fstat(self.password_fd).st_size, 0)
            if self.phase == "review" and self.error:
                raise self.error
            return self.reviewed_plan

        @contextmanager
        def checkout(_plan: Any) -> Generator[Path]:
            self.events.append("clone")
            self.assertEqual(_plan, self.reviewed_plan)
            if self.phase == "clone" and self.error:
                raise self.error
            try:
                yield Path("/fixture-checkout")
            finally:
                self.events.append("clone-cleanup")

        @contextmanager
        def storage(
            _plan: Any,
            *,
            password_fd: int,
            confirmation: str,
            before_write: Any,
        ) -> Generator[Any]:
            self.assertEqual(_plan, self.reviewed_plan)
            self.assertEqual(password_fd, self.password_fd)
            self.assertEqual(
                confirmation, self.reviewed_plan.storage.disk.path
            )
            self.assertGreater(os.fstat(password_fd).st_size, 0)
            if self.phase == "storage" and self.error:
                raise self.error
            before_write()
            self.events.append("write")
            try:
                yield common.PreparedStorage(
                    Path("/mnt"),
                    "/efi",
                    "/luks",
                    "/dev/mapper/cryptroot",
                    24680,
                    password_fd,
                )
            finally:
                self.events.append("storage-cleanup")
                if self.phase == "cleanup" and self.error:
                    raise self.error

        def generate(*_args: Any) -> Path:
            self.assertEqual(_args[0], self.reviewed_plan)
            self.events.append("generate")
            if self.phase == "generate" and self.error:
                raise self.error
            return Path("/mnt/home/river/Projects/nix")

        def finish(*_args: Any) -> None:
            self.assertEqual(_args[0], self.reviewed_plan)
            self.events.append("install")
            if self.phase == "install" and self.error:
                raise self.error

        def prompt(*_args: Any) -> str | bool:
            if "confirmation" not in self.events:
                self.events.append("confirmation")
                if self.phase == "confirmation" and self.error:
                    raise self.error
                return self.confirmation
            with self.assertRaises(OSError):
                os.fstat(self.password_fd)
            self.events.append("reboot-question")
            if self.phase == "reboot" and self.error:
                raise self.error
            return self.reboot

        def run(command: list[str], **_kwargs: Any) -> Any:
            self.assertEqual(command, ["systemctl", "reboot"])
            self.events.append("reboot")
            if self.phase == "reboot-command" and self.error:
                raise self.error
            return subprocess.CompletedProcess[str](command, 0)

        with (
            redirect_stdout(self.output),
            redirect_stderr(self.output),
            patch.object(sys.stdin, "isatty", return_value=True),
            patch.object(installation, "storage_preflight") as preflight,
            patch.object(shutil, "which", return_value="fixture"),
            patch.object(
                installation, "native_password", side_effect=password
            ),
            patch.object(installation, "review_plan", side_effect=review),
            patch.object(
                installation, "prepare_checkout", side_effect=checkout
            ),
            patch.object(installation, "prepare_storage", side_effect=storage),
            patch.object(
                installation, "generate_configuration", side_effect=generate
            ),
            patch.object(
                installation, "finish_installation", side_effect=finish
            ),
            patch.object(installation, "ask", side_effect=prompt),
            patch.object(subprocess, "run", side_effect=run),
            patch.object(
                subprocess,
                "Popen",
                side_effect=AssertionError(
                    "Flow tests must not launch real processes"
                ),
            ),
        ):
            yield preflight

    def test_success_cleans_resources_before_optional_reboot(self):
        for reboot in [False, True]:
            self.events.clear()
            self.reboot = reboot
            with (
                self.subTest(reboot=reboot),
                self.environment(),
                patch.object(
                    questionary, "confirm", wraps=questionary.confirm
                ) as confirm,
            ):
                self.assertEqual(installation.install(self.plan), 0)
                self.assertIs(confirm.call_args.kwargs["default"], False)
            self.assertEqual(
                self.events[:10],
                [
                    "password",
                    "review",
                    "confirmation",
                    "clone",
                    "write",
                    "generate",
                    "install",
                    "storage-cleanup",
                    "clone-cleanup",
                    "password-cleanup",
                ],
            )
            self.assertEqual(
                self.events[10:],
                ["reboot-question", "reboot"]
                if reboot
                else ["reboot-question"],
            )

    def test_failure_before_or_after_writes_reports_correct_disk_state(self):
        for phase in [
            "password",
            "review",
            "confirmation",
            "clone",
            "storage",
            "generate",
            "install",
            "cleanup",
        ]:
            self.events.clear()
            self.output.seek(0)
            self.output.truncate()
            self.phase, self.error = phase, ValueError("fixture failure")
            with self.subTest(phase=phase), self.environment():
                self.assertEqual(installation.install(self.plan), 1)
            self.assertNotIn("reboot-question", self.events)
            if phase in {
                "password",
                "review",
                "confirmation",
                "clone",
                "storage",
            }:
                self.assertIn("No disk changes made", self.output.getvalue())
                self.assertNotIn("write", self.events)
            else:
                self.assertIn("disk was modified", self.output.getvalue())
                self.assertIn("storage-cleanup", self.events)
                self.assertIn("clone-cleanup", self.events)
                self.assertNotIn(
                    "No disk changes made", self.output.getvalue()
                )
            if phase != "password":
                self.assertIn("password-cleanup", self.events)
                with self.assertRaises(OSError):
                    os.fstat(self.password_fd)
            if phase in {"password", "review", "confirmation"}:
                self.assertNotIn("clone", self.events)

    def test_cancellation_and_reboot_cancellation_have_distinct_results(self):
        for phase, expected in [
            ("password", 0),
            ("review", 0),
            ("confirmation", 0),
            ("clone", 0),
            ("install", 1),
            ("reboot", 0),
        ]:
            self.events.clear()
            self.output.seek(0)
            self.output.truncate()
            self.phase, self.error = phase, KeyboardInterrupt()
            with self.subTest(phase=phase), self.environment():
                self.assertEqual(installation.install(self.plan), expected)
            self.assertNotIn("reboot", self.events)
            if phase != "password":
                with self.assertRaises(OSError):
                    os.fstat(self.password_fd)
            if phase in {"password", "review", "confirmation"}:
                self.assertNotIn("clone", self.events)
                self.assertNotIn("write", self.events)
            if phase == "install":
                self.assertIn("disk was modified", self.output.getvalue())
            if phase == "reboot":
                self.assertIn(
                    "installation is complete", self.output.getvalue()
                )

    def test_failed_reboot_keeps_installation_success_message(self):
        self.reboot = True
        self.phase = "reboot-command"
        self.error = subprocess.CalledProcessError(1, ["systemctl", "reboot"])
        with self.environment():
            self.assertEqual(installation.install(self.plan), 1)
        self.assertIn("Installation complete", self.output.getvalue())
        self.assertIn("reboot failed", self.output.getvalue())
        self.assertEqual(
            self.events[-5:],
            [
                "storage-cleanup",
                "clone-cleanup",
                "password-cleanup",
                "reboot-question",
                "reboot",
            ],
        )

    def test_review_changes_reach_cloning_storage_and_configuration(self):
        self.reviewed_plan = replace(
            self.plan,
            username="delta_bot",
            swap_gib=24,
            storage=planning.plan_storage(disk(name="/dev/fixture1"), "erase"),
        )
        self.confirmation = self.reviewed_plan.storage.disk.path
        with self.environment():
            self.assertEqual(installation.install(self.plan), 0)
        self.assertEqual(self.events.count("password"), 1)

    def test_confirmation_mismatch_never_clones_and_releases_password(self):
        self.confirmation = "/dev/other"
        with self.environment():
            self.assertEqual(installation.install(self.plan), 1)
        self.assertNotIn("clone", self.events)
        self.assertNotIn("write", self.events)
        self.assertIn("No disk changes made", self.output.getvalue())
        with self.assertRaises(OSError):
            os.fstat(self.password_fd)

    def test_reviewed_disk_must_pass_preflight_before_authorization(self):
        with self.environment() as preflight:
            preflight.side_effect = [None, ValueError("changed during review")]
            self.assertEqual(installation.install(self.plan), 1)
        self.assertNotIn("confirmation", self.events)
        self.assertNotIn("clone", self.events)
        with self.assertRaises(OSError):
            os.fstat(self.password_fd)

    def test_preflight_failures_stop_before_clone(
        self,
    ):
        with self.environment():
            with patch.object(sys.stdin, "isatty", return_value=False):
                self.assertEqual(installation.install(self.plan), 1)
            self.assertFalse(self.events)
            with patch.object(shutil, "which", return_value=None):
                self.assertEqual(installation.install(self.plan), 1)
            self.assertFalse(self.events)
        with self.environment() as preflight:
            preflight.side_effect = ValueError("busy disk")
            self.assertEqual(installation.install(self.plan), 1)
            self.assertFalse(self.events)


if __name__ == "__main__":
    unittest.main()

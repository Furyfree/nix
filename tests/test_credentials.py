"""Native password handling."""

import fcntl
import io
import os
import pty
import select
import shutil
import signal
import subprocess
import sys
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any
from unittest.mock import patch

from helpers import GIB, disk
from nixos_setup import common, credentials, planning


class CredentialTests(unittest.TestCase):
    def test_real_native_prompts_confirm_without_echoing_password_text(self):
        if __name__ != "__main__":
            # xdist has threads; fork the TTY only in a fresh interpreter.
            result = subprocess.run(
                [
                    sys.executable,
                    __file__,
                    self.id().removeprefix(__name__ + "."),
                ],
                capture_output=True,
                text=True,
                timeout=25,
                check=False,
                # The fresh interpreter needs pytest's path to the package.
                env={
                    **os.environ,
                    "PYTHONPATH": str(
                        Path(__file__).resolve().parents[1] / "scripts"
                    ),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return
        pid, terminal = pty.fork()
        if pid == 0:
            try:
                with credentials.native_password() as fd:
                    matches = os.pread(fd, 100, 0) == b"disposable-tty-fixture"
                os._exit(0 if matches else 1)
            except BaseException:
                os._exit(1)
        finished = False
        output = b""
        prompts = [b"Password for disk, root and user:", b"Confirm password:"]
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                child, status = os.waitpid(pid, os.WNOHANG)
                if child:
                    finished = True
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0)
                    break
                readable, _, _ = select.select([terminal], [], [], 0.1)
                if readable:
                    try:
                        output += os.read(terminal, 4096)
                    except OSError:
                        continue
                if prompts and prompts[0] in output:
                    prompts.pop(0)
                    os.write(terminal, b"disposable-tty-fixture\n")
            self.assertTrue(finished, "Native password prompt timed out")
            self.assertFalse(prompts, "Both native prompts must appear")
            self.assertNotIn(b"disposable-tty-fixture", output)
        finally:
            if not finished:
                os.killpg(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
            os.close(terminal)

    def test_native_confirmation_retries_and_closes_secret_handles(self):
        original_run: Any = subprocess.run
        handles: list[int] = []
        answers = iter(
            [
                b"",
                b"",
                b"first fixture",
                b"different fixture",
                b"matched fixture",
                b"matched fixture",
            ]
        )

        def run(command: list[str], **kwargs: Any) -> Any:
            self.assertNotIn("input", kwargs)
            self.assertNotIn("capture_output", kwargs)
            if command[0] == "systemd-ask-password":
                fd = kwargs["stdout"]
                handles.append(fd)
                self.assertEqual(os.fstat(fd).st_mode & 0o777, 0o600)
                self.assertIn("-n", command)
                os.write(fd, next(answers))
                return subprocess.CompletedProcess[bytes](command, 0)
            result: subprocess.CompletedProcess[bytes] = original_run(
                command, **kwargs
            )
            return result

        with (
            patch.object(subprocess, "run", side_effect=run),
            redirect_stdout(io.StringIO()),
        ):
            with credentials.native_password() as fd:
                self.assertEqual(os.pread(fd, 100, 0), b"matched fixture")
                with self.assertRaises(OSError):
                    os.write(fd, b"cannot overwrite")
                self.assertTrue(
                    fcntl.fcntl(fd, fcntl.F_GETFD) & fcntl.FD_CLOEXEC
                )
        self.assertEqual(len(handles), 6)
        for handle in set(handles):
            with self.assertRaises(OSError):
                os.fstat(handle)

    @unittest.skipUnless(
        shutil.which("cryptsetup"), "cryptsetup is not on PATH"
    )
    def test_real_cryptsetup_uses_the_shared_fd_without_opening_a_mapper(self):
        # Both the LUKS image and keys are anonymous memory files, never disks.
        with (
            credentials.memory_file() as image,
            credentials.memory_file() as password,
            credentials.memory_file() as wrong,
        ):
            os.ftruncate(image, 64 * 1024**2)
            os.write(password, b"disposable crypto fixture")
            os.write(wrong, b"wrong fixture")
            credentials.seal_file(password)
            credentials.seal_file(wrong)
            target = f"/proc/self/fd/{image}"
            common.run_command(
                [
                    "cryptsetup",
                    "luksFormat",
                    "--type",
                    "luks2",
                    "--batch-mode",
                    "--pbkdf",
                    "pbkdf2",
                    "--pbkdf-force-iterations",
                    "1000",
                    "--key-file",
                    f"/proc/self/fd/{password}",
                    target,
                ],
                pass_fds=(image, password),
                timeout=30,
            )
            for fd, expected in [(password, 0), (wrong, 2)]:
                result = subprocess.run(
                    [
                        "cryptsetup",
                        "open",
                        "--test-passphrase",
                        "--key-file",
                        f"/proc/self/fd/{fd}",
                        target,
                    ],
                    pass_fds=(image, fd),
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=10,
                    check=False,
                )
                self.assertEqual(result.returncode, expected)

    def test_native_password_failure_or_cancel_releases_all_handles(self):
        original_create = os.memfd_create
        for error in [
            KeyboardInterrupt(),
            subprocess.CalledProcessError(1, ["systemd-ask-password"]),
            subprocess.TimeoutExpired(["systemd-ask-password"], 190),
        ]:
            handles: list[int] = []

            def create(
                *args: Any, handles: list[int] = handles, **kwargs: Any
            ) -> int:
                fd = original_create(*args, **kwargs)
                handles.append(fd)
                return fd

            with (
                self.subTest(error=type(error)),
                patch.object(os, "memfd_create", side_effect=create),
                patch.object(subprocess, "run", side_effect=error),
            ):
                with self.assertRaises(type(error)):
                    with credentials.native_password():
                        self.fail("Failed password prompt yielded a password")
            for fd in handles:
                with self.assertRaises(OSError):
                    os.fstat(fd)

    def test_native_tools_build_account_input_without_a_python_password_string(
        self,
    ):
        plan = common.Plan(
            "nixos-test",
            "delta_bot",
            "",
            "none",
            planning.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        with credentials.memory_file() as password:
            os.write(password, b"fixture: spaces and unicode \xc3\xa6")
            storage = common.PreparedStorage(
                Path("/mnt"), "/efi", "/luks", common.MAPPER, 1, password
            )
            records: list[int] = []
            original_read = os.read
            original_pread = os.pread
            original_open: Any = io.open

            def read(fd: int, size: int) -> bytes:
                self.assertNotEqual(fd, password, "Python read password bytes")
                return original_read(fd, size)

            def pread(fd: int, size: int, offset: int) -> bytes:
                self.assertNotEqual(fd, password, "Python read password bytes")
                return original_pread(fd, size, offset)

            def open_file(file: Any, *args: Any, **kwargs: Any) -> Any:
                self.assertFalse(
                    file == password or str(file).startswith("/proc/self/fd/"),
                    "Python opened the password for reading",
                )
                return original_open(file, *args, **kwargs)

            def consume(command: list[str], **kwargs: Any) -> None:
                self.assertEqual(
                    command,
                    common.enter_command(
                        storage, "/nix/var/nix/profiles/system/sw/bin/chpasswd"
                    ),
                )
                fd = kwargs["stdin"]
                records.append(fd)
                self.assertEqual(
                    original_read(fd, 1000),
                    b"root:fixture: spaces and unicode \xc3\xa6\n"
                    b"delta_bot:fixture: spaces and unicode \xc3\xa6\n",
                )
                with self.assertRaises(OSError):
                    os.write(fd, b"cannot overwrite")

            with (
                patch.object(credentials, "run_command", side_effect=consume),
                patch.object(os, "read", side_effect=read),
                patch.object(os, "pread", side_effect=pread),
                patch("builtins.open", side_effect=open_file),
                patch.object(io, "open", side_effect=open_file),
            ):
                credentials.set_passwords(plan, storage)
            self.assertEqual(len(records), 1)
            with self.assertRaises(OSError):
                os.fstat(records[0])
            os.fstat(password)

    def test_account_input_is_released_if_native_password_setting_fails(self):
        plan = common.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            planning.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        records: list[int] = []
        with credentials.memory_file() as password:
            os.write(password, b"fixture")
            storage = common.PreparedStorage(
                Path("/mnt"), "/efi", "/luks", common.MAPPER, 1, password
            )

            def fail(command: list[str], **kwargs: Any) -> None:
                records.append(kwargs["stdin"])
                raise subprocess.CalledProcessError(1, command)

            with patch.object(credentials, "run_command", side_effect=fail):
                with self.assertRaises(subprocess.CalledProcessError):
                    credentials.set_passwords(plan, storage)
            with self.assertRaises(OSError):
                os.fstat(records[0])

    def test_routine_output_is_quiet_but_failed_commands_show_diagnostics(
        self,
    ):
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(output):
            common.run_command(["printf", "routine output"])
            self.assertEqual(output.getvalue(), "")
            with self.assertRaises(subprocess.CalledProcessError):
                common.run_command(
                    ["ls", "--", "/missing-installer-fixture-path"]
                )
        self.assertIn("missing-installer-fixture-path", output.getvalue())


if __name__ == "__main__":
    unittest.main()

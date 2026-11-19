"""Native password entry kept outside Python strings."""

import fcntl
import os
import subprocess
from collections.abc import Generator
from contextlib import contextmanager

from nixos_setup.common import (
    Plan,
    PreparedStorage,
    enter_command,
    run_command,
)


@contextmanager
def memory_file() -> Generator[int]:
    fd = os.memfd_create("nixos-setup", os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
    try:
        os.fchmod(fd, 0o600)
        yield fd
    finally:
        os.close(fd)


def seal_file(fd: int) -> None:
    fcntl.fcntl(
        fd,
        fcntl.F_ADD_SEALS,
        fcntl.F_SEAL_WRITE
        | fcntl.F_SEAL_GROW
        | fcntl.F_SEAL_SHRINK
        | fcntl.F_SEAL_SEAL,
    )


@contextmanager
def native_password() -> Generator[int]:
    """Only native tools read/write password bytes; Python owns the handles."""
    with memory_file() as password:
        with memory_file() as confirmation:
            while True:
                for fd, prompt in (
                    (password, "Password for disk, root and user:"),
                    (confirmation, "Confirm password:"),
                ):
                    os.ftruncate(fd, 0)
                    os.lseek(fd, 0, os.SEEK_SET)
                    subprocess.run(
                        [
                            "systemd-ask-password",
                            "-n",
                            "--echo=masked",
                            "--timeout=180",
                            prompt,
                        ],
                        stdout=fd,
                        check=True,
                        timeout=190,
                    )
                result = subprocess.run(
                    [
                        "cmp",
                        "--silent",
                        f"/proc/self/fd/{password}",
                        f"/proc/self/fd/{confirmation}",
                    ],
                    pass_fds=(password, confirmation),
                    check=False,
                    timeout=10,
                )
                if result.returncode not in (0, 1):
                    raise subprocess.CalledProcessError(
                        result.returncode, result.args
                    )
                if result.returncode == 0 and os.fstat(password).st_size > 0:
                    break
                print("Passwords must be nonempty and match. Try again.")
        seal_file(password)
        yield password


def set_passwords(plan: Plan, storage: PreparedStorage) -> None:
    with memory_file() as records:
        for user in ("root", plan.username):
            subprocess.run(
                ["printf", "%s:", user], stdout=records, check=True, timeout=10
            )
            subprocess.run(
                ["cat", f"/proc/self/fd/{storage.password_fd}"],
                pass_fds=(storage.password_fd,),
                stdout=records,
                check=True,
                timeout=10,
            )
            subprocess.run(
                ["printf", "\\n"], stdout=records, check=True, timeout=10
            )
        seal_file(records)
        os.lseek(records, 0, os.SEEK_SET)
        run_command(
            enter_command(
                storage, "/nix/var/nix/profiles/system/sw/bin/chpasswd"
            ),
            stdin=records,
            timeout=60,
        )

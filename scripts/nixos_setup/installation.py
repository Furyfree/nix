"""Native installation, verification and the overall flow."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

import questionary

from nixos_setup.common import (
    GIB,
    Plan,
    PreparedStorage,
    command_output,
    enter_command,
    run_command,
)
from nixos_setup.configuration import (
    evaluate_configuration,
    generate_configuration,
    prepare_checkout,
)
from nixos_setup.credentials import native_password, set_passwords
from nixos_setup.storage import prepare_storage, storage_preflight
from nixos_setup.wizard import ask, review_plan


def finish_installation(
    plan: Plan, storage: PreparedStorage, repo: Path
) -> None:
    expected_repo = storage.root / "home" / plan.username / "Projects/nix"
    if repo != expected_repo:
        raise ValueError("Installation checkout is outside the chosen home.")
    before = (repo / "flake.lock").read_bytes()
    expected = evaluate_configuration(repo, plan, storage.resume_offset)
    if storage.password_fd < 0 or os.fstat(storage.password_fd).st_size == 0:
        raise ValueError("Missing shared installation password.")
    print("Installing NixOS...")
    run_command(
        [
            "nixos-install",
            "--root",
            str(storage.root),
            "--flake",
            f"path:{repo}#{plan.host}",
            "--no-channel-copy",
            "--no-write-lock-file",
            "--no-update-lock-file",
            "--no-root-password",
        ],
        timeout=3600,
    )
    bin_path = "/nix/var/nix/profiles/system/sw/bin/"

    def query(*command: str) -> str:
        return command_output(
            enter_command(storage, *command),
            timeout=60,
            env={**os.environ, "LC_ALL": "C"},
        ).strip()

    def password_set(user: str) -> None:
        status = query(bin_path + "passwd", "--status", user).split()
        if len(status) < 2 or status[:2] != [user, "P"]:
            raise ValueError(f"Password is not set for {user}.")

    print("Setting account passwords...")
    set_passwords(plan, storage)
    password_set("root")
    password_set(plan.username)
    uid = int(query(bin_path + "id", "-u", plan.username))
    gid = int(query(bin_path + "id", "-g", plan.username))
    if uid <= 0 or gid < 0:
        raise ValueError("Installed user has an invalid account identity.")
    home = f"/home/{plan.username}"
    owner = f"{uid}:{gid}"
    for arguments in (
        ["--no-dereference", "--", owner, home, home + "/Projects"],
        ["-R", "--no-dereference", "--", owner, home + "/Projects/nix"],
    ):
        run_command(
            enter_command(storage, bin_path + "chown", *arguments),
            timeout=120,
        )
    print("Checking the installed system and checkout...")
    system = query(bin_path + "readlink", "-f", "/nix/var/nix/profiles/system")
    if system != expected["system"]:
        raise ValueError(
            "Installed system does not match the generated flake."
        )
    run_command(
        enter_command(storage, bin_path + "test", "-x", system + "/init"),
        timeout=60,
    )
    for path in (
        storage.root / "home" / plan.username,
        repo.parent,
        repo,
        repo / ".git",
    ):
        stat = path.stat()
        if (stat.st_uid, stat.st_gid) != (uid, gid):
            raise ValueError(f"Installed user does not own {path}.")
    git = subprocess.check_output(
        [
            "git",
            "-c",
            f"safe.directory={repo}",
            "-C",
            str(repo),
            "rev-parse",
            "--is-inside-work-tree",
        ],
        text=True,
        timeout=10,
    ).strip()
    if git != "true" or (repo / "flake.lock").read_bytes() != before:
        raise ValueError(
            "Installed checkout or lock file changed unexpectedly."
        )
    boot = storage.root / "boot"
    efi = boot / "efi" / ("boot" if expected["removable"] else "limine")
    loader = efi / "BOOTX64.EFI"
    if not loader.is_file() or loader.stat().st_size == 0:
        raise ValueError(
            "Installed Limine EFI executable is missing or empty."
        )
    entries = (boot / "limine/limine.conf").read_text()
    if (
        system + "/init" not in entries
        or f"resume_offset={storage.resume_offset}" not in entries
        or (plan.windows and f"guid({plan.windows})" not in entries)
    ):
        raise ValueError("Limine entries do not match the installed system.")
    swap = storage.root / "var/swap/swapfile"
    offset = int(
        subprocess.check_output(
            ["btrfs", "inspect-internal", "map-swapfile", "-r", str(swap)],
            text=True,
            timeout=10,
        ).strip()
    )
    if (
        swap.stat().st_size != plan.swap_gib * GIB
        or offset != storage.resume_offset
    ):
        raise ValueError("Installed swap size or resume offset changed.")
    print("Installation checked. Boot and hibernation still need a real test.")


def install(plan: Plan) -> int:
    modified = False

    def mark_modified() -> None:
        nonlocal modified
        modified = True

    try:
        if not sys.stdin.isatty():
            raise ValueError(
                "Installation requires an interactive root console."
            )
        storage_preflight(plan)
        for tool in (
            "nixos-install",
            "nixos-enter",
            "systemctl",
            "systemd-ask-password",
            "cmp",
            "cat",
            "printf",
        ):
            if shutil.which(tool) is None:
                raise ValueError(f"Missing installation tool: {tool}")
        with native_password() as password_fd:
            plan = review_plan(plan, dry_run=False)
            storage_preflight(plan)
            confirmation = ask(
                questionary.text(
                    f"Erase {plan.storage.disk.path}?"
                    " Type its full device path"
                )
            )
            if confirmation != plan.storage.disk.path:
                raise ValueError(
                    "Disk confirmation did not match. No changes made."
                )
            with prepare_checkout(plan) as checkout:
                with prepare_storage(
                    plan,
                    password_fd=password_fd,
                    confirmation=confirmation,
                    before_write=mark_modified,
                ) as storage:
                    repo = generate_configuration(plan, storage, checkout)
                    finish_installation(plan, storage, repo)
    except KeyboardInterrupt, EOFError:
        if modified:
            print(
                "\nInstallation cancelled. The disk was modified.",
                file=sys.stderr,
            )
            return 1
        print("\nInstallation cancelled. No disk changes made.")
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        RuntimeError,
        subprocess.SubprocessError,
    ) as error:
        state = (
            "The disk was modified." if modified else "No disk changes made."
        )
        print(f"Installation failed: {error}\n{state}", file=sys.stderr)
        return 1
    print(
        f"Installation complete. Checkout: /home/{plan.username}/Projects/nix"
    )
    try:
        reboot = ask(questionary.confirm("Reboot now?", default=False))
        if reboot:
            subprocess.run(["systemctl", "reboot"], check=True, timeout=30)
    except KeyboardInterrupt, EOFError:
        print("Reboot cancelled; installation is complete.")
    except (OSError, subprocess.SubprocessError) as error:
        print(
            f"Installation is complete, but reboot failed: {error}",
            file=sys.stderr,
        )
        return 1
    return 0

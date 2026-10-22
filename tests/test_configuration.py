"""Configuration generation and evaluation."""

import io
import json
import shutil
import subprocess
import unittest
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, final
from unittest.mock import patch

from helpers import GIB, disk, public_key
from nixos_setup import common, configuration, planning


@final
class ConfigurationTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.directory = TemporaryDirectory(prefix="installer-config-test-")
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.checkout = self.base / "checkout"
        self.fixture(self.checkout)
        local = self.checkout / "hosts/nixos-test/local"
        local.mkdir()
        (local / "hardware-configuration.nix").write_text(
            configuration.preflight_hardware()
        )
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
            self.base / "target",
            "/dev/fixture-efi",
            "/dev/fixture-luks",
            "/dev/mapper/cryptroot",
            24680,
        )
        self.snapshot: dict[str, Any] = {
            "system": "/nix/store/fixture-nixos-system",
            "mutable": True,
            "git": True,
            "efi": "/boot",
            "limine": True,
            "removable": False,
            "entries": "",
            "host": "nixos-test",
            "user": True,
            "groups": ["wheel", "networkmanager"],
            "keys": [],
            "home": "/home/river",
            "autoLogin": True,
            "autoLoginUser": "river",
            "initialSessionUser": "river",
            "swaps": [{"device": "/var/swap/swapfile", "size": 49152}],
            "resume": "/dev/mapper/cryptroot",
            "params": ["resume_offset=24680"],
            "failures": [],
            "luks": "/dev/disk/by-uuid/fresh-luks",
            "filesystems": {
                path: {
                    "fsType": "btrfs",
                    "device": "/dev/mapper/cryptroot",
                    "options": [f"subvol={name}", "compress=zstd"],
                }
                for name, path in [
                    ("root", "/"),
                    ("home", "/home"),
                    ("snapshots", "/.snapshots"),
                    ("log", "/var/log"),
                    ("cache", "/var/cache"),
                    ("swapfile", "/var/swap"),
                    ("flatpak", "/var/lib/flatpak"),
                    ("docker", "/var/lib/docker"),
                    ("containerd", "/var/lib/containerd"),
                ]
            },
        }
        self.snapshot["filesystems"]["/boot"] = {
            "device": "/dev/disk/by-uuid/fresh-efi",
            "fsType": "vfat",
            "options": ["fmask=0077", "dmask=0077"],
        }
        self.output = io.StringIO()

    def fixture(self, destination: Path) -> None:
        root = Path(__file__).resolve().parents[1]
        destination.mkdir()
        for name in [
            "flake.nix",
            "flake.lock",
            "system.nix",
            ".gitignore",
        ]:
            shutil.copy2(root / name, destination / name)
        shutil.copytree(root / "components", destination / "components")
        shutil.copytree(root / "home", destination / "home")
        shutil.copytree(root / "configs", destination / "configs")
        for host in common.HOSTS:
            # Leave out this machine's own installer-generated data.
            shutil.copytree(
                root / "hosts" / host,
                destination / "hosts" / host,
                ignore=shutil.ignore_patterns("local"),
            )
        shutil.copytree(
            root / "hosts/installer", destination / "hosts/installer"
        )
        # Other test workers may be writing bytecode there during the copy.
        shutil.copytree(
            root / "scripts",
            destination / "scripts",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        (destination / ".git").mkdir()
        (destination / ".git/HEAD").write_text("fixture Git metadata\n")

    def probe(self, command: list[str], **_kwargs: Any) -> str:
        if command[0] == "nixos-generate-config":
            self.assertEqual(
                command,
                [
                    "nixos-generate-config",
                    "--root",
                    str(self.storage.root),
                    "--show-hardware-config",
                ],
            )
            return "fresh hardware\n"
        if command[0] == "nix":
            self.assertIn("--no-update-lock-file", command)
            self.assertIn("--no-write-lock-file", command)
            return json.dumps(self.snapshot)
        if command[:2] == ["cryptsetup", "luksUUID"]:
            return "fresh-luks\n"
        self.assertEqual(command[:5], ["blkid", "-s", "UUID", "-o", "value"])
        return "fresh-efi\n"

    def test_generation_preserves_custom_files_lock_and_git_metadata(self):
        selected = self.checkout / "hosts/nixos-test"
        original = {
            p: p.read_bytes()
            for p in [
                self.checkout / "flake.lock",
                selected / "configuration.nix",
                selected / "home.nix",
                self.checkout / ".git/HEAD",
            ]
        }
        with (
            patch.object(subprocess, "check_output", side_effect=self.probe),
            redirect_stdout(self.output),
        ):
            target = configuration.generate_configuration(
                self.plan,
                self.storage,
                self.checkout,
            )
        self.assertEqual(target, self.storage.root / "home/river/Projects/nix")
        for path, data in original.items():
            self.assertEqual(
                (target / path.relative_to(self.checkout)).read_bytes(), data
            )
        self.assertEqual(
            (
                target / "hosts/nixos-test/local/hardware-configuration.nix"
            ).read_text(),
            "fresh hardware\n",
        )
        module = (
            target / "hosts/nixos-test/local/installation.nix"
        ).read_text()
        self.assertIn('users.users."river"', module)
        self.assertIn("sizeGiB = 48", module)
        self.assertIn("resume_offset=24680", module)
        self.assertNotIn("password", module.lower())
        self.assertNotIn("PRIVATE KEY", module)

    def test_generation_adds_only_ignored_data_to_a_git_checkout(self):
        shutil.rmtree(self.checkout / ".git")
        for command in (["init", "-q"], ["add", "."]):
            subprocess.run(
                ["git", "-C", str(self.checkout), *command],
                check=True,
                capture_output=True,
            )
        before = subprocess.check_output(
            ["git", "-C", str(self.checkout), "status", "--porcelain"]
        )
        with (
            patch.object(subprocess, "check_output", side_effect=self.probe),
            redirect_stdout(self.output),
        ):
            target = configuration.generate_configuration(
                self.plan, self.storage, self.checkout
            )
        after = subprocess.check_output(
            ["git", "-C", str(target), "status", "--porcelain"]
        )
        self.assertEqual(after, before)
        for name in ("hardware-configuration.nix", "installation.nix"):
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(target),
                    "check-ignore",
                    "-q",
                    f"hosts/nixos-test/local/{name}",
                ],
                check=True,
            )

    def test_generation_refuses_local_symlinks(self):
        local = self.checkout / "hosts/nixos-test/local"
        (local / "hardware-configuration.nix").unlink()
        (local / "hardware-configuration.nix").symlink_to(
            self.checkout / "home/common.nix"
        )
        with (
            patch.object(subprocess, "check_output") as probe,
            self.assertRaisesRegex(ValueError, "unsafe"),
        ):
            configuration.generate_configuration(
                self.plan, self.storage, self.checkout
            )
        probe.assert_not_called()

    def test_installer_bundle_excludes_machine_records(self):
        host = self.checkout / "hosts/nixos-test"
        (host / "installation.nix").write_text("legacy machine record")
        source = Path(
            common.command_output(
                [
                    "nix",
                    "--extra-experimental-features",
                    "nix-command flakes",
                    "eval",
                    "--raw",
                    "--no-write-lock-file",
                    f"path:{self.checkout}#nixosConfigurations.installer.config.environment.etc.nixos-config.source",
                ],
                timeout=300,
            ).strip()
        )
        self.assertTrue(
            (source / "hosts/nixos-test/configuration.nix").is_file()
        )
        self.assertFalse((source / "hosts/nixos-test/local").exists())
        self.assertFalse(
            (source / "hosts/nixos-test/installation.nix").exists()
        )
        self.assertFalse(
            (source / "hosts/nixos-test/hardware-configuration.nix").exists()
        )

    def test_real_nix_local_data_builds_and_ignores_legacy_files(self):
        host = self.checkout / "hosts/nixos-test"
        (host / "local/installation.nix").write_text(
            configuration.render_installation(self.plan, 24680)
        )
        self.assertFalse((host / "hardware-configuration.nix").exists())
        command = [
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "eval",
            "--raw",
            "--no-write-lock-file",
            "--no-update-lock-file",
            f"path:{self.checkout}#nixosConfigurations.nixos-test.config.system.build.toplevel.outPath",
        ]
        before = common.command_output(command, timeout=300)
        for name in ("hardware-configuration.nix", "installation.nix"):
            (host / name).write_text(
                'throw "Legacy data must not be imported"'
            )
        self.assertEqual(common.command_output(command, timeout=300), before)
        common.run_command(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "build",
                "--no-link",
                "--no-write-lock-file",
                "--no-update-lock-file",
                f"path:{self.checkout}#nixosConfigurations.nixos-test.config.system.build.toplevel",
            ],
            timeout=600,
        )

    def test_public_outputs_and_incomplete_local_data(self):
        local = self.checkout / "hosts/nixos-test/local"
        shutil.rmtree(local)
        command = [
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "eval",
            "--json",
            "--no-write-lock-file",
            f"path:{self.checkout}#nixosConfigurations",
            "--apply",
            "builtins.attrNames",
        ]
        self.assertEqual(
            json.loads(common.command_output(command, timeout=300)),
            ["installer"],
        )
        host = self.checkout / "hosts/nixos-test"
        for name in ("hardware-configuration.nix", "installation.nix"):
            (host / name).write_text(
                'throw "Legacy data must not be imported"'
            )
        self.assertEqual(
            json.loads(common.command_output(command, timeout=300)),
            ["installer"],
        )
        local.mkdir()
        for name, data in (
            ("hardware-configuration.nix", configuration.preflight_hardware()),
            (
                "installation.nix",
                configuration.render_installation(self.plan, 24680),
            ),
        ):
            with self.subTest(missing_other_file=name):
                path = local / name
                path.write_text(data)
                errors = io.StringIO()
                with (
                    redirect_stderr(errors),
                    self.assertRaises(subprocess.CalledProcessError),
                ):
                    common.command_output(
                        [
                            *command[:-2],
                            "--apply",
                            "c: c.nixos-test.config.system.build."
                            "toplevel.drvPath",
                        ],
                        timeout=300,
                    )
                self.assertIn(
                    "Incomplete hosts/nixos-test/local", errors.getvalue()
                )
                path.unlink()

    def test_existing_target_and_symlink_ancestor_refuse_generation(self):
        target = self.storage.root / "home/river/Projects/nix"
        target.mkdir(parents=True)
        marker = target / "keep"
        marker.write_text("keep")
        with patch.object(subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "already exists"):
                configuration.generate_configuration(
                    self.plan,
                    self.storage,
                    self.checkout,
                )
            self.assertEqual(marker.read_text(), "keep")
            shutil.rmtree(self.storage.root / "home")
            (self.storage.root / "home").symlink_to(self.checkout)
            with self.assertRaisesRegex(ValueError, "symlink"):
                configuration.generate_configuration(
                    self.plan,
                    self.storage,
                    self.checkout,
                )
            run.assert_not_called()

    def test_failed_generator_or_wrong_uuid_never_copies_target(self):
        for failure in ["generator", "uuid", "efi", "custom"]:
            with self.subTest(failure=failure):

                def probe(
                    command: list[str], failure: str = failure, **kwargs: Any
                ) -> str:
                    if command[0] == "nixos-generate-config":
                        if failure == "generator":
                            raise subprocess.CalledProcessError(1, command)
                        if failure == "custom":
                            (
                                self.checkout / "hosts/nixos-test/home.nix"
                            ).write_text("changed")
                    return self.probe(command, **kwargs)

                if failure == "uuid":
                    self.snapshot["luks"] = "/dev/disk/by-uuid/stale-luks"
                else:
                    self.snapshot["luks"] = "/dev/disk/by-uuid/fresh-luks"
                self.snapshot["filesystems"]["/boot"]["device"] = (
                    "/dev/disk/by-uuid/stale-efi"
                    if failure == "efi"
                    else "/dev/disk/by-uuid/fresh-efi"
                )
                with (
                    patch.object(
                        subprocess, "check_output", side_effect=probe
                    ),
                    redirect_stdout(self.output),
                ):
                    with self.assertRaises(
                        (ValueError, subprocess.CalledProcessError)
                    ):
                        configuration.generate_configuration(
                            self.plan,
                            self.storage,
                            self.checkout,
                        )
                self.assertFalse((self.storage.root / "home").exists())

    def test_evaluation_rejects_ignored_settings_and_failed_assertions(self):
        for field, value in [
            ("user", False),
            ("keys", ["unexpected key"]),
            ("home", "/home/wrong"),
            ("autoLogin", False),
            ("autoLoginUser", "wrong"),
            ("initialSessionUser", "wrong"),
            ("swaps", []),
            ("params", ["resume_offset=999"]),
            ("failures", ["a real NixOS assertion failed"]),
        ]:
            with self.subTest(field=field):
                result = {**self.snapshot, field: value}
                with patch.object(
                    subprocess, "check_output", return_value=json.dumps(result)
                ):
                    with self.assertRaises(ValueError):
                        configuration.evaluate_configuration(
                            self.checkout,
                            self.plan,
                            24680,
                        )

    def test_clone_checks_before_yield_and_removes_own_temporary_directory(
        self,
    ):
        created: list[Path] = []

        def clone(command: list[str], **kwargs: Any) -> Any:
            self.assertEqual(
                command[3:6], ["flake", "clone", "github:Furyfree/nix/main"]
            )
            self.assertEqual(kwargs["env"]["GIT_TERMINAL_PROMPT"], "0")
            path = Path(command[-1])
            self.fixture(path)
            created.append(path)
            return subprocess.CompletedProcess[str](command, 0)

        self.snapshot["params"] = ["resume_offset=0"]
        with (
            patch.object(subprocess, "run", side_effect=clone),
            patch.object(subprocess, "check_output", side_effect=self.probe),
            patch.object(shutil, "which", return_value="fixture"),
            redirect_stdout(self.output),
        ):
            with configuration.prepare_checkout(self.plan) as checkout:
                self.assertTrue((checkout / ".git").is_dir())
                self.assertEqual(checkout, created[0])
                self.assertIn(
                    "resume_offset=0",
                    (
                        checkout
                        / "hosts/nixos-test/local"
                        / "installation.nix"
                    ).read_text(),
                )
        self.assertFalse(created[0].parent.exists())

    def test_clone_failure_timeout_and_cancel_release_temporary_files(self):
        created: list[Path] = []
        for error in [
            subprocess.CalledProcessError(1, ["nix", "flake", "clone"]),
            subprocess.TimeoutExpired(["nix", "flake", "clone"], 180),
            KeyboardInterrupt(),
        ]:
            created.clear()

            def clone(
                command: list[str],
                error: BaseException = error,
                **_kwargs: Any,
            ) -> Any:
                path = Path(command[-1])
                self.fixture(path)
                created.append(path)
                raise error

            with (
                self.subTest(error=type(error)),
                patch.object(subprocess, "run", side_effect=clone),
                patch.object(shutil, "which", return_value="fixture"),
                redirect_stdout(self.output),
            ):
                with self.assertRaises(type(error)):
                    with configuration.prepare_checkout(self.plan):
                        self.fail("Failed clone yielded a checkout")
                self.assertFalse(created[0].parent.exists())

    def test_clone_refuses_missing_lock_and_unsafe_installation_file(self):
        created: list[Path] = []
        for problem in ["lock", "symlink"]:
            created.clear()

            def clone(
                command: list[str], problem: str = problem, **_kwargs: Any
            ) -> Any:
                path = Path(command[-1])
                self.fixture(path)
                created.append(path)
                if problem == "lock":
                    (path / "flake.lock").unlink()
                else:
                    (path / "hosts/nixos-test/local").mkdir()
                    (
                        path / "hosts/nixos-test/local/installation.nix"
                    ).symlink_to(
                        self.checkout / "home/common.nix",
                    )
                return subprocess.CompletedProcess[str](command, 0)

            with (
                self.subTest(problem=problem),
                patch.object(subprocess, "run", side_effect=clone),
                patch.object(shutil, "which", return_value="fixture"),
                redirect_stdout(self.output),
            ):
                with self.assertRaises(ValueError):
                    with configuration.prepare_checkout(self.plan):
                        self.fail("Unsafe clone yielded a checkout")
                self.assertFalse(created[0].parent.exists())

    def test_unsupported_plan_and_missing_tools_stop_before_clone(self):
        examples = [
            replace(self.plan, host="installer"),
            replace(self.plan, host="unknown"),
            replace(self.plan, windows="not-a-guid"),
            replace(
                self.plan, storage=planning.plan_storage(disk(), "preserve")
            ),
        ]
        with patch.object(subprocess, "run") as run:
            for plan in examples:
                with self.subTest(host=plan.host, mode=plan.storage.mode):
                    with self.assertRaises(ValueError):
                        with configuration.prepare_checkout(plan):
                            self.fail("Unsupported plan reached a checkout")
            with patch.object(shutil, "which", return_value=None):
                with self.assertRaisesRegex(ValueError, "Missing"):
                    with configuration.prepare_checkout(self.plan):
                        self.fail("Missing tools were ignored")
            run.assert_not_called()

    def test_real_nix_evaluation_preserves_key_comments_and_chosen_values(
        self,
    ):
        for username, size, offset, key in [
            ("river", 48, 24680, ""),
            (
                "delta_bot",
                24,
                13579,
                public_key('quote" slash\\ interpolation${throw "oops"}'),
            ),
        ]:
            plan = replace(
                self.plan, username=username, swap_gib=size, ssh_key=key
            )
            (
                self.checkout / "hosts/nixos-test/local/installation.nix"
            ).write_text(configuration.render_installation(plan, offset))
            result = configuration.evaluate_configuration(
                self.checkout, plan, offset
            )
            self.assertEqual(result["keys"], [key] if key else [])
            self.assertEqual(result["home"], f"/home/{username}")
            self.assertIs(result["autoLogin"], True)
            self.assertEqual(result["autoLoginUser"], username)
            self.assertEqual(result["initialSessionUser"], username)

    def test_real_nix_evaluation_of_each_host_and_its_windows_entry(self):
        guid = "0f2c9a4e-1b7d-4c3a-9e8f-5a6b7c8d9e0f"
        for host, windows in [
            ("desktop", guid),
            ("laptop", ""),
            ("nixos-test", guid),
        ]:
            with self.subTest(host=host, windows=windows):
                plan = replace(self.plan, host=host, windows=windows)
                local = self.checkout / "hosts" / host / "local"
                local.mkdir(exist_ok=True)
                (local / "hardware-configuration.nix").write_text(
                    configuration.preflight_hardware()
                )
                (local / "installation.nix").write_text(
                    configuration.render_installation(plan, 24680)
                )
                result = configuration.evaluate_configuration(
                    self.checkout, plan, 24680
                )
                self.assertEqual(result["host"], host)
                if windows:
                    self.assertIn(
                        f"path: guid({guid}):/EFI/Microsoft/Boot/bootmgfw.efi",
                        result["entries"],
                    )
                else:
                    self.assertNotIn("/Windows", result["entries"])
                    # A plan expecting Windows rejects a host without it.
                    with self.assertRaisesRegex(ValueError, "does not match"):
                        configuration.evaluate_configuration(
                            self.checkout, replace(plan, windows=guid), 24680
                        )

    def test_real_nix_evaluation_selects_an_unambiguous_desktop_account(self):
        for accounts, explicit, expected in [
            ([], None, None),
            (["river"], None, "river"),
            (["river", "delta_bot"], None, None),
            (["river", "delta_bot"], "delta_bot", "delta_bot"),
            (["root", "river"], None, "river"),
        ]:
            with self.subTest(accounts=accounts, explicit=explicit):
                # Existing installs declare accounts without auto-login policy.
                declarations: list[str] = []
                for account in accounts:
                    user = common.nix_string(account)
                    normal = "false" if account == "root" else "true"
                    declarations.extend(
                        [
                            f"users.users.{user}.isNormalUser = {normal};",
                            f"home-manager.users.{user} = import ../home.nix;",
                        ]
                    )
                if explicit is not None:
                    declarations.append(
                        "services.displayManager.autoLogin.user = "
                        f"{common.nix_string(explicit)};"
                    )
                (
                    self.checkout / "hosts/nixos-test/local/installation.nix"
                ).write_text(
                    "{ ... }: {\n" + "\n".join(declarations) + "\n}\n"
                )
                result = json.loads(
                    common.command_output(
                        [
                            "nix",
                            "--extra-experimental-features",
                            "nix-command flakes",
                            "eval",
                            "--json",
                            "--no-write-lock-file",
                            "--no-update-lock-file",
                            f"path:{self.checkout}#nixosConfigurations."
                            "nixos-test.config",
                            "--apply",
                            """c: let
                              a = c.services.displayManager.autoLogin;
                            in {
                              enabled = a.enable;
                              user = a.user;
                              initial =
                                c.services.greetd.settings.initial_session
                                or null;
                            }""",
                        ],
                        timeout=300,
                    )
                )
                self.assertIs(result["enabled"], expected is not None)
                self.assertEqual(result["user"], expected)
                if expected is None:
                    self.assertIsNone(result["initial"])
                else:
                    self.assertEqual(result["initial"]["user"], expected)


if __name__ == "__main__":
    unittest.main()

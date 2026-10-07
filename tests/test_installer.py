"""Controlled planner examples; no disks are written or installed."""

import base64
import importlib.util
import io
import json
import shutil
import struct
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
        "maj:min": "259:7",
        "serial": "fixture-serial",
        "wwn": "fixture-wwn",
        "children": [],
        **changes,
    }


def partition(sector: int | None, size: int, **changes: Any) -> dict[str, Any]:
    return device(type="part", start=sector, size=size, **changes)


def disk(**changes: Any) -> Any:
    return installer.parse_disks({"blockdevices": [device(**changes)]})[0]


def public_key(comment: str = "fixture") -> str:
    kind = b"ssh-ed25519"
    wire = (
        struct.pack(">I", len(kind))
        + kind
        + struct.pack(">I", 32)
        + bytes(range(32))
    )
    return "ssh-ed25519 " + base64.b64encode(wire).decode() + " " + comment


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


@final
class ConfigurationTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.directory = TemporaryDirectory(prefix="installer-config-test-")
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.checkout = self.base / "checkout"
        self.fixture(self.checkout)
        self.plan = installer.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            installer.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        self.storage = installer.PreparedStorage(
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
            "host": "nixos-test",
            "user": True,
            "groups": ["wheel", "networkmanager"],
            "keys": [],
            "home": "/home/river",
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
        for name in ["flake.nix", "flake.lock", "system.nix", "home.nix"]:
            shutil.copy2(root / name, destination / name)
        shutil.copytree(root / "components", destination / "components")
        shutil.copytree(
            root / "hosts/nixos-test", destination / "hosts/nixos-test"
        )
        (destination / ".git").mkdir()
        (destination / ".git/HEAD").write_text("fixture Git metadata\n")

    def probe(self, command: list[str], **_kwargs: Any) -> str:
        if command[0] == "nix":
            self.assertIn("--no-update-lock-file", command)
            self.assertIn("--no-write-lock-file", command)
            return json.dumps(self.snapshot)
        if command[:2] == ["cryptsetup", "luksUUID"]:
            return "fresh-luks\n"
        self.assertEqual(command[:5], ["blkid", "-s", "UUID", "-o", "value"])
        return "fresh-efi\n"

    def generator(self, command: list[str], **_kwargs: Any) -> Any:
        self.assertEqual(
            command,
            [
                "nixos-generate-config",
                "--root",
                str(self.storage.root),
                "--dir",
                str(self.checkout / "hosts/nixos-test"),
            ],
        )
        (
            self.checkout / "hosts/nixos-test/hardware-configuration.nix"
        ).write_text("fresh hardware\n")
        return subprocess.CompletedProcess[str](command, 0)

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
            patch.object(subprocess, "run", side_effect=self.generator),
            patch.object(subprocess, "check_output", side_effect=self.probe),
            redirect_stdout(self.output),
        ):
            target = installer.generate_configuration(
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
                target / "hosts/nixos-test/hardware-configuration.nix"
            ).read_text(),
            "fresh hardware\n",
        )
        module = (target / "hosts/nixos-test/installation.nix").read_text()
        self.assertIn('users.users."river"', module)
        self.assertIn("sizeGiB = 48", module)
        self.assertIn("resume_offset=24680", module)
        self.assertNotIn("password", module.lower())
        self.assertNotIn("PRIVATE KEY", module)

    def test_existing_target_and_symlink_ancestor_refuse_generation(self):
        target = self.storage.root / "home/river/Projects/nix"
        target.mkdir(parents=True)
        marker = target / "keep"
        marker.write_text("keep")
        with patch.object(subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "already exists"):
                installer.generate_configuration(
                    self.plan,
                    self.storage,
                    self.checkout,
                )
            self.assertEqual(marker.read_text(), "keep")
            shutil.rmtree(self.storage.root / "home")
            (self.storage.root / "home").symlink_to(self.checkout)
            with self.assertRaisesRegex(ValueError, "symlink"):
                installer.generate_configuration(
                    self.plan,
                    self.storage,
                    self.checkout,
                )
            run.assert_not_called()

    def test_failed_generator_or_wrong_uuid_never_copies_target(self):
        for failure in ["generator", "uuid", "efi", "custom"]:
            with self.subTest(failure=failure):

                def run(
                    command: list[str],
                    failure: str = failure,
                    **kwargs: Any,
                ) -> Any:
                    if failure == "generator":
                        raise subprocess.CalledProcessError(1, command)
                    result = self.generator(command, **kwargs)
                    if failure == "custom":
                        (
                            self.checkout / "hosts/nixos-test/home.nix"
                        ).write_text("changed")
                    return result

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
                    patch.object(subprocess, "run", side_effect=run),
                    patch.object(
                        subprocess, "check_output", side_effect=self.probe
                    ),
                    redirect_stdout(self.output),
                ):
                    with self.assertRaises(
                        (ValueError, subprocess.CalledProcessError)
                    ):
                        installer.generate_configuration(
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
                        installer.evaluate_configuration(
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
            with installer.prepare_checkout(self.plan) as checkout:
                self.assertTrue((checkout / ".git").is_dir())
                self.assertEqual(checkout, created[0])
                self.assertIn(
                    "resume_offset=0",
                    (
                        checkout / "hosts/nixos-test" / "installation.nix"
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
                    with installer.prepare_checkout(self.plan):
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
                    (path / "hosts/nixos-test/installation.nix").symlink_to(
                        self.checkout / "home.nix",
                    )
                return subprocess.CompletedProcess[str](command, 0)

            with (
                self.subTest(problem=problem),
                patch.object(subprocess, "run", side_effect=clone),
                patch.object(shutil, "which", return_value="fixture"),
                redirect_stdout(self.output),
            ):
                with self.assertRaises(ValueError):
                    with installer.prepare_checkout(self.plan):
                        self.fail("Unsafe clone yielded a checkout")
                self.assertFalse(created[0].parent.exists())

    def test_unsupported_plan_and_missing_tools_stop_before_clone(self):
        examples = [
            replace(self.plan, host="desktop"),
            replace(self.plan, host="laptop"),
            replace(
                self.plan, storage=installer.plan_storage(disk(), "preserve")
            ),
        ]
        with patch.object(subprocess, "run") as run:
            for plan in examples:
                with self.subTest(host=plan.host, mode=plan.storage.mode):
                    with self.assertRaises(ValueError):
                        with installer.prepare_checkout(plan):
                            self.fail("Unsupported plan reached a checkout")
            with patch.object(shutil, "which", return_value=None):
                with self.assertRaisesRegex(ValueError, "Missing"):
                    with installer.prepare_checkout(self.plan):
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
            (self.checkout / "hosts/nixos-test/installation.nix").write_text(
                installer.render_installation(plan, offset)
            )
            result = installer.evaluate_configuration(
                self.checkout, plan, offset
            )
            self.assertEqual(result["keys"], [key] if key else [])
            self.assertEqual(result["home"], f"/home/{username}")


@final
class StorageExecutionTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.target = disk()
        self.plan = installer.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            installer.plan_storage(self.target, "erase"),
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
            patch.object(installer.os, "geteuid", return_value=0),
            patch.object(installer.shutil, "which", return_value="/fixture"),
            patch.object(
                installer, "discover_disks", return_value=(self.target,)
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
            patch.object(installer.os.path, "ismount", return_value=False),
            patch.object(Path, "mkdir"),
            patch.object(Path, "chmod"),
            patch.object(
                questionary.Question,
                "unsafe_ask",
                return_value=self.target.path,
            ),
            patch.object(subprocess, "check_output", side_effect=probe),
            patch.object(subprocess, "run", side_effect=run) as execute,
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
            with installer.prepare_storage(self.plan) as prepared:
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
        self.assertIn(
            [
                "cryptsetup",
                "luksFormat",
                "--type",
                "luks2",
                "/dev/fixture-system",
            ],
            self.commands,
        )
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
                with installer.prepare_storage(self.plan, before_write=marker):
                    self.fail("Failed wipe should stop preparation")
        marker.assert_called_once_with()
        self.assertIn("disk was modified", self.output.getvalue())

    def test_signature_wipe_targets_only_selected_disk_and_its_partitions(
        self,
    ):
        self.target = disk(
            children=[partition(2048, 10 * GIB, name="/dev/fixture0p1")]
        )
        self.plan = installer.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            installer.plan_storage(self.target, "erase"),
            32 * GIB,
            48,
        )
        with self.environment():
            with installer.prepare_storage(self.plan):
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
                    "root": patch.object(
                        installer.os, "geteuid", return_value=1000
                    ),
                    "uefi": patch.object(Path, "is_dir", return_value=False),
                    "tool": patch.object(
                        installer.shutil, "which", return_value=None
                    ),
                }[name]
                with change, self.assertRaises((PermissionError, ValueError)):
                    with installer.prepare_storage(self.plan):
                        self.fail("Unsafe storage preparation was allowed")
                self.assertFalse(self.commands)

    def test_unsupported_plans_and_invalid_swap_never_reach_writes(self):
        plans = [
            replace(self.plan, host="desktop"),
            replace(self.plan, host="laptop"),
            installer.Plan(
                "nixos-test",
                "river",
                "",
                "none",
                installer.plan_storage(self.target, "preserve"),
                32 * GIB,
                48,
            ),
            installer.Plan(
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
                    with installer.prepare_storage(plan):
                        self.fail("Unsafe storage preparation was allowed")
                self.assertFalse(self.commands)

    def test_missing_stable_disk_identity_prevents_erasure(self):
        for target in [disk(serial=None, wwn=None), disk(**{"maj:min": None})]:
            self.target = target
            self.plan = installer.Plan(
                "nixos-test",
                "river",
                "",
                "none",
                installer.plan_storage(target, "erase"),
                32 * GIB,
                48,
            )
            with self.subTest(target=target), self.environment():
                with self.assertRaisesRegex(ValueError, "identity"):
                    with installer.prepare_storage(self.plan):
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
                    with installer.prepare_storage(self.plan):
                        self.fail("Changed disk was accepted")
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
                        installer.os.path, "ismount", return_value=True
                    ),
                }[name]
                with change, self.assertRaises(ValueError):
                    with installer.prepare_storage(self.plan):
                        self.fail("Foreign resource was accepted")
                self.assertFalse(self.commands)

    def test_foreign_partition_is_rejected_before_signature_wipe(self):
        self.target = disk(
            children=[partition(2048, 10 * GIB, name="/dev/otherp1")]
        )
        self.plan = installer.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            installer.plan_storage(self.target, "erase"),
            32 * GIB,
            48,
        )
        with self.environment(), self.assertRaisesRegex(ValueError, "belong"):
            with installer.prepare_storage(self.plan):
                self.fail("Foreign partition was accepted")
        self.assertFalse(self.commands)

    def test_confirmation_mismatch_and_cancellation_make_no_changes(self):
        for answer in ["/dev/other", KeyboardInterrupt(), EOFError()]:
            with self.subTest(answer=answer), self.environment():
                with patch.object(
                    questionary.Question, "unsafe_ask", side_effect=[answer]
                ):
                    with self.assertRaises(
                        (ValueError, KeyboardInterrupt, EOFError)
                    ):
                        with installer.prepare_storage(self.plan):
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
                        with installer.prepare_storage(self.plan):
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
            with installer.prepare_storage(self.plan):
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
                    with installer.prepare_storage(self.plan):
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
                        with installer.prepare_storage(self.plan):
                            self.fail("Invalid resume offset was accepted")
                self.assertEqual(
                    self.commands[-1], ["cryptsetup", "close", "cryptroot"]
                )

    def test_new_foreign_mount_is_not_overmounted_or_unmounted(self):
        def foreign_mount(path: Path) -> bool:
            return path == Path("/mnt/home")

        with self.environment():
            with patch.object(
                installer.os.path,
                "ismount",
                side_effect=foreign_mount,
            ):
                with self.assertRaisesRegex(ValueError, "already in use"):
                    with installer.prepare_storage(self.plan):
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
                    with installer.prepare_storage(self.plan):
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
                with installer.prepare_storage(self.plan):
                    pass
        self.assertNotIn(["cryptsetup", "close", "cryptroot"], self.commands)
        self.assertIn("cleanup failed", self.output.getvalue())

    def test_repeating_a_stale_plan_cannot_erase_again(self):
        with self.environment():
            with installer.prepare_storage(self.plan):
                pass
        self.commands.clear()
        changed = installer.parse_disks(self.new_devices)[0]
        with self.environment() as mocks:
            discover, _ = mocks
            discover.return_value = (changed,)
            with self.assertRaisesRegex(ValueError, "changed"):
                with installer.prepare_storage(self.plan):
                    self.fail("Stale plan was reused")
        self.assertFalse(self.commands)


@final
class InstallationTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.directory = TemporaryDirectory(prefix="installer-finish-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name) / "target"
        self.plan = installer.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            installer.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        self.storage = installer.PreparedStorage(
            self.root,
            "/dev/fixture-efi",
            "/dev/fixture-luks",
            "/dev/mapper/cryptroot",
            24680,
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
            for key in [
                "input",
                "stdin",
                "stdout",
                "stderr",
                "capture_output",
            ]:
                self.assertNotIn(
                    key, kwargs, "Password I/O must remain native"
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

        with (
            redirect_stdout(self.output),
            redirect_stderr(self.output),
            patch.object(Path, "stat", autospec=True, side_effect=stat),
            patch.object(subprocess, "run", side_effect=run) as execute,
            patch.object(subprocess, "check_output", side_effect=probe),
            patch.object(
                installer,
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
            installer.finish_installation(self.plan, self.storage, self.repo)
        install = self.commands[0]
        self.assertEqual(install[0], "nixos-install")
        self.assertIn(f"path:{self.repo}#nixos-test", install)
        self.assertIn("--no-channel-copy", install)
        self.assertIn("--no-write-lock-file", install)
        self.assertIn("--no-update-lock-file", install)
        self.assertNotIn("--no-root-password", install)
        self.assertNotIn("--no-bootloader", install)
        self.assertTrue(
            any(
                Path(c[4]).name == "passwd"
                and c[-1] == "river"
                and "--status" not in c
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
            installer.finish_installation(self.plan, self.storage, self.repo)
        steps = [
            c
            for c in self.commands
            if c[0] == "nixos-install"
            or c[0] == "nixos-enter"
            and Path(c[4]).name in {"passwd", "chown", "test"}
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
                    installer.finish_installation(
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
                        installer.finish_installation(
                            self.plan, self.storage, self.repo
                        )
            finally:
                setattr(self, field, previous)
        (self.root / "boot/efi/limine/BOOTX64.EFI").unlink()
        with self.environment(), self.assertRaisesRegex(ValueError, "EFI"):
            installer.finish_installation(self.plan, self.storage, self.repo)

    def test_wrong_checkout_refuses_native_install(self):
        with self.environment(), self.assertRaisesRegex(ValueError, "home"):
            installer.finish_installation(
                self.plan, self.storage, self.root / "wrong"
            )
        self.assertFalse(self.commands)


@final
class InstallFlowTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.plan = installer.Plan(
            "nixos-test",
            "river",
            "",
            "none",
            installer.plan_storage(disk(), "erase"),
            32 * GIB,
            48,
        )
        self.output = io.StringIO()
        self.events: list[str] = []
        self.error: BaseException | None = None
        self.phase = ""
        self.reboot = False

    @contextmanager
    def environment(self) -> Generator[Mock]:
        @contextmanager
        def checkout(_plan: Any) -> Generator[Path]:
            self.events.append("clone")
            if self.phase == "clone" and self.error:
                raise self.error
            try:
                yield Path("/fixture-checkout")
            finally:
                self.events.append("clone-cleanup")

        @contextmanager
        def storage(_plan: Any, *, before_write: Any) -> Generator[Any]:
            self.events.append("confirmation")
            if self.phase == "confirmation" and self.error:
                raise self.error
            before_write()
            self.events.append("write")
            try:
                yield installer.PreparedStorage(
                    Path("/mnt"),
                    "/efi",
                    "/luks",
                    "/dev/mapper/cryptroot",
                    24680,
                )
            finally:
                self.events.append("storage-cleanup")
                if self.phase == "cleanup" and self.error:
                    raise self.error

        def generate(*_args: Any) -> Path:
            self.events.append("generate")
            if self.phase == "generate" and self.error:
                raise self.error
            return Path("/mnt/home/river/Projects/nix")

        def finish(*_args: Any) -> None:
            self.events.append("install")
            if self.phase == "install" and self.error:
                raise self.error

        def prompt(*_args: Any) -> bool:
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
            patch.object(installer, "storage_preflight") as preflight,
            patch.object(shutil, "which", return_value="fixture"),
            patch.object(installer, "prepare_checkout", side_effect=checkout),
            patch.object(installer, "prepare_storage", side_effect=storage),
            patch.object(
                installer, "generate_configuration", side_effect=generate
            ),
            patch.object(installer, "finish_installation", side_effect=finish),
            patch.object(installer, "ask", side_effect=prompt),
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
                self.assertEqual(installer.install(self.plan), 0)
                self.assertIs(confirm.call_args.kwargs["default"], False)
            self.assertEqual(
                self.events[:7],
                [
                    "clone",
                    "confirmation",
                    "write",
                    "generate",
                    "install",
                    "storage-cleanup",
                    "clone-cleanup",
                ],
            )
            self.assertEqual(
                self.events[7:],
                ["reboot-question", "reboot"]
                if reboot
                else ["reboot-question"],
            )

    def test_failure_before_or_after_writes_reports_correct_disk_state(self):
        for phase in [
            "clone",
            "confirmation",
            "generate",
            "install",
            "cleanup",
        ]:
            self.events.clear()
            self.output.seek(0)
            self.output.truncate()
            self.phase, self.error = phase, ValueError("fixture failure")
            with self.subTest(phase=phase), self.environment():
                self.assertEqual(installer.install(self.plan), 1)
            self.assertNotIn("reboot-question", self.events)
            if phase in {"clone", "confirmation"}:
                self.assertIn("No disk changes made", self.output.getvalue())
                self.assertNotIn("write", self.events)
            else:
                self.assertIn("disk was modified", self.output.getvalue())
                self.assertIn("storage-cleanup", self.events)
                self.assertIn("clone-cleanup", self.events)
                self.assertNotIn(
                    "No disk changes made", self.output.getvalue()
                )

    def test_cancellation_and_reboot_cancellation_have_distinct_results(self):
        for phase, expected in [
            ("confirmation", 0),
            ("install", 1),
            ("reboot", 0),
        ]:
            self.events.clear()
            self.output.seek(0)
            self.output.truncate()
            self.phase, self.error = phase, KeyboardInterrupt()
            with self.subTest(phase=phase), self.environment():
                self.assertEqual(installer.install(self.plan), expected)
            self.assertNotIn("reboot", self.events)
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
            self.assertEqual(installer.install(self.plan), 1)
        self.assertIn("Installation complete", self.output.getvalue())
        self.assertIn("reboot failed", self.output.getvalue())
        self.assertEqual(
            self.events[-4:],
            ["storage-cleanup", "clone-cleanup", "reboot-question", "reboot"],
        )

    def test_preflight_failures_stop_before_clone(
        self,
    ):
        with self.environment():
            with patch.object(sys.stdin, "isatty", return_value=False):
                self.assertEqual(installer.install(self.plan), 1)
            self.assertFalse(self.events)
            with patch.object(shutil, "which", return_value=None):
                self.assertEqual(installer.install(self.plan), 1)
            self.assertFalse(self.events)
        with self.environment() as preflight:
            preflight.side_effect = ValueError("busy disk")
            self.assertEqual(installer.install(self.plan), 1)
            self.assertFalse(self.events)


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
        ):
            status = installer.main(["--dry-run"] if argv is None else argv)
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
            "Disk preparation stages",
            "Create 20 GiB swap",
            "Configuration stages",
            "latest main",
            "/home/river/Projects/nix",
            "hosts/laptop/installation.nix",
            "BLOCKED",
            "flake.lock",
        ]:
            self.assertIn(text, output)
        self.assertTrue(calls)

    def test_default_installation_refuses_unsafe_environment_without_writes(
        self,
    ):
        status, output, _, calls = self.run_preview(
            ["laptop", disk(), "erase", "river", "", "20"],
            argv=[],
        )
        self.assertEqual(status, 1)
        self.assertIn("Host: laptop", output)
        self.assertIn("Swap: 20 GiB", output)
        self.assertIn("Installation failed", output)
        self.assertIn("No disk changes made", output)
        self.assertNotIn("Preview complete", output)
        self.assertTrue(calls)

    def test_default_mode_dispatches_to_install_but_dry_run_does_not(self):
        with patch.object(installer, "install", return_value=0) as install:
            status, _, _, _ = self.run_preview(
                ["nixos-test", disk(), "erase", "river", "", "48"],
                argv=[],
            )
            self.assertEqual(status, 0)
            self.assertEqual(install.call_args.args[0].username, "river")
            install.reset_mock()
            status, _, _, _ = self.run_preview(
                ["nixos-test", disk(), "erase", "river", "", "48", True],
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
                patch.object(installer, "collect_plan") as collect,
            ):
                with self.assertRaises(SystemExit) as error:
                    installer.main(argv)
                self.assertEqual(error.exception.code, status)
                collect.assert_not_called()

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
        modes: list[tuple[list[str] | None, list[Any]]] = [
            (None, answers),
            ([], answers[:-1]),
        ]
        for argv, prompts in modes:
            for index in range(len(prompts)):
                with self.subTest(argv=argv, prompt=index):
                    status, output, _, _ = self.run_preview(
                        prompts[:index] + [KeyboardInterrupt()], argv=argv
                    )
                    self.assertEqual(status, 0)
                    self.assertIn("Planning cancelled", output)
                    self.assertNotIn("Preview complete", output)
        for final_answer in [False, None, EOFError()]:
            status, output, _, _ = self.run_preview(
                answers[:-1] + [final_answer]
            )
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

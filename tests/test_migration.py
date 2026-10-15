"""The one-time host-data migration."""

import os
import shutil
import subprocess
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import final


@final
class MigrationTests(unittest.TestCase):
    def __init__(self, methodName: str = "runTest") -> None:
        super().__init__(methodName)
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.repo = self.base / "checkout"
        self.host = self.repo / "hosts/nixos-test"
        self.host.mkdir(parents=True)
        (self.repo / ".git").mkdir()
        (self.repo / "flake.lock").write_text("pinned inputs")
        self.hardware = b"detected hardware with preserved UUIDs\n"
        self.installation = (
            b"{ imports = [ (import ../../components/swap.nix {}) ]; "
            b"home-manager.users.river = import ./home.nix; }\n"
        )
        (self.host / "hardware-configuration.nix").write_bytes(self.hardware)
        (self.host / "installation.nix").write_bytes(self.installation)
        self.script = self.repo / "scripts/migrations/host-data.sh"
        self.script.parent.mkdir(parents=True)
        shutil.copy2(
            Path(__file__).resolve().parents[1]
            / "scripts/migrations/host-data.sh",
            self.script,
        )
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "commands"
        commands = {
            "git": """#!/bin/bash
set -eu
printf 'git %s\\n' "$*" >> "$TEST_LOG"
repo=$2
hardware="$repo/hosts/nixos-test/hardware-configuration.nix"
case "$3" in
 rev-parse) printf '%s\\n' "$repo" ;;
 status)
   if [[ $(< "$hardware") != example ]]; then
     printf ' M hosts/nixos-test/hardware-configuration.nix\\n'
   fi
   if [[ -f "$repo/hosts/nixos-test/installation.nix" ]]; then
     printf '?? hosts/nixos-test/installation.nix\\n'
   fi ;;
 check-ignore|ls-files) ;;
 restore)
   printf 'example' > "$repo/hosts/nixos-test/hardware-configuration.nix"
   ;;
 *) exit 90 ;;
esac
""",
            "nix": """#!/bin/bash
set -eu
printf 'nix %s\\n' "$*" >> "$TEST_LOG"
case " $* " in
 *' eval '*)
   if [[ ${TEST_FAILURE:-} == settings ]] &&
      [[ -f "$TEST_REPO/hosts/nixos-test/local/installation.nix" ]]; then
     printf /nix/store/different-system
   else
     printf /nix/store/unchanged-system
   fi ;;
 *' build '*)
   [[ ${TEST_FAILURE:-} != build ]] || exit 42
   if [[ ${TEST_FAILURE:-} == lock ]]; then
     printf changed > "$TEST_REPO/flake.lock"
   fi ;;
 *) exit 91 ;;
esac
""",
        }
        bash = shutil.which("bash")
        assert bash is not None
        for name, content in commands.items():
            path = self.bin / name
            path.write_text(content.replace("#!/bin/bash", f"#!{bash}", 1))
            path.chmod(0o755)

    def migrate(
        self, *args: str, failure: str = ""
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(self.script), *args],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "XDG_STATE_HOME": str(self.base / "state"),
                "TEST_LOG": str(self.log),
                "TEST_REPO": str(self.repo),
                "TEST_FAILURE": failure,
            },
            text=True,
            capture_output=True,
            timeout=30,
        )

    def test_migration_preserves_data_backups_and_never_activates(self):
        result = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        local = self.host / "local"
        self.assertEqual(
            (local / "hardware-configuration.nix").read_bytes(), self.hardware
        )
        migrated = (local / "installation.nix").read_text()
        self.assertIn("import ../../../components/swap.nix", migrated)
        self.assertIn("import ../home.nix", migrated)
        backups = list(
            (self.base / "state/nix/host-data-migrations").iterdir()
        )
        self.assertEqual(len(backups), 1)
        self.assertEqual(
            (backups[0] / "hardware-configuration.nix").read_bytes(),
            self.hardware,
        )
        self.assertEqual(
            (backups[0] / "installation.nix").read_bytes(), self.installation
        )
        self.assertFalse((self.host / "installation.nix").exists())
        self.assertEqual(
            (self.host / "hardware-configuration.nix").read_text(), "example"
        )
        commands = self.log.read_text()
        self.assertIn("build --no-link", commands)
        self.assertNotIn("switch", commands)
        self.assertNotIn("python", commands)

    def test_migration_preview_and_conflicts_do_not_write(self):
        result = self.migrate("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.host / "local").exists())
        self.assertFalse((self.base / "state").exists())
        (self.host / "local").mkdir()
        result = self.migrate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("overwrite", result.stderr)
        self.assertEqual(
            (self.host / "hardware-configuration.nix").read_bytes(),
            self.hardware,
        )

    def test_changed_settings_build_or_lock_keeps_originals(self):
        for failure in ("settings", "build", "lock"):
            with self.subTest(failure=failure):
                result = self.migrate(failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(
                    (self.host / "hardware-configuration.nix").read_bytes(),
                    self.hardware,
                )
                self.assertEqual(
                    (self.host / "installation.nix").read_bytes(),
                    self.installation,
                )
                self.assertNotIn(" restore ", self.log.read_text())
                shutil.rmtree(self.host / "local")
                (self.repo / "flake.lock").write_text("pinned inputs")

    def test_symlinks_and_unrecognized_imports_are_rejected(self):
        (self.host / "installation.nix").write_text("custom imports")
        result = self.migrate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unrecognized", result.stderr)
        (self.host / "installation.nix").unlink()
        (self.host / "installation.nix").symlink_to(self.repo / "flake.lock")
        result = self.migrate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe", result.stderr)
        self.assertFalse((self.host / "local").exists())


if __name__ == "__main__":
    unittest.main()

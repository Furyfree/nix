"""Configuration cloning, generation and evaluation."""

import json
import os
import shutil
import subprocess
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any

from nixos_setup.common import (
    HOSTS,
    MAPPER,
    SOURCE_FLAKE,
    SUBVOLUMES,
    Plan,
    PreparedStorage,
    command_output,
    nix_string,
    run_command,
)
from nixos_setup.planning import (
    GUID,
    key_fingerprint,
    swap_error,
    username_error,
)


def windows_entry(guid: str) -> str:
    """Limine menu entry that chainloads Windows from another disk."""
    return (
        "/Windows\n"
        "  protocol: efi\n"
        f"  path: guid({guid}):/EFI/Microsoft/Boot/bootmgfw.efi\n"
    )


def render_installation(plan: Plan, resume_offset: int) -> str:
    if plan.host not in HOSTS or plan.storage.mode != "erase":
        raise ValueError(
            "Only erase installation of a known host is supported."
        )
    if plan.windows and not GUID.fullmatch(plan.windows):
        raise ValueError("Invalid Windows partition GUID.")
    if username_error(plan.username) or swap_error(
        str(plan.swap_gib), plan.storage.capacity
    ):
        raise ValueError("Invalid installation user or swap size.")
    if type(resume_offset) is not int or resume_offset < 0:
        raise ValueError("Invalid swap resume offset.")
    key_fingerprint(plan.ssh_key)
    user = nix_string(plan.username)
    key = nix_string(plan.ssh_key)
    keys = f"[ {key} ]" if plan.ssh_key else "[ ]"
    windows = (
        "  boot.loader.limine.extraEntries = "
        f"{nix_string(windows_entry(plan.windows))};\n"
        if plan.windows
        else ""
    )
    compression = "\n".join(
        f'  fileSystems.{nix_string(path)}.options = [ "compress=zstd" ];'
        for _, path in SUBVOLUMES
        if path != "/"
    )
    return f"""{{ ... }}:

{{
  imports = [ (import ../../../components/swap.nix {{
    sizeGiB = {plan.swap_gib};
  }}) ];

  programs.git.enable = true;
  users.users.{user} = {{
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = {keys};
  }};
  home-manager.users.{user} = import ../home.nix;

{compression}
  boot.resumeDevice = {nix_string(MAPPER)};
  boot.kernelParams = [ "resume_offset={resume_offset}" ];
{windows}}}
"""


def preflight_hardware() -> str:
    """Temporary mounts for pre-erasure checks, not deployment."""
    mounts = "\n".join(
        f"  fileSystems.{nix_string(path)} = {{ "
        f"device = {nix_string(MAPPER)}; "
        f'fsType = "btrfs"; options = [ "subvol={name}" ]; }};'
        for name, path in SUBVOLUMES
    )
    return f"""{{ ... }}: {{
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.initrd.luks.devices.cryptroot.device =
    "/dev/disk/by-uuid/preflight-only";
  fileSystems."/boot" = {{
    device = "/dev/disk/by-uuid/preflight-only"; fsType = "vfat";
  }};
{mounts}
}}
"""


def local_configuration(host: Path) -> Path:
    local = host / "local"
    if local.is_symlink() or (local.exists() and not local.is_dir()):
        raise ValueError(
            "Local configuration directory must not be a symlink."
        )
    for name in ("hardware-configuration.nix", "installation.nix"):
        path = local / name
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError(
                f"Missing or unsafe local configuration file: {path}"
            )
    return local


def evaluate_configuration(
    repo: Path, plan: Plan, offset: int
) -> dict[str, Any]:
    user = nix_string(plan.username)
    expression = f"""c: {{
      toplevel = c.system.build.toplevel.drvPath;
      system = c.system.build.toplevel.outPath;
      mutable = c.users.mutableUsers;
      git = c.programs.git.enable;
      efi = c.boot.loader.efi.efiSysMountPoint;
      limine = c.boot.loader.limine.enable && c.boot.loader.limine.efiSupport;
      removable = c.boot.loader.limine.efiInstallAsRemovable;
      entries = c.boot.loader.limine.extraEntries;
      host = c.networking.hostName;
      user = c.users.users.{user}.isNormalUser;
      groups = c.users.users.{user}.extraGroups;
      keys = c.users.users.{user}.openssh.authorizedKeys.keys;
      home = c.home-manager.users.{user}.home.homeDirectory;
      autoLogin = c.services.displayManager.autoLogin.enable;
      autoLoginUser = c.services.displayManager.autoLogin.user;
      initialSessionUser = c.services.greetd.settings.initial_session.user;
      swaps = map (s: {{ inherit (s) device size; }}) c.swapDevices;
      resume = c.boot.resumeDevice;
      params = c.boot.kernelParams;
      filesystems = builtins.mapAttrs (_: f:
        {{ inherit (f) device fsType options; }}) c.fileSystems;
      luks = c.boot.initrd.luks.devices.cryptroot.device;
      failures = map (a: a.message)
        (builtins.filter (a: !a.assertion) c.assertions);
    }}"""
    result = json.loads(
        command_output(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "eval",
                "--json",
                "--no-write-lock-file",
                "--no-update-lock-file",
                f"path:{repo}#nixosConfigurations.{plan.host}.config",
                "--apply",
                expression,
            ],
            timeout=300,
        )
    )
    if (
        result["failures"]
        or result["mutable"] is not True
        or result["git"] is not True
        or result["efi"] != "/boot"
        or result["limine"] is not True
        or result["host"] != plan.host
        or result["user"] is not True
        or not {"wheel", "networkmanager"} <= set(result["groups"])
        or result["keys"] != ([plan.ssh_key] if plan.ssh_key else [])
        or result["home"] != f"/home/{plan.username}"
        or result["autoLogin"] is not True
        or result["autoLoginUser"] != plan.username
        or result["initialSessionUser"] != plan.username
        or result["swaps"]
        != [
            {
                "device": "/var/swap/swapfile",
                "size": plan.swap_gib * 1024,
            }
        ]
        or result["resume"] != MAPPER
        or (windows_entry(plan.windows) if plan.windows else "")
        not in result["entries"]
        or [p for p in result["params"] if p.startswith("resume_offset=")]
        != [f"resume_offset={offset}"]
    ):
        raise ValueError(
            "Generated host configuration does not match the plan."
        )
    for name, path in SUBVOLUMES:
        fs = result["filesystems"].get(path, {})
        if (
            fs.get("fsType") != "btrfs"
            or fs.get("device") != MAPPER
            or f"subvol={name}" not in fs.get("options", [])
            or "compress=zstd" not in fs.get("options", [])
        ):
            raise ValueError(
                f"Generated mount does not match the plan: {path}"
            )
    return result


@contextmanager
def prepare_checkout(plan: Plan) -> Generator[Path]:
    """Clone and validate before erasure, keeping the lock unchanged."""
    provisional = render_installation(plan, 0)
    for tool in ("nix", "git", "nixos-generate-config", "blkid", "cryptsetup"):
        if shutil.which(tool) is None:
            raise ValueError(f"Missing installation tool: {tool}")
    with TemporaryDirectory(prefix="nixos-setup-") as directory:
        repo = Path(directory) / "nix"
        print(f"Cloning latest main from {SOURCE_FLAKE}...")
        run_command(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "flake",
                "clone",
                SOURCE_FLAKE,
                "--dest",
                str(repo),
            ],
            timeout=180,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )
        host = repo / "hosts" / plan.host
        for path in (
            repo,
            repo / ".git",
            repo / "hosts",
            host,
            repo / "components",
        ):
            if path.is_symlink() or not path.is_dir():
                raise ValueError("Clone is not a standalone Git checkout.")
        for path in (
            repo / "flake.nix",
            repo / "flake.lock",
            host / "configuration.nix",
            host / "home.nix",
            repo / "components" / "swap.nix",
        ):
            if path.is_symlink() or not path.is_file():
                raise ValueError(
                    f"Missing or unsafe configuration file: {path}"
                )
        local = local_configuration(host)
        if local.exists():
            raise ValueError(
                "Public clone must not contain local machine data."
            )
        local.mkdir(mode=0o700)
        lock = (repo / "flake.lock").read_bytes()
        (local / "hardware-configuration.nix").write_text(preflight_hardware())
        (local / "installation.nix").write_text(provisional)
        print("Checking chosen settings with temporary mount fixtures...")
        evaluate_configuration(repo, plan, 0)
        if (repo / "flake.lock").read_bytes() != lock:
            raise ValueError("Configuration evaluation changed flake.lock.")
        yield repo


def generate_configuration(
    plan: Plan,
    storage: PreparedStorage,
    checkout: Path,
) -> Path:
    """Keep tracked config; write detected machine data locally."""
    settings = render_installation(plan, storage.resume_offset)
    if (
        not storage.root.is_absolute()
        or storage.root == Path("/")
        or storage.resume_device != MAPPER
    ):
        raise ValueError(
            "Invalid prepared installation root or resume device."
        )
    target = storage.root / "home" / plan.username / "Projects" / "nix"
    for path in (target, *target.parents):
        if path.is_symlink():
            raise ValueError(
                f"Installation path must not be a symlink: {path}"
            )
    if target.exists():
        raise ValueError("Target checkout already exists; refusing overwrite.")
    host = checkout / "hosts" / plan.host
    preserved = {
        path: path.read_bytes()
        for path in (
            checkout / "flake.lock",
            host / "configuration.nix",
            host / "home.nix",
            *(
                [host / "hardware-configuration.nix"]
                if (host / "hardware-configuration.nix").exists()
                else []
            ),
        )
    }
    local = local_configuration(host)
    local.mkdir(mode=0o700, exist_ok=True)
    print("Generating hardware settings from the mounted installation...")
    hardware = command_output(
        [
            "nixos-generate-config",
            "--root",
            str(storage.root),
            "--show-hardware-config",
        ],
        timeout=120,
    )
    if not hardware.strip():
        raise ValueError("Hardware detection returned an empty configuration.")
    (local / "hardware-configuration.nix").write_text(hardware)
    (local / "installation.nix").write_text(settings)
    result = evaluate_configuration(checkout, plan, storage.resume_offset)
    luks_uuid = subprocess.check_output(
        ["cryptsetup", "luksUUID", storage.luks_device],
        text=True,
        timeout=10,
    ).strip()
    efi_uuid = subprocess.check_output(
        ["blkid", "-s", "UUID", "-o", "value", storage.efi_device],
        text=True,
        timeout=10,
    ).strip()
    if (
        not luks_uuid
        or not efi_uuid
        or result["luks"] != f"/dev/disk/by-uuid/{luks_uuid}"
        or result["filesystems"]["/boot"]["device"]
        != f"/dev/disk/by-uuid/{efi_uuid}"
        or result["filesystems"]["/boot"]["fsType"] != "vfat"
    ):
        raise ValueError("Generated hardware uses the wrong disk identifiers.")
    if any(path.read_bytes() != data for path, data in preserved.items()):
        raise ValueError("Generation changed custom settings or flake.lock.")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(checkout, target, symlinks=True)
    print(f"Configuration ready at {target}; ownership follows installation.")
    return target

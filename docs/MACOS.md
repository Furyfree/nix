# macOS work profile review and implementation plan

The `macos-home-manager` branch provides standalone Home Manager configurations
for Apple silicon Macs. Keep mac-setup responsible for applications, command-line
tools and system settings; use Home Manager for shared configuration and Mise
for its declared runtimes and tools. Prepare and validate the work profile
before activating it.

This review covers branch commit `ee397e5` and the locally recorded main commit
`62ea090`. It describes repository behavior and generic setup requirements;
machine inventories, account details and private SSH hosts stay outside Git.

## Integrating main

At the reviewed revisions, the branch has six commits absent from main and
main has nine commits absent from the branch. A merge simulation produced a
conflict-free tree. Main includes updated Nix inputs, another shell plugin,
Fastfetch fixes and Linux desktop changes.

Fetch the latest remote refs before integrating main. Remote fetching failed
in the review environment, so these revisions do not establish the current
remote state. Merge main into the feature branch and repeat checks against
the resulting lock file; a conflict-free merge does not establish that the
configuration evaluates or works on macOS.

## Findings before activation

### Shell initialization and portability

- `configs/zsh/.zprofile` initializes Apple silicon Homebrew and Cargo, but
  does not initialize Nix. Ensure fresh login shells load the installed Nix
  profile and can find `nix`, `nix-env` and `nix-store`. Do not rely on the
  launching terminal's inherited PATH.
- Preserve needed local shell settings before replacing the managed files.
  The existing `work.zsh` hook supports private work configuration outside
  the repository; do not copy its contents into public configuration.
- The `codium-extensions` alias in `configs/zsh/conf.d/aliases.zsh` uses
  GNU `xargs -a`. Replace it with input redirection or another form supported
  by macOS before describing the alias as shared across platforms.
- `configs/fastfetch/config.jsonc` contains a NixOS logo and Linux-specific
  probes for installation age, Noctalia and Flatpak. Select appropriate
  platform settings and verify the installed Fastfetch supports the Lua
  formatting used by the shared configuration.
- Review Ghostty's shared GTK settings and Mac override with the installed
  Mac version, and check editor shortcuts on the Mac keyboard.

### SSH profiles and private hosts

`configs/ssh/work.conf` already selects `github.pub` for `github.com` and
`work.pub` for other hosts, with `IdentitiesOnly yes`. Preserve that routing.
`home/darwin.nix` maps the common agent socket path to the Mac 1Password
socket and links the Git signer from the installed application.

The profile includes `~/.ssh/local.conf`. Before replacing an existing SSH
configuration, preserve its private host entries in that local file or obtain
the correct private document. Verify hostname, user, port and key selection
with `ssh -G`; host blocks in included files can affect the selected identities.

Public key files select keys held by the agent. Obtain them from the correct
1Password account and vault. An item lookup may need both `--account` and
`--vault`; verify the lookup succeeds before redirecting output into a key
file, since shell redirection can leave an empty file on failure. Confirm
the work agent configuration makes both intended keys available. Keep key
contents, fingerprints, account identifiers and private host records out of
this public review.

### Git settings and required tools

The shared Git configuration enables delta, Git LFS and SSH commit signing.
Provide the corresponding executables before relying on those features.
Store machine-specific commit identity and signing-key selection in the
untracked local Git configuration.

Check both `~/.gitconfig` and `~/.config/git/config`. Git reads the former
after the XDG configuration, so overlapping values can override the new
settings. Reconcile the files deliberately and inspect effective values with
`git config --show-origin` before testing a signed commit in a temporary repo.

Audit tools against `INSTALLATION.md` and the configurations actually enabled
on the Mac. Distinguish runtime requirements from optional applications and
Linux-only developer checks. Make VSCodium configuration conditional when the
application is not installed. Home Manager still needs Nix dependencies for
activation, including the referenced Yq executable; documentation should not
imply that building the configuration adds nothing to the Nix store.

### Existing files and live checkout links

`home/common.nix` links the repository's `pull-projects` over any existing
local command. Bring the final per-repository status table into the tracked
script before activation, preserving fast-forward-only updates and skip
behavior for unsafe repository states.

Inventory managed destinations before activation and compare existing shell,
Ghostty, editor, Git and agent settings. Keep needed local settings and make
backups before replacement. Check for existing backup-name collisions rather
than deleting earlier backups automatically.

Most managed files link directly into `~/Projects/nix/configs`. Once active,
editing or switching branches in that checkout can immediately change the
configuration applications read without another Home Manager activation.
Use separate checkouts for subsequent reviews and unvalidated changes.

### Mac host configuration and workstation commands

- Create only the selected Mac host's ignored `local/user.nix`, setting
  `home.username`. `macos-work` already selects the work SSH profile.
  Confirm the derived home directory and generated destinations before use.
- `nix-workstation` requires exactly one matching Mac `local/user.nix` to
  select the host. Provide a clear preflight error for missing or ambiguous
  host configuration.
- `cmd_switch_darwin` creates a temporary result link without removing it.
  Add cleanup on success, declined confirmation and failure. The leftover
  links can retain store paths after old profile generations are removed.
- Validate that `switch`, `info`, `rollback` and `clean` use the same profile
  path as the pinned Home Manager activation. Verify retention and rollback
  with disposable generations before relying on recovery.
- Do not treat `nix flake check` alone as proof that the custom
  `homeConfigurations` output was evaluated. Evaluate and build the selected
  Mac activation package explicitly.

## Implementation order

1. Fetch and integrate current main without activating a configuration.
2. Fix shell initialization, command portability, platform-specific display
   settings and temporary build cleanup. Preserve the improved pull summary.
3. Align mac-setup's tool declarations with the enabled Mac configurations
   and update `INSTALLATION.md` to describe the actual requirements.
4. Prepare the ignored work host data and private local SSH and Git files.
   Confirm the existing 1Password keys and agent selection before switching.
5. Build and inspect the selected configuration, compare existing destination
   files, and prepare backups and an explicit recovery procedure.
6. Review the resulting changes before a separately authorized activation.
   Keep the current terminal open during the first activation and verify a
   fresh terminal before closing it.

## Validation and acceptance

The temporary merged snapshot passed Bash syntax checks for the workstation
and pull scripts, a Zsh syntax check for `.zprofile`, and 14 installer planning
tests. A stand-in build reproduced the leftover result link after a declined
Mac switch. These checks do not establish that the Mac configuration builds
or activates successfully.

The wider installer tests need Linux facilities, including `memfd_create`,
and their path checks encountered macOS's `/var` symlink. Run the repository's
full Linux checks on Linux. Nix evaluation in the review environment was
blocked by daemon socket permissions; live activation has not been tested.

Before activation:

- Run the repository checks appropriate to each platform, including the full
  Linux gate after integrating main.
- Explicitly evaluate and build
  `path:.#homeConfigurations.macos-work.activationPackage` without invoking
  `activate`. Use temporary host fixtures outside the live checkout for tests.
- Inspect the generated activation and managed files, then use the pinned
  Home Manager's activation dry run and verify that it leaves user files
  unchanged. Check configuration merges and backup behavior in isolation.
- Test fresh login and interactive shell startup with isolated configuration
  paths; do not trigger runtime installation or overwrite the live shell.
- Check SSH routing and Git settings without publishing private output.
  Test signing in a temporary repository with the intended identity.
- Exercise switch cancellation, failed builds and cleanup with stand-in
  commands. Confirm rollback/profile behavior before the first live switch.

After a separately authorized activation, verify fresh terminal startup,
GitHub and work Git authentication, signed commits, Ghostty and editor
settings, and the pull summary. Then verify generation listing and the agreed
recovery path. A successful build alone does not satisfy these checks.

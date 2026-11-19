# macOS

Every Mac, through nix-darwin and Homebrew, from the one `macos` host. The root
`AGENTS.md` holds the rules that must not break.

## Map

- `default.nix`: every Mac: nix-darwin, Homebrew and the Home Manager user.
- `common.nix`: the Homebrew apps and command-line tools every Mac gets; a
  tool there mirrors `../home-manager/cli-tools.nix`.
- `settings.nix`, `shortcuts.nix`: macOS settings and keyboard shortcuts.
- `home.nix`: Home Manager for the Macs, on top of
  `../home-manager/common.nix`.
- `personal.nix`, `work.nix`: one profile per Mac, which the ignored
  `local/user.nix` imports with the account.
- `bootstrap.sh`: the first setup; it writes `local/user.nix`.

## Verify

`just eval-local` evaluates both profiles on Linux; a switch needs the Mac.

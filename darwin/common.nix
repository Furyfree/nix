# Apps, fonts and command-line tools from Homebrew on every Mac.
_:

{
  homebrew = {
    taps = [
      {
        name = "abue-ammar/tinycast";
        trusted = true;
      }
    ];

    casks = [
      # Window management, launcher and menu bar
      "thaw@beta" # Thaw 3: the only version for macOS 27
      "vorssaint"
      "abue-ammar/tinycast/tinycast"
      "itsycal" # 0.27 or later on 27

      # Terminal, editors and development
      "ghostty"
      "zed"
      "vscodium"
      "jetbrains-toolbox"
      "t3-code"

      # AI
      "chatgpt" # never --zap: it deletes ~/.codex
      "claude"

      # Browser and notes
      "brave-origin"
      "obsidian"

      # Communication and media
      "signal"
      "spotify"
      "iina"
      "obs" # 33.0 or later; 32.x crashes on 27.2

      # Security
      "1password"
      "1password-cli"

      "font-jetbrains-mono-nerd-font" # Ghostty's font
      "font-inter" # Zed's interface font, as on Linux
    ];

    # Command-line tools the shared configs use, as components/shell.nix,
    # cli.nix and development.nix install them on NixOS; a tool added there goes
    # here too.
    # macOS and the Command Line Tools provide Git, clangd, clang-format, file,
    # zip and unzip; Nix installs nixd and nh, which Homebrew lacks.
    brews = [
      "starship"
      "sheldon"
      "fzf"
      "zoxide"
      "bat"
      "eza"
      "git-lfs"
      "neovim"
      "tree-sitter-cli" # the CLI; "tree-sitter" is only the library
      "gh"
      "lazygit"
      "btop"
      "fastfetch"
      "yazi"
      "fd"
      "ripgrep"
      "tealdeer"
      "just"
      "yq" # mikefarah's yq, as nixpkgs' yq-go
      "duf"
      "tokei"
      "sevenzip" # installs 7zz, which aliases.zsh maps to 7z
      "unar" # RAR archives: Homebrew dropped unrar
      "poppler"
      "imagemagick"
      "yt-dlp"
      "typst"
      "nmap"
      "gitleaks"
      "ffmpeg"
      # python3 for scripts such as ai-workflow's install.py; macOS's own is too
      # old.
      "python"
    ];
  };
}

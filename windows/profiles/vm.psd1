# My Windows: my apps, Mise for runtimes, languages and CLI tools, and NixOS-WSL.
# desktop builds on this layer.
@{
    Include    = @('common')
    Winget     = @(
        'jdx.mise'
        'DEVCOM.JetBrainsMonoNerdFont'
        'Brave.BraveOrigin'
        'AgileBits.1Password'
        'AgileBits.1Password.CLI'
        'Tailscale.Tailscale'
        'ZedIndustries.Zed'
        'VSCodium.VSCodium'
        'JetBrains.Toolbox'
        'Anthropic.Claude'
        'OpenAI.ChatGPT'
        'Obsidian.Obsidian'
        'OpenWhisperSystems.Signal'
        # Its installer refuses to run as administrator.
        @{ Id = 'Spotify.Spotify'; User = $true }
        # Word, Excel and PowerPoint only, as on the Mac.
        @{
            Id   = 'Microsoft.Office'
            Args = @('--override', '/configure "{configs}\windows\office.xml"')
        }
        # Not from Mise; configs/mise/conf.d/windows-tools.toml says why.
        '7zip.7zip'
        'Gyan.FFmpeg'
    )
    Registry   = @('personal.reg')
    Links      = @{
        '~\.config\git\config'                             = 'git/config'
        '~\.config\git\ignore'                             = 'git/ignore'
        '~\.config\starship.toml'                          = 'starship/starship.toml'
        '%LOCALAPPDATA%\nvim'                              = 'nvim'
        '~\.config\mise\config.toml'                       = 'mise/config.toml'
        '~\.config\mise\conf.d\runtimes.toml'              = 'mise/conf.d/runtimes.toml'
        '~\.config\mise\conf.d\agents.toml'                = 'mise/conf.d/agents.toml'
        '~\.config\mise\conf.d\windows-tools.toml'         = 'mise/conf.d/windows-tools.toml'
        '%APPDATA%\VSCodium\product.json'                  = 'vscodium/product.json'
        '%APPDATA%\VSCodium\User\keybindings.json'         = 'vscodium/keybindings.json'
        # A list, which a merge would replace anyway
        '%APPDATA%\Zed\keymap.json'                        = 'zed/keymap.json'
        # T3 Code keeps these next to its threads and secrets, which stay unlinked.
        '~\.t3\userdata\settings.json'                     = 't3code/settings.json'
        '~\.t3\userdata\client-settings.json'              = 't3code/client-settings.json'
        '~\.t3\userdata\keybindings.json'                  = 't3code/keybindings.json'
        '~\.ssh\config'                                    = 'ssh/windows.conf'
        '%LOCALAPPDATA%\1Password\config\ssh\agent.toml'   = '1password/ssh/personal.toml'
        '~\Documents\PowerShell\profile.ps1'               = 'windows/powershell/profile.ps1'
        '~\.wslconfig'                                     = 'windows/wslconfig'
    }
    Merges     = @{
        # GitHub Dark, as on the Mac; Noctalia's theme exists only on Linux.
        '%APPDATA%\VSCodium\User\settings.json'            = @('vscodium/settings.json', 'windows/vscodium.json')
        '%APPDATA%\Zed\settings.json'                      = 'zed/settings.json'
        '~\.claude\settings.json'                          = 'claude/settings.json'
        '~\.codex\config.toml'                             = 'codex/config.toml'
        '%APPDATA%\GitHub CLI\config.yml'                  = 'gh/config.yml'
        # Windows Terminal adds its own profiles to this file.
        '%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' =
        'windows/terminal/settings.json'
    }
    GitWindows = $true
    Extensions = @{ codium = 'vscodium/extensions.txt' }
    # Location, for night light and the time zone; WinUtil's Standard tweaks
    # disable it.
    Services   = @{ lfsvc = 'Manual' }
    NightLight = $true
    Wallpaper  = 'Pictures\Wallpapers\charcoal-amber-mountain-horizon.jpg'
    # NixOS-WSL's release image, checked against its SHA-256 before install
    Wsl        = @{
        Distribution = 'NixOS'
        Image        = 'https://github.com/nix-community/NixOS-WSL/releases/download/2605.7.2/nixos.wsl'
        Sha256       = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
    }
}

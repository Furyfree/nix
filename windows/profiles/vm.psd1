# My Windows: my apps, and Mise for runtimes, languages and CLI tools. Without
# WSL: this runs in a VM on Linux, which has no WSL2. desktop builds on this
# layer.
@{
    Include     = @('common')
    Winget      = @(
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
    # No winget package
    Downloads   = @{
        Fastmail = @{
            Url    = 'https://www.fastmail.com/download/windows/x64/'
            Signer = 'Fastmail Pty Ltd'
            Args   = @('/S')
            Path   = '%LOCALAPPDATA%\Programs\Fastmail\Fastmail.exe'
        }
    }
    Registry    = @('personal.reg')
    Links       = @{
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
        '%DOCUMENTS%\PowerShell\profile.ps1'               = 'windows/powershell/profile.ps1'
    }
    Merges      = @{
        # GitHub's themes, as on the Mac; Noctalia's exist only on Linux.
        '%APPDATA%\VSCodium\User\settings.json'            = @('vscodium/settings.json', 'windows/vscodium.json')
        '%APPDATA%\Zed\settings.json'                      = @('zed/settings.json', 'windows/zed.json')
        '~\.claude\settings.json'                          = 'claude/settings.json'
        '~\.codex\config.toml'                             = 'codex/config.toml'
        '%APPDATA%\GitHub CLI\config.yml'                  = 'gh/config.yml'
        # Windows Terminal adds its own profiles to this file. Its new-tab menu
        # lists profiles by name, NixOS second on desktop; the others hide.
        '%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' =
        'windows/terminal/settings.json'
    }
    GitWindows  = $true
    Extensions  = @{ codium = 'vscodium/extensions.txt' }
    # Location, for night light and the time zone; WinUtil's Standard tweaks
    # disable it.
    Services    = @{ lfsvc = 'Manual' }
    # The home and projects folders, as in the Linux file manager
    QuickAccess = @('~', '~\Projects')
    NightLight  = $true
    Wallpaper   = 'Pictures\Wallpapers\charcoal-amber-mountain-horizon.jpg'
}

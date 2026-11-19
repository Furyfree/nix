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
        'ZedIndustries.Zed'
        # Word, Excel and PowerPoint only, as on the Mac.
        @{
            Id   = 'Microsoft.Office'
            Args = @('--override', '/configure "{configs}\windows\office.xml"')
        }
        # Not from Mise; configs/mise/conf.d/windows-tools.toml says why.
        '7zip.7zip'
    )
    Registry    = @('personal.reg')
    Links       = @{
        '~\.config\git\config'                             = 'git/config'
        '~\.config\git\ignore'                             = 'git/ignore'
        '~\.config\starship.toml'                          = 'starship/starship.toml'
        '%LOCALAPPDATA%\nvim'                              = 'nvim'
        '~\.config\mise\config.toml'                       = 'mise/config.toml'
        '~\.config\mise\conf.d\agents.toml'                = 'mise/conf.d/agents.toml'
        '~\.config\mise\conf.d\windows-tools.toml'         = 'mise/conf.d/windows-tools.toml'
        '~\.ssh\config'                                    = 'ssh/windows.conf'
        '%LOCALAPPDATA%\1Password\config\ssh\agent.toml'   = '1password/ssh/personal.toml'
        '%DOCUMENTS%\PowerShell\profile.ps1'               = 'windows/powershell/profile.ps1'
    }
    Merges      = @{
        '%APPDATA%\Zed\settings.json'                      = @('zed/settings.json', 'windows/zed.json')
        # Zed saves its keymap itself.
        '%APPDATA%\Zed\keymap.json'                        = 'zed/keymap.json'
        '~\.claude\settings.json'                          = 'claude/settings.json'
        '~\.codex\config.toml'                             = 'codex/config.toml'
        '%APPDATA%\GitHub CLI\config.yml'                  = 'gh/config.yml'
        # Windows Terminal adds its own profiles to this file. Its new-tab menu
        # lists profiles by name; the others hide.
        '%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' =
        'windows/terminal/settings.json'
    }
    GitWindows  = $true
    # Location, for night light and the time zone; WinUtil's Standard tweaks
    # disable it.
    Services    = @{ lfsvc = 'Manual' }
    # The home and projects folders, as in the Linux file manager
    QuickAccess = @('~', '~\Projects')
    NightLight  = $true
    Wallpaper   = 'Pictures\Wallpapers\charcoal-amber-mountain-horizon.jpg'
}

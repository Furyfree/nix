# My Windows: my apps, and Mise for runtimes, languages and CLI tools. Without
# WSL: this runs in a VM on Linux, which has no WSL2. desktop builds on this
# layer.
@{
    Include     = @('common')
    Winget      = @(
        'jdx.mise'
        'Brave.BraveOrigin'
        'AgileBits.1Password'
        'AgileBits.1Password.CLI'
        'ZedIndustries.Zed'
        # Word, Excel and PowerPoint only, as on the Mac.
        @{
            Id   = 'Microsoft.Office'
            Args = @('--override', '/configure "{configs}\windows\office.xml"')
        }
        # Not from Mise; configs/mise/conf.d/windows.toml says why.
        '7zip.7zip'
        'Gyan.FFmpeg'
        'ImageMagick.ImageMagick'
    )
    # The terminal and editors' font; the hash is from the release's SHA-256.txt.
    Fonts       = @{
        'JetBrainsMono Nerd Font' = @{
            Url    = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.zip'
            Sha256 = 'fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e'
            Files  = @('JetBrainsMonoNerdFont-*.ttf', 'JetBrainsMonoNerdFontMono-*.ttf')
        }
    }
    Registry    = @('personal.reg')
    Links       = @{
        '~\.config\git\config'                             = 'git/config'
        '~\.config\git\ignore'                             = 'git/ignore'
        '~\.config\starship.toml'                          = 'starship/starship.toml'
        '%LOCALAPPDATA%\nvim'                              = 'nvim'
        '~\.config\mise\config.toml'                       = 'mise/config.toml'
        '~\.config\mise\conf.d\windows.toml'               = 'mise/conf.d/windows.toml'
        '~\.ssh\config'                                    = 'ssh/windows.conf'
        '%LOCALAPPDATA%\1Password\config\ssh\agent.toml'   = '1password/ssh/personal.toml'
        '%DOCUMENTS%\PowerShell\profile.ps1'               = 'windows/powershell/profile.ps1'
        '~\.config\fastfetch\ff.lua'                       = 'fastfetch/ff.lua'
    }
    Merges      = @{
        '%APPDATA%\Zed\settings.json'                      = @('zed/settings.json', 'windows/zed.json')
        # Zed saves its keymap itself.
        '%APPDATA%\Zed\keymap.json'                        = 'zed/keymap.json'
        '~\.claude\settings.json'                          = 'claude/settings.json'
        '~\.codex\config.toml'                             = 'codex/config.toml'
        '%APPDATA%\GitHub CLI\config.yml'                  = 'gh/config.yml'
        # The shared layout with the Windows logo, as the Mac gets its own.
        '~\.config\fastfetch\config.jsonc'                 = @('fastfetch/config.jsonc', 'windows/fastfetch.json')
        # Windows Terminal adds its own profiles to this file. Its new-tab menu
        # lists profiles by name, NixOS second on desktop; the others hide.
        '%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' =
        'windows/terminal/settings.json'
    }
    GitWindows  = $true
    # Location, for night light and the time zone; WinUtil's Standard tweaks
    # disable it.
    Services    = @{ lfsvc = 'Manual' }
    # desktop.psd1 names its own
    Taskbar     = 'windows/taskbar-vm.xml'
    # The home and projects folders, as in the Linux file manager
    QuickAccess = @('~', '~\Projects')
    NightLight  = $true
    Wallpaper   = 'Pictures\Wallpapers\charcoal-amber-mountain-horizon.jpg'
}

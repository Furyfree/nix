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
    # Location, for night light and the time zone; WinUtil's Standard tweaks
    # disable it.
    Services   = @{ lfsvc = 'Manual' }
    NightLight = $true
    Wallpaper  = 'Pictures\Wallpapers\charcoal-amber-mountain-horizon.jpg'
    Wsl        = @{ Distribution = 'NixOS' }
}

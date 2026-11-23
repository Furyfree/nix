# The gaming PC: vm and gaming, plus the apps I use every day, its hardware,
# NixOS in WSL and dual boot with NixOS.
@{
    Include    = @('vm', 'gaming')
    Winget     = @(
        'Microsoft.PowerToys'
        'T3Tools.T3Code'
        'Tailscale.Tailscale'
        'Microsoft.VisualStudioCode'
        'JetBrains.Toolbox'
        'Anthropic.Claude'
        'OpenAI.ChatGPT'
        'Obsidian.Obsidian'
        'OpenWhisperSystems.Signal'
        # Its installer refuses to run as administrator.
        @{ Id = 'Spotify.Spotify'; User = $true }
    )
    # NVIDIA App
    Store      = @('XP8CLZL93F5Z4P')
    # No winget package
    Downloads  = @{
        Fastmail = @{
            Url    = 'https://www.fastmail.com/download/windows/x64/'
            Signer = 'Fastmail Pty Ltd'
            Args   = @('/S')
            Path   = '%LOCALAPPDATA%\Programs\Fastmail\Fastmail.exe'
        }
    }
    Registry   = @('desktop.reg')
    Links      = @{
        '~\.wslconfig'                         = 'windows/wslconfig'
        '%APPDATA%\Code\User\keybindings.json' = 'vscode/keybindings.json'
    }
    Merges     = @{
        # GitHub's themes, as on the Mac; Noctalia's exist only on Linux.
        '%APPDATA%\Code\User\settings.json'   = @('vscode/settings.json', 'windows/vscode.json')
        # T3 Code saves these itself, next to its threads and secrets, which stay
        # out of the checkout.
        '~\.t3\userdata\settings.json'        = 't3code/settings.json'
        '~\.t3\userdata\client-settings.json' = 't3code/client-settings.json'
        '~\.t3\userdata\keybindings.json'     = 't3code/keybindings.json'
    }
    # VS Code's extensions and its way into NixOS in WSL
    Extensions = @{ code = @('vscode/extensions.txt', 'ms-vscode-remote.remote-wsl') }
    Taskbar    = 'windows/taskbar.xml'
    # NixOS-WSL's release image, checked against its SHA-256 before install
    Wsl        = @{
        Distribution = 'NixOS'
        Image        = 'https://github.com/nix-community/NixOS-WSL/releases/download/2605.7.2/nixos.wsl'
        Sha256       = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
    }
    Power      = @{
        # Screen off after 5 minutes
        'SUB_VIDEO VIDEOIDLE'       = 300
        # Never sleep
        'SUB_SLEEP STANDBYIDLE'     = 0
        # The power button does nothing
        'SUB_BUTTONS PBUTTONACTION' = 0
    }
    BitLocker  = $true
}

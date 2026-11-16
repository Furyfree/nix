# The gaming PC: vm and gaming, plus its hardware, NixOS in WSL and dual boot
# with NixOS.
@{
    Include   = @('vm', 'gaming')
    # NVIDIA App
    Store     = @('XP8CLZL93F5Z4P')
    Registry  = @('desktop.reg')
    Links     = @{ '~\.wslconfig' = 'windows/wslconfig' }
    # NixOS-WSL's release image, checked against its SHA-256 before install
    Wsl       = @{
        Distribution = 'NixOS'
        Image        = 'https://github.com/nix-community/NixOS-WSL/releases/download/2605.7.2/nixos.wsl'
        Sha256       = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
    }
    Power     = @{
        # Screen off after 5 minutes
        'SUB_VIDEO VIDEOIDLE'       = 300
        # Never sleep
        'SUB_SLEEP STANDBYIDLE'     = 0
        # The power button does nothing
        'SUB_BUTTONS PBUTTONACTION' = 0
    }
    BitLocker = $true
}

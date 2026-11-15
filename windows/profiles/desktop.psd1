# The gaming PC: vm and gaming, plus its hardware and dual boot with NixOS.
@{
    Include   = @('vm', 'gaming')
    # NVIDIA App
    Store     = @('XP8CLZL93F5Z4P')
    Registry  = @('desktop.reg')
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

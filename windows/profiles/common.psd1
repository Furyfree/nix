# Every profile. basic, vm and desktop pick layers from this folder; apply.ps1
# reads them in Include order and applies each layer once. Keys:
#   Include         layers applied first, by file name without .psd1
#   Winget          package IDs; a hashtable adds Args (extra winget arguments;
#                   {configs} is the checkout's configs folder) or User = $true
#                   for an installer that refuses to run as administrator
#   Store           Microsoft Store IDs
#   Registry        files in windows/registry, imported in order
#   Links           target = file or folder in configs/; ~ is the home folder
#                   and %NAME% an environment variable. A real file in the way
#                   moves to <name>.before-nix-workstation first.
#   Merges          target = configs/ file or files, for settings apps rewrite:
#                   Yq sets only their keys, in order
#   GitWindows      $true writes ~\.config\git\windows, which git/config
#                   includes: Windows' ssh.exe and 1Password's signing program
#   Extensions      editor command = extension IDs, or a configs/ file of them
#   Wsl             Distribution, plus Apt packages for Ubuntu
#   Power           powercfg values on the active plan, 'SUBGROUP SETTING' = AC
#   Services        start types, name = 'Manual', 'Automatic' or 'Disabled'
#   NightLight      $true schedules night light from sunset to sunrise
#   Wallpaper       a picture under the home folder for the desktop and lock
#                   screen, set once it exists
#   BitLocker       $true turns it on with a recovery key file
@{
    Winget   = @(
        'Git.Git'
        'Microsoft.PowerShell'
        'Microsoft.PowerToys'
        'T3Tools.T3Code'
        # The C and C++ compiler and linker; Rust and Cargo builds need them.
        @{
            Id   = 'Microsoft.VisualStudio.BuildTools'
            Args = @(
                '--override'
                '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
            )
        }
    )
    Registry = @('common.reg')
}

# PowerShell 7's profile on vm and desktop, linked as
# ~\Documents\PowerShell\profile.ps1: what configs/zsh gives zsh on Linux.

# Mise first, so the tools below are on PATH.
if (Get-Command mise -ErrorAction Ignore) { mise activate pwsh | Out-String | Invoke-Expression }
if (Get-Command starship -ErrorAction Ignore) { starship init powershell | Out-String | Invoke-Expression }
if (Get-Command zoxide -ErrorAction Ignore) { zoxide init powershell | Out-String | Invoke-Expression }

# Listings through eza; ls is PowerShell's alias for Get-ChildItem until removed.
if (Get-Command eza -ErrorAction Ignore) {
    Remove-Item Alias:ls -Force -ErrorAction Ignore
    function ls { eza --icons=auto --grid --group-directories-first @args }
    function ll { eza -la --header --icons=auto --group-directories-first @args }
    function la { eza -a --icons=auto --grid --group-directories-first @args }
    function lt { eza --tree --icons=auto --group-directories-first @args }
}

# bat -pp, as the zsh alias: plain output, no pager.
$env:BAT_STYLE = 'plain'
$env:BAT_PAGING = 'never'

Set-Alias n nvim
Set-Alias lg lazygit
Set-Alias c Clear-Host
Set-Alias f fastfetch
Set-Alias help tldr
if (-not (Get-Command code -ErrorAction Ignore)) { Set-Alias code codium }

# nix-workstation's switch, update and mise on Linux
function nswitch { & "$HOME\Projects\nix\windows\apply.ps1" @args }
function nupdate { & "$HOME\Projects\nix\windows\apply.ps1" -Update @args }
function mup { mise upgrade @args }

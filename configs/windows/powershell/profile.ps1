# PowerShell 7's profile on vm and desktop, linked as
# ~\Documents\PowerShell\profile.ps1: what configs/zsh gives zsh on Linux.

# A tool's init script, saved until the tool's program changes: starting the
# three programs on every start is slow on Windows.
function Get-InitScript([string] $tool, [string[]] $arguments) {
    $program = (Get-Command $tool -CommandType Application -ErrorAction Ignore | Select-Object -First 1).Source
    if (-not $program) { return }
    $file = Join-Path $env:LOCALAPPDATA "nix-workstation\init\$tool.ps1"
    $stamp = "# $program $((Get-Item $program).LastWriteTimeUtc.Ticks)"
    if ((Get-Content $file -TotalCount 1 -ErrorAction Ignore) -ne $stamp) {
        New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
        @($stamp) + @(& $program @arguments) | Set-Content $file
    }
    $file
}

# Mise first, so the tools below are on PATH.
$init = Get-InitScript mise activate, pwsh
if ($init) { . $init }
$init = Get-InitScript starship init, powershell, '--print-full-init'
if ($init) { . $init }
$init = Get-InitScript zoxide init, powershell
if ($init) { . $init }
Remove-Variable init

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

# nix-workstation's switch, update and mise on Linux
function nswitch { & "$HOME\Projects\nix\windows\apply.ps1" @args }
function nupdate { & "$HOME\Projects\nix\windows\apply.ps1" -Update @args }
function mup { mise upgrade @args }

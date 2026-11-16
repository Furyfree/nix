#Requires -Version 7.4
<#
Makes Windows match a profile from windows/profiles; nswitch runs it. It checks
first and asks for administrator once, through sudo, only when a machine-wide
step has work. A second run changes nothing.
#>
param(
    # basic, vm or desktop; without it, the one hosts\windows\local\profile names
    [Alias('Profile')]
    [string] $ProfileName,
    # Upgrade winget and Mise packages first
    [switch] $Update,
    # The administrator half, which this script starts through sudo
    [switch] $Elevated
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$state = Join-Path $env:LOCALAPPDATA 'nix-workstation'
$failures = [System.Collections.Generic.List[string]]::new()
$wingetFlags = @('--accept-source-agreements', '--disable-interactivity')
$installFlags = @('--exact', '--silent', '--no-upgrade', '--accept-package-agreements') + $wingetFlags

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($admin -ne $Elevated.IsPresent) {
    throw 'Run apply.ps1 as yourself, not as administrator; it asks for administrator itself.'
}

if (-not $ProfileName) {
    $file = Join-Path $root 'hosts\windows\local\profile'
    if (-not (Test-Path $file)) { throw "Pass -Profile basic, vm or desktop, or write it to $file." }
    $ProfileName = (Get-Content $file -Raw).Trim()
}

# Each layer once, after the layers it includes. Lists add up, tables merge
# and single values take the last layer's.
$layers = [System.Collections.Generic.List[string]]::new()
function Add-Layer([string] $name) {
    if ($layers.Contains($name)) { return }
    $data = Import-PowerShellDataFile (Join-Path $PSScriptRoot "profiles\$name.psd1")
    foreach ($include in $data.Include) { Add-Layer $include }
    $layers.Add($name)
}
Add-Layer $ProfileName
$want = @{}
foreach ($layer in $layers) {
    $data = Import-PowerShellDataFile (Join-Path $PSScriptRoot "profiles\$layer.psd1")
    $data.Remove('Include')
    foreach ($key in $data.Keys) {
        $value = $data[$key]
        if ($null -eq $want[$key]) { $want[$key] = $value }
        elseif ($value -is [hashtable]) { foreach ($name in $value.Keys) { $want[$key][$name] = $value[$name] } }
        elseif ($value -is [array]) { $want[$key] += $value }
        else { $want[$key] = $value }
    }
}
foreach ($key in 'Winget', 'Store', 'Registry', 'VSCodeExtensions') { if ($null -eq $want[$key]) { $want[$key] = @() } }
foreach ($key in 'Power', 'Services', 'Wsl') { if ($null -eq $want[$key]) { $want[$key] = @{} } }
$packages = foreach ($entry in $want.Winget) { if ($entry -is [string]) { @{ Id = $entry } } else { $entry } }
$wallpaper = if ($want.Wallpaper) { Join-Path $HOME $want.Wallpaper }
$lockScreenKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

function Get-Installed {
    $file = Join-Path ([IO.Path]::GetTempPath()) "nix-workstation-$PID.json"
    winget export --output $file @wingetFlags *> $null
    if (-not (Test-Path $file)) { throw 'winget export failed.' }
    (Get-Content $file -Raw | ConvertFrom-Json).Sources.Packages.PackageIdentifier
    Remove-Item $file
}

function Get-RegistryHashes {
    $file = Join-Path $state 'registry.json'
    if (Test-Path $file) { Get-Content $file -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
}

function Get-RegistryChanges {
    $hashes = Get-RegistryHashes
    $want.Registry | Where-Object {
        $hashes[$_] -ne (Get-FileHash (Join-Path $PSScriptRoot "registry\$_")).Hash
    }
}

function Get-PowerAc([string] $subgroup, [string] $setting) {
    # The last two values are the AC and DC indexes.
    $values = [regex]::Matches((powercfg /query SCHEME_CURRENT $subgroup $setting) -join "`n", '0x[0-9a-fA-F]{8}')
    if ($values.Count -ge 2) { [Convert]::ToInt64($values[$values.Count - 2].Value, 16) }
}

function Test-BitLocker {
    # 1 is on and 3 encrypting; the Shell reads this without administrator.
    $protection = (New-Object -ComObject Shell.Application).NameSpace($env:SystemDrive).Self.ExtendedProperty(
        'System.Volume.BitLockerProtection')
    $protection -in 1, 3 -and (Test-Path (Join-Path $HOME "bitlocker-recovery-$env:COMPUTERNAME.txt"))
}

# What needs administrator, worked out the same way in both halves
function Get-AdminWork($installed) {
    @{
        Packages   = @($packages | Where-Object { -not $_.User -and $installed -notcontains $_.Id })
        Store      = @($want.Store | Where-Object { $installed -notcontains $_ })
        Registry   = @(Get-RegistryChanges)
        Power      = @($want.Power.Keys | Where-Object {
                $subgroup, $setting = $_ -split ' '
                (Get-PowerAc $subgroup $setting) -ne $want.Power[$_]
            })
        Services   = @($want.Services.Keys | Where-Object { [string](Get-Service $_).StartType -ne $want.Services[$_] })
        BitLocker  = $want.BitLocker -and -not (Test-BitLocker)
        LockScreen = $wallpaper -and (Test-Path $wallpaper) -and
            (Get-ItemProperty $lockScreenKey -ErrorAction Ignore).LockScreenImagePath -ne $wallpaper
    }
}

function Test-Work($work) {
    $work.Packages -or $work.Store -or $work.Registry -or $work.Power -or $work.Services -or $work.BitLocker -or
    $work.LockScreen
}

# winget exit codes for an app that is already there, or there after a restart
$wingetDone = @(0, 0x8A150061, 0x8A15010D)
$wingetRestart = @(0x8A150109, 0x8A15010B)
function Install-Package([string] $id, [string[]] $more) {
    Write-Host "install  $id"
    winget install --id $id @installFlags @more
    if ($LASTEXITCODE -in $wingetRestart) { $script:failures.Add("restart Windows to finish $id") }
    elseif ($LASTEXITCODE -notin $wingetDone) { $script:failures.Add("install $id ($LASTEXITCODE)") }
}

# The step sees this function's variables, so their names must not be ones a
# step uses.
function Invoke-Step([string] $stepName, [scriptblock] $stepBlock) {
    try { & $stepBlock } catch { $script:failures.Add("${stepName}: $_") }
}

function Save-RegistryBackup([string] $file) {
    # The first time apply touches a key, its old values go to the backup
    # folder; a key that did not exist gets an empty file.
    $backup = Join-Path $state 'backup'
    New-Item -ItemType Directory -Force $backup | Out-Null
    foreach ($line in Get-Content $file) {
        if ($line -notmatch '^\[(.+)\]$') { continue }
        $key = $Matches[1]
        $target = Join-Path $backup (($key -replace '[\\/:*?"<>|]', '_') + '.reg')
        if (Test-Path $target) { continue }
        reg export $key $target /y *> $null
        if ($LASTEXITCODE -ne 0) { Set-Content $target "Windows Registry Editor Version 5.00`r`n`r`n; Absent" }
    }
}

function Enable-BitLockerWithKey {
    # The recovery key goes to a file only; never print it.
    $drive = $env:SystemDrive
    $keyFile = Join-Path $HOME "bitlocker-recovery-$env:COMPUTERNAME.txt"
    $recovery = (Get-BitLockerVolume $drive).KeyProtector | Where-Object KeyProtectorType -EQ 'RecoveryPassword' |
        Select-Object -First 1
    if (-not $recovery) {
        $recovery = (Add-BitLockerKeyProtector $drive -RecoveryPasswordProtector -WarningAction Ignore).KeyProtector |
            Where-Object KeyProtectorType -EQ 'RecoveryPassword' | Select-Object -First 1
    }
    if (-not (Test-Path $keyFile)) {
        Set-Content $keyFile $recovery.RecoveryPassword -NoNewline
        Write-Host "BitLocker's recovery key is in $keyFile; keep it in 1Password from another device."
    }
    if ((Get-BitLockerVolume $drive).VolumeStatus -eq 'FullyDecrypted') {
        Enable-BitLocker $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly -TpmProtector -SkipHardwareTest `
            -WarningAction Ignore | Out-Null
    }
    $volume = Get-BitLockerVolume $drive
    if (-not ($volume.KeyProtector | Where-Object KeyProtectorType -EQ 'Tpm')) {
        Add-BitLockerKeyProtector $drive -TpmProtector -WarningAction Ignore | Out-Null
    }
    $volume = Get-BitLockerVolume $drive
    if ($volume.ProtectionStatus -eq 'Off' -and $volume.VolumeStatus -eq 'FullyEncrypted') {
        Resume-BitLocker $drive | Out-Null
    }
}

if ($Elevated) {
    if ($Update) {
        Write-Host 'upgrade  winget'
        winget upgrade --all --silent --accept-package-agreements @wingetFlags
        if ($LASTEXITCODE -ne 0) { $failures.Add("winget upgrade ($LASTEXITCODE)") }
    }
    $work = Get-AdminWork (Get-Installed)
    foreach ($package in $work.Packages) {
        $more = @('--source', 'winget') + @(foreach ($arg in $package.Args) { $arg.Replace('{configs}', "$root\configs") })
        Install-Package $package.Id $more
    }
    foreach ($id in $work.Store) { Install-Package $id @('--source', 'msstore') }
    if ($work.Registry) {
        New-Item -ItemType Directory -Force $state | Out-Null
        $hashes = Get-RegistryHashes
        foreach ($name in $work.Registry) {
            $file = Join-Path $PSScriptRoot "registry\$name"
            Invoke-Step "registry $name" {
                Save-RegistryBackup $file
                Write-Host "import   $name"
                reg import $file *> $null
                if ($LASTEXITCODE -ne 0) { throw "reg import failed ($LASTEXITCODE)" }
                $hashes[$name] = (Get-FileHash $file).Hash
            }
        }
        $hashes | ConvertTo-Json | Set-Content (Join-Path $state 'registry.json')
    }
    if ($work.Power) {
        foreach ($name in $work.Power) {
            Write-Host "power    $name"
            $subgroup, $setting = $name -split ' '
            powercfg /setacvalueindex SCHEME_CURRENT $subgroup $setting $want.Power[$name]
            if ($LASTEXITCODE -ne 0) { $failures.Add("power $name ($LASTEXITCODE)") }
        }
        powercfg /setactive SCHEME_CURRENT
    }
    foreach ($name in $work.Services) {
        Write-Host "service  $name"
        Invoke-Step "service $name" { Set-Service $name -StartupType $want.Services[$name] }
    }
    if ($work.LockScreen) {
        Write-Host 'lock     screen picture'
        Invoke-Step 'lock screen' {
            # New-Item -Force would empty a key that exists.
            if (-not (Test-Path $lockScreenKey)) { New-Item $lockScreenKey -Force | Out-Null }
            Set-ItemProperty $lockScreenKey LockScreenImagePath $wallpaper
            Set-ItemProperty $lockScreenKey LockScreenImageUrl $wallpaper
            Set-ItemProperty $lockScreenKey LockScreenImageStatus 1 -Type DWord
        }
    }
    if ($work.BitLocker) {
        Write-Host 'enable   BitLocker'
        Invoke-Step 'BitLocker' { Enable-BitLockerWithKey }
    }
    foreach ($failure in $failures) { Write-Host "FAIL     $failure" }
    exit [int]($failures.Count -gt 0)
}

$installed = Get-Installed
$work = Get-AdminWork $installed
if ($Update -or (Test-Work $work)) {
    $arguments = @('-NoProfile', '-File', $PSCommandPath, '-Elevated', '-Profile', $ProfileName)
    if ($Update) { $arguments += '-Update' }
    sudo pwsh @arguments
    if ($LASTEXITCODE -ne 0) { $failures.Add('the administrator steps; see above') }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

foreach ($package in $packages | Where-Object { $_.User -and $installed -notcontains $_.Id }) {
    Install-Package $package.Id @('--source', 'winget')
}

if (Get-Command mise -ErrorAction Ignore) {
    if ($Update) {
        Write-Host 'upgrade  mise'
        mise upgrade
        if ($LASTEXITCODE -ne 0) { $failures.Add("mise upgrade ($LASTEXITCODE)") }
    }
    mise install --yes
    if ($LASTEXITCODE -ne 0) { $failures.Add("mise install ($LASTEXITCODE)") }
}

if ($want.VSCodeExtensions -and (Get-Command code -ErrorAction Ignore)) {
    $extensions = code --list-extensions
    foreach ($extension in $want.VSCodeExtensions | Where-Object { $extensions -notcontains $_ }) {
        Write-Host "extend   $extension"
        code --install-extension $extension
        if ($LASTEXITCODE -ne 0) { $failures.Add("VS Code extension $extension ($LASTEXITCODE)") }
    }
}

if ($want.NightLight) {
    Invoke-Step 'night light' {
        # The schedule, sunset to sunrise, in Windows' CloudStore format.
        # Windows rewrites it with its own times, so only the schedule flag,
        # 02 01 after the inner header 43 42 01 00, compares.
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\' +
            'default$windows.data.bluelightreduction.settings\windows.data.bluelightreduction.settings'
        $current = (Get-ItemProperty $key -ErrorAction Ignore).Data
        if (-not $current -or -not [Convert]::ToHexString($current).Contains('434201000201')) {
            Write-Host 'set      night light'
            $schedule = [byte[]](0x43, 0x42, 0x01, 0x00, 0x02, 0x01, 0xCA, 0x14, 0x00, 0xCA, 0x1E, 0x00, 0xCF,
                0x28, 0x90, 0x35, 0xCA, 0x32, 0x0E, 0x13, 0x2E, 0x17, 0x00, 0xCA, 0x3C, 0x0E, 0x07, 0x2E, 0x0C,
                0x00, 0x00)
            $tail = [byte[]](@(0x2A, 0x2B, 0x0E, $schedule.Length) + $schedule + @(0x00, 0x00, 0x00))
            $time = [uint64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $varint = while ($true) {
                if ($time -lt 0x80) { [byte]$time; break }
                [byte](($time -band 0x7F) -bor 0x80)
                $time = $time -shr 7
            }
            if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
            Set-ItemProperty $key Data ([byte[]](@(0x43, 0x42, 0x01, 0x00, 0x0A, 0x02, 0x01, 0x00, 0x2A, 0x06) +
                $varint + $tail)) -Type Binary
        }
    }
}

if ($wallpaper -and (Test-Path $wallpaper)) {
    $desktop = 'HKCU:\Control Panel\Desktop'
    if ((Get-ItemProperty $desktop).WallPaper -ne $wallpaper) {
        Write-Host 'set      wallpaper'
        Set-ItemProperty $desktop WallpaperStyle '10'
        Set-ItemProperty $desktop TileWallpaper '0'
        Add-Type -Namespace NixWorkstation -Name Desktop -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
'@
        # Set the wallpaper, save it and tell open windows.
        if (-not [NixWorkstation.Desktop]::SystemParametersInfo(0x14, 0, $wallpaper, 3)) { $failures.Add('wallpaper') }
    }
}

if ($want.Wsl.Distribution -eq 'Ubuntu') {
    Invoke-Step 'Ubuntu' {
        $env:WSL_UTF8 = '1'
        # A WSL without distributions exits with an error here too.
        if ((wsl --list --quiet 2> $null) -notcontains 'Ubuntu') {
            Write-Host 'install  Ubuntu'
            wsl --install --distribution Ubuntu --no-launch
            if ($LASTEXITCODE -ne 0) { throw "wsl --install ($LASTEXITCODE); restart Windows if WSL is new" }
            Write-Host 'note     Open Ubuntu from Start to create your Linux user; then run this again.'
        }
        elseif (-not (wsl --distribution Ubuntu --user root --exec getent passwd 1000)) {
            Write-Host 'note     Open Ubuntu from Start to create your Linux user; then run this again.'
        }
        else {
            $apt = $want.Wsl.Apt -join ' '
            if ($apt) { wsl --distribution Ubuntu --user root --exec sh -c "dpkg -s $apt > /dev/null 2>&1" }
            if ($apt -and $LASTEXITCODE -ne 0) {
                Write-Host "apt      $apt"
                wsl --distribution Ubuntu --user root --exec sh -c "apt-get update && apt-get install -y $apt"
                if ($LASTEXITCODE -ne 0) { throw "apt-get install ($LASTEXITCODE)" }
            }
            # Git in Ubuntu signs in through Git for Windows' Credential Manager.
            $helper = '/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'
            if ((wsl --distribution Ubuntu --exec git config --global --get credential.helper) -ne $helper) {
                Write-Host 'set      Git credential helper in Ubuntu'
                wsl --distribution Ubuntu --exec git config --global credential.helper $helper
            }
        }
    }
}

if ($work.Registry.Count -gt @(Get-RegistryChanges).Count) {
    # The taskbar and Explorer read their settings at start; Windows restarts it.
    Write-Host 'restart  Explorer'
    Stop-Process -Name explorer -Force
}

foreach ($failure in $failures) { Write-Host "FAIL     $failure" }
exit [int]($failures.Count -gt 0)

#Requires -Version 7.4
<#
Makes Windows match a profile from windows/profiles; nswitch runs it. It checks
first and asks for administrator once, through sudo, only when a machine-wide
step has work. A second run changes nothing.
#>
param(
    # Upgrade winget and Mise packages first
    [switch] $Update,
    # The administrator half, which this script starts through sudo
    [switch] $Elevated
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$state = Join-Path $env:LOCALAPPDATA 'nix-workstation'
# Windows' Documents folder, wherever OneDrive or the user moved it; profiles
# link into it as %DOCUMENTS%.
$env:DOCUMENTS = [Environment]::GetFolderPath('MyDocuments')
$failures = [System.Collections.Generic.List[string]]::new()
$wingetFlags = @('--accept-source-agreements', '--disable-interactivity')
$installFlags = @('--exact', '--silent', '--no-upgrade', '--accept-package-agreements') + $wingetFlags

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($admin -ne $Elevated.IsPresent) {
    throw 'Run apply.ps1 as yourself, not as administrator; it asks for administrator itself.'
}

# bootstrap.ps1 writes basic, vm or desktop here.
$ProfileName = (Get-Content (Join-Path $root 'hosts\windows\local\profile') -Raw).Trim()

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
foreach ($key in 'Winget', 'Store', 'Registry') { if ($null -eq $want[$key]) { $want[$key] = @() } }
foreach ($key in 'Links', 'Merges', 'Extensions', 'Power', 'Services', 'Wsl', 'Downloads') {
    if ($null -eq $want[$key]) { $want[$key] = @{} }
}
$packages = foreach ($entry in $want.Winget) { if ($entry -is [string]) { @{ Id = $entry } } else { $entry } }
$wallpaper = if ($want.Wallpaper) { Join-Path $HOME $want.Wallpaper }
$lockScreenKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
# The Start Layout policy, which only administrators may set, even per user
$taskbar = if ($want.Taskbar) { [IO.Path]::GetFullPath((Join-Path $root "configs/$($want.Taskbar)")) }
$taskbarKey = 'HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Explorer'

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
    # The last two values are the AC and DC indexes. /qh also lists settings
    # Windows hides, such as the power button's action on some PCs.
    $values = [regex]::Matches((powercfg /qh SCHEME_CURRENT $subgroup $setting) -join "`n", '0x[0-9a-fA-F]{8}')
    if ($values.Count -ge 2) { [Convert]::ToInt64($values[$values.Count - 2].Value, 16) }
}

function Test-BitLocker {
    # 1 is on and 3 encrypting; the Shell reads this without administrator.
    $protection = (New-Object -ComObject Shell.Application).NameSpace($env:SystemDrive).Self.ExtendedProperty(
        'System.Volume.BitLockerProtection')
    $protection -in 1, 3 -and (Test-Path (Join-Path $HOME "bitlocker-recovery-$env:COMPUTERNAME.txt"))
}

function Test-Wsl {
    # Windows' own wsl.exe exits with an error until WSL is installed. WSL 2
    # also needs the Host Compute Service, which the Virtual Machine Platform
    # brings only after a restart.
    wsl --status *> $null
    $LASTEXITCODE -eq 0 -and (Get-Service vmcompute -ErrorAction Ignore)
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
        Taskbar    = $taskbar -and $(
            $policy = Get-ItemProperty "Registry::$taskbarKey" -ErrorAction Ignore
            $policy.StartLayoutFile -ne $taskbar -or $policy.LockedStartLayout -ne 1
        )
        Wsl        = $want.Wsl.Distribution -and -not (Test-Wsl)
    }
}

function Test-Work($work) {
    $work.Packages -or $work.Store -or $work.Registry -or $work.Power -or $work.Services -or $work.BitLocker -or
    $work.LockScreen -or $work.Taskbar -or $work.Wsl
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

# The value names a .reg file sets, by key
function Get-RegistryNames([string] $file) {
    $names = [ordered]@{}
    foreach ($line in Get-Content $file) {
        if ($line -match '^\[(.+)\]$') { $key = $Matches[1]; if (-not $names.Contains($key)) { $names[$key] = @() } }
        elseif ($line -match '^"(.+?)"=') { $names[$key] += $Matches[1] }
    }
    $names
}

function Save-RegistryBackup([Collections.IDictionary] $names) {
    # A file per key that undoes apply, so reg import restores the key: the
    # first time apply touches it, its old values, or the key's deletion when
    # it did not exist; then deletions for values apply adds, also later ones.
    $backup = Join-Path $state 'backup'
    New-Item -ItemType Directory -Force $backup | Out-Null
    foreach ($key in $names.Keys) {
        $target = Join-Path $backup (($key -replace '[\\/:*?"<>|]', '_') + '.reg')
        if (-not (Test-Path $target)) {
            reg export $key $target /y *> $null
            if ($LASTEXITCODE -ne 0) {
                Set-Content $target "Windows Registry Editor Version 5.00`r`n`r`n[-$key]" -Encoding unicode
                continue
            }
        }
        if ((Get-Content $target) -contains "[-$key]") { continue }
        # The values the backup already restores, in this key's own sections;
        # an export also holds its subkeys.
        $section = $null
        $saved = foreach ($line in Get-Content $target) {
            if ($line -match '^\[(.+)\]$') { $section = $Matches[1] }
            elseif ($section -eq $key -and $line -match '^"(.+?)"=') { $Matches[1] }
        }
        $item = Get-Item -LiteralPath "Registry::$key" -ErrorAction Ignore
        $old = if ($item) { $item.GetValueNames() } else { @() }
        $new = @($names[$key] | Where-Object { $saved -notcontains $_ -and $old -notcontains $_ })
        if ($new) {
            $deletions = @("[$key]") + @(foreach ($name in $new) { "`"$name`"=-" })
            Set-Content $target ((Get-Content $target -Raw).TrimEnd() + "`r`n`r`n" + ($deletions -join "`r`n")) -Encoding unicode
        }
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
    # A drive Windows encrypted itself waits for its TPM protector to turn
    # protection on. One that has it and protection off was suspended for a
    # restart, by INSTALLATION.md or an update, and resumes by itself.
    $volume = Get-BitLockerVolume $drive
    if (-not ($volume.KeyProtector | Where-Object KeyProtectorType -EQ 'Tpm')) {
        Add-BitLockerKeyProtector $drive -TpmProtector -WarningAction Ignore | Out-Null
        $volume = Get-BitLockerVolume $drive
        if ($volume.ProtectionStatus -eq 'Off' -and $volume.VolumeStatus -eq 'FullyEncrypted') {
            Resume-BitLocker $drive | Out-Null
        }
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
                Save-RegistryBackup (Get-RegistryNames $file)
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
    if ($work.Taskbar) {
        Write-Host 'taskbar  pins from the next sign-in'
        Invoke-Step 'taskbar' {
            Save-RegistryBackup @{ $taskbarKey = 'StartLayoutFile', 'LockedStartLayout' }
            if (-not (Test-Path "Registry::$taskbarKey")) { New-Item "Registry::$taskbarKey" -Force | Out-Null }
            Set-ItemProperty "Registry::$taskbarKey" StartLayoutFile $taskbar
            Set-ItemProperty "Registry::$taskbarKey" LockedStartLayout 1 -Type DWord
        }
    }
    if ($work.BitLocker) {
        Write-Host 'enable   BitLocker'
        Invoke-Step 'BitLocker' { Enable-BitLockerWithKey }
    }
    if ($work.Wsl) {
        Write-Host 'install  WSL'
        wsl --install --no-distribution
        if ($LASTEXITCODE -ne 0) { $failures.Add("wsl --install ($LASTEXITCODE)") }
    }
    foreach ($failure in $failures) { Write-Host "FAIL     $failure" }
    exit [int]($failures.Count -gt 0)
}

$installed = Get-Installed
$work = Get-AdminWork $installed
if ($Update -or (Test-Work $work)) {
    $arguments = @('-NoProfile', '-File', $PSCommandPath, '-Elevated')
    if ($Update) { $arguments += '-Update' }
    sudo pwsh @arguments
    if ($LASTEXITCODE -ne 0) { $failures.Add('the administrator steps; see above') }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

foreach ($package in $packages | Where-Object { $_.User -and $installed -notcontains $_.Id }) {
    Install-Package $package.Id @('--source', 'winget')
}

# ~ and %NAME% in the profiles' targets
function Resolve-Target([string] $path) {
    [Environment]::ExpandEnvironmentVariables(($path -replace '^~', $HOME))
}

# Apps without a winget package, from their publisher, as yourself; each
# updates itself.
foreach ($name in $want.Downloads.Keys) {
    $download = $want.Downloads[$name]
    if (Test-Path (Resolve-Target $download.Path)) { continue }
    Invoke-Step "install $name" {
        Write-Host "install  $name"
        $installer = Join-Path ([IO.Path]::GetTempPath()) "nix-workstation-$name.exe"
        Invoke-WebRequest $download.Url -OutFile $installer
        $signature = Get-AuthenticodeSignature $installer
        $signer = if ($signature.SignerCertificate) {
            $signature.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
        }
        if ($signature.Status -ne 'Valid' -or $signer -ne $download.Signer) {
            Remove-Item $installer
            throw "the installer is not signed by $($download.Signer)."
        }
        $process = Start-Process $installer -ArgumentList $download.Args -Wait -PassThru
        Remove-Item $installer
        if ($process.ExitCode -ne 0) { throw "the installer exited with $($process.ExitCode)." }
    }
}

# A write under a linked folder lands in what it points to, such as the
# checkout.
function Assert-RealFolder([string] $path) {
    $folder = Get-Item (Split-Path $path) -Force -ErrorAction Ignore
    if ($folder.LinkType) { throw "$($folder.FullName) is a link; remove it and run this again." }
}

foreach ($target in $want.Links.Keys) {
    $path = Resolve-Target $target
    $source = [IO.Path]::GetFullPath((Join-Path $root "configs/$($want.Links[$target])"))
    Invoke-Step "link $target" {
        $item = Get-Item $path -Force -ErrorAction Ignore
        if ($item.LinkType -and $item.Target -eq $source) { return }
        Assert-RealFolder $path
        if ($item.LinkType) { Remove-Item $path -Force }
        elseif ($item) {
            $backup = "$path.before-nix-workstation"
            if (Test-Path $backup) { throw "$backup already exists; move one of them away." }
            Write-Host "backup   $backup"
            Move-Item $path $backup
        }
        Write-Host "link     $target"
        New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
        New-Item -ItemType SymbolicLink -Path $path -Target $source | Out-Null
    }
}

if ($want.GitWindows) {
    Invoke-Step 'Git settings for Windows' {
        # Git's own ssh cannot reach 1Password's agent pipe; Windows' ssh can.
        # winget installs 1Password as an MSIX package with an app alias; its
        # other installers use the two folders after it.
        $sign = "$env:LOCALAPPDATA\Microsoft\WindowsApps\op-ssh-sign.exe",
            "$env:LOCALAPPDATA\1Password\app\8\op-ssh-sign.exe",
            "$env:ProgramFiles\1Password\app\8\op-ssh-sign.exe" | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $sign) { throw "1Password's op-ssh-sign.exe is missing." }
        $file = Join-Path $HOME '.config\git\windows'
        $text = "# Written by windows/apply.ps1.`n[core]`n`tsshCommand = C:/Windows/System32/OpenSSH/ssh.exe`n" +
            "[gpg `"ssh`"]`n`tprogram = $($sign.Replace('\', '/'))`n"
        if ((Get-Content $file -Raw -ErrorAction Ignore) -ne $text) {
            Write-Host 'write    ~\.config\git\windows'
            Assert-RealFolder $file
            New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
            Set-Content $file $text -NoNewline
        }
    }
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

# Apps rewrite these files, so only the repo's keys are set, as on Linux.
$yq = if ($want.Merges.Count -and (Get-Command mise -ErrorAction Ignore)) { mise which yq 2> $null }
# Yq writes UTF-8; the console's own code page would mangle other characters.
$encoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
foreach ($target in $want.Merges.Keys) {
    $path = Resolve-Target $target
    $patches = @(foreach ($patch in $want.Merges[$target]) { Join-Path $root "configs/$patch" })
    Invoke-Step "merge $target" {
        if (-not $yq) { throw 'Mise has no yq.' }
        Assert-RealFolder $path
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
            New-Item $path | Out-Null
        }
        $format = @{ '.json' = 'json'; '.toml' = 'toml'; '.yml' = 'yaml' }[[IO.Path]::GetExtension($path)]
        # An empty file is no document to Yq, so the patches alone remain.
        $merged = & $yq ea -p $format -o $format '. as $item ireduce ({}; . * $item)' $path @patches
        if ($LASTEXITCODE -ne 0) { Write-Host "skip     $target`: Yq cannot merge it"; return }
        $merged = $merged -join "`n"
        if ($merged -ne "$(Get-Content $path -Raw)".TrimEnd()) {
            Write-Host "merge    $target"
            Set-Content $path $merged
        }
    }
}
[Console]::OutputEncoding = $encoding

foreach ($editor in $want.Extensions.Keys) {
    if (-not (Get-Command $editor -ErrorAction Ignore)) { continue }
    # IDs, and configs/ files of them, which are paths
    $list = foreach ($item in $want.Extensions[$editor]) {
        if ($item -like '*/*') { Get-Content (Join-Path $root "configs/$item") } else { $item }
    }
    $present = & $editor --list-extensions
    foreach ($extension in $list | Where-Object { $present -notcontains $_ }) {
        Write-Host "extend   $extension"
        & $editor --install-extension $extension
        if ($LASTEXITCODE -ne 0) { $failures.Add("$editor extension $extension ($LASTEXITCODE)") }
    }
}

if ($want.QuickAccess) {
    Invoke-Step 'Quick access' {
        # Pins only, so folders pinned or unpinned by hand stay as they are.
        $shell = New-Object -ComObject Shell.Application
        $pinned = @($shell.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}').Items() |
            Where-Object { $_.ExtendedProperty('System.Home.IsPinned') } | ForEach-Object Path)
        foreach ($folder in $want.QuickAccess) {
            $path = Resolve-Target $folder
            if ($pinned -contains $path) { continue }
            Write-Host "pin      $folder"
            $shell.Namespace($path).Self.InvokeVerb('pintohome')
        }
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

if ($work.Wsl) {
    # A new WSL works only after a restart; the distribution comes next run.
    Write-Host 'note     Restart Windows to finish WSL, then run this again.'
}
elseif ($want.Wsl.Distribution -eq 'Ubuntu') {
    Invoke-Step 'Ubuntu' {
        $env:WSL_UTF8 = '1'
        # A WSL without distributions exits with an error here too.
        if ((wsl --list --quiet 2> $null) -notcontains 'Ubuntu') {
            Write-Host 'install  Ubuntu'
            wsl --install --distribution Ubuntu --no-launch
            if ($LASTEXITCODE -ne 0) { throw "wsl --install ($LASTEXITCODE)" }
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
elseif ($want.Wsl.Distribution -eq 'NixOS') {
    Invoke-Step 'NixOS' {
        $env:WSL_UTF8 = '1'
        # Linux account names are lowercase letters, digits, - and _.
        $user = $env:USERNAME.ToLower()
        if ($user -notmatch '^[a-z_][a-z0-9_-]*$') { throw "$env:USERNAME is no Linux account name." }
        $shell = '/run/current-system/sw/bin/sh'
        # Done once the account has its checkout; nswitch inside NixOS applies
        # later changes. Until then each run redoes the steps still missing.
        # wsl.exe prints its own errors to stdout.
        wsl --distribution NixOS --user $user --exec $shell -c 'test -f ~/Projects/nix/hosts/wsl/local/user.nix' *> $null
        if ($LASTEXITCODE -eq 0) { return }
        # A new NixOS has no SSH key for GitHub, so its clones use HTTPS;
        # INSTALLATION.md switches the checkout to SSH afterwards.
        $url = (git -C $root remote get-url origin) -replace '^git@github\.com:', 'https://github.com/'
        $branch = git -C $root branch --show-current
        if (-not $branch) { $branch = 'main' }

        if ((wsl --list --quiet 2> $null) -notcontains 'NixOS') {
            $image = Join-Path ([IO.Path]::GetTempPath()) 'nixos.wsl'
            try {
                Write-Host 'download NixOS-WSL'
                Invoke-WebRequest $want.Wsl.Image -OutFile $image
                if ((Get-FileHash $image).Hash -ne $want.Wsl.Sha256) { throw "$image does not match its checksum." }
                Write-Host 'install  NixOS'
                wsl --install --from-file $image --no-launch
                if ($LASTEXITCODE -ne 0) { throw "wsl --install ($LASTEXITCODE)" }
            }
            finally { Remove-Item $image -ErrorAction Ignore }
        }

        # A login shell, since wsl --exec starts without NixOS' PATH. Git may
        # check this file out with CRLF, which sh reads as part of each line.
        function Invoke-NixOS([string] $account, [string] $script, [string[]] $arguments) {
            wsl --distribution NixOS --user $account --exec $shell -lc ($script -replace "`r") sh @arguments
            if ($LASTEXITCODE -ne 0) { throw "in NixOS as $account ($LASTEXITCODE)" }
        }
        $userNix = "{ wsl.defaultUser = `"$user`"; }"
        # NixOS-WSL's steps for a new account, until it exists: build the boot
        # generation as root, then start it once as root and stop it.
        wsl --distribution NixOS --user $user --exec $shell -c true *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "build    NixOS for $user"
            Invoke-NixOS root @'
export NIX_CONFIG='experimental-features = nix-command flakes'
rm -rf /tmp/nix &&
nix run nixpkgs#git -- clone --branch "$1" "$2" /tmp/nix &&
mkdir -p /tmp/nix/hosts/wsl/local && printf '%s\n' "$3" > /tmp/nix/hosts/wsl/local/user.nix &&
nixos-rebuild boot --flake path:/tmp/nix#wsl
'@ @($branch, $url, $userNix)
            wsl --terminate NixOS
            Invoke-NixOS root 'true'
            wsl --terminate NixOS
        }
        # The checkout in the account's home, as on Linux
        Invoke-NixOS $user @'
{ [ -d ~/Projects/nix/.git ] || git clone --branch "$1" "$2" ~/Projects/nix; } &&
mkdir -p ~/Projects/nix/hosts/wsl/local && printf '%s\n' "$3" > ~/Projects/nix/hosts/wsl/local/user.nix
'@ @($branch, $url, $userNix)
    }
}

if ($work.Registry.Count -gt @(Get-RegistryChanges).Count) {
    # The taskbar and Explorer read their settings at start; Windows restarts it.
    Write-Host 'restart  Explorer'
    Stop-Process -Name explorer -Force
}

foreach ($failure in $failures) { Write-Host "FAIL     $failure" }
exit [int]($failures.Count -gt 0)

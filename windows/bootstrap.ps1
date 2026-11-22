#Requires -Version 5.1
<#
Sets up Windows from this repo. Run it as yourself in Windows PowerShell:

    irm https://raw.githubusercontent.com/Furyfree/nix/main/windows/bootstrap.ps1 | iex

It asks for a profile, enables sudo, runs WinUtil's Standard tweaks when the
Win11 Creator ISO did not install Windows, installs Git and PowerShell 7,
clones this repo to ~\Projects\nix and runs windows\apply.ps1, which installs
WSL for the profiles that use it.
#>
param(
    # The branch to clone, for testing one before it is merged
    [string] $Branch = 'main'
)

# A script block, so iex leaves the caller's session as it was.
& {
    $ErrorActionPreference = 'Stop'
    $repo = Join-Path $HOME 'Projects\nix'

    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) { throw 'Run this as yourself, not as administrator; it asks for administrator itself.' }

    $choice = (Read-Host 'Profile: vm or desktop').Trim().ToLower()
    if (@('vm', 'desktop') -notcontains $choice) { throw "No profile '$choice'." }
    $exists = Test-Path $repo
    if ($exists -and (Read-Host "$repo already exists. Pull and continue? [y/N]") -notmatch '^y(es)?$') { return }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        # App Installer registers winget some minutes after the first sign-in.
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    }

    # The administrator steps, in their own window behind one UAC prompt
    $steps = @'
$ErrorActionPreference = 'Stop'
try {
    sudo config --enable normal
    if ($LASTEXITCODE -ne 0) { throw 'sudo config failed.' }
    # Win11 Creator's post-install script, named after WinOneShot or WinUtil
    $creator = 'C:\Windows\Setup\Scripts\WinOneShot-PostInstall.ps1', 'C:\Windows\Setup\Scripts\WinUtil-PostInstall.ps1'
    if ((Test-Path $creator) -notcontains $true) {
        # WinUtil reports its own errors; Stop would end it at the first.
        & {
            $ErrorActionPreference = 'Continue'
            & ([scriptblock]::Create((Invoke-RestMethod 'https://christitus.com/win'))) -Preset Standard
        }
    }
    foreach ($id in 'Git.Git', 'Microsoft.PowerShell') {
        winget install --id $id --exact --silent --no-upgrade --source winget --accept-package-agreements `
            --accept-source-agreements --disable-interactivity
        # 0x8A150061: already installed
        if ($LASTEXITCODE -notin 0, 0x8A150061) { throw "winget install $id failed ($LASTEXITCODE)." }
    }
    # Otherwise the exit code is 1 when the last command, winget, did not return 0.
    exit 0
}
catch {
    Write-Host $_ -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
'@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($steps))
    $process = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-EncodedCommand', $encoded
    if ($process.ExitCode -ne 0) { throw 'The administrator steps failed.' }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')

    if ($exists) {
        git -C $repo pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull failed in $repo." }
    }
    else {
        git clone --branch $Branch https://github.com/Furyfree/nix.git $repo
        if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
    }
    $local = Join-Path $repo 'windows\local'
    New-Item -ItemType Directory -Force $local | Out-Null
    Set-Content (Join-Path $local 'profile') $choice

    pwsh -NoProfile -File (Join-Path $repo 'windows\apply.ps1')
}

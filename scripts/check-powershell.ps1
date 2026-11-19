#!/usr/bin/env pwsh
# Parse the Windows scripts without running them, and load each Windows profile
# and the layers, registry files and configs it names.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
foreach ($script in Get-ChildItem windows, configs, scripts -Recurse -Filter *.ps1) {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$errors)
    if ($errors) { throw "$($script): $($errors[0])" }
}
foreach ($file in Get-ChildItem windows/profiles -Filter *.psd1) {
    $layer = Import-PowerShellDataFile $file.FullName
    foreach ($name in $layer.Include) {
        if (-not (Test-Path "windows/profiles/$name.psd1")) { throw "$($file.Name): no layer $name" }
    }
    foreach ($name in $layer.Registry) {
        if (-not (Test-Path "windows/registry/$name")) { throw "$($file.Name): no registry file $name" }
    }
    $configs = @($layer.Links.Values) + @($layer.Merges.Values | ForEach-Object { $_ }) +
        @($layer.Extensions.Values | ForEach-Object { $_ } | Where-Object { $_ -like '*/*' }) + @($layer.Taskbar)
    foreach ($name in $configs | Where-Object { $_ }) {
        if (-not (Test-Path "configs/$name")) { throw "$($file.Name): no configs/$name" }
    }
}

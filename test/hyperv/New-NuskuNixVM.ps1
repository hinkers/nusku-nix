<#
.SYNOPSIS
    Creates the Hyper-V test VM used to exercise the nusku-nix installer.

.DESCRIPTION
    Creates a Generation 2 VM with Secure Boot off, fixed memory, a dynamic VHDX
    in the Hyper-V default path, the NixOS ISO attached and first in the boot
    order, the Default Switch, and Standard checkpoints (no automatic ones).
    Then follow test/hyperv/README.md for the one-time base install.
    Requires an elevated shell or membership in "Hyper-V Administrators".
    Ported from nusku-arch test/hyperv/New-NuskuVM.ps1.

.PARAMETER IsoPath
    Path to the NixOS graphical installer ISO.

.PARAMETER Name
    VM name (default nusku-nix-test). The nusku-arch VM is 'nusku-test'; this
    script never touches a VM with another name.

.PARAMETER Force
    Remove an existing VM with the same name (its checkpoints and its VHDX) and
    create it again. Without -Force an existing VM is left alone and the script stops.

.EXAMPLE
    .\New-NuskuNixVM.ps1 -IsoPath E:\nixos-graphical-26.05.13164.6f06d204d8f2-x86_64-linux.iso
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,
    [string]$Name = 'nusku-nix-test',
    [int]$MemoryGB = 8,
    [int]$Cpus = 4,
    [int]$DiskGB = 60,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Stop-Friendly([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

# --- Permissions -----------------------------------------------------------
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    Stop-Friendly "Hyper-V PowerShell module not found. Enable the 'Microsoft-Hyper-V-All' Windows feature and reboot."
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# Well-known SID S-1-5-32-578 = Hyper-V Administrators (name is localised).
$isHvAdmin = $principal.IsInRole((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-578')))
if (-not ($isAdmin -or $isHvAdmin)) {
    Stop-Friendly @"
This script needs an elevated PowerShell or membership in 'Hyper-V Administrators'.
Fix (run once in an elevated PowerShell), then sign out and back in:
    Add-LocalGroupMember -Group 'Hyper-V Administrators' -Member `$env:USERNAME
"@
}

# --- Preconditions ---------------------------------------------------------
if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
    Stop-Friendly "ISO not found: $IsoPath"
}
$IsoPath = (Resolve-Path -LiteralPath $IsoPath).ProviderPath

if (-not (Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue)) {
    Stop-Friendly "The 'Default Switch' virtual switch does not exist. It is created by Hyper-V on Windows 10/11; try rebooting, or check that the Hyper-V feature is fully enabled."
}

$vhdPath = Join-Path (Get-VMHost).VirtualHardDiskPath "$Name.vhdx"

$existing = Get-VM -Name $Name -ErrorAction SilentlyContinue
if ($existing) {
    $oldDisks = @(Get-VMHardDiskDrive -VM $existing | ForEach-Object { $_.Path })
    if (-not $Force) {
        Stop-Friendly ("A VM named '$Name' already exists (disks: $($oldDisks -join ', ')). It was left alone. " +
            "Pass -Force to delete it, its checkpoints and its disks and create it again, or pick another -Name.")
    }
    Write-Host "Removing the existing VM '$Name' (-Force)..." -ForegroundColor Yellow
    if ($existing.State -in 'Running', 'Paused') { Stop-VM -Name $Name -TurnOff -Force }
    Get-VMSnapshot -VMName $Name -ErrorAction SilentlyContinue | Remove-VMSnapshot
    # Wait (up to ~2 min) for any snapshot merge to finish before deleting disks.
    for ($i = 0; $i -lt 60; $i++) {
        $vmNow = Get-VM -Name $Name
        if ($vmNow.Status -notmatch 'Merging') { break }
        Start-Sleep -Seconds 2
    }
    Remove-VM -Name $Name -Force
    foreach ($d in $oldDisks) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -LiteralPath $d -Force }
    }
}
if (Test-Path -LiteralPath $vhdPath) {
    Stop-Friendly "Disk already exists but no VM '$Name' owns it: $vhdPath. Delete it manually or pick another -Name."
}

# --- Create ----------------------------------------------------------------
Write-Host "Creating VM '$Name' ($Cpus CPU, $MemoryGB GB RAM, $DiskGB GB disk)..."
$vm = New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemoryGB * 1GB) `
    -NewVHDPath $vhdPath -NewVHDSizeBytes ($DiskGB * 1GB) -SwitchName 'Default Switch'

Set-VM -VM $vm -ProcessorCount $Cpus -StaticMemory -CheckpointType Standard -AutomaticCheckpointsEnabled $false
Set-VMFirmware -VM $vm -EnableSecureBoot Off
Enable-VMIntegrationService -VM $vm -Name 'Guest Service Interface'

$dvd = Add-VMDvdDrive -VM $vm -Path $IsoPath -Passthru
$disk = Get-VMHardDiskDrive -VM $vm
Set-VMFirmware -VM $vm -BootOrder $dvd, $disk

Write-Host "Created '$Name'." -ForegroundColor Green
Write-Host "Next: Start-VM -Name $Name; vmconnect.exe localhost $Name   (then follow test/hyperv/README.md, section 3)"

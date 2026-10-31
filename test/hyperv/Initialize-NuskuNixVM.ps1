<#
.SYNOPSIS
    Finishes the nusku-nix test VM's first-boot setup from Windows, over SSH.

.DESCRIPTION
    Run once after the base install (test/hyperv/README.md, section 3), when SSH is on in the
    VM (switched on by hand there). Then:
    1. copies the test SSH key ($HOME\.ssh\nusku_test.pub) into ~USER/.ssh/authorized_keys
       (you type USER's password once);
    2. copies guest-setup.sh into the VM and runs it with sudo in a terminal (sudo asks for
       the password once): passwordless sudo, Hyper-V guest services and git in
       /etc/nixos/nusku-test.nix, then nixos-rebuild switch;
    3. checks key-only SSH, passwordless sudo and git.
    It does not start, stop or checkpoint the VM.

.PARAMETER Name
    VM name (default nusku-nix-test). An existing VM works too, e.g. -Name nusku-test.

.PARAMETER User
    The VM user from the base install (default tester).

.PARAMETER IpAddress
    The VM's IPv4 address, when Hyper-V doesn't report one yet (read it in the VM with
    `ip -4 addr`). By default it comes from Get-VMNetworkAdapter.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File test\hyperv\Initialize-NuskuNixVM.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Name = 'nusku-nix-test',
    [string]$User = 'tester',
    [string]$IpAddress = ''
)
$ErrorActionPreference = 'Stop'

function Stop-Friendly([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

# Get-VM -Name takes wildcards; never let one reach another VM.
if ($Name -match '[\*\?\[\]]') { Stop-Friendly "-Name '$Name': wildcard characters (* ? [ ]) are not allowed." }
if ($User -notmatch '^[a-z_][a-z0-9_-]*$') { Stop-Friendly "-User '$User' is not a valid user name." }

$key  = Join-Path $HOME '.ssh\nusku_test'
$opts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-o', 'LogLevel=ERROR')
$setup = Join-Path $PSScriptRoot 'guest-setup.sh'

if (-not (Test-Path "$key.pub")) { Stop-Friendly "No $key.pub. Create the key first (README section 1)." }
if (-not (Test-Path $setup)) { Stop-Friendly "guest-setup.sh not found next to this script." }
try { $null = Get-VM -Name $Name -ErrorAction Stop }
catch { Stop-Friendly "VM '$Name' not found (or no permission: join 'Hyper-V Administrators' and sign in again)." }

$ip = $IpAddress
if (-not $ip) { $ip = @((Get-VMNetworkAdapter -VMName $Name).IPAddresses) | Where-Object { $_ -match '^\d+(\.\d+){3}$' -and $_ -notlike '169.254.*' } | Select-Object -First 1 }
if (-not $ip) {
    Stop-Friendly ("No IPv4 address for VM '$Name' yet. Wait a few seconds and run this again, or read it in the VM " +
        "with 'ip -4 addr' and pass -IpAddress.")
}
Write-Host "VM $Name is at $ip" -ForegroundColor Cyan

Write-Host "`n1/3 Copying the test SSH key in (type $User's password once)" -ForegroundColor Cyan
Get-Content "$key.pub" | ssh @opts "$User@$ip" "umask 077; mkdir -p ~/.ssh && tr -d '\r' >> ~/.ssh/authorized_keys"
if ($LASTEXITCODE -ne 0) { Stop-Friendly "Copying the key failed. Is SSH on in the VM (README section 3) and the password right?" }

Write-Host "`n2/3 Adding passwordless sudo, Hyper-V guest services and git, then rebuilding (sudo asks for the password once)" -ForegroundColor Cyan
scp -i $key @opts $setup "${User}@${ip}:/tmp/nusku-guest-setup.sh"
if ($LASTEXITCODE -ne 0) { Stop-Friendly "Copying guest-setup.sh failed." }
# A real terminal (-t) for sudo's password prompt; CRs stripped in case the file has CRLF.
ssh -t -i $key @opts "$User@$ip" "tr -d '\r' < /tmp/nusku-guest-setup.sh > /tmp/nusku-setup.sh && sudo bash /tmp/nusku-setup.sh $User"
if ($LASTEXITCODE -ne 0) { Stop-Friendly "The setup in the VM failed (see above)." }

Write-Host "`n3/3 Checking key-only SSH, passwordless sudo and git" -ForegroundColor Cyan
ssh -i $key -o BatchMode=yes @opts "$User@$ip" 'sudo -n true && git --version && echo ready'
if ($LASTEXITCODE -ne 0) { Stop-Friendly "The check failed (see above)." }
Write-Host "`nAll set. Now run 'sudo poweroff' in the VM, then on the host: Checkpoint-VM -Name $Name -SnapshotName clean-nixos" -ForegroundColor Green

<#
.SYNOPSIS
    Restores a clean NixOS VM, installs nusku-nix with install.sh, reboots, checks
    the desktop and takes screenshots.

.DESCRIPTION
    1. Restore checkpoint 'clean-nixos' and start the VM.
    2. Wait for an IPv4 address (via Hyper-V KVP) and for SSH; check the base install
       (passwordless sudo, git).
    3. Package the working tree (tracked + untracked, honouring .gitignore, including
       uncommitted changes), copy it to ~/nusku, add hosts/<HostName>/settings.json from
       the settings fixture (hostname and user replaced), and commit it all in a fresh git
       repo (the flake only sees tracked files; install.sh commits too).
    4. Run ./install.sh --host <HostName> --no-reboot with
       NUSKU_FLAKE_ATTR=<HostName>-hyperv-test, so it builds the test variant (the host +
       test/hyperv/guest.nix: sshd, passwordless sudo, KVP, autologin). install.sh copies the
       VM's own /etc/nixos/hardware-configuration.nix into the host. It runs detached in the
       guest, so a network restart during the switch can't kill it; its output is streamed.
    5. Set up probes (a spawn-at-startup in local.kdl, an Obsidian vault), reboot, wait for
       SDDM autologin to start niri and the Nusku shell (bar).
    6. Check the session, theming, menus, apps and the ledger's VM items; screenshots with grim
       (desktop, fastfetch, rofi, keybinds, quick settings, calendar, GTK, and the picked
       Firefox / Neovim / Obsidian); a second rebuild must change nothing; a rollback
       generation must exist. Print a PASS/WARN/FAIL table.
    On error the VM is left running for debugging.
    Results go to test/screenshots/<timestamp>/ (gitignored): screenshots, install.log,
    install.out, checks.txt.
    Exit code is 2 if the run could not get going before the install (VM, SSH, packaging);
    1 once the install has started and anything fails (the install, its timeout, the guest
    not coming back after the reboot, a check, a screenshot); else 0.

.PARAMETER Name
    VM name (default nusku-nix-test).

.PARAMETER HostName
    The Nusku host the run installs: hosts/<HostName> in the copy (default nusku-nix-test).

.PARAMETER User
    Guest user (default tester). Needs the nusku_test key in ~/.ssh/authorized_keys and
    NOPASSWD sudo in the checkpoint (README).

.PARAMETER Settings
    The settings.json to install, relative to the repo root. Default: the small host,
    test/fixtures/hosts/hyperv-small/settings.json (Neovim + Python, Firefox, Obsidian,
    GNOME Calendar, Pokemon). Its hostname and user are replaced with -HostName and -User.

.PARAMETER Full
    Use test/fixtures/hosts/hyperv-full/settings.json instead: every app and language.
    Takes hours and tens of GB; see the README.

.PARAMETER InstallTimeoutMin
    How long install.sh may take (default 240 minutes).

.PARAMETER KeepRunning
    Leave the VM running at the end. By default it is shut down (Stop-VM).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File test\hyperv\Invoke-NuskuNixTest.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File test\hyperv\Invoke-NuskuNixTest.ps1 -Full -KeepRunning
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Name = 'nusku-nix-test',
    [string]$HostName = 'nusku-nix-test',
    [string]$User = 'tester',
    [string]$Settings = 'test/fixtures/hosts/hyperv-small/settings.json',
    [switch]$Full,
    [int]$InstallTimeoutMin = 240,
    [switch]$KeepRunning
)

$ErrorActionPreference = 'Stop'

$Checkpoint = 'clean-nixos'
$KeyPath    = Join-Path $HOME '.ssh\nusku_test'
$RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutDir     = Join-Path $RepoRoot "test\screenshots\$Stamp"
$FlakeAttr  = "$HostName-hyperv-test"
$script:Ip  = $null

if ($Full) { $Settings = 'test/fixtures/hosts/hyperv-full/settings.json' }

$SshOpts = @(
    '-i', $KeyPath,
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=NUL',
    '-o', 'ConnectTimeout=5',
    '-o', 'ServerAliveInterval=5',
    '-o', 'ServerAliveCountMax=3',
    '-o', 'BatchMode=yes',
    '-o', 'LogLevel=ERROR'
)

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

# Note: on error the VM is deliberately left as-is (usually running) so you can debug it.
# Exit 2 before the install starts (the run could not get going); exit 1 after (a product failure).
$script:InstallStarted = $false
function Stop-WithError([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host "The VM '$Name' is left as it is for debugging (ssh -i $KeyPath $User@$($script:Ip))."
    if ($script:InstallStarted) { exit 1 }
    exit 2
}

# Builds the ssh command string for a script: base64 has no quoting hazards
# and avoids the CRLF that PowerShell 5.1 appends when piping to a native exe.
function ConvertTo-RemoteCommand([string]$Script) {
    $body = ($Script -replace "`r", '') + "`n"
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($body))
    return "echo $b64 | base64 -d | bash"
}

# Runs a bash script on the guest. Returns stdout lines; the remote exit code
# is left in $script:RemoteExit (255: ssh itself failed).
function Invoke-Remote([string]$Script) {
    $out = & ssh.exe -n @SshOpts "$User@$($script:Ip)" (ConvertTo-RemoteCommand $Script)
    $script:RemoteExit = $LASTEXITCODE
    return $out
}

function Copy-FromGuest([string]$Remote, [string]$Local) {
    & scp.exe @SshOpts "$User@$($script:Ip):$Remote" $Local
    return ($LASTEXITCODE -eq 0)
}

function Get-GuestIPv4 {
    $adapter = Get-VMNetworkAdapter -VMName $Name
    $addr = @($adapter.IPAddresses) |
        Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and $_ -notlike '169.254.*' } |
        Select-Object -First 1
    return $addr
}

# Waits for an IPv4 and an open port 22. With -NotBootId, additionally waits
# until the guest reports a boot_id different from that value (i.e. it has
# really rebooted, not just still shutting down).
function Wait-ForSsh([int]$TimeoutSec = 180, [string]$NotBootId = '') {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $script:Ip = $null
    $sawIp = $false
    $sawPort = $false
    while ((Get-Date) -lt $deadline) {
        if (-not $script:Ip) { $script:Ip = Get-GuestIPv4 }
        if ($script:Ip) {
            $sawIp = $true
            $client = New-Object System.Net.Sockets.TcpClient
            $open = $false
            try {
                $task = $client.ConnectAsync($script:Ip, 22)
                $open = ($task.Wait(2000) -and $client.Connected)
            } catch { } finally { $client.Close() }
            if ($open) {
                $sawPort = $true
                if (-not $NotBootId) { return }
                $id = (Invoke-Remote 'cat /proc/sys/kernel/random/boot_id') | Select-Object -First 1
                if ($script:RemoteExit -eq 0 -and $id -and $id -ne $NotBootId) { return }
            } else {
                # The address may have changed after a reboot; re-read it next loop.
                $script:Ip = $null
            }
        }
        Start-Sleep -Seconds 3
    }
    if (-not $sawIp) {
        Stop-WithError ("No IPv4 address for VM '$Name' after ${TimeoutSec}s. Are the Hyper-V guest " +
            "services on in the guest (virtualisation.hypervGuest.enable = true; README section 3)?")
    }
    if (-not $sawPort) {
        Stop-WithError ("VM '$Name' has an IP but port 22 never opened within ${TimeoutSec}s. " +
            "Is services.openssh.enable = true in the guest (README section 3)? After a Nusku build, " +
            "was it the -hyperv-test variant (NUSKU_FLAKE_ATTR) that was built?")
    }
    Stop-WithError "VM '$Name' did not come back from the reboot (boot_id unchanged) within ${TimeoutSec}s."
}

function Assert-SshAuth {
    $null = & ssh.exe -n @SshOpts "$User@$($script:Ip)" 'true'
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError ("SSH login as '$User' failed. Is the public key '$KeyPath.pub' in " +
            "~$User/.ssh/authorized_keys in the guest (and was the checkpoint taken after adding it)?")
    }
}

# ---------------------------------------------------------------- preflight
foreach ($tool in 'ssh.exe', 'scp.exe', 'tar.exe', 'git.exe') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Stop-WithError "$tool not found on PATH (OpenSSH client and tar ship with Windows; install Git for Windows for git)."
    }
}
if (-not (Test-Path $KeyPath)) {
    Stop-WithError "SSH key $KeyPath not found. See test\hyperv\README.md section 1."
}

# Get-VM -Name takes wildcards; never let one reach another VM (nusku-arch's nusku-test).
if ($Name -match '[\*\?\[\]]') { Stop-WithError "-Name '$Name': wildcard characters (* ? [ ]) are not allowed." }
try { $null = Get-VM -Name $Name -ErrorAction Stop }
catch { Stop-WithError "VM '$Name' not found (or no permission: join 'Hyper-V Administrators' and sign in again). Create it with test\hyperv\New-NuskuNixVM.ps1." }

$snap = Get-VMSnapshot -VMName $Name -Name $Checkpoint -ErrorAction SilentlyContinue
if (-not $snap) {
    Stop-WithError "Checkpoint '$Checkpoint' not found on VM '$Name'. Take it after the base install: Checkpoint-VM -Name $Name -SnapshotName $Checkpoint"
}

if ($HostName -notmatch '^[a-z0-9-]{1,63}$') { Stop-WithError "-HostName '$HostName': use a-z, 0-9 and '-' only." }
$settingsPath = Join-Path $RepoRoot $Settings
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { Stop-WithError "Settings file '$Settings' not found under the repo root." }
# The host's settings: the fixture with this run's host name and user (both checked by the build).
$settingsText = [System.IO.File]::ReadAllText($settingsPath) -replace "`r", ''
$settingsText = [regex]::Replace($settingsText, '"hostname"\s*:\s*"[^"]*"', "`"hostname`": `"$HostName`"")
$settingsText = [regex]::Replace($settingsText, '"user"\s*:\s*"[^"]*"', "`"user`": `"$User`"")
try { $settingsObj = $settingsText | ConvertFrom-Json }
catch { Stop-WithError "Settings file '$Settings' is not valid JSON: $($_.Exception.Message)" }
$Apps = @()
if ($settingsObj.apps) { $Apps = @($settingsObj.apps) }
$Langs = @()
if ($settingsObj.langs) { $Langs = @($settingsObj.langs) }
$Accent = "$($settingsObj.accent)"
function Test-App([string]$Id) { return ($Apps -contains $Id) }
function Test-Lang([string]$Id) { return ($Langs -contains $Id) }

New-Item -ItemType Directory -Force $OutDir | Out-Null
Write-Host "Settings: $Settings (apps: $($Apps -join ' '); langs: $($Langs -join ' '))"
Write-Host "Builds:   .#$FlakeAttr"

# ------------------------------------------------------------ 1. restore VM
Write-Step "Restoring checkpoint '$Checkpoint' on '$Name'"
if ((Get-VM -Name $Name).State -in 'Running', 'Paused') { Stop-VM -Name $Name -TurnOff -Force }
Restore-VMCheckpoint -VMName $Name -Name $Checkpoint -Confirm:$false
Start-VM -Name $Name

# --------------------------------------------------------------- 2. wait IP
Write-Step 'Waiting for IP address and SSH'
Wait-ForSsh 240
Write-Host "    $User@$($script:Ip)"
Assert-SshAuth

$null = Invoke-Remote 'sudo -n true'
if ($script:RemoteExit -ne 0) {
    Stop-WithError "sudo asks '$User' for a password. The checkpoint needs the NOPASSWD rule from README section 3 (security.sudo.extraRules)."
}
$null = Invoke-Remote 'command -v git >/dev/null'
if ($script:RemoteExit -ne 0) { Stop-WithError "git is not installed in the guest (README section 3: environment.systemPackages = [ pkgs.git ])." }
# Before the install: the installer's own tools (jq, lspci) are not on the base system, so a
# working install shows its `nix shell --inputs-from` re-exec worked.
$baseTools = ((Invoke-Remote 'for t in jq lspci; do command -v $t >/dev/null && echo "$t:present" || echo "$t:absent"; done') -join ' ')
$baseSystem = (Invoke-Remote 'readlink /run/current-system') | Select-Object -First 1

# ------------------------------------------------------------- 3. package
Write-Step 'Packaging working tree'
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "nusku-nix-$Stamp"
New-Item -ItemType Directory -Force $tmp | Out-Null
$rawList  = Join-Path $tmp 'files.raw'
$list     = Join-Path $tmp 'files.lst'
$tarball  = Join-Path $tmp 'nusku.tar'

Push-Location $RepoRoot
try {
    # Capture raw bytes (NUL separators) without any shell or pipeline in between.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git.exe'
    $psi.Arguments = 'ls-files -co --exclude-standard -z'
    $psi.WorkingDirectory = $RepoRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $fs = [System.IO.File]::Create($rawList)
    try { $proc.StandardOutput.BaseStream.CopyTo($fs) } finally { $fs.Close() }
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { Stop-WithError 'git ls-files failed.' }

    $text  = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($rawList))
    # .NET Framework has no Split(char, options) overload, so pass a char[]
    # explicitly; also drop empty entries (the trailing NUL) defensively.
    # hosts/<HostName> is written below, from the settings fixture.
    $files = $text.Split([char[]]@([char]0), [System.StringSplitOptions]::RemoveEmptyEntries) |
        Where-Object { $_ -and $_ -notlike 'test/screenshots/*' -and $_ -notlike "hosts/$HostName/*" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }   # drop files deleted but not yet committed
    $bytes = [System.Text.Encoding]::UTF8.GetBytes((($files -join [char]0) + [char]0))
    [System.IO.File]::WriteAllBytes($list, $bytes)

    & tar.exe --null -T $list -cf $tarball
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'tar failed.' }
} finally { Pop-Location }
Write-Host ("    {0} files, {1:N0} KiB" -f @($files).Count, ((Get-Item $tarball).Length / 1KB))

Write-Step 'Copying to guest'
& scp.exe @SshOpts $tarball "$User@$($script:Ip):/tmp/nusku.tar"
if ($LASTEXITCODE -ne 0) { Stop-WithError 'scp of the tarball failed.' }
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

# Windows tar does not carry exec bits, so restore them (the same files git has as 100755).
$execBits = (& git.exe -C $RepoRoot ls-files -s | Where-Object { $_ -like '100755 *' } |
    ForEach-Object { ($_ -split "`t", 2)[1] }) -join "`n"
$settingsB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($settingsText))
$execB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($execBits + "`n"))
$prepare = @'
set -e
rm -rf ~/nusku && mkdir -p ~/nusku
tar -xf /tmp/nusku.tar -C ~/nusku
rm -f /tmp/nusku.tar
cd ~/nusku
echo @EXEC@ | base64 -d | while IFS= read -r f; do [ -n "$f" ] && [ -f "$f" ] && chmod +x "$f"; done
chmod +x install.sh scripts/* test/*.sh 2>/dev/null || true
mkdir -p hosts/@HOST@
echo @SETTINGS@ | base64 -d > hosts/@HOST@/settings.json
# The flake only sees files git knows about; install.sh commits hosts/@HOST@ itself.
git init -q -b main
git add -A
git -c user.name=@USER@ -c user.email=@USER@@@HOST@ commit -q -m "nusku-nix working tree (Hyper-V test)"
git log --oneline | head -1
'@
$prepare = $prepare.Replace('@EXEC@', $execB64).Replace('@SETTINGS@', $settingsB64).Replace('@HOST@', $HostName).Replace('@USER@', $User)
$prepOut = Invoke-Remote $prepare
if ($script:RemoteExit -ne 0) { Stop-WithError "Preparing ~/nusku in the guest failed: $($prepOut -join ' / ')" }
Write-Host "    ~/nusku: $($prepOut -join ' ')"

# --------------------------------------------------------------- 4. install
Write-Step "Running install.sh --host $HostName (NUSKU_FLAKE_ATTR=$FlakeAttr); this takes a while"
# Detached (setsid + nohup): the first switch restarts NetworkManager and sshd, which may drop
# this SSH connection; the install must not die with it. Exit status goes to ~/install.exit.
$launch = @'
rm -f ~/install.exit ~/install.out
cd ~/nusku
nohup setsid bash -c 'NUSKU_FLAKE_ATTR=@ATTR@ ./install.sh --host @HOST@ --no-reboot > ~/install.out 2>&1; echo $? > ~/install.exit' </dev/null >/dev/null 2>&1 &
echo started
'@
$launch = $launch.Replace('@ATTR@', $FlakeAttr).Replace('@HOST@', $HostName)
$null = Invoke-Remote $launch
if ($script:RemoteExit -ne 0) { Stop-WithError 'Could not start install.sh in the guest.' }
$script:InstallStarted = $true

# The exit code once install.sh has finished; else "running" while its wrapper (the bash -c
# above, whose command line holds "install.sh --host") is alive, or "dead" when nothing is left
# and no exit code was written (killed, OOM, the guest rebooted). Re-read once after a pause, as
# the wrapper may have just written the file as it exited.
$pollExit = @'
cat ~/install.exit 2>/dev/null && exit 0
pgrep -u "$(id -u)" -f 'install\.sh --host' >/dev/null && { echo running; exit 0; }
sleep 2
cat ~/install.exit 2>/dev/null || echo dead
'@

$installExit = $null
$shown = 0
$deadline = (Get-Date).AddMinutes($InstallTimeoutMin)
$lastContact = Get-Date
while ($true) {
    $chunk = @(Invoke-Remote "tail -n +$($shown + 1) ~/install.out 2>/dev/null | head -n 500")
    if ($script:RemoteExit -eq 0) {
        $lastContact = Get-Date
        foreach ($line in $chunk) { if ($null -ne $line) { Write-Host "    $line" } }
        $shown += @($chunk | Where-Object { $null -ne $_ }).Count
        $code = (Invoke-Remote $pollExit) | Select-Object -First 1
        if ($script:RemoteExit -eq 0 -and "$code" -eq 'dead') {
            $null = Copy-FromGuest '~/install.out' (Join-Path $OutDir 'install.out')
            Stop-WithError "install.sh is no longer running in the guest and left no exit code in ~/install.exit (killed?). See $(Join-Path $OutDir 'install.out')."
        }
        if ("$code" -match '^\d+$') {
            $rest = @(Invoke-Remote "tail -n +$($shown + 1) ~/install.out 2>/dev/null")
            foreach ($line in $rest) { if ($null -ne $line) { Write-Host "    $line" } }
            $installExit = [int]$code
            break
        }
    } elseif (((Get-Date) - $lastContact).TotalSeconds -gt 120) {
        # The switch may have moved the guest to a new address; look it up again.
        $newIp = Get-GuestIPv4
        if ($newIp) { $script:Ip = $newIp }
    }
    if ((Get-Date) -gt $deadline) {
        Stop-WithError "install.sh did not finish within $InstallTimeoutMin minutes (see ~/install.out in the guest)."
    }
    Start-Sleep -Seconds 15
}
Write-Host "    install.sh exit code: $installExit"

$null = Copy-FromGuest '~/install.out' (Join-Path $OutDir 'install.out')
$remoteLog = (Invoke-Remote 'ls -t ~/.local/state/nusku/install-*.log 2>/dev/null | head -1') | Select-Object -First 1
if ($remoteLog -and (Copy-FromGuest $remoteLog (Join-Path $OutDir 'install.log'))) {
    Write-Host "    log: $(Join-Path $OutDir 'install.log')"
}
if ($installExit -ne 0) {
    Write-Host "Install FAILED (exit $installExit). See $(Join-Path $OutDir 'install.out')." -ForegroundColor Red
    Write-Host "The VM '$Name' is left running for debugging (ssh -i $KeyPath $User@$($script:Ip))."
    exit 1
}

# Every guest script after the install: the session's runtime dir, Wayland socket and niri
# socket (so grim and niri msg work over SSH), the system and user profiles on PATH, and two
# helpers. NixOS wraps many programs (.swaybg-wrapped), so processes are matched on the command line.
$envPreamble = @'
exec 2>&1
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export PATH="/run/wrappers/bin:/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin:$PATH"
export WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1)
export NIRI_SOCKET=$(ls -t "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null | head -1)
procs() { pgrep -u "$(id -u)" -f "(^|/)\.?$1(-wrapped)?( |$)"; }
running() { procs "$1" >/dev/null; }
environ_of() { tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null; }
# The Nusku shell (Quickshell: bar, quick settings, notifications) is a user service.
shellpid() { p=$(systemctl --user show -p MainPID --value nusku-shell 2>/dev/null); [ "${p:-0}" != 0 ] && echo "$p"; }
'@ + "`n"

# Before the reboot: probes the checks look at after it.
#  - a spawn-at-startup in the user's own local.kdl (included last), next to config.kdl's: it
#    must run too (the include is read, and startup commands add up);
#  - an Obsidian vault in Obsidian's own list (as if Obsidian had made it), for the Catppuccin
#    theme step (activation at boot and nusku/apps.kdl's spawn-at-startup at login).
$probes = @'
set -e
rm -f /tmp/nusku-local-kdl-probe
kdl="${XDG_CONFIG_HOME:-$HOME/.config}/nusku/local.kdl"
mkdir -p "$(dirname "$kdl")"
cat >> "$kdl" <<'KDL'
// nusku-nix Hyper-V test (test/hyperv): local.kdl's startup command must run as well.
spawn-at-startup "touch" "/tmp/nusku-local-kdl-probe"
KDL
'@
if (Test-App 'obsidian') {
    $probes += "`n" + @'
v="$HOME/Vault"
mkdir -p "$v/.obsidian"
printf '# Nusku test vault\n' > "$v/Welcome.md"
f="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json"
mkdir -p "$(dirname "$f")"
cur='{}'
[ -s "$f" ] && cur=$(cat "$f")
printf '%s' "$cur" | jq --arg p "$v" '.vaults.nuskutest0000001 = { path: $p, ts: 1700000000000, open: true }' > "$f.new"
rm -f "$f"
mv "$f.new" "$f"
'@
}
$probeOut = Invoke-Remote ($envPreamble + $probes)
if ($script:RemoteExit -ne 0) { Write-Host "    setting up the probes failed: $($probeOut -join ' / ')" -ForegroundColor Yellow }

# --------------------------------------------------------------- 5. reboot
Write-Step 'Rebooting and waiting for autologin'
$bootId = (Invoke-Remote 'cat /proc/sys/kernel/random/boot_id') | Select-Object -First 1
if (-not $bootId) { Stop-WithError 'Could not read boot_id from the guest before rebooting.' }
$null = Invoke-Remote 'sudo systemctl reboot'   # ssh may drop with 255; ignore
Start-Sleep -Seconds 5
Wait-ForSsh 300 $bootId
Write-Host "    $User@$($script:Ip)"

$niriUp = $false
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    $null = Invoke-Remote ($envPreamble + '[ -n "$NIRI_SOCKET" ] && niri msg version >/dev/null 2>&1')
    if ($script:RemoteExit -eq 0) { $niriUp = $true; break }
    Start-Sleep -Seconds 3
}
if (-not $niriUp) { Write-Host '    niri did not start within 180 s' -ForegroundColor Yellow }

$deadline = (Get-Date).AddSeconds(60)
while ($niriUp -and (Get-Date) -lt $deadline) {
    $null = Invoke-Remote ($envPreamble + 'shellpid >/dev/null')
    if ($script:RemoteExit -eq 0) { break }
    Start-Sleep -Seconds 2
}
# Let the wallpaper (swaybg, started by nusku-wallpaper restore) come up.
$deadline = (Get-Date).AddSeconds(30)
while ($niriUp -and (Get-Date) -lt $deadline) {
    $null = Invoke-Remote ($envPreamble + 'running swaybg')
    if ($script:RemoteExit -eq 0) { break }
    Start-Sleep -Seconds 2
}
Start-Sleep -Seconds 3   # let it draw

# --------------------------------------------------------------- 6. checks
Write-Step 'Checking'
$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$Check, [string]$Status, [string]$Detail) {
    $results.Add([pscustomobject]@{ Check = $Check; Result = $Status; Detail = $Detail })
    $color = 'Green'
    if ($Status -eq 'WARN') { $color = 'Yellow' } elseif ($Status -eq 'FAIL') { $color = 'Red' }
    $short = $Detail
    if ($short.Length -gt 140) { $short = $short.Substring(0, 137) + '...' }
    Write-Host ("    {0,-4} {1}: {2}" -f $Status, $Check, $short) -ForegroundColor $color
}

# Invoke-Check NAME SCRIPT: runs SCRIPT (after the preamble) on the guest. Exit 0 = PASS,
# 3 = WARN, anything else = FAIL; the output (stdout + stderr) is the detail.
function Invoke-Check([string]$Check, [string]$Script) {
    $out = Invoke-Remote ($envPreamble + $Script)
    $text = (@($out) | Where-Object { $null -ne $_ -and "$_".Trim() -ne '' } | ForEach-Object { "$_".Trim() }) -join ' / '
    $status = 'FAIL'
    if ($script:RemoteExit -eq 0) { $status = 'PASS' } elseif ($script:RemoteExit -eq 3) { $status = 'WARN' }
    if ($script:RemoteExit -eq 255) { $text = "ssh failed. $text" }
    Add-Result $Check $status $text
}

# --- The system ------------------------------------------------------------
foreach ($svc in 'display-manager', 'NetworkManager', 'bluetooth', 'power-profiles-daemon', 'sshd', 'hv-kvp') {
    $svcScript = "s=`$(systemctl is-active $svc); echo `$s; [ `"`$s`" = active ] && exit 0"
    # A Hyper-V VM has no Bluetooth adapter, so bluetooth.service is condition-skipped.
    if ($svc -eq 'bluetooth') { $svcScript += "; [ `"`$s`" = inactive ] && { echo '(no adapter in a VM)'; exit 3; }" }
    Invoke-Check "service $svc" ($svcScript + '; exit 1')
}
Invoke-Check 'built the test variant' @"
cur=`$(readlink /run/current-system); echo "`$cur"
[ "`$cur" != '$baseSystem' ] || { echo 'still the base system'; exit 1; }
"@
# guest.nix sets NUSKU_FLAKE_ATTR system-wide so a nusku-rebuild the owner types in the VM keeps
# building the variant. The loop itself never relies on that: it passes NUSKU_FLAKE_ATTR
# explicitly to install.sh and to its nusku-rebuild. This only checks the setting reaches an
# interactive shell (what the owner types into) and, for information, the loop's ssh commands.
Invoke-Check 'NUSKU_FLAKE_ATTR in the user''s shells' @"
i=`$(zsh -ic 'print -r -- "ATTR=`${NUSKU_FLAKE_ATTR:-}"' </dev/null 2>/dev/null | sed -n 's/^ATTR=//p' | tail -1)
s="`${NUSKU_FLAKE_ATTR:-}"
echo "interactive zsh: '`$i'; the loop's ssh commands: '`$s'"
[ "`$i" = '$FlakeAttr' ] || { echo 'not set in an interactive shell: a nusku-rebuild typed in the VM would build the plain host (no sshd)'; exit 1; }
[ "`$s" = '$FlakeAttr' ] || { echo 'not in the ssh command environment (the loop passes it explicitly, so this is only a note)'; exit 3; }
"@
Invoke-Check 'host name = host directory' "h=`$(cat /proc/sys/kernel/hostname); echo `$h; [ `"`$h`" = '$HostName' ]"
Invoke-Check 'checkout recorded for nusku-rebuild' "r=`$(cat ~/.config/nusku/repo); echo `$r; [ `"`$r`" = `"`$HOME/nusku`" ]"
Invoke-Check 'install: nix shell --inputs-from on a fresh install' @"
echo 'before the install: $baseTools'
grep -q 'Nusku is installed' ~/install.out || { echo 'no "Nusku is installed" in install.out'; exit 1; }
case '$baseTools' in *'jq:absent'*) exit 0 ;; *) echo 'jq was already on the base system, so the re-exec was not needed'; exit 3 ;; esac
"@
Invoke-Check 'install: --sudo activation as the user' @"
grep -n 'Building $FlakeAttr (NUSKU_FLAKE_ATTR)' ~/install.out | head -1
grep -q 'Building $FlakeAttr' ~/install.out || exit 1
! grep -qi 'sudo: a password is required\|sudo: a terminal is required' ~/install.out
"@
Invoke-Check 'detection: timedatectl / localectl output parses' @"
cd ~/nusku && . lib/sh/detect.sh
unset NUSKU_TIMEZONE NUSKU_LOCALE NUSKU_KEYMAP
tz=`$(timedatectl show -p Timezone --value); loc=`$(_detect_localectl 'System Locale'); km=`$(detect_keymap)
echo "localectl: `$(localectl status | sed -n 's/^ *\(VC Keymap\|X11 Layout\): */\1=/p' | tr '\n' ' ')"
gpu=`$(detect_gpu)
echo "timezone=`$tz locale=`$loc keymap=`$km gpu=`$gpu"
[ "`$tz" = '$($settingsObj.timezone)' ] && [ "`$loc" = 'LANG=$($settingsObj.locale)' ] && [ "`$km" = '$($settingsObj.keymap)' ] && [ "`$gpu" = vm ]
"@

# --- The session -------------------------------------------------------------
Invoke-Check 'process niri (autologin)' @'
niri msg version >/dev/null 2>&1 || { echo 'no niri instance answers'; exit 1; }
loginctl list-sessions --no-legend | grep -w "$(id -un)" | head -3
niri msg version 2>/dev/null | head -2
'@
# These start with the session (graphical-session.target, which niri-session reaches).
Invoke-Check 'session services (nusku-shell, swayidle, polkit-gnome, upower)' @'
ok=0
s=$(systemctl is-active upower); echo "upower: $s"; [ "$s" = active ] || ok=1
for u in nusku-shell swayidle polkit-gnome; do s=$(systemctl --user is-active "$u"); echo "$u: $s"; [ "$s" = active ] || ok=1; done
exit $ok
'@
Invoke-Check 'wallpaper (swaybg)' 'procs swaybg | head -1; running swaybg'
Invoke-Check 'niri config valid (as installed, with local.kdl)' 'niri validate 2>&1 | tail -2; niri validate >/dev/null 2>&1'
# The repo's script with Rofi stubbed (the installed one puts its own Rofi first on PATH): it
# reads the installed config (config.kdl and its includes) the way Super + / does.
Invoke-Check 'keybind menu lists binds' @'
command -v nusku-menu-keybinds >/dev/null || { echo 'nusku-menu-keybinds not installed'; exit 1; }
grep -q 'include "binds-nusku.kdl"' ~/.config/niri/config.kdl || { echo 'config.kdl does not include binds-nusku.kdl'; exit 1; }
stub=$(mktemp -d)
printf '#!/bin/sh\ncat > %s/listed\nexit 1\n' "$stub" > "$stub/rofi"
chmod +x "$stub/rofi"
PATH="$stub:$PATH" bash ~/nusku/scripts/nusku-menu-keybinds
rc=$?
grep -E 'Search keybinds +Super \+ /|Go to workspace' "$stub/listed"
grep -qE 'Search keybinds +Super \+ /' "$stub/listed" && grep -q 'Go to workspace 1' "$stub/listed" || rc=1
echo "lines=$(wc -l < "$stub/listed")"
rm -rf "$stub"
exit $rc
'@
# local.kdl (included last) and nusku/apps.kdl (Obsidian, when picked) were both read at start.
Invoke-Check 'startup commands from config.kdl, apps.kdl and local.kdl all ran' @'
ok=0
running swaybg && echo 'config.kdl: nusku-wallpaper restore (swaybg)' || ok=1
[ -e /tmp/nusku-local-kdl-probe ] && echo 'local.kdl: probe ran' || { echo 'local.kdl: probe did not run'; ok=1; }
[ -f ~/.config/nusku/apps.kdl ] && echo 'nusku/apps.kdl present'
exit $ok
'@
# settings.json "keymap" is an xkb layout: niri's from the generated nusku/input.kdl.
Invoke-Check 'keyboard: the settings layout in niri (nusku/input.kdl)' (@'
grep -F 'layout "@KM@"' ~/.config/nusku/input.kdl || { echo 'nusku/input.kdl lacks layout "@KM@"'; exit 1; }
r=$(niri msg --json keyboard-layouts 2>&1 | jq -r '.names | join(",")'); echo "niri: $r"
[ -n "$r" ] && [ "$r" != null ] || exit 3
'@ -replace '@KM@', $settingsObj.keymap)
if (Test-App 'sunshine') {
    # Its unit is WantedBy graphical-session.target, which niri-session reaches.
    Invoke-Check 'sunshine: started with the session' 'systemctl --user is-active sunshine'
}
if (Test-App 'wayvnc') {
    # Started with the session, listening on every address (the firewall opens 5900), with keys.
    Invoke-Check 'wayvnc: running, on 0.0.0.0:5900, with its keys' @'
s=$(systemctl --user is-active wayvnc); echo "wayvnc: $s"; [ "$s" = active ] || exit 1
ss -tln | grep -E '0\.0\.0\.0:5900|\*:5900' || { echo 'not listening on 5900'; exit 1; }
ls ~/.local/state/nusku/wayvnc/ | tr '\n' ' '
[ -s ~/.local/state/nusku/wayvnc/tls_cert.pem ] && [ -s ~/.local/state/nusku/wayvnc/rsa_key.pem ]
'@
}
Invoke-Check 'session PATH (niri children)' @'
p=$(shellpid); [ -n "$p" ] || { echo 'no nusku-shell to read'; exit 1; }
path=$(environ_of "$p" | sed -n 's/^PATH=//p')
echo "$path"
case ":$path:" in *":/etc/profiles/per-user/$(id -un)/bin:"*) ;; *) echo 'no per-user profile'; exit 1 ;; esac
case ":$path:" in *":/run/current-system/sw/bin:"*) ;; *) echo 'no system profile'; exit 1 ;; esac
for c in nusku-wallpaper nusku-calendar nusku-quick qs niri xwayland-satellite; do PATH="$path" command -v "$c" >/dev/null || { echo "$c not found on it"; exit 1; }; done
'@
Invoke-Check 'cursor theme' @"
p=`$(shellpid)
t=`$(environ_of "`$p" | sed -n 's/^XCURSOR_THEME=//p'); echo "XCURSOR_THEME=`$t"
[ "`$t" = 'catppuccin-mocha-$Accent-cursors' ] || exit 1
for d in ~/.icons ~/.local/share/icons /etc/profiles/per-user/`$(id -un)/share/icons /run/current-system/sw/share/icons; do
    [ -d "`$d/`$t/cursors" ] && { echo "found in `$d"; exit 0; }
done
echo 'theme directory not found'; exit 1
"@
Invoke-Check 'GTK relative @import' @'
ok=0
for v in 3.0 4.0; do
    f="$HOME/.config/gtk-$v/gtk.css"
    imp=$(sed -n 's/^@import "\([^"]*\)";.*/\1/p' "$f" | head -1)
    [ -n "$imp" ] || { echo "gtk-$v: no @import"; ok=1; continue; }
    if [ -r "$(dirname "$f")/$imp" ]; then
        echo "gtk-$v: $imp resolves from ~/.config/gtk-$v"
        grep -q '@define-color\|accent' "$(dirname "$f")/$imp" || { echo "gtk-$v: imported file has no colours"; ok=1; }
    else
        echo "gtk-$v: $imp does not resolve"; ok=1
    fi
done
exit $ok
'@
Invoke-Check 'SDDM greeter background' @'
b=/var/lib/nusku/sddm-background/background
echo "$b -> $(readlink "$b") ($(stat -L -c '%U %a' "$b" 2>/dev/null))"
sudo -n -u sddm test -r "$b" || { echo 'the sddm user cannot read it'; exit 1; }
grep -rqs sddm-background /run/current-system/sw/share/sddm/themes/*/theme.conf* /etc/sddm.conf* &&
    echo 'theme config points at it' || { echo 'no theme config names it'; exit 3; }
'@

# --- Menus ----------------------------------------------------------------------
Invoke-Check 'niri action from a bind (focus-workspace 2)' @'
niri msg action focus-workspace 2 >/dev/null || exit 1
sleep 1
idx=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .idx'); echo "focused: $idx"
niri msg action focus-workspace 1 >/dev/null
[ "$idx" = 2 ]
'@
Invoke-Check 'rofi theme (imports through HM links)' @'
out=$(rofi -theme nusku -dump-theme 2>&1); rc=$?
echo "$out" | grep -iE 'error|failed' | head -3
[ $rc -eq 0 ] && ! echo "$out" | grep -qiE 'error|failed' && echo "$(echo "$out" | wc -l) theme lines"
'@
# Rofi lists the first <id>.desktop on XDG_DATA_HOME:XDG_DATA_DIRS (as the session has them);
# Nusku's NoDisplay copies must come first.
Invoke-Check 'rofi hides NoDisplay entries' @'
p=$(shellpid)
dirs="$HOME/.local/share:$(environ_of "$p" | sed -n 's/^XDG_DATA_DIRS=//p')"
ok=0; n=0
for id in rofi rofi-theme-selector xfce4-about thunar-volman-settings qt5ct qt6ct; do
    first=""
    IFS=:; for d in $dirs; do [ -f "$d/applications/$id.desktop" ] && { first="$d/applications/$id.desktop"; break; }; done; unset IFS
    [ -n "$first" ] || continue
    n=$((n + 1))
    grep -qx 'NoDisplay=true' "$first" || { echo "$id: shown ($first)"; ok=1; }
done
echo "$n hidden entries checked"
[ $n -gt 0 ] || exit 1
exit $ok
'@
$browserIds = @{ firefox = 'firefox.desktop'; chromium = 'chromium-browser.desktop'; brave = 'brave-browser.desktop'; librewolf = 'librewolf.desktop' }
$picked = @('firefox', 'chromium', 'brave', 'librewolf' | Where-Object { Test-App $_ })
if ($picked.Count -gt 0) {
    $ids = ($picked | ForEach-Object { $browserIds[$_] }) -join ' '
    Invoke-Check 'browser desktop ids (gtk-launch, default)' @"
p=`$(shellpid)
dirs="`$HOME/.local/share:`$(environ_of "`$p" | sed -n 's/^XDG_DATA_DIRS=//p')"
ok=0
for id in $ids; do
    found=''; IFS=:; for d in `$dirs; do [ -f "`$d/applications/`$id" ] && found=1; done; unset IFS
    [ -n "`$found" ] && echo "`$id ok" || { echo "`$id missing"; ok=1; }
done
def=`$(xdg-mime query default x-scheme-handler/https); echo "https -> `$def"
[ "`$def" = '$($browserIds[$picked[0]])' ] || ok=1
exit `$ok
"@
}

# --- Apps --------------------------------------------------------------------------
if (Test-App 'pokemon') {
    # krabby draws sprites with half-block characters (U+2580 / U+2584) and truecolor escapes;
    # the NixOS logo uses neither. Byte-wise grep so the guest locale does not matter.
    Invoke-Check 'nusku-fetch pokemon sprite' @'
command -v krabby >/dev/null || { echo 'krabby not installed'; exit 1; }
n=$(nusku-fetch 2>&1 | LC_ALL=C grep -cP "\xe2\x96[\x80\x84]"); echo "$n sprite lines"; [ "$n" -gt 0 ]
'@
}
if (Test-App 'firefox') {
    Invoke-Check 'firefox: Firefox Color by policy, from the store' @'
f=$(readlink -f "$(command -v firefox)"); d=$(dirname "$f")/..
pol=$(ls "$d"/lib/*/distribution/policies.json 2>/dev/null | head -1)
[ -n "$pol" ] || { echo "no policies.json next to $f"; exit 1; }
url=$(jq -r '.policies.ExtensionSettings["FirefoxColor@mozilla.com"].install_url // empty' "$pol"); echo "$url"
case "$url" in file:///nix/store/*.xpi) [ -f "${url#file://}" ] ;; *) exit 1 ;; esac
'@
    # catppuccin/nix's Firefox Color theme: frame = Mocha crust (#11111b), icons = the accent
    # (read from the rendered ~/.config/nusku/theme/gtk.css), and firstRunDone set.
    Invoke-Check 'firefox: catppuccin settings in the profile' @'
s=$(find ~/.config/mozilla/firefox ~/.mozilla/firefox -path '*FirefoxColor@mozilla.com*' -name 'storage.js' 2>/dev/null | head -1)
[ -n "$s" ] || { echo 'no Firefox Color storage.js'; exit 1; }
hex=$(sed -n 's/^@define-color accent_color #\([0-9a-fA-F]\{6\}\);.*/\1/p' ~/.config/nusku/theme/gtk.css | head -1)
[ -n "$hex" ] || { echo 'no accent in ~/.config/nusku/theme/gtk.css'; exit 1; }
r=$((16#${hex:0:2})); g=$((16#${hex:2:2})); b=$((16#${hex:4:2}))
echo "$s; accent #$hex"
jq -e --argjson r "$r" --argjson g "$g" --argjson b "$b" '
    .firstRunDone == true
    and .theme.colors.frame == { r: 17, g: 17, b: 27 }
    and .theme.colors.icons == { r: $r, g: $g, b: $b }' "$s" >/dev/null ||
    { echo "not the Catppuccin Mocha theme in the accent: $(jq -c '.theme.colors | { frame, icons }' "$s")"; exit 1; }
'@
}
# catppuccin/nix's Chromium/Brave theme extension (Catppuccin Mocha, from the Chrome Web Store),
# listed for the browser's first start. test/eval/hyperv.nix fails if catppuccin/nix changes the id.
$catppuccinCrx = 'bkkmolkhemgaeaeggcmfbghljjjoofoh'
foreach ($b in @(@{ id = 'chromium'; dir = '.config/chromium' }, @{ id = 'brave'; dir = '.config/BraveSoftware/Brave-Browser' })) {
    if (Test-App $b.id) {
        Invoke-Check "$($b.id): catppuccin extension listed" @"
j=~/$($b.dir)/'External Extensions'/$catppuccinCrx.json
[ -f "`$j" ] || { echo "no `$j"; ls ~/$($b.dir)/'External Extensions'/ 2>&1 | head -3; exit 1; }
echo "`$j"; jq -e '.external_update_url' "`$j"
"@
    }
}
if (Test-App 'obsidian') {
    Invoke-Check 'obsidian: theme selected in a vault' @'
a="$HOME/Vault/.obsidian/appearance.json"
t=$(jq -r '.cssTheme // empty' "$a" 2>/dev/null); echo "cssTheme=$t"
[ -n "$t" ] && [ -f "$HOME/Vault/.obsidian/themes/$t/theme.css" ] && [ -e "$HOME/Vault/.obsidian/.nusku-theme-applied" ]
'@
}
if (Test-App 'neovim') {
    Write-Host '    (Neovim: installing the lazy-lock.json plugins headless; needs the network)'
    Invoke-Check 'neovim: plugins at the lock (nusku.sync)' 'set -o pipefail; timeout 900 nvim --headless "+lua require(''nusku.sync'').run()" "+cquit 2" </dev/null | tail -3'
    Invoke-Check 'neovim: no mason, no site/parser' @'
d="$HOME/.local/share/nvim"
[ ! -e "$d/mason" ] || { echo "$d/mason exists"; exit 1; }
[ ! -e "$d/site/parser" ] || { echo "$d/site/parser exists"; exit 1; }
echo 'neither exists'
'@
    Invoke-Check 'neovim: blink.cmp from Nix, its fuzzy library from the store (nothing downloaded)' @'
[ ! -e "$HOME/.local/share/nvim/lazy/blink.cmp" ] || { echo 'lazy.nvim cloned blink.cmp'; exit 1; }
n=$(find "$HOME/.local/share/nvim" -name 'libblink_cmp_fuzzy*' | wc -l)
[ "$n" -eq 0 ] || { echo "$n fuzzy libraries under ~/.local/share/nvim"; exit 1; }
out=$(timeout 120 nvim --headless "+lua local p = require('lazy.core.config').plugins['blink.cmp']; require('lazy').load({ plugins = { 'blink.cmp' } }); io.stdout:write('dir=' .. p.dir .. ' rust=' .. tostring(pcall(require, 'blink.cmp.fuzzy.rust')) .. '\n')" +qa </dev/null 2>&1)
echo "$out" | grep -E '^dir='
echo "$out" | grep -qE '^dir=/nix/store/.*blink.cmp.* rust=true$'
'@
    Invoke-Check 'neovim: lockfile copy mode 644, the user''s' @'
s=$(stat -c '%a %U' ~/.local/share/nvim/lazy-lock.json); echo "$s"; [ "$s" = "644 $(id -un)" ]
'@
    $probeLua = @'
local want = vim.split(os.getenv("PROBE_WANT") or "", ",", { trimempty = true })
local function clients()
  local n = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do n[c.name] = c end
  return n
end
vim.wait(tonumber(os.getenv("PROBE_WAIT") or "60000"), function()
  local n = clients()
  for _, w in ipairs(want) do
    if not n[w] then return false end
  end
  return true
end, 500)
local n, list = clients(), {}
for k in pairs(n) do list[#list + 1] = k end
table.sort(list)
io.stdout:write("clients=" .. table.concat(list, ",") .. "\n")
io.stdout:write("highlighter=" .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil) .. "\n")
if n.jdtls then io.stdout:write("jdtls_cmd=" .. table.concat(n.jdtls.config.cmd or {}, " ") .. "\n") end
vim.cmd("qa!")
'@
    $probeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($probeLua -replace "`r", '') + "`n"))
    $null = Invoke-Remote "echo $probeB64 | base64 -d > /tmp/nusku-probe.lua"
    if (Test-Lang 'python') {
        Invoke-Check 'neovim: basedpyright + ruff attach, highlighter on' @'
mkdir -p /tmp/py && cd /tmp/py
printf '[project]\nname = "demo"\nversion = "0.1.0"\n' > pyproject.toml
printf 'import os\n\n\ndef greet(name: str) -> str:\n    return f"Hello, {name}!"\n\n\nprint(greet(os.getenv("USER", "world")))\n' > demo.py
out=$(PROBE_WANT=basedpyright,ruff PROBE_WAIT=90000 timeout 180 nvim --headless demo.py -c 'luafile /tmp/nusku-probe.lua' </dev/null)
echo "$out" | grep -E '^(clients|highlighter)='
echo "$out" | grep -q '^clients=.*basedpyright' && echo "$out" | grep -q '^clients=.*ruff' && echo "$out" | grep -q '^highlighter=true'
'@
    }
    if (Test-Lang 'java') {
        Invoke-Check 'neovim: jdtls with Lombok' @'
mkdir -p /tmp/java/src/main/java/demo && cd /tmp/java
printf '<project><modelVersion>4.0.0</modelVersion><groupId>demo</groupId><artifactId>demo</artifactId><version>1</version></project>\n' > pom.xml
printf 'package demo;\n\npublic class Demo {\n    public static void main(String[] args) {}\n}\n' > src/main/java/demo/Demo.java
out=$(PROBE_WANT=jdtls PROBE_WAIT=150000 timeout 240 nvim --headless src/main/java/demo/Demo.java -c 'luafile /tmp/nusku-probe.lua' </dev/null)
echo "$out" | grep -E '^(clients|jdtls_cmd)=' | cut -c1-300
echo "$out" | grep -q '^jdtls_cmd=.*-javaagent:.*lombok.jar' && exit 0
echo "$out" | grep -q '^clients=.*jdtls' && exit 1
echo 'jdtls did not start in time'; exit 3
'@
    }
}
if (Test-Lang 'rust') {
    Write-Host '    (Rust: waiting for nusku-rustup, up to 20 minutes)'
    Invoke-Check 'rust: nusku-rustup toolchain + rust-analyzer' @'
for i in $(seq 1 240); do
    st=$(systemctl --user show -p ActiveState --value nusku-rustup)
    [ "$st" = activating ] || break
    sleep 5
done
echo "nusku-rustup: $(systemctl --user show -p ActiveState,Result --value nusku-rustup | tr '\n' ' ')"
rustup default | head -1
rustup default 2>/dev/null | grep -q '(default)' || exit 1
rust-analyzer --version
'@
}
if (Test-App 'gamemode') {
    # A 32-bit libgamemodeauto for 32-bit games (nusku-arch's lib32-gamemode): ELF class byte 01.
    Invoke-Check 'gamemode: gamemoded + 32-bit library' @'
command -v gamemoded >/dev/null || { echo 'no gamemoded'; exit 1; }
c32=0
for p in $(nix-store -qR /run/current-system | grep -- '-gamemode-'); do
    for f in "$p"/lib/libgamemodeauto.so*; do
        [ -f "$f" ] || continue
        cls=$(od -An -tx1 -j4 -N1 "$f" | tr -d ' ')
        echo "$f class=$cls"
        [ "$cls" = 01 ] && c32=1
    done
done
[ $c32 -eq 1 ] && exit 0
echo 'no 32-bit libgamemodeauto in the system closure'; exit 3
'@
}
if (Test-App 'docker') {
    Invoke-Check 'docker service' 's=$(systemctl is-active docker); echo $s; [ "$s" = active ]'
}
if (Test-App 'localsend') {
    Invoke-Check 'firewall allows LocalSend (53317)' 'sudo -n iptables -S 2>/dev/null | grep -- "--dport 53317" | head -2 | grep . || sudo -n nft list ruleset 2>/dev/null | grep -m2 53317'
}
if (Test-App 'snapper') {
    Invoke-Check 'snapper skipped on ext4 (warning)' 'grep -m1 "Snapper was skipped" ~/install.out'
}
# The picked apps' commands (the build put them in a profile).
$appCommands = [ordered]@{
    'neovim' = 'nvim'; 'gh' = 'gh'; 'claude-code' = 'claude'; 'lazygit' = 'lazygit'; 'docker' = 'docker'; 'vscode' = 'code'
    'firefox' = 'firefox'; 'chromium' = 'chromium'; 'brave' = 'brave'; 'librewolf' = 'librewolf'; 'discord' = 'discord'
    'obsidian' = 'obsidian'; 'libreoffice' = 'libreoffice'; 'thunderbird' = 'thunderbird'; 'calendar' = 'gnome-calendar'
    'bitwarden' = 'bitwarden'; 'zathura' = 'zathura'; 'localsend' = 'localsend_app'; 'spotify' = 'spotify'; 'vlc' = 'vlc'
    'obs' = 'obs'; 'audacity' = 'audacity'; 'gimp' = 'gimp'; 'krita' = 'krita'; 'inkscape' = 'inkscape'; 'kdenlive' = 'kdenlive'
    'blender' = 'blender'; 'steam' = 'steam'; 'lutris' = 'lutris'; 'heroic' = 'heroic'; 'parsec' = 'parsecd'
    'sunshine' = 'sunshine'; 'moonlight' = 'moonlight'; 'gamemode' = 'gamemoderun'; 'mangohud' = 'mangohud'
    'protonup' = 'protonup-qt'; 'wine' = 'wine'; 'osrs' = 'bolt-launcher'; 'yazi' = 'yazi'; 'remmina' = 'remmina'; 'wayvnc' = 'wayvnc'
    'gparted' = 'gparted'; 'pokemon' = 'krabby'
}
$cmds = @($appCommands.Keys | Where-Object { Test-App $_ } | ForEach-Object { $appCommands[$_] })
if ($cmds.Count -gt 0) {
    Invoke-Check 'picked apps: commands on PATH' @"
missing=''
for c in $($cmds -join ' '); do command -v "`$c" >/dev/null || missing="`$missing `$c"; done
[ -z "`$missing" ] && echo '$($cmds.Count) commands found' || { echo "missing:`$missing"; exit 1; }
"@
}

# ------------------------------------------------------------ 7. screenshots
function Save-Screenshot([string]$File) {
    $null = Invoke-Remote ($envPreamble + 'grim /tmp/shot.png')
    if ($script:RemoteExit -ne 0) {
        Write-Host "    grim failed for $File (is niri rendering?)" -ForegroundColor Yellow
        $script:shotFailed = $true
        return
    }
    if (Copy-FromGuest '/tmp/shot.png' (Join-Path $OutDir $File)) {
        Write-Host "    saved $(Join-Path $OutDir $File)"
    } else {
        $script:shotFailed = $true
    }
}
function Invoke-Session([string]$Cmd) {
    # Started by niri, as a bind would start it (the session's environment).
    $null = Invoke-Remote ($envPreamble + "niri msg action spawn-sh -- '$Cmd' >/dev/null")
}
$script:shotFailed = $false
# niri has no action to move the cursor, so it stays where it is (a no-op kept for the calls below).
$moveCursor = 'true'
$closeAll = 'for p in kitty rofi firefox obsidian thunar nusku-calendar; do pkill -u "$(id -u)" -f "(^|/)\.?$p(-wrapped)?( |$)" 2>/dev/null; done; pkill -u "$(id -u)" -f "[o]bsidian" 2>/dev/null; qs -c nusku ipc call panel close >/dev/null 2>&1; true'

if ($niriUp) {
    Write-Step 'Taking screenshots'
    # Park the cursor off the bar (no tooltips).
    $null = Invoke-Remote ($envPreamble + $moveCursor)
    Start-Sleep -Seconds 1
    Save-Screenshot 'desktop.png'

    # A fresh kitty shows the nusku-fetch (fastfetch) greeting, the accent border and the title.
    Invoke-Session 'kitty'
    Start-Sleep -Seconds 5
    $null = Invoke-Remote ($envPreamble + $moveCursor)
    Save-Screenshot 'fastfetch.png'
    $null = Invoke-Remote ($envPreamble + $closeAll)

    Invoke-Session 'rofi -show drun -theme nusku'
    Start-Sleep -Seconds 4   # software rendering: give rofi time to map and animate in
    Save-Screenshot 'rofi.png'
    $null = Invoke-Remote ($envPreamble + $closeAll)

    # The keybind menu (Super + /), started the way its bind starts it.
    Invoke-Session 'nusku-menu-keybinds'
    Start-Sleep -Seconds 4
    Save-Screenshot 'keybinds.png'
    $null = Invoke-Remote ($envPreamble + $closeAll)

    # A notification pop-up, then quick settings (Super + N / the bar pill) with it in the list.
    $null = Invoke-Remote ($envPreamble + "notify-send -a Nusku 'Nusku test' 'A notification from the Hyper-V loop' >/dev/null")
    Start-Sleep -Seconds 2
    Save-Screenshot 'notification.png'
    $null = Invoke-Remote ($envPreamble + 'qs -c nusku ipc call panel open >/dev/null')
    Start-Sleep -Seconds 3
    Save-Screenshot 'quick-settings.png'
    $null = Invoke-Remote ($envPreamble + 'qs -c nusku ipc call panel close >/dev/null')

    # The clock's drop-down calendar: it re-executes itself with gtk4-layer-shell preloaded.
    Invoke-Session 'nusku-calendar'
    Start-Sleep -Seconds 5
    Invoke-Check 'calendar: LD_PRELOAD re-exec (gtk4-layer-shell)' @'
p=$(pgrep -u "$(id -u)" -f 'nusku-calendar' | head -1)
[ -n "$p" ] || { echo 'nusku-calendar is not running'; exit 1; }
l=$(environ_of "$p" | sed -n 's/^LD_PRELOAD=//p'); echo "LD_PRELOAD=$l"
case "$l" in *libgtk4-layer-shell.so*) ;; *) exit 1 ;; esac
niri msg --json layers | jq -r '.[].namespace' | sort -u | tr '\n' ' '
'@
    $null = Invoke-Remote ($envPreamble + $moveCursor)
    Save-Screenshot 'calendar.png'
    $null = Invoke-Remote ($envPreamble + $closeAll)

    # GTK theme (adw-gtk3-dark + the accent from the @import) in Thunar.
    Invoke-Session 'thunar'
    Start-Sleep -Seconds 4
    Save-Screenshot 'gtk-thunar.png'
    $null = Invoke-Remote ($envPreamble + $closeAll)

    if (Test-App 'firefox') {
        Invoke-Session 'firefox'
        Start-Sleep -Seconds 25
        Invoke-Check 'firefox: Firefox Color installed at first start' @'
e=$(find ~/.config/mozilla/firefox ~/.mozilla/firefox -name extensions.json 2>/dev/null | head -1)
[ -n "$e" ] || { echo 'no extensions.json yet'; exit 1; }
jq -r '.addons[] | select(.id == "FirefoxColor@mozilla.com") | "\(.id) \(.version) active=\(.active) \(.sourceURI // "")"' "$e" | grep . || exit 1
jq -e '.addons[] | select(.id == "FirefoxColor@mozilla.com") | .active' "$e" >/dev/null
'@
        Save-Screenshot 'firefox.png'
        $null = Invoke-Remote ($envPreamble + $closeAll)
    }
    if (Test-App 'obsidian') {
        Invoke-Session 'obsidian'
        Start-Sleep -Seconds 15
        Save-Screenshot 'obsidian.png'
        $null = Invoke-Remote ($envPreamble + $closeAll)
    }
    if (Test-App 'neovim') {
        Invoke-Session 'kitty -e nvim /tmp/py/demo.py'
        Start-Sleep -Seconds 8
        $null = Invoke-Remote ($envPreamble + $moveCursor)
        Save-Screenshot 'neovim.png'
        $null = Invoke-Remote ($envPreamble + $closeAll)
    }
} else {
    Write-Host '    No niri session: no screenshots.' -ForegroundColor Yellow
    $script:shotFailed = $true
}

# ------------------------------------------------ 8. rebuild again, rollback
Write-Step 'Rebuilding again with nusku-rebuild (must change nothing)'
Invoke-Check 'second rebuild is a no-op' @"
gens() { ls -d /nix/var/nix/profiles/system-*-link | wc -l; }
before=`$(readlink /run/current-system); g1=`$(gens)
NUSKU_FLAKE_ATTR='$FlakeAttr' nusku-rebuild > ~/rebuild2.out 2>&1; rc=`$?
after=`$(readlink /run/current-system); g2=`$(gens)
echo "nusku-rebuild exit `$rc; generations `$g1 -> `$g2"
[ `$rc -eq 0 ] || { tail -5 ~/rebuild2.out; exit 1; }
[ "`$before" = "`$after" ] || { echo "system changed: `$before -> `$after"; exit 1; }
[ "`$g1" = "`$g2" ] || { echo 'same system, but a new generation'; exit 3; }
"@
$null = Copy-FromGuest '~/rebuild2.out' (Join-Path $OutDir 'rebuild2.out')
# /boot is root-only (0700), so everything under it is read with sudo. systemd-boot entry files
# are named by hash (nixos-<hash>.conf), so the generations are counted from `bootctl list`
# titles ("NixOS (Generation N ..."), else from the entry files; GRUB lists one menuentry per
# generation under "NixOS - All configurations".
Invoke-Check 'rollback generation exists' @'
g=$(ls -d /nix/var/nix/profiles/system-*-link | wc -l)
if sudo -n test -f /boot/grub/grub.cfg; then
    b=$(sudo -n grep -cE 'menuentry "NixOS - Configuration [0-9]+' /boot/grub/grub.cfg); how='GRUB menu entries'
else
    b=$(sudo -n bootctl list --no-pager 2>/dev/null | grep -cE '^ *title: NixOS \(Generation [0-9]+'); how='systemd-boot entries (bootctl list)'
    if [ "$b" -eq 0 ]; then
        b=$(sudo -n sh -c 'ls /boot/loader/entries/' 2>/dev/null | grep -cE '^nixos-.*\.conf$'); how='systemd-boot entry files'
    fi
fi
echo "$g system generations, $b $how"
[ "$g" -ge 2 ] && [ "$b" -ge 2 ]
'@

# ---------------------------------------------------------------- finish
$results | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host
$results | Format-Table -AutoSize -Wrap | Out-String -Width 400 | Set-Content -Encoding UTF8 (Join-Path $OutDir 'checks.txt')
$checksFailed = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count -gt 0

if (-not $KeepRunning -and -not $checksFailed -and -not $script:shotFailed) {
    Write-Step 'Shutting the VM down'
    Stop-VM -Name $Name -TurnOff -Force
} elseif (-not $KeepRunning) {
    Write-Host "Leaving '$Name' running for debugging (ssh -i $KeyPath $User@$($script:Ip))." -ForegroundColor Yellow
}

Write-Host ''
if ($script:shotFailed) { Write-Host 'A screenshot is missing.' -ForegroundColor Red }
if ($checksFailed)      { Write-Host 'One or more checks FAILED.' -ForegroundColor Red }
Write-Host "Results: $OutDir"
Write-Host 'Manual checks (look at the screenshots, then the rest): test/hyperv/README.md, section 6.'
if ($checksFailed -or $script:shotFailed) { exit 1 }
Write-Host 'All good.' -ForegroundColor Green
exit 0

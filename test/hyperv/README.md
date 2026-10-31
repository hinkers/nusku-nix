# Hyper-V test VM (NixOS)

A throwaway NixOS VM for testing nusku-nix end to end, as nusku-arch's `test/hyperv` does for
Arch. You install minimal NixOS by hand once and take a checkpoint (`clean-nixos`). Each run of
the test loop restores that checkpoint, copies your working tree in, runs `./install.sh`,
reboots into the desktop, checks it and takes screenshots.

The VM is called `nusku-nix-test`. nusku-arch's VM (`nusku-test`) is a different VM; nothing
here touches it.

## 1. One-time host setup

In an **elevated** PowerShell, if you have not done this for nusku-arch already:

```powershell
Add-LocalGroupMember -Group "Hyper-V Administrators" -Member $env:USERNAME
```

Sign out and back in. The loop uses the same SSH key as nusku-arch's, `$HOME\.ssh\nusku_test`.
Create it if it does not exist:

```powershell
New-Item -ItemType Directory -Force "$HOME\.ssh" | Out-Null
if (-not (Test-Path "$HOME\.ssh\nusku_test")) { ssh-keygen -t ed25519 -f "$HOME\.ssh\nusku_test" -N '""' }
```

## 2. Create the VM

```powershell
.\test\hyperv\New-NuskuNixVM.ps1 -IsoPath E:\nixos-graphical-26.05.13164.6f06d204d8f2-x86_64-linux.iso
Start-VM -Name nusku-nix-test
vmconnect.exe localhost nusku-nix-test
```

This creates a Generation 2 VM with Secure Boot off, 8 GB RAM, 4 CPUs, a 60 GB dynamic disk,
the Default Switch, the ISO first in the boot order, and Standard checkpoints. If a VM with
that name exists, the script stops; `-Force` deletes it (with its checkpoints and disk) and
creates it again. Other options: `-Name`, `-MemoryGB`, `-Cpus`, `-DiskGB`.

60 GB is enough for the small run. If you plan to run `-Full` (every app and language), create
the VM with `-DiskGB 120` instead: the disk is dynamic, so it only takes the space the guest
writes.

## 3. Base install (by hand, inside the VM)

In the VM window, pick the first boot menu entry. The live desktop starts and the installer
opens; if it doesn't, open **Install NixOS** from the applications. On each page:

1. **Welcome:** American English. Next.
2. **Location:** any region and zone (the test host sets its own). Next.
3. **Keyboard:** English (US), Default. Next.
4. **Users:**
   - Your name: `tester`
   - Login name: `tester`
   - Computer name: `nusku-nix-test`
   - A password of your choice, twice.
   - Tick **Use the same password for the administrator account**.
   - Leave **Log in automatically without asking for the password** unticked.
   - Next.
5. **Desktop:** **No desktop**. Next.
6. **Unfree Software:** tick **Allow unfree software** (Nusku allows it anyway). Next.
7. **Partitions:** **Erase disk**. Swap: **Swap (no Hibernate)**. File system: **ext4** if the
   page offers a choice. Leave encryption off. Next.
8. **Summary:** Install, then confirm **Install now**. It takes a few minutes.
9. **Finish:** untick **Restart now**, then Done.

Power the VM off. Don't reboot it, or the ISO boots again. On the host:

```powershell
Stop-VM -Name nusku-nix-test            # shuts the live system down
Set-VMDvdDrive -VMName nusku-nix-test -Path $null
Set-VMFirmware -VMName nusku-nix-test -FirstBootDevice (Get-VMHardDiskDrive -VMName nusku-nix-test)
Start-VM -Name nusku-nix-test
```

### First boot: let the test loop in

Log in on the console as `tester`. The loop needs SSH, passwordless sudo, the Hyper-V guest
services (KVP reports the VM's IP address to the host) and git. They go in a file of their own
next to `configuration.nix`.

First type this by hand and enter your password, so sudo doesn't ask again while the typed
block below runs. If it asks during the block, the lines after it go into the password prompt.

```bash
sudo -v
```

Then, within five minutes (sudo's timeout), type the first block below into the VM. To do
that, copy it on the host and use the VM window's menu: **Clipboard → Type clipboard text**.

```bash
sudo tee /etc/nixos/nusku-test.nix > /dev/null <<'EOF'
# Hyper-V test VM only: what the nusku-nix test loop needs before Nusku's first build.
{ pkgs, ... }:
{
  services.openssh.enable = true;
  security.sudo.extraRules = [
    { users = [ "tester" ]; commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ]; }
  ];
  virtualisation.hypervGuest.enable = true;
  environment.systemPackages = [ pkgs.git ];
}
EOF
sudo sed -i 's|\./hardware-configuration\.nix|./hardware-configuration.nix ./nusku-test.nix|' /etc/nixos/configuration.nix
grep -n 'nusku-test.nix' /etc/nixos/configuration.nix
```

The `grep` must print the `imports` line with both files,
`./hardware-configuration.nix ./nusku-test.nix`. If it prints nothing, add `./nusku-test.nix`
to the `imports` list by hand (`sudo nano /etc/nixos/configuration.nix`).

Then build it (run `sudo -v` again first if more than five minutes have passed):

```bash
sudo nixos-rebuild switch
```

It should end without errors.

Now put the host's key in `~tester/.ssh/authorized_keys`. Run this on the host and type the
password once. SSH still accepts passwords until Nusku's build turns them off.

```powershell
$ip = @((Get-VMNetworkAdapter -VMName nusku-nix-test).IPAddresses) | Where-Object { $_ -match '^\d+(\.\d+){3}$' } | Select-Object -First 1
$ip
Get-Content "$HOME\.ssh\nusku_test.pub" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL tester@$ip "umask 077; mkdir -p ~/.ssh && tr -d '\r' >> ~/.ssh/authorized_keys"
```

If `$ip` is empty, wait a few seconds and run the first line again. If it stays empty,
check in the VM that `systemctl status hv-kvp` is running.

Check the key works, with no password prompt:

```powershell
ssh -i "$HOME\.ssh\nusku_test" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL tester@$ip 'sudo -n true && git --version && echo ready'
```

It must print a git version and `ready`.

The key lives in `~/.ssh/authorized_keys`, not in the NixOS config, so it survives Nusku's first
build, which replaces everything from `/etc/nixos`. Section 5 explains how the loop keeps SSH
and sudo after that build.

## 4. Checkpoint

Shut the VM down from inside (`sudo poweroff`), then on the host:

```powershell
Checkpoint-VM -Name nusku-nix-test -SnapshotName clean-nixos
```

Every run restores this checkpoint. To restore it by hand:
`Restore-VMSnapshot -VMName nusku-nix-test -Name clean-nixos -Confirm:$false`.

## 5. Running the test loop

```powershell
# The small host: Neovim + Python, Firefox, Obsidian, GNOME Calendar, Pokemon.
powershell -NoProfile -ExecutionPolicy Bypass -File test\hyperv\Invoke-NuskuNixTest.ps1
# Every app and every language.
powershell -NoProfile -ExecutionPolicy Bypass -File test\hyperv\Invoke-NuskuNixTest.ps1 -Full
# Any settings.json in the repo (its hostname and user are replaced).
powershell -NoProfile -ExecutionPolicy Bypass -File test\hyperv\Invoke-NuskuNixTest.ps1 -Settings test/fixtures/hosts/vm-min/settings.json
```

Options: `-KeepRunning` leaves the VM up at the end (it is always left up after a failure),
`-InstallTimeoutMin 240`, `-Name`, `-HostName` (default `nusku-nix-test`), `-User`.

The small run downloads a few GB and takes from about 20 minutes to an hour, depending on your
connection. A `-Full` run downloads tens of GB (Steam, Blender, LibreOffice, every language's
tools and more) and can take several hours.

What a run does:

1. It restores `clean-nixos`, starts the VM and waits for its IP address (KVP) and SSH.
2. It copies the working tree into `~/nusku`: tracked and untracked files, honouring
   `.gitignore`, uncommitted changes included. It adds `hosts/nusku-nix-test/settings.json`
   from the settings fixture and commits everything in a fresh git repo, because the flake only
   sees tracked files.
3. It runs `./install.sh --host nusku-nix-test --no-reboot` with
   `NUSKU_FLAKE_ATTR=nusku-nix-test-hyperv-test`. install.sh copies the VM's own
   `/etc/nixos/hardware-configuration.nix` into the host, commits it and builds. The install
   runs detached in the guest and its output is streamed to your terminal.
4. It reboots. SDDM logs `tester` straight into Hyprland.
5. It runs the checks and prints a PASS/WARN/FAIL table.
6. It takes screenshots: desktop, fastfetch (kitty), rofi, keybinds, quick settings, calendar,
   GTK (Thunar), plus Firefox, Obsidian and Neovim when they are picked.
7. It runs `nusku-rebuild` again (it must change nothing) and checks that a rollback generation
   exists.

Results go to `test/screenshots/<timestamp>/`, which is gitignored: the PNGs, `install.out`,
`install.log`, `rebuild2.out` and `checks.txt`. The exit code is:

- 0 for "All good.";
- 2 when the run couldn't get going before the install (VM, SSH, packaging);
- 1 for anything that fails once the install has started: the install itself, its timeout, the
  guest not coming back after the reboot, a check or a screenshot. If install.sh dies without an
  exit code, the loop stops at once instead of waiting for the timeout.

### How the VM keeps SSH and sudo after Nusku's build

Nusku's first `nixos-rebuild switch` replaces everything `/etc/nixos` set up, including sshd,
the NOPASSWD rule and the guest services. So the loop doesn't build the plain host `NAME`. It
builds `NAME-hyperv-test`, a separate flake output: the same host plus
[`guest.nix`](guest.nix). guest.nix adds:

- sshd with keys only, reading `~/.ssh/authorized_keys`;
- NOPASSWD sudo for the host's user;
- the Hyper-V guest services;
- SDDM autologin into Hyprland;
- `NUSKU_FLAKE_ATTR`, so `nusku-rebuild` in the VM builds the variant again.

These variants exist only for hosts whose `settings.json` has `"gpu": "vm"`, and guest.nix
refuses to build for any other host. A host's own output, `NAME`, never includes it.
`test/eval/hyperv.nix` checks all of this without the VM. install.sh and nusku-rebuild build
the variant only when `NUSKU_FLAKE_ATTR` is set (`lib/sh/rebuild.sh`), and they refuse any
value that doesn't end in `-hyperv-test`. A real machine never sets it. The loop passes it
explicitly to install.sh and nusku-rebuild; guest.nix also sets it for the VM's shells, so a
`nusku-rebuild` you type in the VM keeps building the variant.

## 6. Manual checks

Automation is impractical for these, so after a run, look at them by hand. Use the
screenshots, or the VM itself with `-KeepRunning`.

- **Screenshots:**
  - Bar, wallpaper, accent border, quick-settings panel and calendar drop-down: compare with
    nusku-arch.
  - `gtk-thunar.png`: the accent is visible, which shows GTK honoured the relative `@import`.
  - `firefox.png`: Firefox is Catppuccin Mocha in the accent.
  - `obsidian.png`: the test vault opens with Catppuccin.
  - `neovim.png`: catppuccin-mocha, highlighting on, no Mason.
- **Cursor:** in the VM window, the pointer is the Catppuccin cursor in the accent (grim doesn't
  capture it).
- **SDDM greeter:** log out (power menu → Log out). The greeter shows the wallpaper as its
  background. Log back in as `tester`.
- **Calendar events:** in GNOME Calendar, add an Online Account (Google or Nextcloud). The
  clock's drop-down then shows dots on days with events.
- **Rust toolchain offline → online:** on a `-Full` run, disconnect the VM's network adapter
  before logging in. `nusku-rustup` fails without blocking the login. Reconnect, then run
  `systemctl --user restart nusku-rustup`, and the toolchain installs.
- **Neovim after a lazy-lock bump:** change a pin in `config/nvim/lazy-lock.json`, then
  `git add` it and run `nusku-rebuild` in the VM. Open `nvim`: it restores the plugins once and
  says nothing on the next start.
- **The installer's menu on the console:** in the VM window (a real `/dev/tty`), run
  `cd ~/nusku && ./install.sh --reconfigure`. The menu draws and keys work. Esc leaves without
  changes.
- **nusku-update:** the copy in the VM has no remote, so this needs a clone with an upstream.
  Check it on a real machine.
- **An unmanaged Firefox `profiles.ini`:** create `~/.config/mozilla/firefox/profiles.ini` by
  hand, then run `nusku-rebuild`. The rebuild reports the collision the README describes.
- **wayvnc (`-Full`):** it listens on localhost only (`ss -tlnp | grep 5900`).

Skipped, because the VM can't show them:

- the NVIDIA 580 legacy driver (`legacy_580`): there is no NVIDIA GPU in Hyper-V, so check it
  on hardware;
- saved Wi-Fi surviving the first build: the VM has no Wi-Fi;
- hyprpaper: Hyper-V has no render node, so the loop expects the swaybg fallback and marks it
  WARN.

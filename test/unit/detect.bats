# lib/sh/detect.sh: what the installer reads from the running machine. lspci and the other
# probes are stubs; the GPU table is nusku-arch's gpu_suggest (lib/gpu.sh).

setup() {
    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"
    export NUSKU_DRM_DIR="$BATS_TEST_TMPDIR/drm" # empty: no laptop screen unless a test adds one
    export LSPCI_OUT="$BATS_TEST_TMPDIR/lspci" VIRT=none
    : >"$LSPCI_OUT"
    printf '#!/bin/sh\ncat "$LSPCI_OUT"\n' >"$STUBS/lspci"
    printf '#!/bin/sh\necho "$VIRT"\n[ "$VIRT" != none ]\n' >"$STUBS/systemd-detect-virt"
    chmod +x "$STUBS"/*
}

detect() { PATH="$STUBS:$PATH" bash -c 'set -Eeuo pipefail; source lib/sh/log.sh; source lib/sh/detect.sh; '"$1"; }

# stub NAME BODY: a shell-script stub for one command.
stub() {
    printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

INTEL='00:02.0 VGA compatible controller: Intel Corporation Alder Lake-P GT2 [Iris Xe Graphics] (rev 0c)'
NVIDIA='01:00.0 3D controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)'
AMD='0a:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] (rev c8)'
NVIDIA_DESKTOP='2d:00.0 VGA compatible controller: NVIDIA Corporation AD104 [GeForce RTX 4070] (rev a1)'
AUDIO='00:1f.3 Audio device: Intel Corporation Alder Lake PCH-P High Definition Audio Controller (rev 01)'

gpu_is() { # gpu_is EXPECTED LSPCI_LINE...
    local want="$1"
    shift
    printf '%s\n' "$@" >"$LSPCI_OUT"
    run detect detect_gpu
    [ "$status" -eq 0 ]
    [ "$output" = "$want" ] || { echo "lspci: $* -> $output, want $want"; return 1; }
}

@test "detect_gpu: the nusku-arch table" {
    gpu_is hybrid-intel "$INTEL" "$NVIDIA" "$AUDIO"
    gpu_is hybrid-amd "$AMD" "$NVIDIA"
    gpu_is nvidia "$NVIDIA_DESKTOP" "$AUDIO"
    gpu_is intel "$INTEL" "$AUDIO"
    gpu_is amd "$AMD"
    gpu_is amd "$AUDIO" # nothing recognised: falls back to amd
}

@test "detect_gpu: a virtual machine is vm whatever lspci says" {
    VIRT=microsoft gpu_is vm "$NVIDIA_DESKTOP"
}

@test "detect_gpu: never fails without lspci or systemd-detect-virt" {
    rm "$STUBS/lspci" "$STUBS/systemd-detect-virt"
    run detect detect_gpu
    [ "$status" -eq 0 ]
    [ "$output" = amd ]
}

@test "detect_prime_ids: lspci addresses become decimal PCI:bus:device:function" {
    printf '%s\n' "$INTEL" "$AUDIO" "$NVIDIA" >"$LSPCI_OUT"
    run detect detect_prime_ids
    [ "$output" = $'intel PCI:0:2:0\nnvidia PCI:1:0:0' ]
    printf '%s\n' "$AMD" "$NVIDIA" >"$LSPCI_OUT"
    run detect detect_prime_ids
    [ "$output" = $'amd PCI:10:0:0\nnvidia PCI:1:0:0' ]
}

@test "detect_prime_ids: hex devices and functions, a PCI domain, first card of each kind" {
    printf '%s\n' '0000:00:1f.7 Display controller: Intel Corporation Device' \
        '0000:c1:00.0 3D controller: NVIDIA Corporation Device' \
        '0000:c2:00.0 3D controller: NVIDIA Corporation Other' >"$LSPCI_OUT"
    run detect detect_prime_ids
    [ "$output" = $'intel PCI:0:31:7\nnvidia PCI:193:0:0' ]
}

# fake_panel CONNECTOR MODE: a sysfs-style DRM connector whose preferred mode is MODE.
fake_panel() {
    mkdir -p "$NUSKU_DRM_DIR/$1"
    printf '%s\n1280x800\n' "$2" >"$NUSKU_DRM_DIR/$1/modes"
}

@test "detect_panels: 1920x1200 and 1920x1080 laptop screens get 1.25 (nusku-arch gpu_panel_lua)" {
    fake_panel card1-eDP-1 1920x1200
    fake_panel card0-eDP-2 1920x1080
    run detect 'detect_panels intel'
    [ "$output" = '[{"output":"eDP-2","scale":1.25},{"output":"eDP-1","scale":1.25}]' ] # card0 before card1
}

@test "detect_panels: other laptop screens, external monitors and VMs get none" {
    fake_panel card1-eDP-1 2880x1800
    fake_panel card1-DP-1 1920x1080
    run detect 'detect_panels amd'
    [ "$output" = '[]' ]
    rm -r "$NUSKU_DRM_DIR"
    fake_panel card1-eDP-1 1920x1200
    run detect 'detect_panels vm'
    [ "$output" = '[]' ]
}

@test "detect_boot: EFI gets systemd-boot, BIOS gets GRUB on the root disk" {
    mkdir -p "$BATS_TEST_TMPDIR/efi"
    NUSKU_EFI_DIR="$BATS_TEST_TMPDIR/efi" run detect detect_boot
    [ "$output" = systemd-boot ]
    stub findmnt 'echo /dev/nvme0n1p2'
    stub lsblk '[ "$*" = "-n -d -o PKNAME /dev/nvme0n1p2" ] && echo nvme0n1'
    NUSKU_EFI_DIR="$BATS_TEST_TMPDIR/none" run detect detect_boot
    [ "$output" = "grub /dev/nvme0n1" ]
    NUSKU_EFI_DIR="$BATS_TEST_TMPDIR/none" NUSKU_ROOT_DISK=/dev/sdb run detect detect_boot
    [ "$output" = "grub /dev/sdb" ]
}

@test "detect_timezone, detect_locale, detect_keymap: read from timedatectl and localectl" {
    stub timedatectl 'echo Australia/Brisbane'
    stub localectl "printf '   System Locale: LANG=en_AU.UTF-8\n                  LC_TIME=en_GB.UTF-8\n       VC Keymap: n/a\n      X11 Layout: de\n'"
    run detect 'detect_timezone; detect_locale; detect_keymap'
    [ "$output" = $'Australia/Brisbane\nen_AU.UTF-8\nde' ]
    stub localectl "printf '   System Locale: LANG=en_US.UTF-8\n       VC Keymap: uk\n      X11 Layout: gb\n'"
    run detect detect_keymap
    [ "$output" = gb ] # the X11 layout first: the answer is an xkb layout
}

@test "detect_keymap: only a console keymap set: its xkb layout (uk is gb, de-latin1 is de)" {
    stub localectl "printf '   System Locale: LANG=en_GB.UTF-8\n       VC Keymap: uk\n      X11 Layout: (unset)\n'"
    run detect detect_keymap
    [ "$output" = gb ]
    stub localectl "printf '       VC Keymap: de-latin1-nodeadkeys\n      X11 Layout: n/a\n'"
    run detect detect_keymap
    [ "$output" = de ]
    stub localectl "printf '       VC Keymap: fr\n'"
    run detect detect_keymap
    [ "$output" = fr ]
}

@test "keymap_xkb: console keymap names to xkb layouts; xkb names unchanged" {
    run detect 'for k in uk sv-latin1 sg jp106 br-abnt2 us gb de "us,de" fr-latin9; do keymap_xkb "$k"; done'
    [ "$output" = $'gb\nse\nch\njp\nbr\nus\ngb\nde\nus,de\nfr' ]
}

@test "detect_keymap: VC Keymap (unset), as on a fresh NixOS, falls back to the X11 layout" {
    # Exactly what `localectl status` printed on the Hyper-V test VM (Task 12).
    stub localectl "printf '   System Locale: LANG=en_AU.UTF-8\n       VC Keymap: (unset)\n      X11 Layout: us\n'"
    run detect 'detect_locale; detect_keymap'
    [ "$output" = $'en_AU.UTF-8\nus' ]
    stub localectl "printf '   System Locale: LANG=en_AU.UTF-8\n       VC Keymap: (unset)\n      X11 Layout: de\n'"
    run detect detect_keymap
    [ "$output" = de ]
}

@test "detect_keymap: neither VC Keymap nor X11 Layout set gives us, never a placeholder" {
    stub localectl "printf '   System Locale: LANG=en_AU.UTF-8\n       VC Keymap: (unset)\n      X11 Layout: (unset)\n'"
    run detect detect_keymap
    [ "$output" = us ]
    stub localectl "printf '   System Locale: LANG=en_AU.UTF-8\n       VC Keymap: \n'"
    run detect detect_keymap
    [ "$output" = us ]
}

@test "detect_*: fall back to UTC, en_US.UTF-8 and us without timedatectl or localectl" {
    stub timedatectl 'exit 1'
    stub localectl 'exit 1'
    run env -u LANG PATH="$STUBS:$PATH" bash -c 'source lib/sh/log.sh; source lib/sh/detect.sh; NUSKU_LOCALTIME=/nonexistent detect_timezone; detect_locale; detect_keymap'
    [ "$output" = $'UTC\nen_US.UTF-8\nus' ]
}

@test "detect_*: every value can be set from the environment" {
    run env NUSKU_HOSTNAME=box NUSKU_USER=amy NUSKU_TIMEZONE=Europe/Paris NUSKU_LOCALE=fr_FR.UTF-8 \
        NUSKU_KEYMAP=fr NUSKU_HOME_FSTYPE=btrfs bash -c 'source lib/sh/log.sh; source lib/sh/detect.sh
        detect_hostname; detect_user; detect_timezone; detect_locale; detect_keymap; detect_home_btrfs && echo btrfs'
    [ "$output" = $'box\namy\nEurope/Paris\nfr_FR.UTF-8\nfr\nbtrfs' ]
}

@test "detect_home_btrfs: only when /home is its own btrfs mount" {
    stub findmnt '[ "$*" = "-n -o FSTYPE --mountpoint /home" ] && echo btrfs'
    run detect 'detect_home_btrfs && echo yes || echo no'
    [ "$output" = yes ]
    stub findmnt 'exit 1' # /home is not a mount point
    run detect 'detect_home_btrfs && echo yes || echo no'
    [ "$output" = no ]
}

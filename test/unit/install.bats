# install.sh end to end, in a throwaway git repo (a copy of the installer) with real git and
# stubs for nix, nixos-rebuild and sudo (which record their calls), lspci and
# systemd-detect-virt. Detection of user, time zone and so on comes from the environment.
#
# The first test's output must equal test/fixtures/hosts/installer-laptop/settings.json, which
# test/run-eval.sh evaluates as a fixture host: so what the installer writes passes the
# settings.json validation (modules/nixos/options.nix).

GOLDEN=test/fixtures/hosts/installer-laptop
FIXTURES="$PWD/test/fixtures"

setup() {
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/lib" "$REPO/hosts"
    cp install.sh "$REPO/"
    cp -r lib/sh "$REPO/lib/"
    cp lib/palette.nix lib/installer-config.nix lib/home-paths.txt "$REPO/lib/"
    : >"$REPO/hosts/.gitkeep"
    export HOME="$BATS_TEST_TMPDIR/home" # no git identity unless a test sets one
    mkdir -p "$HOME"
    git -C "$REPO" init -q
    git -C "$REPO" add -A
    owner commit -q -m init

    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls" CATALOGUE="$PWD/test/fixtures/catalogue.json"
    : >"$CALLS"
    # Each call is logged as one line, written at once (the sudo keep-alive runs alongside), with
    # newlines (NIX_CONFIG has two) as spaces and a space at the end.
    # The NixOS installer's settings (lib/sh/installer-config.sh): the evaluator prints
    # $INSTALLER_OUT (test/fixtures/installer/<case>/evaluated.json). NO_CHANNEL: no <nixpkgs> on
    # NIX_PATH; FAIL_EVAL: the configuration does not evaluate.
    cat >"$STUBS/nix" <<'EOF'
#!/bin/sh
printf 'nix %s\n' "$*" >>"$CALLS"
printf '%s\n' "nix NIX_CONFIG=$(printf '%s\n' "$NIX_CONFIG" | tr '\n' ' ')" >>"$CALLS"
case "$*" in
    *home.file*)
        cat "$HM_TARGETS"
        exit 0
        ;;
    *installer-config.nix*)
        case "$*" in *"builtins.nixPath"*)
            [ -z "${NO_CHANNEL:-}" ] || { echo "error: no nixpkgs channel on NIX_PATH" >&2; exit 1; } ;;
        esac
        [ -z "${FAIL_EVAL:-}" ] || { echo "error: undefined variable 'foo' at /etc/nixos/configuration.nix:3:5" >&2; exit 1; }
        cat "$INSTALLER_OUT"
        exit 0
        ;;
esac
case "$1" in eval) cat "$CATALOGUE" ;; esac
EOF
    cat >"$STUBS/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$(printf 'sudo %s\n' "$*" | tr '\n' ' ')" >>"$CALLS"
exit 0
EOF
    # nixos-rebuild: --help says whether it has --sudo (OLD_REBUILD: an older one without it).
    cat >"$STUBS/nixos-rebuild" <<'EOF'
#!/bin/sh
if [ "$1" = --help ]; then
    if [ -n "${OLD_REBUILD:-}" ]; then echo "  --use-remote-sudo  use sudo"; else echo "  --sudo  use sudo"; fi
    exit 0
fi
printf '%s\n' "$(printf 'nixos-rebuild %s NIX_CONFIG=%s\n' "$*" "$NIX_CONFIG" | tr '\n' ' ')" >>"$CALLS"
[ -z "${FAIL_BUILD:-}" ] || { echo "error: build failed"; exit 1; }
EOF
    printf '#!/bin/sh\ncat "$LSPCI_OUT"\n' >"$STUBS/lspci"
    printf '#!/bin/sh\necho none\nexit 1\n' >"$STUBS/systemd-detect-virt"
    chmod +x "$STUBS"/*
    export LSPCI_OUT="$BATS_TEST_TMPDIR/lspci"
    printf '%s\n' '00:02.0 VGA compatible controller: Intel Corporation Alder Lake-P GT2 [Iris Xe Graphics]' \
        '01:00.0 3D controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile]' >"$LSPCI_OUT"

    export NUSKU_IN_SHELL=1 NUSKU_EUID=1000 NUSKU_NIXOS_MARKER="$REPO/install.sh"
    export NUSKU_HOSTNAME=nixos NUSKU_USER=tester NUSKU_TIMEZONE=Australia/Brisbane \
        NUSKU_LOCALE=en_AU.UTF-8 NUSKU_KEYMAP=us NUSKU_HOME_FSTYPE=ext4
    export NUSKU_EFI_DIR="$BATS_TEST_TMPDIR" NUSKU_DRM_DIR="$BATS_TEST_TMPDIR/drm"
    mkdir -p "$NUSKU_DRM_DIR/card1-eDP-1"
    printf '1920x1200\n' >"$NUSKU_DRM_DIR/card1-eDP-1/modes"
    export NUSKU_HW_CONFIG="$BATS_TEST_TMPDIR/hardware-configuration.nix"
    cp "$GOLDEN/hardware-configuration.nix" "$NUSKU_HW_CONFIG"
    export NUSKU_NIXOS_CONFIG="$BATS_TEST_TMPDIR/configuration.nix"
    : >"$NUSKU_NIXOS_CONFIG"
    export INSTALLER_OUT="$PWD/test/fixtures/installer/plain/evaluated.json"
    # The host's Home Manager targets (`nix eval` of home.file): hyperv-small's, which picks
    # Neovim and Firefox and uses the mauve accent.
    export HM_TARGETS="$PWD/test/fixtures/home-targets.json"
    export NUSKU_TUI_IN="$BATS_TEST_TMPDIR/keys" NUSKU_TUI_OUT="$BATS_TEST_TMPDIR/screen"
    : >"$NUSKU_TUI_IN"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    unset NUSKU_LOG NUSKU_STEP NUSKU_CATALOGUE NUSKU_FLAKE_ATTR
}

owner() { git -C "$REPO" -c user.name=Owner -c user.email=owner@example.com "$@"; }
install() { PATH="$STUBS:$PATH" bash "$REPO/install.sh" "$@"; }
keys() { printf "$1" >"$NUSKU_TUI_IN"; }
commits() { git -C "$REPO" rev-list --count HEAD; }
last_subject() { git -C "$REPO" log -1 --format=%s; }

# seed_host NAME: a committed hosts/NAME (the golden settings, renamed) with an old hardware config.
seed_host() {
    mkdir -p "$REPO/hosts/$1"
    jq --arg n "$1" '.hostname = $n' "$GOLDEN/settings.json" >"$REPO/hosts/$1/settings.json"
    printf '# old disk UUIDs\n{ ... }: { }\n' >"$REPO/hosts/$1/hardware-configuration.nix"
    git -C "$REPO" add "hosts/$1"
    owner commit -q -m "host: $1"
}

# set_apps NAME APPS_JSON LANGS_JSON: change a seeded host's picks (committed).
set_apps() {
    local f="$REPO/hosts/$1/settings.json"
    jq --argjson a "$2" --argjson l "$3" '.apps = $a | .langs = $l' "$f" >"$f.new"
    mv "$f.new" "$f"
    owner commit -q -am "picks"
}

@test "first run: the menu writes hosts/NAME (the golden fixture), commits it and builds it" {
    # Host name: replace "nixos" with installer-laptop; then Install.
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    run install --no-reboot
    [ "$status" -eq 0 ]
    diff "$REPO/hosts/installer-laptop/settings.json" "$GOLDEN/settings.json"
    diff "$REPO/hosts/installer-laptop/hardware-configuration.nix" "$GOLDEN/hardware-configuration.nix"
    [ "$(last_subject)" = "host: installer-laptop" ]
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = $'hosts/installer-laptop/hardware-configuration.nix\nhosts/installer-laptop/settings.json' ]
    [ -z "$(git -C "$REPO" status --porcelain)" ]
    grep -qxF "nixos-rebuild switch --flake $REPO#installer-laptop --sudo NIX_CONFIG=extra-experimental-features = nix-command flakes warn-dirty = false " "$CALLS"
    ! grep -q '^sudo.*nixos-rebuild' "$CALLS" || false # built as the user; sudo only activates
    [[ "$output" == *"Nusku is installed."* ]]
}

@test "every nix call gets flakes switched on (a fresh NixOS has them off)" {
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    run install --no-reboot
    [ "$status" -eq 0 ]
    grep -qxF "nix eval --json $REPO#lib.catalogue" "$CALLS"
    grep -q '^nix NIX_CONFIG=' "$CALLS"
    ! grep '^nix NIX_CONFIG=' "$CALLS" | grep -vF 'extra-experimental-features = nix-command flakes' || false
    grep -qF "nixos-rebuild switch --flake $REPO#installer-laptop --sudo NIX_CONFIG=extra-experimental-features = nix-command flakes" "$CALLS"
}

@test "the re-run inside nix shell does not add the flakes setting twice" {
    seed_host laptop
    NIX_CONFIG=$'extra-experimental-features = nix-command flakes\nwarn-dirty = false' run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    grep -qxF "nixos-rebuild switch --flake $REPO#laptop --sudo NIX_CONFIG=extra-experimental-features = nix-command flakes warn-dirty = false " "$CALLS"
}

@test "it re-runs itself under nix shell with the flake's pinned jq, git and pciutils" {
    seed_host laptop
    unset NUSKU_IN_SHELL
    run install --host laptop
    [ "$status" -eq 0 ]
    grep -qxF "nix shell --inputs-from $REPO nixpkgs#jq nixpkgs#git nixpkgs#pciutils --command bash $REPO/install.sh --host laptop" "$CALLS"
    grep -qF 'nix NIX_CONFIG=extra-experimental-features = nix-command flakes' "$CALLS"
    ! grep -q nixos-rebuild "$CALLS" || false # the re-run (here: the stub) does the work
}

@test "--host NAME: takes the new hardware config, keeps settings.json, asks nothing" {
    seed_host laptop
    local before
    before="$(cat "$REPO/hosts/laptop/settings.json")"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    diff "$REPO/hosts/laptop/hardware-configuration.nix" "$NUSKU_HW_CONFIG"
    [ "$(cat "$REPO/hosts/laptop/settings.json")" = "$before" ]
    [ "$(last_subject)" = "host: laptop" ]
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = hosts/laptop/hardware-configuration.nix ]
    [ ! -s "$NUSKU_TUI_OUT" ] # no screen was drawn
    grep -qF "nixos-rebuild switch --flake $REPO#laptop --sudo" "$CALLS"
}

@test "--host with NUSKU_FLAKE_ATTR (only the Hyper-V test VM sets it) builds that output instead" {
    seed_host laptop
    NUSKU_FLAKE_ATTR=laptop-hyperv-test run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    grep -qF "nixos-rebuild switch --flake $REPO#laptop-hyperv-test --sudo" "$CALLS"
    [ "$(grep -c "^nixos-rebuild switch" "$CALLS")" -eq 1 ]
    [ "$(last_subject)" = "host: laptop" ] # the same host files: hosts/laptop
    [[ "$output" == *"Building laptop-hyperv-test (NUSKU_FLAKE_ATTR) instead of laptop"* ]]
}

@test "--host with a NUSKU_FLAKE_ATTR not ending in -hyperv-test fails and builds nothing" {
    seed_host laptop
    NUSKU_FLAKE_ATTR=desk run install --host laptop --no-reboot
    [ "$status" -ne 0 ]
    [[ "$output" == *"NUSKU_FLAKE_ATTR=desk refused"* ]]
    ! grep -q "^nixos-rebuild switch" "$CALLS" || false
}

@test "a second identical run makes no commit" {
    seed_host laptop
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    local n
    n="$(commits)"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(commits)" = "$n" ]
    [[ "$output" == *"hosts/laptop is unchanged"* ]]
    [ "$(grep -c nixos-rebuild "$CALLS")" -eq 2 ]
}

@test "a plain re-run on a machine that has its host rebuilds it without questions" {
    seed_host laptop
    NUSKU_HOSTNAME=laptop run install --no-reboot
    [ "$status" -eq 0 ]
    [ ! -s "$NUSKU_TUI_OUT" ]
    grep -qF "nixos-rebuild switch --flake $REPO#laptop" "$CALLS"
}

@test "--host with an unknown name fails and lists the known hosts" {
    seed_host laptop
    run install --host desk --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"No hosts/desk/settings.json"*"Known hosts: laptop"* ]]
    ! grep -q nixos-rebuild "$CALLS" || false
}

@test "--apps changes only the app and language picks, commits and rebuilds" {
    seed_host laptop
    # Tick all of Dev, then all of Languages (2nd row); Done.
    keys ' \e[B \e[F\n'
    NUSKU_HOSTNAME=laptop run install --apps --no-reboot
    [ "$status" -eq 0 ]
    local f="$REPO/hosts/laptop/settings.json"
    [ "$(jq -c 'del(.apps, .langs)' "$f")" = "$(jq -c 'del(.apps, .langs) | .hostname = "laptop"' "$GOLDEN/settings.json")" ]
    [ "$(jq -c .apps "$f")" = '["neovim","gh","claude-code","lazygit","docker","vscode","firefox","discord","obsidian","spotify","vlc"]' ]
    [ "$(jq -c .langs "$f")" = '["python","php","gdscript","js","rust","go","cpp","csharp","java","lua"]' ]
    [ "$(last_subject)" = "host: laptop" ]
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = hosts/laptop/settings.json ]
    grep -qF "nixos-rebuild switch --flake $REPO#laptop" "$CALLS"
}

@test "--apps with nothing changed makes no commit" {
    seed_host laptop
    local n before
    n="$(commits)"
    before="$(cat "$REPO/hosts/laptop/settings.json")"
    keys '\e[F\n' # Done straight away
    NUSKU_HOSTNAME=laptop run install --apps --no-reboot
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/hosts/laptop/settings.json")" = "$before" ]
    [ "$(commits)" = "$n" ]
}

@test "--reconfigure opens the menu on this machine's settings" {
    seed_host laptop
    # Rows: User .. Boot loader, Graphics, NVIDIA driver, PRIME bus IDs, Accent colour, Apps, Install.
    # From Install, up twice is Accent: blue -> sapphire.
    keys '\e[F\e[A\e[A\n\e[A\n\e[F\n'
    NUSKU_HOSTNAME=laptop run install --reconfigure --no-reboot
    [ "$status" -eq 0 ]
    local f="$REPO/hosts/laptop/settings.json"
    [ "$(jq -r .accent "$f")" = sapphire ]
    [ "$(jq -c 'del(.accent)' "$f")" = "$(jq -c 'del(.accent) | .hostname = "laptop"' "$GOLDEN/settings.json")" ]
    [ "$(last_subject)" = "host: laptop" ]
}

@test "--apps and --reconfigure need this machine's host" {
    run install --apps --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"--apps needs this machine's host (hosts/nixos)"* ]]
}

@test "no git identity: the commit is made as the user, for that commit only" {
    seed_host laptop
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" log -1 --format='%an <%ae>')" = "tester <tester@laptop>" ]
    ! git -C "$REPO" config user.name || false
    ! git -C "$REPO" config user.email || false
}

@test "with a git identity, the commit uses it" {
    seed_host laptop
    git -C "$REPO" config user.name Amy
    git -C "$REPO" config user.email amy@example.com
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" log -1 --format='%an <%ae>')" = "Amy <amy@example.com>" ]
}

@test "only hosts/NAME goes into the commit, not other staged work" {
    seed_host laptop
    echo scratch >"$REPO/notes.txt"
    git -C "$REPO" add notes.txt
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = hosts/laptop/hardware-configuration.nix ]
    [ "$(git -C "$REPO" diff --cached --name-only)" = notes.txt ]
}

@test "the summary carries the notes for the picked apps" {
    seed_host laptop
    set_apps laptop '["docker","firefox","calendar","sunshine"]' '["rust"]'
    mkdir -p "$HOME/.mozilla/firefox"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [[ "$output" == *"docker group: that is root-equivalent"* ]]
    [[ "$output" == *"https://localhost:47990"* ]]
    [[ "$output" == *"Online Accounts"* ]]
    [[ "$output" == *"Rust: the toolchain downloads in the background after you log in"* ]]
    [[ "$output" == *"~/.mozilla/firefox"*"README"* ]]
    [[ "$output" == *"Next step: Reboot to log in."* ]]
    [[ "$output" != *"No web browser"* ]]
    set_apps laptop '[]' '[]'
    run install --host laptop --no-reboot
    [[ "$output" == *"No web browser is installed"* ]]
    [[ "$output" != *"docker group"* ]]
}

@test "reboot prompt: Reboot now reboots, running out of input does not" {
    seed_host laptop
    run install --host laptop
    [ "$status" -eq 0 ]
    ! grep -q 'systemctl reboot' "$CALLS" || false
    keys '\n'
    run install --host laptop
    [ "$status" -eq 0 ]
    grep -qxF 'sudo systemctl reboot ' "$CALLS"
}

@test "an older nixos-rebuild (no --sudo) gets --use-remote-sudo" {
    seed_host laptop
    OLD_REBUILD=1 run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    grep -qF "nixos-rebuild switch --flake $REPO#laptop --use-remote-sudo NIX_CONFIG=" "$CALLS"
}

@test "a failed build fails the install and points at the log" {
    seed_host laptop
    FAIL_BUILD=1 run install --host laptop --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"Nusku install failed during step: Build"* ]]
    [[ "$output" == *"Full log: "* ]]
}

@test "a failed first build says how to retry: ./install.sh --host NAME" {
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    FAIL_BUILD=1 run install --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"hosts/installer-laptop is saved and committed, so fix the problem, then run: ./install.sh --host installer-laptop"* ]]
    [ "$(last_subject)" = "host: installer-laptop" ]
    FAIL_BUILD= run install --host installer-laptop --no-reboot
    [ "$status" -eq 0 ]
}

@test "it records the checkout in ~/.config/nusku/repo for nusku-rebuild, even when the build fails" {
    seed_host laptop
    FAIL_BUILD=1 run install --host laptop --no-reboot
    [ "$status" -eq 1 ]
    [ "$(cat "$HOME/.config/nusku/repo")" = "$(realpath "$REPO")" ]
    printf '/old/place\n' >"$HOME/.config/nusku/repo"
    FAIL_BUILD= run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/nusku/repo")" = "$(realpath "$REPO")" ]
    ! git -C "$REPO" ls-files --error-unmatch .config >/dev/null 2>&1 || false
}

@test "--host refuses a host whose user does not exist here" {
    seed_host laptop
    local f="$REPO/hosts/laptop/settings.json"
    jq '.user = "nosuchuser"' "$f" >"$f.new" && mv "$f.new" "$f" && owner commit -q -am "other user"
    run install --host laptop --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"hosts/laptop is for user nosuchuser, who does not exist on this machine"*"sudo passwd nosuchuser"*"hosts/laptop/settings.json"* ]]
    ! grep -q nixos-rebuild "$CALLS" || false
}

@test "refuses root, refuses outside NixOS, refuses mixed options" {
    NUSKU_EUID=0 run install --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"Run install.sh as your normal user, not root"* ]]
    NUSKU_NIXOS_MARKER=/nonexistent run install --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"only installs on NixOS"* ]]
    run install --host laptop --apps
    [ "$status" -eq 2 ]
    run install --apps --reconfigure
    [ "$status" -eq 2 ]
}

# --- hosts/NAME/installer.nix: the NixOS installer's boot and encryption settings -------------


# evaluator CHANNEL|FLAKE: the evaluator's command line, with the system's nixpkgs channel or
# the flake's pinned nixpkgs.
evaluator() {
    local nixos='(let c = builtins.filter (e: e.prefix == "nixpkgs" && builtins.pathExists e.path) builtins.nixPath; in if c == [ ] then throw "no nixpkgs channel on NIX_PATH" else (builtins.head c).path + "/nixos")'
    [ "$1" = CHANNEL ] || nixos="((builtins.getFlake \"git+file://$(realpath "$REPO")\").inputs.nixpkgs + \"/nixos\")"
    printf 'nix eval --impure --json --expr import (/. + "%s/lib/installer-config.nix") (import %s { configuration = /. + "%s"; }).config' \
        "$(realpath "$REPO")" "$nixos" "$NUSKU_NIXOS_CONFIG"
}

@test "BIOS + LUKS first run: GRUB on the evaluated disk, installer.nix carries cryptodisk, key file and LUKS" {
    export INSTALLER_OUT="$FIXTURES/installer/bios-luks/evaluated.json"
    # The old guess: / is on a LUKS mapping, whose parent is a partition.
    printf '#!/bin/sh\necho /dev/mapper/luks-5f2b8c1e\n' >"$STUBS/findmnt"
    printf '#!/bin/sh\necho vda2\n' >"$STUBS/lsblk"
    chmod +x "$STUBS/findmnt" "$STUBS/lsblk"
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    NUSKU_EFI_DIR=/nonexistent run install --no-reboot
    [ "$status" -eq 0 ]
    [ "$(jq -c .boot "$REPO/hosts/installer-laptop/settings.json")" = '{"loader":"grub","device":"/dev/vda"}' ]
    diff "$REPO/hosts/installer-laptop/installer.nix" "$FIXTURES/hosts/vm-luks/installer.nix"
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = $'hosts/installer-laptop/hardware-configuration.nix\nhosts/installer-laptop/installer.nix\nhosts/installer-laptop/settings.json' ]
    grep -qxF "$(evaluator CHANNEL)" "$CALLS"
}

@test "--host on UEFI + encrypted swap: installer.nix written and committed; unchanged next time" {
    seed_host laptop
    export INSTALLER_OUT="$FIXTURES/installer/uefi-swap/evaluated.json"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    diff "$REPO/hosts/laptop/installer.nix" "$FIXTURES/hosts/vm-swap/installer.nix"
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = $'hosts/laptop/hardware-configuration.nix\nhosts/laptop/installer.nix' ]
    local n
    n="$(commits)"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(commits)" = "$n" ]
}

@test "a plain install writes no installer.nix; --host drops a stale one" {
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    run install --no-reboot
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/hosts/installer-laptop/installer.nix" ]
    seed_host laptop
    cp "$FIXTURES/hosts/vm-swap/installer.nix" "$REPO/hosts/laptop/"
    git -C "$REPO" add hosts/laptop && owner commit -q -m "old install"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/hosts/laptop/installer.nix" ]
    [ "$(git -C "$REPO" show --name-status --format= HEAD | grep installer.nix)" = $'D\thosts/laptop/installer.nix' ]
}

@test "no nixpkgs channel: the flake's pinned nixpkgs evaluates configuration.nix" {
    seed_host laptop
    export INSTALLER_OUT="$FIXTURES/installer/uefi-swap/evaluated.json"
    NO_CHANNEL=1 run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    grep -qxF "$(evaluator CHANNEL)" "$CALLS"
    grep -qxF "$(evaluator FLAKE)" "$CALLS"
    diff "$REPO/hosts/laptop/installer.nix" "$FIXTURES/hosts/vm-swap/installer.nix"
}

@test "configuration.nix that does not evaluate: the install stops before building" {
    seed_host laptop
    FAIL_EVAL=1 run install --host laptop --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not evaluate $NUSKU_NIXOS_CONFIG"*"undefined variable 'foo'"* ]]
    ! grep -q nixos-rebuild "$CALLS" || false
}

@test "no /etc/nixos/configuration.nix: nothing carried, an existing installer.nix is kept" {
    seed_host laptop
    cp "$FIXTURES/hosts/vm-swap/installer.nix" "$REPO/hosts/laptop/"
    git -C "$REPO" add hosts/laptop && owner commit -q -m "old install"
    NUSKU_NIXOS_CONFIG=/nonexistent run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [[ "$output" == *"No /nonexistent"* ]]
    diff "$REPO/hosts/laptop/installer.nix" "$FIXTURES/hosts/vm-swap/installer.nix"
    ! grep -q installer-config "$CALLS" || false
}

@test "--apps and --reconfigure leave installer.nix alone (no evaluation)" {
    seed_host laptop
    keys '\e[F\n'
    export INSTALLER_OUT="$FIXTURES/installer/bios-luks/evaluated.json"
    NUSKU_HOSTNAME=laptop run install --apps --no-reboot
    [ "$status" -eq 0 ]
    ! grep -q installer-config "$CALLS" || false
    [ ! -e "$REPO/hosts/laptop/installer.nix" ]
}

# --- settings.json "stateVersion": the release NixOS was installed with -------------------------

@test "stateVersion: the first run records the installed release; --host never changes it" {
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    run install --no-reboot
    [ "$status" -eq 0 ]
    [ "$(jq -r .stateVersion "$REPO/hosts/installer-laptop/settings.json")" = 25.11 ] # plain/evaluated.json
    export INSTALLER_OUT="$FIXTURES/installer/bios-luks/evaluated.json" # a reinstall from 25.05
    run install --host installer-laptop --no-reboot
    [ "$status" -eq 0 ]
    [ "$(jq -r .stateVersion "$REPO/hosts/installer-laptop/settings.json")" = 25.11 ]
}

@test "stateVersion: from nixos-version without configuration.nix; a host without one keeps none" {
    printf '#!/bin/sh\necho "25.05.20250601.abcdef0 (Warbler)"\n' >"$STUBS/nixos-version"
    chmod +x "$STUBS/nixos-version"
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    NUSKU_NIXOS_CONFIG=/nonexistent run install --no-reboot
    [ "$status" -eq 0 ]
    [ "$(jq -r .stateVersion "$REPO/hosts/installer-laptop/settings.json")" = 25.05 ]
    seed_host laptop
    local f="$REPO/hosts/laptop/settings.json"
    jq 'del(.stateVersion)' "$f" >"$f.new" && mv "$f.new" "$f" && owner commit -q -am "older host"
    keys '\e[F\n'
    NUSKU_HOSTNAME=laptop run install --reconfigure --no-reboot
    [ "$status" -eq 0 ]
    [ "$(jq 'has("stateVersion")' "$f")" = false ]
}

# --- the home check: files where Home Manager puts its own -----------------------------------

# leftovers: nusku-arch's files (plain files and folders), next to ones Home Manager already made
# (links into the Nix store) and files Nusku doesn't manage.
leftovers() {
    mkdir -p "$HOME/.config/niri" "$HOME/.config/kitty" "$HOME/.config/nvim/lua" "$HOME/.config/gtk-3.0"
    echo 'old' >"$HOME/.config/niri/config.kdl"
    echo 'old' >"$HOME/.zshrc"
    ln -s /nix/store/x-home-manager-files/.config/kitty/kitty.conf "$HOME/.config/kitty/kitty.conf"
    ln -s /nix/store/x-home-manager-files/.config/nvim/init.lua "$HOME/.config/nvim/init.lua"
    echo '{}' >"$HOME/.config/nvim/lazyvim.json" # LazyVim writes it into the managed folder
    echo 'file:///home bookmarks' >"$HOME/.config/gtk-3.0/bookmarks"
    mkdir -p "$HOME/.config/hypr" "$HOME/.icons/catppuccin-mocha-mauve-cursors"
    echo 'old' >"$HOME/.config/hypr/hyprlock.conf"
    echo 'x' >"$HOME/.icons/catppuccin-mocha-mauve-cursors/index.theme"
}

@test "home check: leftovers are listed and, on Move, moved to ~/nusku-backup-<time> before the build" {
    seed_host laptop
    leftovers
    keys '\n'
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [[ "$output" == *"~/.zshrc"* && "$output" == *"~/.config/niri"* && "$output" == *"~/.config/hypr/hyprlock.conf"* ]]
    [[ "$output" == *"~/.icons/catppuccin-mocha-mauve-cursors"* ]]
    [[ "$output" != *"~/.config/kitty"* && "$output" != *"~/.config/nvim"* && "$output" != *"gtk-3.0"* ]]
    local backup
    backup="$(echo "$HOME"/nusku-backup-*)"
    [ -d "$backup" ]
    [ "$(cat "$backup/.config/niri/config.kdl")" = old ] && [ "$(cat "$backup/.zshrc")" = old ]
    [ -f "$backup/.config/hypr/hyprlock.conf" ] && [ -d "$backup/.icons/catppuccin-mocha-mauve-cursors" ]
    [ ! -e "$HOME/.config/niri" ] && [ ! -e "$HOME/.zshrc" ]
    [ -L "$HOME/.config/kitty/kitty.conf" ] && [ -f "$HOME/.config/nvim/lazyvim.json" ] && [ -f "$HOME/.config/gtk-3.0/bookmarks" ]
    grep -qF "nixos-rebuild switch --flake $REPO#laptop" "$CALLS"
    [[ "$output" == *"Files that were in Home Manager's way are in $backup"* ]]
}

@test "home check: Stop moves nothing and builds nothing" {
    seed_host laptop
    leftovers
    keys '\e[B\n'
    run install --host laptop --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"Stopped before the build; nothing was moved"* ]]
    [ -f "$HOME/.zshrc" ] && [ -f "$HOME/.config/niri/config.kdl" ]
    ! ls -d "$HOME"/nusku-backup-* 2>/dev/null || false
    ! grep -q nixos-rebuild "$CALLS" || false
}

@test "home check without a terminal: stops with the list, moves nothing" {
    seed_host laptop
    leftovers
    unset NUSKU_TUI_IN
    run install --host laptop --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"~/.zshrc"*"Move them out of the way"* ]]
    [ -f "$HOME/.zshrc" ]
    ! grep -q nixos-rebuild "$CALLS" || false
}

@test "home check: a home Home Manager already manages passes without a question" {
    seed_host laptop
    mkdir -p "$HOME/.config/niri"
    ln -s /nix/store/x-home-manager-files/.zshrc "$HOME/.zshrc"
    ln -s /nix/store/x-home-manager-files/.config/niri/config.kdl "$HOME/.config/niri/config.kdl"
    echo 'mine' >"$HOME/.config/niri/notes.txt"
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [ ! -s "$NUSKU_TUI_OUT" ]
    [[ "$output" != *"weren't made by Home Manager"* ]]
}

@test "home check: only this host's real targets; an app it doesn't pick is not flagged" {
    seed_host laptop
    jq 'map(select(test("nvim|mozilla") | not))' "$HM_TARGETS" >"$BATS_TEST_TMPDIR/targets.json"
    export HM_TARGETS="$BATS_TEST_TMPDIR/targets.json"
    mkdir -p "$HOME/.config/nvim" "$HOME/.config/mozilla/firefox"
    echo 'mine' >"$HOME/.config/nvim/init.lua"
    echo 'mine' >"$HOME/.config/mozilla/firefox/profiles.ini"
    echo 'old' >"$HOME/.zshrc"
    keys '\n'
    run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [[ "$output" == *"~/.zshrc"* ]]
    [[ "$output" != *"[WARN]   ~/.config/nvim"* && "$output" != *"[WARN]   ~/.config/mozilla"* ]]
    [ "$(cat "$HOME/.config/nvim/init.lua")" = mine ] && [ -f "$HOME/.config/mozilla/firefox/profiles.ini" ]
    grep -qF "nix eval --json $(realpath "$REPO")#nixosConfigurations.\"laptop\".config.home-manager.users.\"tester\".home.file" "$CALLS"
}

@test "--host whose configuration.nix no longer evaluates keeps its installer.nix, with a warning" {
    seed_host laptop
    cp "$FIXTURES/hosts/vm-swap/installer.nix" "$REPO/hosts/laptop/"
    git -C "$REPO" add hosts/laptop && owner commit -q -m "installed"
    FAIL_EVAL=1 run install --host laptop --no-reboot
    [ "$status" -eq 0 ]
    [[ "$output" == *"Could not evaluate $NUSKU_NIXOS_CONFIG"*"keeping hosts/laptop/installer.nix"* ]]
    diff "$REPO/hosts/laptop/installer.nix" "$FIXTURES/hosts/vm-swap/installer.nix"
    grep -qF "nixos-rebuild switch --flake $REPO#laptop" "$CALLS"
}

@test "a first run whose configuration.nix does not evaluate still stops" {
    keys '\n\x7f\x7f\x7f\x7f\x7finstaller-laptop\n\e[F\n'
    FAIL_EVAL=1 run install --no-reboot
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not evaluate $NUSKU_NIXOS_CONFIG"* ]]
    ! grep -q nixos-rebuild "$CALLS" || false
}

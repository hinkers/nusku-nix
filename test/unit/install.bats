# install.sh end to end, in a throwaway git repo (a copy of the installer) with real git and
# stubs for nix, nixos-rebuild and sudo (which record their calls), lspci and
# systemd-detect-virt. Detection of user, time zone and so on comes from the environment.
#
# The first test's output must equal test/fixtures/hosts/installer-laptop/settings.json, which
# test/run-eval.sh evaluates as a fixture host: so what the installer writes passes the
# settings.json validation (modules/nixos/options.nix).

GOLDEN=test/fixtures/hosts/installer-laptop

setup() {
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/lib" "$REPO/hosts"
    cp install.sh "$REPO/"
    cp -r lib/sh "$REPO/lib/"
    cp lib/palette.nix "$REPO/lib/"
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
    cat >"$STUBS/nix" <<'EOF'
#!/bin/sh
printf 'nix %s\n' "$*" >>"$CALLS"
printf '%s\n' "nix NIX_CONFIG=$(printf '%s\n' "$NIX_CONFIG" | tr '\n' ' ')" >>"$CALLS"
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

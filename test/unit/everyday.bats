# nusku-rebuild and nusku-update, run from scripts/ against a throwaway checkout (a clone of a
# bare "origin", so git pull has an upstream) with real git and stubs for nix and nixos-rebuild,
# which record their calls. The checkout is found from ~/.config/nusku/repo (written by
# install.sh) or $NUSKU_REPO; the host is the machine's host name (NUSKU_HOSTNAME here).

setup() {
    export HOME="$BATS_TEST_TMPDIR/home" # no git identity unless a test sets one
    mkdir -p "$HOME"
    unset XDG_CONFIG_HOME NUSKU_REPO NIX_CONFIG NUSKU_FLAKE_ATTR
    export NUSKU_HOSTNAME=box

    local seed="$BATS_TEST_TMPDIR/seed"
    mkdir -p "$seed/lib/sh" "$seed/hosts/box"
    cp lib/sh/rebuild.sh lib/sh/git.sh "$seed/lib/sh/"
    printf '{ }\n' >"$seed/flake.nix"
    printf '{ "pins": 1 }\n' >"$seed/flake.lock"
    printf '{ }\n' >"$seed/hosts/box/settings.json"
    git -C "$seed" init -q -b main
    git -C "$seed" add -A
    git -C "$seed" -c user.name=Owner -c user.email=owner@example.com commit -q -m init
    ORIGIN="$BATS_TEST_TMPDIR/origin.git"
    git clone -q --bare "$seed" "$ORIGIN"
    REPO="$BATS_TEST_TMPDIR/repo"
    git clone -q "$ORIGIN" "$REPO"

    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    # nix: `flake update` writes NEW_LOCK into ./flake.lock (an input moved), when set.
    cat >"$STUBS/nix" <<'EOF'
#!/bin/sh
printf 'nix %s (in %s)\n' "$*" "$PWD" >>"$CALLS"
if [ "$1 $2" = "flake update" ] && [ -n "${NEW_LOCK:-}" ]; then
    printf '%s\n' "$NEW_LOCK" >flake.lock
fi
exit 0
EOF
    cat >"$STUBS/nixos-rebuild" <<'EOF'
#!/bin/sh
if [ "$1" = --help ]; then echo "  --sudo  use sudo"; exit 0; fi
printf '%s\n' "$(printf 'nixos-rebuild %s NIX_CONFIG=%s\n' "$*" "$NIX_CONFIG" | tr '\n' ' ')" >>"$CALLS"
[ -z "${FAIL_BUILD:-}" ] || { echo "error: build failed"; exit 1; }
EOF
    # sudo: records each call. PASSWORD_SUDO: `sudo -n true` fails (a password is needed), so
    # `sudo -v` asks; FAIL_SUDO: that fails too (wrong password).
    cat >"$STUBS/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$CALLS"
case "$*" in
    "-n true") [ -z "${PASSWORD_SUDO:-}${FAIL_SUDO:-}" ] ;;
    -v) [ -z "${FAIL_SUDO:-}" ] ;;
esac
EOF
    chmod +x "$STUBS"/*
}

owner() { git -C "$1" -c user.name=Owner -c user.email=owner@example.com "${@:2}"; }
record() {
    mkdir -p "$HOME/.config/nusku"
    printf '%s\n' "$1" >"$HOME/.config/nusku/repo"
}
rebuild() { PATH="$STUBS:$PATH" bash scripts/nusku-rebuild "$@"; }
update() { PATH="$STUBS:$PATH" bash scripts/nusku-update "$@"; }
built() { grep -qF "nixos-rebuild switch --flake $1#box --sudo NIX_CONFIG=extra-experimental-features = nix-command flakes" "$CALLS"; }
nothing_built() { ! grep -q nixos-rebuild "$CALLS"; }
# first_line PATTERN: the line number of the first call matching PATTERN (empty if none).
first_line() { grep -n -m1 -- "$1" "$CALLS" | cut -d: -f1; }

# upstream_commit: a new commit on origin (from another clone), as when the owner pushes.
upstream_commit() {
    local other="$BATS_TEST_TMPDIR/other"
    [ -d "$other" ] || git clone -q "$ORIGIN" "$other"
    printf '%s\n' "$1" >"$other/upstream.txt"
    git -C "$other" add upstream.txt
    owner "$other" commit -q -m "upstream: $1"
    git -C "$other" push -q origin main
}

# --- nusku-rebuild -----------------------------------------------------------------------

@test "rebuild: the checkout from ~/.config/nusku/repo, the host from the host name" {
    record "$REPO"
    run rebuild
    [ "$status" -eq 0 ]
    built "$REPO"
    [ "$(grep -c nixos-rebuild "$CALLS")" -eq 1 ]
}

@test "rebuild: sudo is asked for first, before the build" {
    record "$REPO"
    PASSWORD_SUDO=1 run rebuild
    [ "$status" -eq 0 ]
    built "$REPO"
    [ -n "$(first_line '^sudo -v')" ]
    [ "$(first_line '^sudo -v')" -lt "$(first_line '^nixos-rebuild')" ]
}

@test "rebuild: passwordless sudo isn't asked for (no sudo -v)" {
    record "$REPO"
    run rebuild
    [ "$status" -eq 0 ]
    built "$REPO"
    ! grep -q '^sudo -v' "$CALLS"
}

@test "rebuild: no sudo (wrong password) stops it before anything is built" {
    record "$REPO"
    FAIL_SUDO=1 run rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"the switch needs sudo"*"Nothing was built"* ]]
    nothing_built
}

@test "rebuild: NUSKU_FLAKE_ATTR (set only in the Hyper-V test VM) picks the flake output" {
    record "$REPO"
    NUSKU_FLAKE_ATTR=box-hyperv-test run rebuild
    [ "$status" -eq 0 ]
    grep -qF "nixos-rebuild switch --flake $REPO#box-hyperv-test --sudo" "$CALLS"
    [ "$(grep -c nixos-rebuild "$CALLS")" -eq 1 ]
    [[ "$output" == *"Building box-hyperv-test (NUSKU_FLAKE_ATTR) instead of box"* ]]
}

@test "rebuild: a NUSKU_FLAKE_ATTR not ending in -hyperv-test is refused, nothing built" {
    record "$REPO"
    NUSKU_FLAKE_ATTR=other-box run rebuild
    [ "$status" -ne 0 ]
    [[ "$output" == *"NUSKU_FLAKE_ATTR=other-box refused"*"must end in -hyperv-test"* ]]
    nothing_built
}

@test "rebuild: XDG_CONFIG_HOME moves the file" {
    mkdir -p "$BATS_TEST_TMPDIR/xdg/nusku"
    printf '%s\n' "$REPO" >"$BATS_TEST_TMPDIR/xdg/nusku/repo"
    XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" run rebuild
    [ "$status" -eq 0 ]
    built "$REPO"
}

@test "rebuild: NUSKU_REPO without the file, and NUSKU_REPO wins over the file" {
    NUSKU_REPO="$REPO" run rebuild
    [ "$status" -eq 0 ]
    built "$REPO"
    : >"$CALLS"
    cp -r "$REPO" "$BATS_TEST_TMPDIR/copy"
    record "$REPO"
    NUSKU_REPO="$BATS_TEST_TMPDIR/copy" run rebuild
    [ "$status" -eq 0 ]
    built "$BATS_TEST_TMPDIR/copy"
}

@test "rebuild: no recorded checkout and no NUSKU_REPO says how to fix it" {
    run rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"Nusku checkout"* ]]
    [[ "$output" == *"./install.sh --host box"* ]]
    [[ "$output" == *"NUSKU_REPO"* ]]
    nothing_built
}

@test "rebuild: a recorded checkout that is gone says so" {
    record "$BATS_TEST_TMPDIR/moved"
    run rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"$BATS_TEST_TMPDIR/moved"*"no flake.nix"* ]]
    [[ "$output" == *"./install.sh --host box"* ]]
    nothing_built
}

@test "rebuild: a machine with no hosts/<hostname> is refused" {
    record "$REPO"
    NUSKU_HOSTNAME=elsewhere run rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"hosts/elsewhere"* ]]
    [[ "$output" == *"Known hosts: box"* ]]
    nothing_built
}

@test "rebuild: a checkout without lib/sh/rebuild.sh is refused" {
    record "$REPO"
    rm "$REPO/lib/sh/rebuild.sh"
    run rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"$REPO/lib/sh/rebuild.sh"* ]]
    nothing_built
}

@test "rebuild: a failed build fails and points at the boot menu" {
    record "$REPO"
    FAIL_BUILD=1 run rebuild
    [ "$status" -eq 1 ]
    [[ "$output" == *"error: build failed"* ]]
    [[ "$output" == *"nusku-rebuild: the build failed"*"boot menu"* ]]
}

@test "rebuild: --help, and unknown options are refused" {
    run rebuild --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: nusku-rebuild"* ]]
    run rebuild --frobnicate
    [ "$status" -eq 2 ]
    nothing_built
}

# --- nusku-update ------------------------------------------------------------------------

@test "update: pulls, updates flake.lock, rebuilds, then commits flake.lock on yes" {
    record "$REPO"
    upstream_commit one
    NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 0 ]
    [ -f "$REPO/upstream.txt" ]
    grep -qxF "nix flake update (in $REPO)" "$CALLS"
    built "$REPO"
    [[ "$output" == *"Commit flake.lock?"* ]]
    [ "$(git -C "$REPO" log -1 --format=%s)" = "flake.lock: update" ]
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = flake.lock ]
    [ -z "$(git -C "$REPO" status --porcelain)" ]
}

@test "update: nix flake update runs only after the pull, the build only after both" {
    record "$REPO"
    NEW_LOCK='{ "pins": 2 }' run update <<<"n"
    [ "$status" -eq 0 ]
    grep -v '^sudo' "$CALLS" >"$BATS_TEST_TMPDIR/steps" # the sudo keep-alive runs alongside
    [ "$(sed -n 1p "$BATS_TEST_TMPDIR/steps")" = "nix flake update (in $REPO)" ]
    sed -n 2p "$BATS_TEST_TMPDIR/steps" | grep -q '^nixos-rebuild switch'
}

@test "update: sudo is asked for first, before the update and the build" {
    record "$REPO"
    PASSWORD_SUDO=1 NEW_LOCK='{ "pins": 2 }' run update <<<"n"
    [ "$status" -eq 0 ]
    [ -n "$(first_line '^sudo -v')" ]
    [ "$(first_line '^sudo -v')" -lt "$(first_line '^nix flake update')" ]
}

@test "update: no sudo stops it before the pull or the update" {
    record "$REPO"
    upstream_commit "from elsewhere"
    FAIL_SUDO=1 run update <<<"n"
    [ "$status" -eq 1 ]
    [[ "$output" == *"the switch needs sudo"*"Nothing was changed"* ]]
    ! grep -q '^nix flake update' "$CALLS"
    [ ! -f "$REPO/upstream.txt" ]
    nothing_built
}

@test "update: no (or no answer) leaves flake.lock updated but uncommitted" {
    record "$REPO"
    NEW_LOCK='{ "pins": 2 }' run update <<<"n"
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" log -1 --format=%s)" = init ]
    [ "$(git -C "$REPO" status --porcelain)" = " M flake.lock" ]
    git -C "$REPO" checkout -q flake.lock
    NEW_LOCK='{ "pins": 2 }' run update </dev/null
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" log -1 --format=%s)" = init ]
    [ "$(git -C "$REPO" status --porcelain)" = " M flake.lock" ]
}

@test "update: only flake.lock goes into the commit; untracked files stay as they were" {
    record "$REPO"
    echo scratch >"$REPO/notes.txt"
    NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" show --name-only --format= HEAD)" = flake.lock ]
    [ "$(git -C "$REPO" status --porcelain)" = "?? notes.txt" ]
}

@test "update: no git identity commits as the user, for that commit only; an identity is used" {
    record "$REPO"
    NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" log -1 --format='%an <%ae>')" = "$(id -un) <$(id -un)@box>" ]
    ! git -C "$REPO" config user.name || false
    git -C "$REPO" config user.name Amy
    git -C "$REPO" config user.email amy@example.com
    NEW_LOCK='{ "pins": 3 }' run update <<<"y"
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" log -1 --format='%an <%ae>')" = "Amy <amy@example.com>" ]
}

@test "update: an unchanged flake.lock is not offered for commit" {
    record "$REPO"
    run update <<<"y"
    [ "$status" -eq 0 ]
    built "$REPO"
    [[ "$output" != *"Commit flake.lock?"* ]]
    [[ "$output" == *"flake.lock is unchanged"* ]]
    [ "$(git -C "$REPO" log -1 --format=%s)" = init ]
}

@test "update: uncommitted changes stop it before anything runs" {
    record "$REPO"
    upstream_commit one
    echo '{ "mine": true }' >"$REPO/hosts/box/settings.json"
    NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [[ "$output" == *"hosts/box/settings.json"* ]]
    [ ! -f "$REPO/upstream.txt" ]
    [ "$(cat "$REPO/hosts/box/settings.json")" = '{ "mine": true }' ]
    ! grep -qv '^sudo' "$CALLS" # nothing but asking for sudo
}

@test "update: staged changes stop it too" {
    record "$REPO"
    echo scratch >"$REPO/notes.txt"
    git -C "$REPO" add notes.txt
    run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [ "$(git -C "$REPO" diff --cached --name-only)" = notes.txt ]
    ! grep -qv '^sudo' "$CALLS" # nothing but asking for sudo
}

@test "update: a pull that can't fast-forward stops it and leaves the local commits" {
    record "$REPO"
    upstream_commit theirs
    echo mine >"$REPO/mine.txt"
    git -C "$REPO" add mine.txt
    owner "$REPO" commit -q -m mine
    local head
    head=$(git -C "$REPO" rev-parse HEAD)
    NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" == *"git pull --ff-only"* ]]
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$head" ]
    [ -z "$(git -C "$REPO" status --porcelain)" ]
    ! grep -qv '^sudo' "$CALLS" # nothing but asking for sudo
}

@test "update: a failed build leaves flake.lock uncommitted and says how to go back" {
    record "$REPO"
    FAIL_BUILD=1 NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" != *"Commit flake.lock?"* ]]
    [[ "$output" == *"git -C $REPO checkout flake.lock"* ]]
    [[ "$output" == *"boot menu"* ]]
    [ "$(git -C "$REPO" log -1 --format=%s)" = init ]
    [ "$(git -C "$REPO" status --porcelain)" = " M flake.lock" ]
}

@test "update: the same checks as nusku-rebuild (no checkout, no host)" {
    run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" == *"./install.sh --host box"*"NUSKU_REPO"* ]]
    record "$REPO"
    NUSKU_HOSTNAME=elsewhere run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hosts/elsewhere"* ]]
    ! grep -qv '^sudo' "$CALLS" # nothing but asking for sudo
}

@test "update: no upstream branch stops it and names the likely causes" {
    record "$REPO"
    git -C "$REPO" branch -q --unset-upstream
    NEW_LOCK='{ "pins": 2 }' run update <<<"y"
    [ "$status" -eq 1 ]
    [[ "$output" == *"git pull --ff-only failed"*"no network, no upstream branch, or this machine and the remote both have new commits"* ]]
    [ -z "$(git -C "$REPO" status --porcelain)" ]
    ! grep -qv '^sudo' "$CALLS" # nothing but asking for sudo
}

# --- Both -----------------------------------------------------------------------------------

@test "both: a relative NUSKU_REPO becomes an absolute flake ref" {
    local scripts="$PWD/scripts"
    cd "$BATS_TEST_TMPDIR"
    NUSKU_REPO=repo PATH="$STUBS:$PATH" run bash "$scripts/nusku-rebuild"
    [ "$status" -eq 0 ]
    built "$REPO"
    : >"$CALLS"
    NUSKU_REPO=./repo PATH="$STUBS:$PATH" run bash "$scripts/nusku-update" <<<"n"
    [ "$status" -eq 0 ]
    built "$REPO"
}

@test "both: the marked checkout-finding blocks are identical" {
    block() { sed -n '/^# --- The checkout/,/^# ------/p' "$1" | tail -n +2; }
    [ -n "$(block scripts/nusku-rebuild)" ]
    diff <(block scripts/nusku-rebuild) <(block scripts/nusku-update)
}

# nusku-rustup: rustup's stable default + rust-analyzer and rustfmt, run by a user service that
# retries on failure (modules/home/langs.nix). rustup is a stub keeping its state in files.

setup() {
    export STATE="$BATS_TEST_TMPDIR/state"
    mkdir -p "$STATE" "$BATS_TEST_TMPDIR/bin"
    : >"$STATE/components"
    cat >"$BATS_TEST_TMPDIR/bin/rustup" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$STATE/calls"
case "$*" in
    default)
        if [ -e "$STATE/default" ]; then echo "stable-x86_64-unknown-linux-gnu (default)"
        else echo "error: no default toolchain is configured" >&2; exit 1; fi ;;
    "default stable")
        [ -n "${FAIL_DOWNLOAD:-}" ] && exit 1
        touch "$STATE/default" ;;
    "component list --installed")
        cat "$STATE/components" ;;
    "component add "*)
        [ -n "${FAIL_DOWNLOAD:-}" ] && exit 1
        shift 2
        for c in "$@"; do echo "$c-x86_64-unknown-linux-gnu" >>"$STATE/components"; done ;;
    *) exit 2 ;;
esac
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/rustup"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# not_called TEXT: no rustup call contained TEXT (a bare `! grep` would not fail a bats test).
not_called() {
    if grep -q "$1" "$STATE/calls" 2>/dev/null; then return 1; fi
}

ready() {
    touch "$STATE/default"
    printf '%s\n' cargo-x86_64-unknown-linux-gnu rust-analyzer-x86_64-unknown-linux-gnu \
        rustfmt-x86_64-unknown-linux-gnu >"$STATE/components"
}

@test "already set up: exits 0 without downloading anything" {
    ready
    run scripts/nusku-rustup
    [ "$status" -eq 0 ]
    not_called "default stable"
    not_called "component add"
}

@test "nothing set: sets the stable default and adds both components" {
    run scripts/nusku-rustup
    [ "$status" -eq 0 ]
    grep -qx "default stable" "$STATE/calls"
    grep -qx "component add rust-analyzer rustfmt" "$STATE/calls"
    [ -e "$STATE/default" ]
}

@test "default set, one component missing: adds only that one" {
    touch "$STATE/default"
    echo rustfmt-x86_64-unknown-linux-gnu >"$STATE/components"
    run scripts/nusku-rustup
    [ "$status" -eq 0 ]
    not_called "default stable"
    grep -qx "component add rust-analyzer" "$STATE/calls"
}

@test "toolchain download fails: exits non-zero so the service retries" {
    FAIL_DOWNLOAD=1 run scripts/nusku-rustup
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not install the stable toolchain"* ]]
    not_called "component add"
}

@test "component download fails: exits non-zero" {
    touch "$STATE/default"
    FAIL_DOWNLOAD=1 run scripts/nusku-rustup
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not add rust-analyzer rustfmt"* ]]
}

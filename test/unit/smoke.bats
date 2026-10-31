# Ported from nusku-arch test/unit/smoke.bats.

@test "bats runs" { run true; [ "$status" -eq 0 ]; }

# The owner works on Windows: git, not the working copy, must carry the exec bit, so a checkout
# on Linux (and the shellcheck/bats runs here) can execute scripts/ directly.
@test "every script in scripts/ is executable in git" {
    git config --global --add safe.directory "$PWD" 2>/dev/null || true
    run git ls-files -s scripts/
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    ! grep -v '^100755 ' <<<"$output" || false
}

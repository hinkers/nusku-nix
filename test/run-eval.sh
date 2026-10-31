#!/usr/bin/env bash
# Evaluation tests for nusku-nix. Needs Docker (Docker Desktop on Windows); nothing is built,
# only evaluated, inside the nixos/nix image.
#
#   bash test/run-eval.sh            every check (nix flake check --no-build) + the bad fixtures
#   bash test/run-eval.sh <check>    one check: a fixture host (vm-min, vm-full) or eval-<file>
#   bash test/run-eval.sh bad        only the bad fixtures
#
# Checks (flake.nix, checks.x86_64-linux):
#   <host>        test/fixtures/hosts/<host>: config.system.build.toplevel must evaluate.
#   eval-<file>   test/eval/<file>.nix: { self, hosts, catalogue, lib, pkgs }: { "<name>" = bool; }
#                 every named boolean must be true; the error lists the false names.
# Bad fixtures: test/fixtures/bad/<name>/{settings.json,hardware-configuration.nix,expect.txt};
#   evaluating <name> must fail with an error containing expect.txt's first line.
#
# Flakes only see files git knows about: `git add` new files before running.
set -euo pipefail

if [[ "${1:-}" != "--inside" ]]; then
    repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    mount=$repo
    if command -v cygpath >/dev/null 2>&1; then mount=$(cygpath -m "$repo"); fi
    image=nixos/nix:latest
    docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image" >/dev/null
    # /nix lives in a named volume so reruns reuse the store. Docker seeds an empty volume from
    # the image's /nix, so the volume is named after the image id: a new image gets a new volume.
    id=$(docker image inspect --format '{{.Id}}' "$image" | sed 's/^sha256://' | cut -c1-12)
    tty=()
    if [[ -t 1 ]]; then tty=(-t); fi
    MSYS_NO_PATHCONV=1 exec docker run --rm "${tty[@]}" \
        -v "nusku-nix-store-$id:/nix" -v "$mount:/repo" -w /repo \
        "$image" bash /repo/test/run-eval.sh --inside "$@"
fi
shift

export NIX_CONFIG=$'experimental-features = nix-command flakes\nwarn-dirty = false'
git config --global --add safe.directory '*'

pass=0
fail=0
ok() {
    pass=$((pass + 1))
    printf 'ok   %s\n' "$1"
}
bad() {
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$1"
    local line
    if [[ -n "${2:-}" ]]; then
        printf '%s\n' "$2" | tail -n 30 | while IFS= read -r line; do printf '     %s\n' "$line"; done
    fi
}

run_checks() {
    local out
    if out=$(nix flake check --no-build 2>&1); then
        ok "nix flake check --no-build"
    else
        bad "nix flake check --no-build" "$out"
    fi
}

run_one() {
    local out
    if out=$(nix eval --raw ".#checks.x86_64-linux.\"$1\".drvPath" 2>&1); then
        ok "check $1"
    else
        bad "check $1" "$out"
    fi
}

run_bad() {
    local dir name want out
    for dir in test/fixtures/bad/*/; do
        name=$(basename "$dir")
        want=$(head -n 1 "$dir/expect.txt")
        if out=$(nix eval --impure --raw --expr "
            let flake = builtins.getFlake \"git+file:///repo\";
            in (flake.lib.mkHosts /repo/test/fixtures/bad).\"$name\".config.system.build.toplevel.drvPath" 2>&1); then
            bad "bad/$name evaluated; expected an error containing: $want"
        elif grep -qF -- "$want" <<<"$out"; then
            ok "bad/$name fails with: $want"
        else
            bad "bad/$name error does not contain: $want" "$out"
        fi
    done
}

case "${1:-}" in
    "") run_checks; run_bad ;;
    bad) run_bad ;;
    *) run_one "$1" ;;
esac

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]

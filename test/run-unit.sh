#!/usr/bin/env bash
# Unit tests for nusku-nix's shell scripts. Needs Docker (Docker Desktop on Windows).
#
#   bash test/run-unit.sh            shellcheck every shell script, then every test/unit/*.bats
#   bash test/run-unit.sh <name>     shellcheck, then only test/unit/<name>.bats
#
# Builds test/Dockerfile as the image nusku-nix-test (bats, shellcheck, jq, python3, git, neovim) and mounts
# the repo at /nusku. Tests run the scripts straight from scripts/ with stub commands
# (rofi, nmcli, bluetoothctl, ...) put first on PATH; the Nix-packaged versions are the same
# files with their runtime tools on PATH (lib/scripts.nix).
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mount=$root
if command -v cygpath >/dev/null 2>&1; then mount=$(cygpath -m "$root"); fi

docker build -q -t nusku-nix-test -f "$root/test/Dockerfile" "$root/test" >/dev/null

target=test/unit
if [[ $# -gt 0 ]]; then target="test/unit/$1.bats"; fi

MSYS_NO_PATHCONV=1 exec docker run --rm -v "$mount:/nusku" -w /nusku nusku-nix-test bash -c '
set -euo pipefail
# Shell scripts only (nusku-calendar is Python; its test byte-compiles it).
files=()
for f in install.sh lib/sh/*.sh scripts/* test/*.sh; do
    [[ -f $f ]] && head -n 1 "$f" | grep -qE "^(#!.*(ba)?sh|# shellcheck shell=bash)" && files+=("$f")
done
shellcheck -x "${files[@]}"
echo "shellcheck: ${#files[@]} scripts clean"
bats "$1"
' _ "$target"

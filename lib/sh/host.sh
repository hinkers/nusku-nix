# shellcheck shell=bash
# Nusku - a host's answers: NUSKU_ANSWERS <-> hosts/NAME/settings.json (the schema is
# modules/nixos/options.nix), its hardware config and its commit; and the app catalogue
# (lib/catalogue.nix, read with `nix eval`). Needs lib/sh/log.sh; uses jq, git and nix.
# Sourced, not executed. Test hooks: NUSKU_HW_CONFIG (default
# /etc/nixos/hardware-configuration.nix), NUSKU_CATALOGUE (the catalogue's JSON, skips nix).

NUSKU_ROOT="${NUSKU_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# The answers, one key per setting: HOSTNAME USER TIMEZONE LOCALE KEYMAP BOOT_LOADER BOOT_DEVICE
# GPU NVIDIA PRIME_IGPU PRIME_NVIDIA PANELS (JSON) ACCENT APPS LANGS (space-separated ids).
if ! declare -p NUSKU_ANSWERS >/dev/null 2>&1; then
    declare -gA NUSKU_ANSWERS=()
fi

answers_get() {
    printf '%s\n' "${NUSKU_ANSWERS[$1]:-}"
}

answers_set() {
    NUSKU_ANSWERS[$1]="$2"
}

# --- hosts/NAME -------------------------------------------------------------------------

host_exists() {
    [ -f "$NUSKU_ROOT/hosts/$1/settings.json" ]
}

# host_list: the known host names, space-separated.
host_list() {
    local f names=()
    for f in "$NUSKU_ROOT"/hosts/*/settings.json; do
        [ -f "$f" ] || continue
        f="${f%/settings.json}"
        names+=("${f##*/}")
    done
    printf '%s\n' "${names[*]:-none}"
}

# host_load NAME: the answers from hosts/NAME/settings.json.
host_load() {
    local file="$NUSKU_ROOT/hosts/$1/settings.json" out line
    out="$(jq -r '
        "HOSTNAME=\(.hostname)", "USER=\(.user)", "TIMEZONE=\(.timezone // "UTC")",
        "LOCALE=\(.locale // "en_US.UTF-8")", "KEYMAP=\(.keymap // "us")",
        "BOOT_LOADER=\(.boot.loader // "systemd-boot")", "BOOT_DEVICE=\(.boot.device // "")",
        "GPU=\(.gpu)", "NVIDIA=\(.nvidia // "")",
        "PRIME_IGPU=\(.prime.intelBusId // .prime.amdgpuBusId // "")",
        "PRIME_NVIDIA=\(.prime.nvidiaBusId // "")", "PANELS=\(.panels // [] | tojson)",
        "ACCENT=\(.accent)", "APPS=\(.apps // [] | join(" "))", "LANGS=\(.langs // [] | join(" "))"
        ' "$file")" || die "Could not read $file"
    while IFS= read -r line; do
        NUSKU_ANSWERS[${line%%=*}]="${line#*=}"
    done <<<"$out"
}

# host_settings_json: the answers as settings.json (keys in a fixed order, so an unchanged answer
# gives an unchanged file).
host_settings_json() {
    local k
    local -a args=()
    for k in HOSTNAME USER TIMEZONE LOCALE KEYMAP BOOT_LOADER BOOT_DEVICE GPU NVIDIA PRIME_IGPU PRIME_NVIDIA ACCENT APPS LANGS; do
        args+=(--arg "$k" "${NUSKU_ANSWERS[$k]:-}")
    done
    jq -n "${args[@]}" --argjson PANELS "${NUSKU_ANSWERS[PANELS]:-[]}" '
        def words: split(" ") | map(select(. != ""));
        {
          hostname: $HOSTNAME, user: $USER, timezone: $TIMEZONE, locale: $LOCALE, keymap: $KEYMAP,
          boot: (if $BOOT_LOADER == "grub" then { loader: "grub", device: $BOOT_DEVICE } else { loader: $BOOT_LOADER } end),
          gpu: $GPU,
          nvidia: (if $NVIDIA == "" then null else $NVIDIA end),
          prime: (if ($GPU | startswith("hybrid-")) then
                    { (if $GPU == "hybrid-amd" then "amdgpuBusId" else "intelBusId" end): $PRIME_IGPU,
                      nvidiaBusId: $PRIME_NVIDIA }
                  else null end),
          panels: $PANELS, accent: $ACCENT, apps: ($APPS | words), langs: ($LANGS | words)
        }'
}

# host_write NAME: write hosts/NAME/settings.json from the answers.
host_write() {
    local dir="$NUSKU_ROOT/hosts/$1" json
    json="$(host_settings_json)" || die "Could not write the settings for $1"
    mkdir -p "$dir"
    printf '%s\n' "$json" >"$dir/settings.json"
}

# host_write_picks NAME: change only "apps" and "langs" in hosts/NAME/settings.json.
host_write_picks() {
    local file="$NUSKU_ROOT/hosts/$1/settings.json" json
    json="$(jq --arg apps "${NUSKU_ANSWERS[APPS]:-}" --arg langs "${NUSKU_ANSWERS[LANGS]:-}" '
        def words: split(" ") | map(select(. != ""));
        .apps = ($apps | words) | .langs = ($langs | words)' "$file")" || die "Could not update $file"
    printf '%s\n' "$json" >"$file"
}

# host_copy_hw NAME: this machine's hardware-configuration.nix (from nixos-generate-config) into
# hosts/NAME. A reinstall has new disk UUIDs, so it is copied again each time.
host_copy_hw() {
    local src="${NUSKU_HW_CONFIG:-/etc/nixos/hardware-configuration.nix}"
    [ -r "$src" ] || die "There is no $src. Create it with: sudo nixos-generate-config"
    mkdir -p "$NUSKU_ROOT/hosts/$1"
    cp "$src" "$NUSKU_ROOT/hosts/$1/hardware-configuration.nix"
}

# host_commit NAME: git add hosts/NAME (a flake only sees files git knows) and commit it as
# "host: NAME" when it changed; nothing else staged goes in. Without a git identity the commit is
# made as USER <USER@NAME>, for that commit only. Sets HOST_COMMITTED (read by install.sh) to 1 or 0.
HOST_COMMITTED=0
# shellcheck disable=SC2034
host_commit() {
    local name="$1" path="hosts/$1" user
    local -a who=()
    HOST_COMMITTED=0
    git -C "$NUSKU_ROOT" add -- "$path"
    if git -C "$NUSKU_ROOT" diff --cached --quiet -- "$path"; then
        log_info "hosts/$name is unchanged; nothing to commit"
        return 0
    fi
    if ! git -C "$NUSKU_ROOT" config user.name >/dev/null || ! git -C "$NUSKU_ROOT" config user.email >/dev/null; then
        user="${NUSKU_ANSWERS[USER]:-$(id -un)}"
        who=(-c "user.name=$user" -c "user.email=$user@$name")
        log_info "git has no user.name/user.email: committing as $user <$user@$name> (this commit only)"
    fi
    git -C "$NUSKU_ROOT" "${who[@]}" commit -q -m "host: $name" -- "$path"
    HOST_COMMITTED=1
    log_info "Committed hosts/$name (host: $name)"
}

# --- The app catalogue ------------------------------------------------------------------

catalogue_json() {
    nix eval --json "$NUSKU_ROOT#lib.catalogue"
}

# catalogue_load: NUSKU_CATALOGUE, once.
catalogue_load() {
    [ -z "${NUSKU_CATALOGUE:-}" ] || return 0
    NUSKU_CATALOGUE="$(catalogue_json)" || die "Could not read the app catalogue (nix eval $NUSKU_ROOT#lib.catalogue)"
}

_cat() {
    jq -r "$@" <<<"$NUSKU_CATALOGUE"
}

# cat_starred: the ★ apps (the usual picks), space-separated.
cat_starred() {
    _cat '[.apps[] | select(.star) | .id] | join(" ")'
}

# cat_any_flag FLAG IDS: status 0 when one of the space-separated app IDS has FLAG (browser, btrfs).
cat_any_flag() {
    jq -e --arg f "$1" --arg ids " $2 " \
        'any(.apps[] | select(.[$f] // false); . as $a | $ids | contains(" \($a.id) "))' \
        <<<"$NUSKU_CATALOGUE" >/dev/null
}

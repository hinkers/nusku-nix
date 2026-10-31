# shellcheck shell=bash
# Nusku - git helpers shared by install.sh (lib/sh/host.sh) and nusku-update. Needs only git.
# Sourced, not executed.
#
#   git_who REPO USER HOST    set GIT_WHO to the `git -c` options for one commit in REPO: none
#                             when git has user.name and user.email, else USER <USER@HOST>, for
#                             that commit only (nothing is written to git's config). Status 1
#                             when it fell back, so the caller can say so.

GIT_WHO=()
# shellcheck disable=SC2034  # GIT_WHO is read by the caller
git_who() {
    GIT_WHO=()
    if git -C "$1" config user.name >/dev/null && git -C "$1" config user.email >/dev/null; then
        return 0
    fi
    GIT_WHO=(-c "user.name=$2" -c "user.email=$2@$3")
    return 1
}

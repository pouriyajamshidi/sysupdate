#!/usr/bin/env bash

set -uo pipefail

LOG_FILE=${SYSUPDATE_LOG:-/var/log/sysupdate.txt}
JOURNAL_KEEP=${SYSUPDATE_JOURNAL_KEEP:-14d}
TARGET_USER=${SYSUPDATE_USER:-${SUDO_USER:-}}

if [[ -t 1 ]]; then
    green=$(tput setaf 2)
    yellow=$(tput setaf 3)
    nocolor=$(tput sgr0)
else
    green=""
    yellow=""
    nocolor=""
fi

failures=0

have() {
    command -v "$1" >/dev/null 2>&1
}

warn() {
    printf '\n%s[!] %s%s\n' "$yellow" "$1" "$nocolor"
}

rule() {
    printf '%s%s%s\n' "$green" "$(printf '=%.0s' {1..70})" "$nocolor"
}

step() {
    local label=$1
    shift

    printf '\n%s==> %s%s\n' "$green" "$label" "$nocolor"

    if ! "$@"; then
        failures=$((failures + 1))
        warn "$label failed"
    fi
}

usage() {
    cat <<'EOF'
Usage: sudo sysupdate

Updates the system packages, then removes the leftovers they keep behind.

Environment:
  SYSUPDATE_LOG           log file (default: /var/log/sysupdate.txt)
  SYSUPDATE_USER          user whose toolchains (rustup, choosenim, nimble, v,
                          pipx) are updated too (default: $SUDO_USER)
  SYSUPDATE_JOURNAL_KEEP  how much systemd journal to keep (default: 14d)
EOF
}

update_debian() {
    export DEBIAN_FRONTEND=noninteractive

    step "Refreshing package lists" apt-get update
    step "Upgrading packages" apt-get full-upgrade -y
    step "Removing unused packages" apt-get autoremove --purge -y
    step "Cleaning the package cache" apt-get autoclean -y

    local residual
    mapfile -t residual < <(dpkg-query -f '${Package}\t${db:Status-Abbrev}\n' -W |
        awk '$2 ~ /^rc/ {print $1}')

    if ((${#residual[@]})); then
        step "Purging leftover config of ${#residual[@]} package(s)" \
            apt-get purge -y "${residual[@]}"
    fi
}

update_rpm() {
    local manager=yum

    if have dnf; then
        manager=dnf
    fi

    step "Upgrading packages" "$manager" upgrade -y --refresh
    step "Removing unused packages" "$manager" autoremove -y
    step "Cleaning the package cache" "$manager" clean all
}

update_arch() {
    step "Upgrading packages" pacman -Syu --noconfirm

    local orphans
    mapfile -t orphans < <(pacman -Qtdq || true)

    if ((${#orphans[@]})); then
        step "Removing ${#orphans[@]} orphaned package(s)" \
            pacman -Rns --noconfirm "${orphans[@]}"
    fi

    if have paccache; then
        step "Cleaning the package cache" paccache -rk1
    else
        step "Cleaning the package cache" pacman -Sc --noconfirm
    fi
}

remove_disabled_snaps() {
    local name revision

    while read -r name revision; do
        step "Removing snap $name revision $revision" \
            snap remove "$name" --revision="$revision"
    done < <(snap list --all | awk '/disabled/ {print $1, $3}')
}

update_extras() {
    if have snap; then
        step "Refreshing snaps" snap refresh
        remove_disabled_snaps
    fi

    if have flatpak; then
        step "Updating flatpaks" flatpak update -y
        step "Removing unused flatpak runtimes" flatpak uninstall --unused -y
    fi

    if have journalctl; then
        step "Trimming the journal to $JOURNAL_KEEP" \
            journalctl --vacuum-time="$JOURNAL_KEEP"
    fi
}

update_user_tool() {
    local tool=$1 command=$2

    su - "$TARGET_USER" -c "command -v $tool" >/dev/null 2>&1 || return 0

    step "Updating $tool for $TARGET_USER" su - "$TARGET_USER" -c "$command"
}

update_user_tools() {
    if [[ -z $TARGET_USER ]] || ! id "$TARGET_USER" >/dev/null 2>&1; then
        return 0
    fi

    update_user_tool rustup "rustup update"
    update_user_tool choosenim "choosenim update stable && choosenim update self"
    update_user_tool nimble "nimble -y install nimble"
    update_user_tool v "v up"
    update_user_tool pipx "pipx upgrade-all"
}

reboot_required() {
    [[ -f /var/run/reboot-required ]] ||
        { have needs-restarting && ! needs-restarting -r >/dev/null 2>&1; }
}

run() {
    local started=$SECONDS

    rule
    echo "sysupdate - $(date '+%F %T')"
    rule

    if have apt-get; then
        update_debian
    elif have dnf || have yum; then
        update_rpm
    elif have pacman; then
        update_arch
    else
        warn "No supported package manager found"
        return 1
    fi

    update_extras
    update_user_tools

    if reboot_required; then
        warn "A reboot is required"
    fi

    if ((failures)); then
        warn "Finished in $((SECONDS - started))s with $failures failed step(s)"
    else
        printf '\n%s==> Finished in %ss%s\n' "$green" "$((SECONDS - started))" "$nocolor"
    fi

    rule
    return $((failures > 0))
}

main() {
    if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
        usage
        exit 0
    fi

    if ((EUID != 0)); then
        echo "sysupdate must be run as root" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$LOG_FILE")"

    run 2>&1 | tee >(sed -u 's/\x1b\[[0-9;]*m//g' >>"$LOG_FILE")
    exit "${PIPESTATUS[0]}"
}

main "$@"

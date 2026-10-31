#!/usr/bin/env bash

set -uo pipefail

# The date of the last change, bump it with every change
VERSION=2026.10.31

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
user_bin=""
clean_docker=0
clean_docker_volumes=0

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
Usage: sudo sysupdate [options]

Updates the system packages, then removes the leftovers they keep behind.

Options:
  -u, --user USER   also update USER's own toolchains: rustup, choosenim,
                    nimble and v (default: $SUDO_USER)
  -n, --no-user     system packages only
  -d, --docker      prune stopped containers, dangling images, unused
                    networks and the build cache
      --docker-volumes
                    the above, plus unused anonymous volumes
  -v, --version     show the version
  -h, --help        show this help

Environment:
  SYSUPDATE_LOG           log file (default: /var/log/sysupdate.txt)
  SYSUPDATE_USER          same as --user
  SYSUPDATE_JOURNAL_KEEP  how much systemd journal to keep (default: 14d)
EOF
}

update_debian() {
    export DEBIAN_FRONTEND=noninteractive

    step "Refreshing package lists" apt-get update
    # Keep our own version of a changed config file instead of asking,
    # the new one is saved next to it as .dpkg-dist
    step "Upgrading packages" apt-get full-upgrade -y \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold
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

user_run() {
    su - "$TARGET_USER" -c "export PATH=\"$user_bin:\$PATH\"; $1"
}

update_user_tool() {
    local tool=$1 command=$2

    user_run "command -v $tool" >/dev/null 2>&1 || return 0

    step "$TARGET_USER: $command" user_run "$command"
}

update_user_tools() {
    if [[ -z $TARGET_USER ]]; then
        return 0
    fi

    local home
    home=$(getent passwd "$TARGET_USER" | cut -d: -f6)

    if [[ -z $home ]]; then
        warn "no such user: $TARGET_USER"
        failures=$((failures + 1))
        return 0
    fi

    user_bin="$home/.nimble/bin:$home/.cargo/bin:$home/.local/bin"

    update_user_tool rustup "rustup update"
    update_user_tool choosenim "choosenim update devel"
    update_user_tool choosenim "choosenim update stable"
    update_user_tool choosenim "choosenim update self"
    update_user_tool nimble "nimble -y install nimble"
    update_user_tool v "v up"
}

prune_docker() {
    if ! have docker; then
        warn "docker is not installed"
        failures=$((failures + 1))
        return 0
    fi

    if ! docker info >/dev/null 2>&1; then
        warn "docker is not running"
        failures=$((failures + 1))
        return 0
    fi

    step "Removing stopped containers" docker container prune -f
    step "Removing dangling images" docker image prune -f
    step "Removing unused networks" docker network prune -f
    step "Trimming the build cache" docker builder prune -f

    if ((clean_docker_volumes)); then
        step "Removing unused anonymous volumes" docker volume prune -f
    fi
}

# Kernel modules like the NVIDIA driver are built by DKMS for each kernel.
# If one did not build for the newest kernel, booting it can leave you
# without that driver, so say so before the reboot rather than after.
# shellcheck disable=SC2329 # called through step
check_dkms() {
    local kernels=(/lib/modules/*) kernel status module missing=()

    kernel=$(printf '%s\n' "${kernels[@]##*/}" | sort -V | tail -n 1)
    status=$(dkms status)

    # Lines look like "nvidia/580.95, 6.8.0-45-generic, x86_64: installed"
    # (older dkms: "nvidia, 580.95, ...")
    while read -r module; do
        if ! grep -F ", $kernel," <<<"$status" | grep -E "^${module}[/,]" | grep -q ': installed'; then
            missing+=("$module")
        fi
    done < <(awk -F'[/,]' 'NF {print $1}' <<<"$status" | sort -u)

    if ((${#missing[@]})); then
        echo "Not built for kernel $kernel: ${missing[*]}"
        echo "Do not reboot until this is fixed, see: dkms status"
        return 1
    fi

    echo "All DKMS modules are built for kernel $kernel"
}

reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        return 0
    fi

    if have needs-restarting; then
        ! needs-restarting -r >/dev/null 2>&1
    elif have dnf5 && dnf5 needs-restarting --help >/dev/null 2>&1; then
        ! dnf5 needs-restarting -r >/dev/null 2>&1
    else
        return 1
    fi
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

    if ((clean_docker)); then
        prune_docker
    fi

    if have dkms; then
        step "Checking DKMS modules" check_dkms
    fi

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
    while (($#)); do
        case $1 in
        -u | --user)
            if [[ -z ${2:-} ]]; then
                echo "$1 needs a user name" >&2
                exit 1
            fi
            TARGET_USER=$2
            shift 2
            ;;
        -n | --no-user)
            TARGET_USER=""
            shift
            ;;
        -d | --docker)
            clean_docker=1
            shift
            ;;
        --docker-volumes)
            clean_docker=1
            clean_docker_volumes=1
            shift
            ;;
        -v | --version)
            echo "sysupdate $VERSION"
            exit 0
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        esac
    done

    if ((EUID != 0)); then
        echo "sysupdate must be run as root" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$LOG_FILE")"

    run 2>&1 | tee >(sed -u 's/\x1b\[[0-9;]*m//g; s/\x1b(B//g' >>"$LOG_FILE")
    exit "${PIPESTATUS[0]}"
}

main "$@"

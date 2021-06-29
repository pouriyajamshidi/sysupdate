#!/bin/bash

green=$(tput setaf 2)
nocolor=$(tput sgr0)

function is_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[-] You must run this script as root."
        exit 1
    fi
}

function print_chars() {
    i=0
    echo "${green}"
    while [[ $i -le 100 ]]; do
        echo -n "$1"
        ((i++))
    done
    echo "${nocolor}"
}

function check_dpkg_deinstall() {
    dpkg --get-selections | grep deinstall | awk '{print $1}'
}

function check_distro() {
    grep "^ID=" /etc/os-release | cut -d "=" -f 2
}

function update_RPM() {
    {
        print_chars "*"
        date
        print_chars "-"

        echo "${green}✅ Updating Repositories${nocolor}"
        yum update -y
        print_chars "-"

        until [[ $ANSWER =~ (y|n) ]]; do
            read -rp "Do you want to remove old packages? [y/n]: " -e ANSWER
        done

        if [[ $ANSWER == "n" ]]; then
            echo "Exiting..."
            exit 1
        fi
        echo "${green}✅ Going for system upgrade${nocolor}"
        yum upgrade -y
        print_chars "-"
        print_chars "*"
    } |& tee -a /var/log/sysupdate.txt
}

function update_Arch() {
    {
        print_chars "*"
        date
        print_chars "-"

        echo "${green}✅ Updating Repositories${nocolor}"
        pacman --sync --refresh
        print_chars "-"

        echo "${green}✅ Going for system upgrade${nocolor}"
        pacman --sync --sysupgrade --noconfirm
        print_chars "-"
        print_chars "*"
    } |& tee -a /var/log/sysupdate.txt
}

function update_Debian() {
    {
        print_chars "*"
        date
        print_chars "-"

        echo "${green}✅ Checking for updates${nocolor}"
        apt update
        print_chars "-"

        echo -e "${green}\n✅ Going for system upgrade${nocolor}"
        apt upgrade -y
        print_chars "-"

        echo -e "${green}\n✅ Going for system full upgrade${nocolor}"
        apt full-upgrade -y
        print_chars "-"

        echo -e "${green}\n✅ Going for system distro upgrade${nocolor}"
        apt dist-upgrade -y
        print_chars "-"

        if dpkg -s snap >/dev/null 2>&1; then
            echo "${green}✅ Going for Snap refresh${nocolor}"
            snap refresh
            print_chars "-"
        fi

        if dpkg -s flatpak >/dev/null 2>&1; then
            echo "${green}✅ Going for flatpak update${nocolor}"
            flatpak update -y
            print_chars "-"
        fi

        echo -e "${green}\n✅ Going for auto clean${nocolor}"
        apt autoclean -y
        print_chars "-"

        echo -e "${green}\n✅ Going for auto remove${nocolor}"
        apt autoremove -y
        print_chars "-"

        echo -e "${green}\n✅ Going for purge${nocolor}"
        apt purge -y
        print_chars "-"

        deleted_packages=$(check_dpkg_deinstall)

        if [[ -n $deleted_packages ]]; then

            echo "${green}✅ Going for DPKG cleanup${nocolor}"

            while read -r line; do
                apt-get remove --purge -y $line
            done <<<"$deleted_packages"
            print_chars "-"
        fi

        print_chars "*"
    } |& tee -a /var/log/sysupdate.txt
}

function main() {
    is_root
    distro=$(check_distro)

    if [[ "$distro" == "debian" || "$distro" == "ubuntu" || "$distro" == "raspbian" ]]; then
        update_Debian
    elif [[ "$distro" == "fedora" || "$distro" == "centos" || "$distro" == "ol" || "$distro" == "rhel" ]]; then
        update_RPM
    elif [[ "Arch" == *"$distro"* ]]; then
        update_Arch
    else
        echo "[❌] Operating system is not supported"
    fi
}

main

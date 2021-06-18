#!/bin/bash

green=$(tput setaf 2)
nocolor=$(tput sgr0)

function print_chars() {
    i=0
    echo "${green}"
    while [[ $i -le 100 ]]; do
        echo -n "$1"
        ((i++))
    done
    echo
    echo "${nocolor}"
}

{
    print_chars "*"
    date
    print_chars "-"

    echo "${green}[+] Checking for updates${nocolor}"
    apt update
    print_chars "-"

    echo -e "${green}\n[+] Going for system upgrade${nocolor}"
    apt upgrade -y
    print_chars "-"

    echo -e "${green}\n[+] Going for system full upgrade${nocolor}"
    apt full-upgrade -y
    print_chars "-"

    echo -e "${green}\n[+] Going for system distro upgrade${nocolor}"
    apt dist-upgrade -y
    print_chars "-"

    if dpkg -s snap >/dev/null 2>&1; then
        echo "${green}[+] Going for Snap refresh${nocolor}"
        snap refresh
        print_chars "-"
        echo -e "\n"
    fi

    if dpkg -s flatpak >/dev/null 2>&1; then
        echo "${green}[+] Going for flatpak update${nocolor}"
        flatpak update
        print_chars "-"
        echo -e "\n"
    fi

    echo -e "${green}\n[+] Going for auto clean${nocolor}"
    apt autoclean -y
    print_chars "-"

    echo -e "${green}\n[+] Going for auto remove${nocolor}"
    apt autoremove -y
    print_chars "-"

    echo -e "${green}\n[+] Going for purge${nocolor}"
    apt purge -y
    print_chars "-"

    echo -e "\n"

    echo "${green}[+] Going for DPKG cleanup${nocolor}"
    dpkg --get-selections | grep deinstall | awk '{print $1}' |
        while read line; do
            apt-get remove --purge -y $line
        done
    print_chars "-"
    print_chars "*"
} |& tee -a /var/log/sysupdate.txt

#!/bin/bash

green=$(tput setaf 2)
nocolor=$(tput sgr0)

{
    echo "${green}***************************************************************${nocolor}"
    date
    echo -e "\n"

    echo "${green}[+] Checking for updates${nocolor}"
    apt update

    echo -e "${green}\n[+] Going for system upgrade${nocolor}"
    apt upgrade -y

    echo -e "${green}\n[+] Going for system full upgrade${nocolor}"
    apt full-upgrade -y

    echo -e "${green}\n[+] Going for system distro upgrade${nocolor}"
    apt dist-upgrade -y

    if dpkg -s snap >/dev/null 2>&1; then
        echo "${green}[+] Going for Snap refresh${nocolor}"
        snap refresh
        echo -e "\n"
    fi

    if dpkg -s flatpak >/dev/null 2>&1; then
        echo "${green}[+] Going for flatpak update${nocolor}"
        flatpak update
        echo -e "\n"
    fi

    echo -e "${green}\n[+] Going for auto clean${nocolor}"
    apt autoclean -y

    echo -e "${green}\n[+] Going for auto remove${nocolor}"
    apt autoremove -y

    echo -e "${green}\n[+] Going for purge${nocolor}"
    apt purge -y

    echo -e "\n"

    echo "${green}[+] Going for DPKG cleanup${nocolor}"
    dpkg --get-selections | grep deinstall | awk '{print $1}' |
        while read line; do
            apt-get remove --purge -y $line
        done
    echo -e "${green}\n***************************************************************${nocolor}"
    echo -e "\n"
} |& tee -a /var/log/sysupdate.txt

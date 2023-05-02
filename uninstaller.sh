#!/bin/bash

set -e

## Color
if command -v tput > /dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

## Check root
if [[ $EUID -ne 0 ]]; then
    echo "${RED}error: This script must be run as root!${RESET}"
    exit 1
fi

stop_dae(){
    if [ "$(systemctl is-active dae)" == "active" ]; then
        echo "${GREEN}Stopping dae...${RESET}"
        systemctl stop dae
        echo "${GREEN}Stopped dae${RESET}"
    fi
    if [ -f /etc/init.d/dae ] && [ -f /run/dae.pid ] && [ -n "$(cat /run/dae.pid)" ]; then
        echo "${GREEN}Stopping dae...${RESET}"
        /etc/init.d/dae stop
        echo "${GREEN}Stopped dae${RESET}"
    fi
}

remove_dae(){
    if [ -f /usr/local/bin/dae ]; then
        echo "${GREEN}Removing dae...${RESET}"
        rm -f /usr/local/bin/dae
        echo "${GREEN}Removed dae.${RESET}"
    fi
    if [ -d /usr/local/share/dae ]; then
        echo "${GREEN}Removing dae GeoIP database and GeoSite database...${RESET}"
        rm -rf /usr/local/share/dae
        echo "${GREEN}Removed dae GeoIP database and GeoSite database.${RESET}"
    fi
    if [ -f /usr/local/etc/dae/example.dae ]; then
        echo "${GREEN}Removing example.dae...${RESET}"
        rm -f /usr/local/etc/dae/example.dae
        echo "${GREEN}Removed example.dae.${RESET}"
    fi
}

remove_dae_service(){
    if [ -f /etc/systemd/system/dae.service ]; then
        rm -f /etc/systemd/system/dae.service
        systemctl daemon-reload
    fi
    if [ -f /etc/init.d/dae ]; then
        rm -f /etc/init.d/dae
    fi
}

# Main
if ! stop_dae; then
    echo "${YELLOW}Stop dae failed, you might stop dae and try again.${RESET}"
    exit 1
fi
remove_dae
remove_dae_service
echo "${GREEN}Uninstall dae successfully!${RESET}"
if [ -d /usr/local/etc/dae ]; then
    echo "${GREEN}However, your config file is in this path:${RESET}"
    echo "/usr/local/etc/dae/"
    echo "${GREEN}You can remove this folder manually if you want.${RESET}"
fi

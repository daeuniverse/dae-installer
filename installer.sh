#!/usr/bin/env bash

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

## Check curl, unzip, virt-what
for tool_need in curl unzip virt-what; do
    if ! command -v $tool_need > /dev/null 2>&1; then
        if command -v apt > /dev/null 2>&1; then
            if ! apt install $tool_need -y; then
            echo "${RED}""Run apt to install $tool_need failed, please try again!""${RESET}"
            exit 1
            fi
        echo $tool_need >> /tmp/tool_installed.txt
        elif command -v dnf > /dev/null 2>&1; then
            if ! dnf install $tool_need -y; then
            echo "${RED}""Run dnf to install $tool_need failed, please try again!""${RESET}"
            exit 1
            fi            
        echo $tool_need >> /tmp/tool_installed.txt
        elif command -v yum > /dev/null  2>&1; then
            if ! yum install $tool_need -y; then
            echo "${RED}""Run yum to install $tool_need failed, please try again!""${RESET}"
            exit 1
            fi
        echo $tool_need >> /tmp/tool_installed.txt
        elif command -v zypper > /dev/null 2>&1; then
            if ! zypper --non-interactive install $tool_need; then
            echo "${RED}""Run zypper to install $tool_need failed, please try again!""${RESET}"
            exit 1
            fi            
        echo $tool_need >> /tmp/tool_installed.txt
        elif command -v pacman > /dev/null 2>&1; then
            if ! pacman -Sy $tool_need --noconfirm; then
            echo "${RED}""Run pacman to install $tool_need failed, please try again!""${RESET}"
            exit 1
            fi
        echo $tool_need >> /tmp/tool_installed.txt
        elif command -v apk > /dev/null 2>&1; then
            if ! apk add $tool_need; then
            echo "${RED}""Run apk to install $tool_need failed, please try again!""${RESET}"
            exit 1
            fi
        echo $tool_need >> /tmp/tool_installed.txt
        else
        echo "$tool_need not installed and cannot be installed automatically, stop installation, please install $tool_need and try again!"
        we_should_exit=1
        fi
    fi
done

check_virtualization() {
    if [ -n "$(uname -r | grep microsoft)" ]; then
        echo "${RED}error: WSL is not supported!${RESET}"
        exit 1
    fi
    if [[ $(virt-what) == 'openvz' ]]; then
        echo "${RED}error: OpenVZ is not supported!${RESET}"
        exit 1
    fi
    if [[ "$(virt-what)" == '' ]]; then
        is_virt=no
    else
        is_virt=yes
    fi
}

install_systemd_service() {
    echo "${GREEN}Installing/updating systemd service...${RESET}"
    echo '[Unit]
Description=dae Service
Documentation=https://github.com/daeuniverse/dae
After=network-online.target docker.service systemd-sysctl.service

[Service]
Type=notify
User=root
LimitNPROC=512
LimitNOFILE=1048576
ExecStartPre=/usr/local/bin/dae validate -c /usr/local/etc/dae/config.dae
ExecStart=/usr/local/bin/dae run --disable-timestamp -c /usr/local/etc/dae/config.dae
ExecReload=/usr/local/bin/dae reload $MAINPID
Restart=on-abnormal

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/dae.service
    systemctl daemon-reload
    echo "${GREEN}Systemd service installed/updated,${RESET}"
    echo "${GREEN}you can start dae by running:${RESET}"
    echo "systemctl start dae"
    echo "${GREEN}if you want to start dae at system boot:${RESET}"
    echo "systemctl enable dae"
}

install_openrc_service(){
    echo "${GREEN}Installing/updating OpenRC service...${RESET}"
    echo '#!/sbin/openrc-run
description="dae Service"
command="/usr/local/bin/dae"
command_args="run -c /usr/local/etc/dae/config.dae"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"
output_log="/var/log/dae/access.log"
error_log="/var/log/dae/error.log"
rc_ulimit="-n 30000"
rc_cgroup_cleanup="yes"

depend() {
    after docker net net-online sysctl
    use net
}

start_pre() {
   if [ ! -d "/tmp/dae/" ]; then 
     mkdir "/tmp/dae" 
   fi
   if [ ! -d "/var/log/dae/" ]; then
   ln -s "/tmp/dae/" "/var/log/"
   fi
   if ! /usr/local/bin/dae validate -c /usr/local/etc/dae/config.dae; then
      eerror "dae config file /usr/local/etc/dae/config.dae is invalid or too open, exiting..."
      return 1
   fi
}

reload() {
	ebegin "Reloading $RC_SVCNAME"
	/usr/local/bin/dae reload $(cat "/run/${RC_SVCNAME}.pid")
	eend $?
}' > /etc/init.d/dae
    chmod +x /etc/init.d/dae
    echo "${GREEN}OpenRC service installed/updated,${RESET}"
    echo "${GREEN}you can start dae by running:${RESET}"
    echo "rc-service dae start"
    echo "${GREEN}if you want to start dae at system boot:${RESET}"
    echo "rc-update add dae default"
}

check_version(){
    if ! command -v /usr/local/bin/dae > /dev/null 2>&1; then
    current_version=0
    else
    current_version=$(/usr/local/bin/dae --version | awk '{print $3}')
    fi
    temp_file=$(mktemp /tmp/dae_version.XXXXX)
    trap "rm -f '$temp_file'" exit
    if ! curl -s -I 'https://github.com/daeuniverse/dae/releases/latest' -o "$temp_file"; then
        echo "${RED}error: Failed to get the latest version of dae!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        we_should_exit=1
    else
    	# cat $temp_file
        latest_version=$(grep -i ^location: "$temp_file"|rev|cut -d/ -f1|rev)
	    latest_version=${latest_version%$'\r'} # Trim suffix \r
    fi
}

check_arch() {
if [[ $(uname) == 'Linux' ]]; then
case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='x86_32'
        ;;
      'amd64' | 'x86_64')
        # MACHINE='x86_64'
        AMD64='yes'
        ;;
      'armv5tel')
        MACHINE='armv5'
        ;;
      'armv6l')
        MACHINE='armv6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='armv7'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      *)
        echo "${RED}error: The architecture is not supported.${RESET}"
        exit 1
        ;;
    esac
    if [[ "$AMD64" == 'yes' ]] && [[ "$is_virt" == 'yes' ]]; then
        MACHINE='x86_64'
    elif [[ "$AMD64" == 'yes' ]]; then
        if [ -n "$(cat /proc/cpuinfo | grep avx2)" ]; then
            MACHINE='x86_64_v3_avx2'
        elif [ -n "$(cat /proc/cpuinfo | grep sse)" ]; then
            MACHINE='x86_64_v2_sse'
        else
            MACHINE='x86_64'
        fi
    fi
else
    echo "${RED}error: The operating system is not supported.${RESET}"
    exit 1
fi
}

check_share_dir() {
    if [ ! -d /usr/local/share/dae ]; then
        mkdir -p /usr/local/share/dae
    fi
}

download_geoip() {
    geoip_url="https://github.com/v2rayA/dist-v2ray-rules-dat/raw/master/geoip.dat"
    echo "${GREEN}Downloading GeoIP database...${RESET}"
    echo "${GREEN}Downloading from: $geoip_url${RESET}"
    if ! curl -LO $geoip_url --progress-bar; then
        echo "${RED}error: Failed to download GeoIP database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
    if ! curl -sLO $geoip_url.sha256sum; then
        echo "${RED}error: Failed to download the checksum file of GeoIP database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f geoip.dat
        exit 1
    fi
    geoip_local_sha256=$(sha256sum geoip.dat)
    geoip_remote_sha256=$(cat geoip.dat.sha256sum)
    if [ "$geoip_local_sha256" != "$geoip_remote_sha256" ]; then
        echo "${RED}error: The checksum of the downloaded GeoIP database does not match!${RESET}"
        echo "${RED}Local SHA256: $geoip_local_sha256${RESET}"
        echo "${RED}Remote SHA256: $geoip_remote_sha256${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f geoip.dat
        exit 1
    fi
}
update_geoip() {
    check_share_dir
    mv geoip.dat /usr/local/share/dae/
    rm -f geoip.dat.sha256sum
    echo "${GREEN}GeoIP database have been updated.${RESET}"
}

download_geosite() {
    geosite_url="https://github.com/v2rayA/dist-v2ray-rules-dat/raw/master/geosite.dat"
    echo "${GREEN}Downloading GeoSite database...${RESET}"
    echo "${GREEN}Downloading from: $geosite_url${RESET}"
    if ! curl -LO $geosite_url --progress-bar; then
        echo "${RED}error: Failed to download GeoSite database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
    if ! curl -sLO $geosite_url.sha256sum; then
        echo "${RED}error: Failed to download the checksum file of GeoSite database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f geosite.dat
        exit 1
    fi
    geosite_local_sha256=$(sha256sum geosite.dat)
    geosite_remote_sha256=$(cat geosite.dat.sha256sum)
    if [ "$geoip_local_sha256" != "$geoip_remote_sha256" ]; then
        echo "${RED}error: The checksum of the downloaded GeoIP database does not match!${RESET}"
        echo "${RED}Local SHA256: $geosite_local_sha256${RESET}"
        echo "${RED}Remote SHA256: $geosite_remote_sha256${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f geosite.dat geosite.dat.sha256sum
        exit 1
    fi
}

update_geosite() {
    check_share_dir
    mv geosite.dat /usr/local/share/dae/
    rm -f geosite.dat.sha256sum
    echo "${GREEN}GeoSite database have been updated.${RESET}"
}

stop_dae(){
    if [ "$(systemctl is-active dae)" == "active" ]; then
        echo "${GREEN}Stopping dae...${RESET}"
        systemctl stop dae
        dae_stopped=1
        echo "${GREEN}Stopped dae${RESET}"
    fi
    if [ -f /etc/init.d/dae ] && [ -f /run/dae.pid ] && [ -n "$(cat /run/dae.pid)" ]; then
        echo "${GREEN}Stopping dae...${RESET}"
        /etc/init.d/dae stop
        dae_stopped="1"
        echo "${GREEN}Stopped dae${RESET}"
    fi
}

start_dae(){
    if [ -f /etc/systemd/system/dae.service ] && [ "$dae_stopped" == "1" ]; then
        echo "${GREEN}Starting dae...${RESET}"
        systemctl start dae
        echo "${GREEN}Started dae${RESET}"
    fi
    if [ -f /etc/init.d/dae ] && [ "$dae_stopped" == "1" ]; then
        echo "${GREEN}Starting dae...${RESET}"
        /etc/init.d/dae start
        echo "${GREEN}Started dae${RESET}"
    fi
}

download_dae() {
    download_url=https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip
    echo "${GREEN}Downloading dae...${RESET}"
    echo "${GREEN}Downloading from: $download_url${RESET}"
    if ! curl -LO "$download_url" --progress-bar; then
        echo "${RED}error: Failed to download dae!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
    local_sha256=$(sha256sum dae-linux-"$MACHINE".zip | awk -F ' ' '{print $1}')
    if [ -z "$local_sha256" ]; then
        echo "${RED}error: Failed to get the checksum of the downloaded file!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f dae-linux-"$MACHINE".zip
        exit 1
    fi
    if ! curl -sL "$download_url".dgst -o dae-linux-"$MACHINE".zip.dgst; then
        echo "${RED}error: Failed to download the checksum file!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f dae-linux-"$MACHINE".zip.dgst
        exit 1
    fi
    remote_sha256=$(cat ./dae-linux-"$MACHINE".zip.dgst | awk -F "./dae-linux-$MACHINE.zip" 'NR==3' | awk '{print $1}')
    if [ "$local_sha256" != "$remote_sha256" ]; then
        echo "${RED}error: The checksum of the downloaded file does not match!${RESET}"
        echo "${RED}Local SHA256: $local_sha256${RESET}"
        echo "${RED}Remote SHA256: $remote_sha256${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f dae-linux-"$MACHINE".zip
        exit 1
    fi
}

install_dae() {
    unzip dae-linux-"$MACHINE".zip -d ./dae/
    cp ./dae/dae-linux-"$MACHINE" /usr/local/bin/dae
    chmod +x /usr/local/bin/dae
    rm -f dae-linux-"$MACHINE".zip
    rm -rf dae
}

download_example_config() {
    if [ ! -d /usr/local/etc/dae ]; then
        mkdir -p /usr/local/etc/dae
    fi
    if ! curl -sL "https://github.com/daeuniverse/dae/raw/$latest_version/example.dae" -o /usr/local/etc/dae/example.dae; then
        echo "${YELLOW}warning: Failed to download example config file.${RESET}"
        echo "${YELLOW}You can download it from https://raw.githubusercontent.com/daeuniverse/dae/main/example.dae${RESET}"
    else
        echo "${GREEN}Example config file downloaded to /usr/local/etc/dae/example.dae, you can edit it and save it to /usr/local/etc/dae/config.dae${RESET}"
    fi
}

installation() {
    check_virtualization
    check_version
    if [ "$we_should_exit" == "1" ]; then
        exit 1
    fi
    if [ "$current_version" == "$latest_version" ]; then
        echo "${GREEN}dae is already installed, current version: $current_version${RESET}"
        exit 0
    elif [ "$current_version" == '0' ]; then
        echo "${GREEN}Installing dae version $latest_version... ${RESET}"
    else
        echo "${GREEN}Upgrading dae version $current_version to version $latest_version... ${RESET}"
    fi
    check_arch
    download_dae
    download_geoip
    download_geosite
    stop_dae
    install_dae
    update_geoip
    update_geosite
    if [ -f /usr/lib/systemd/systemd ]; then
        install_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        install_openrc_service
    else
        echo "${YELLOW}warning: There is no Systemd or OpenRC on this system, no service would be installed.${RESET}"
        echo "${YELLOW}You should write service file/script by yourself.${RESET}"
    fi
    start_dae
    echo "${GREEN}dae installed, installed version: $latest_version${RESET}"
    echo "${GREEN}Your config file should be:${RESET} /usr/local/etc/dae/config.dae"
    if [ ! -f /usr/local/etc/dae/config.dae ]; then
        download_example_config
    fi
    if [ -f tool_installed.txt ] && [ -n "$(cat /tmp/tool_installed.txt)" ]; then
        echo "${GREEN}You have installed the following tools during installation:${RESET}"
        cat /tmp/tool_installed.txt
        rm -f /tmp/tool_installed.txt
        echo "${GREEN}You can uninstall them now if you want.${RESET}"
    fi
}
# Main
if ! [ "$1" == "update-geoip" ] && ! [ "$1" == "update-geosite" ] && ! [ "$1" == "install" ] && ! [ "$1" == "" ]; then
    echo "${YELLOW}error: Invalid argument, usage:${RESET}"
    echo "${YELLOW}Run 'install.sh install' to install dae,${RESET}"
    echo "${YELLOW}Run 'install.sh update-geoip' to update GeoIP database,${RESET}"
    echo "${YELLOW}Run 'install.sh update-geosite' to update GeoSite database.${RESET}"
    exit 1
fi
current_dir=$(pwd)
cd /tmp/
if [ "$1" == "" ]; then
    installation
fi
while [ $# != 0 ] ; do
    if [ "$1" == "update-geoip" ]; then
        download_geoip
        update_geoip
    elif [ "$1" == "update-geosite" ]; then
        download_geosite
        update_geosite
    elif [ "$1" == "install" ]; then
        installation
    fi
    shift
done
cd "$current_dir"
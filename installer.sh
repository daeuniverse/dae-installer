#!/usr/bin/env sh

# shellcheck disable=SC3000-SC4000

set -e

## Color
if command -v tput > /dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

## Check System
if [ "$(uname)" != 'Linux' ]; then
    echo "${RED}error: This script only support Linux!${RESET}"
    exit 1
fi

## Check root
user_id="$(id -u "$(whoami)")"
if [ "$user_id" -ne 0 ]; then
    echo "${RED}error: This script must be run as root!${RESET}"
    exit 1
fi

## SHA256SUM
if command -v sha256sum >/dev/null 2>&1; then
    SHA256SUM() {
        sha256sum "$1" | awk -F ' ' '{print$1}'
    }
elif command -v shasum >/dev/null 2>&1; then
    SHA256SUM() {
        shasum -a 256 "$1" | awk -F ' ' '{print$1}'
    }
elif command -v openssl >/dev/null 2>&1; then
    SHA256SUM() {
        openssl dgst -sha256 "$1" | awk -F ' ' '{print$2}'
    }
elif command -v busybox >/dev/null 2>&1; then
    SHA256SUM() {
        busybox sha256sum "$1" | awk -F ' ' '{print$1}'
    }
fi

## Check curl, unzip, virt-what
for tool in curl unzip virt-what; do
    if ! command -v $tool> /dev/null 2>&1; then
        tool_need="$tool"" ""$tool_need"
    fi
done
if [ -n "$tool_need" ]; then
    if command -v apt > /dev/null 2>&1; then
        command_install_tool="apt update; apt install $tool_need -y"
    elif command -v dnf > /dev/null 2>&1; then
        command_install_tool="dnf install $tool_need -y"
    elif command -v yum > /dev/null  2>&1; then
        command_install_tool="yum install $tool_need -y"
    elif command -v zypper > /dev/null 2>&1; then
        command_install_tool="zypper --non-interactive install $tool_need"
    elif command -v pacman > /dev/null 2>&1; then
        command_install_tool="pacman -Sy $tool_need --noconfirm"
    elif command -v apk > /dev/null 2>&1; then
        command_install_tool="apk add $tool_need"
    else
        echo "$RED""You should install ""$tool_need""then try again.""$RESET"
        exit 1
    fi
    if ! /bin/sh -c "$command_install_tool";then
        echo "$RED""Use system package manager to install $tool_need failed,""$RESET"
        echo "$RED""You should install ""$tool_need""then try again.""$RESET"
        exit 1
    fi
fi

get_download_urls(){
    if [ "$use_cdn" = 'yes' ]; then
        systemd_service_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/install/dae.service"
        openrc_service_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae-installer/OpenRC/dae"
        dae_url="https://github.abskoop.workers.dev/https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip"
        dae_hash_url="https://github.abskoop.workers.dev/https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip.dgst"
        example_config_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/example.dae"
        geoip_url="https://cdn.jsdelivr.net/gh/v2rayA/dist-v2ray-rules-dat/geoip.dat"
        geosite_url="https://cdn.jsdelivr.net/gh/v2rayA/dist-v2ray-rules-dat/geosite.dat"
    else
        systemd_service_url="https://github.com/daeuniverse/dae/raw/$latest_version/install/dae.service"
        openrc_service_url="https://github.com/daeuniverse/dae-installer/raw/main/OpenRC/dae"
        dae_url="https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip"
        dae_hash_url="https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip.dgst"
        example_config_url="https://github.com/daeuniverse/dae/raw/$latest_version/example.dae"
        geoip_url="https://github.com/v2rayA/dist-v2ray-rules-dat/raw/master/geoip.dat"
        geosite_url="https://github.com/v2rayA/dist-v2ray-rules-dat/raw/master/geosite.dat"
    fi
}

notice_installled_tool() {
    if [ -n "$tool_need" ]; then
        echo "${GREEN}You have installed the following tools during installation:${RESET}"
        echo "$tool_need"
        echo "${GREEN}You can uninstall them now if you want.${RESET}"
    fi
}

check_virtualization() {
    if [ -n "$(uname -r | grep microsoft)" ]; then
        echo "${RED}error: WSL is not supported!${RESET}"
        exit 1
    fi
    if [ "$(virt-what)" = 'openvz' ]; then
        echo "${RED}error: OpenVZ is not supported!${RESET}"
        exit 1
    fi
    if [ -n "$(virt-what)" ]; then
        is_virt=yes
    fi
}

download_systemd_service(){
    echo "${GREEN}Download systemd service...${RESET}"
    if ! curl -LO -# "$systemd_service_url"; then
        echo "${RED}error: Failed to download Systemd Service!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
}

install_systemd_service() {
    echo "${GREEN}Installing/updating systemd service...${RESET}"
    cat dae.service | sed 's|usr/bin|usr/local/bin|g' | sed 's|etc|usr/local/etc|g' | tee /etc/systemd/system/dae.service
    systemctl daemon-reload
    echo "${GREEN}Systemd service installed/updated.${RESET}"
    rm dae.service
}

download_openrc_service(){
    echo "${GREEN}Download OpenRC service...${RESET}"
    if ! curl -L -# $openrc_service_url -o dae-openrc.sh; then
        echo "${RED}error: Failed to download OpenRC Service!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
}

install_openrc_service(){
    echo "${GREEN}Installing/updating OpenRC service...${RESET}"
    cat dae-openrc.sh | tee /etc/init.d/dae
    chmod +x /etc/init.d/dae
    echo "${GREEN}OpenRC service installed/updated${RESET}"
    rm dae-openrc.sh
}

download_service(){
    if [ -f /usr/lib/systemd/systemd ]; then
        download_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        download_openrc_service
    fi
}

install_service(){
    if [ -f /usr/lib/systemd/systemd ]; then
        install_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        install_openrc_service
    else
        echo "${YELLOW}warning: There is no Systemd or OpenRC on this system, no service would be installed.${RESET}"
        echo "${YELLOW}You should write service file/script by yourself.${RESET}"
    fi
}

check_local_version(){
    if ! command -v /usr/local/bin/dae > /dev/null 2>&1; then
        current_version=0
    else
        current_version=$(/usr/local/bin/dae --version | awk 'NR==1' | awk '{print $3}')
    fi
}

check_online_version(){
    temp_file="$(mktemp /tmp/dae.XXXXXX)"
    if ! curl -s 'https://api.github.com/repos/daeuniverse/dae/releases/latest' -o "$temp_file"; then
        echo "${RED}error: Failed to get the latest version of dae!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    elif ! grep '"tag_name":' "$temp_file" > /dev/null; then
        echo "${RED}error: The GitHub API did not return valid information, please try again later.${RESET}"
        rm "$temp_file"
        exit 1
    else
        latest_version="$(awk -F "tag_name" '{printf $2}' < "$temp_file" | awk -F "," '{printf $1}' | awk -F '"' '{printf $3}')"
        rm "$temp_file"
    fi
}

compare_version(){
    if [[ $latest_version = "$current_version" ]]; then
        # Don't need update
        compare_status=0
    elif [[ "$(printf '%s\n' "$current_version" "$latest_version" | sort -rV | head -n1)" = "$current_version" ]]; then
        # Local version is greater than remote version
        compare_status=1
    else
        # Local version is older than remote version
        compare_status=2
    fi
}

check_arch() {
if [ "$(uname)" = 'Linux' ]; then
case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='x86_32'
        ;;
      'amd64' | 'x86_64')
        AMD64='yes'
        ;;
      'armv5tel')
        MACHINE='armv5'
        ;;
      'armv6l')
        MACHINE='armv6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='armv5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='armv7'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='armv5'
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
    if [ "$AMD64" = 'yes' ] && [ "$is_virt" = 'yes' ]; then
        MACHINE='x86_64'
    elif [ "$AMD64" = 'yes' ]; then
        if [ -n "$(grep avx2 /proc/cpuinfo)" ]; then
            MACHINE='x86_64_v3_avx2'
        elif [ -n "$(grep sse /proc/cpuinfo)" ]; then
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
    echo "${GREEN}Downloading GeoIP database...${RESET}"
    echo "${GREEN}Downloading from: $geoip_url${RESET}"
    if ! curl -LO "$geoip_url" --progress-bar; then
        echo "${RED}error: Failed to download GeoIP database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
    if ! curl -sLO "$geoip_url".sha256sum; then
        echo "${RED}error: Failed to download the checksum file of GeoIP database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f geoip.dat
        exit 1
    fi
    geoip_local_sha256=$(SHA256SUM geoip.dat)
    geoip_remote_sha256=$(cat geoip.dat.sha256sum | awk -F ' ' '{print $1}')
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
    echo "${GREEN}GeoIP database have been installed/updated.${RESET}"
}

download_geosite() {
    echo "${GREEN}Downloading GeoSite database...${RESET}"
    echo "${GREEN}Downloading from: $geosite_url${RESET}"
    if ! curl -LO "$geosite_url" --progress-bar; then
        echo "${RED}error: Failed to download GeoSite database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
    if ! curl -sLO "$geosite_url".sha256sum; then
        echo "${RED}error: Failed to download the checksum file of GeoSite database!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f geosite.dat
        exit 1
    fi
    geosite_local_sha256=$(SHA256SUM geosite.dat)
    geosite_remote_sha256=$(cat geosite.dat.sha256sum | awk -F ' ' '{print $1}')
    if [ "$geoip_local_sha256" != "$geoip_remote_sha256" ]; then
        echo "${RED}error: The checksum of the downloaded GeoSite database does not match!${RESET}"
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
    echo "${GREEN}GeoSite database have been installed/updated.${RESET}"
}

stop_dae(){
    if command -v systemctl > /dev/null 2>&1 && [ "$(systemctl is-active dae)" = "active" ]; then
        echo "${GREEN}Stopping dae...${RESET}"
        systemctl stop dae
        dae_stopped='1'
        echo "${GREEN}Stopped dae${RESET}"
    fi
    if [ -f /etc/init.d/dae ] && [ -f /run/dae.pid ] && [ -n "$(cat /run/dae.pid)" ]; then
        echo "${GREEN}Stopping dae...${RESET}"
        /etc/init.d/dae stop
        dae_stopped='1'
        echo "${GREEN}Stopped dae${RESET}"
    fi
}

start_dae(){
    if [ -f /etc/systemd/system/dae.service ] && [ "$dae_stopped" = "1" ]; then
        echo "${GREEN}Starting dae...${RESET}"
        if ! systemctl start dae;then
            echo "${RED}Failed to start dae!${RESET}"
            echo "${RED}You should check your configuration file and try again.${RESET}"
        else
            echo "${GREEN}Started dae${RESET}"
        fi
    fi
    if [ -f /etc/init.d/dae ] && [ "$dae_stopped" = "1" ]; then
        echo "${GREEN}Starting dae...${RESET}"
        if ! (/etc/init.d/dae start);then
            echo "${RED}Failed to start dae!${RESET}"
            echo "${RED}You should check your configuration file and try again.${RESET}"
        else
            echo "${GREEN}Started dae${RESET}"
        fi
    fi
}

download_dae() {
    echo "${GREEN}Downloading dae...${RESET}"
    echo "${GREEN}Downloading from: $dae_url${RESET}"
    if ! curl -LO "$dae_url" --progress-bar; then
        echo "${RED}error: Failed to download dae!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        exit 1
    fi
    local_sha256=$(SHA256SUM dae-linux-"$MACHINE".zip | awk -F ' ' '{print $1}')
    if [ -z "$local_sha256" ]; then
        echo "${RED}error: Failed to get the checksum of the downloaded file!${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f dae-linux-"$MACHINE".zip
        exit 1
    fi
    if ! curl -sL "$dae_hash_url" -o dae-linux-"$MACHINE".zip.dgst; then
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
    rm -f dae-linux-"$MACHINE".zip.dgst
}

install_dae() {
    temp_dir="$(mktemp -d /tmp/dae.XXXXXX)"
    echo "${GREEN}unzipping dae's zip file...${RESET}"
    unzip dae-linux-"$MACHINE".zip -d "$temp_dir" >> /dev/null
    cp "$temp_dir""/dae-linux-""$MACHINE" /usr/local/bin/dae
    chmod +x /usr/local/bin/dae
    rm -f dae-linux-"$MACHINE".zip
    echo "${GREEN}dae have been installed/updated.${RESET}"
    rm -rf "$temp_dir"
}

download_example_config() {
    echo "${GREEN}Downloading dae's template configuration file...${RESET}"
    echo "${GREEN}Downloading from: $example_config_url${RESET}"
    if [ ! -d /usr/local/etc/dae ]; then
        mkdir -p /usr/local/etc/dae
    fi
    if ! curl -L "$example_config_url" -o /usr/local/etc/dae/example.dae --progress-bar; then
        notify_example="yes"
    fi
}

notify_configuration() {
    echo '----------------------------------------------------------------------'
    if [ "$notify_example" = 'yes' ];then
        echo '----------------------------------------------------------------------'
        echo "${YELLOW}warning: Failed to download example config file.${RESET}"
        echo "${YELLOW}You can download it from:
        https://github.com/daeuniverse/dae/raw/$latest_version/example.dae${RESET}"
        echo '----------------------------------------------------------------------'
    fi
    echo '----------------------------------------------------------------------'
    echo "${GREEN}dae have been installed/updated, installed version:${RESET}"
    echo "$latest_version"
    if command -v systemctl > /dev/null 2>&1; then
        echo "${GREEN}You can start dae by running:${RESET}"
        echo "systemctl start dae.service"
        echo "${GREEN}You can enable dae service so it can be started at system boot:${RESET}"
        echo "systemctl enable dae.service"
    elif command -v openrc-run > /dev/null 2>&1; then
        echo "${GREEN}You can start dae by running:${RESET}"
        echo "/etc/init.d/dae start"
        echo "${GREEN}You can enable dae service so it can be started at system boot:${RESET}"
        echo "rc-update add dae default"
    else
        echo "${YELLOW}No service installed beacuse of missing Systemd/OpenRC,
        you should write a service script/config for your service
        manager by yourself.${RESET}"
    fi
    echo '----------------------------------------------------------------------'
    echo '----------------------------------------------------------------------'
    echo "${GREEN}Your configuration file is:${RESET}"
    echo "/usr/local/etc/dae/config.dae"
    echo "${GREEN}And this file should be read by root only, you should${RESET}"
    echo "${GREEN}change the permission of this file by running:${RESET}"
    echo "chmod 600 /usr/local/etc/dae/config.dae"
    echo '----------------------------------------------------------------------'
    echo '----------------------------------------------------------------------'
}

installation() {
    download_dae
    download_geoip
    download_geosite
    download_example_config
    download_service
    stop_dae
    install_dae
    update_geoip
    update_geosite
    install_service
    start_dae
    notice_installled_tool
    notify_configuration
}

should_we_install_dae() {
    check_virtualization && check_arch    
    if [ "$force_install" = 'yes' ]; then
        check_online_version
        current_version='0'
    else
        check_local_version
        check_online_version
    fi
    compare_version
    get_download_urls
    if [ "$compare_status" = '0' ]; then
        echo "${GREEN}dae is already installed, current version: $current_version${RESET}"
        notice_installled_tool
    elif [ "$current_version" = '0' ]; then
        echo "${GREEN}Installing dae version $latest_version... ${RESET}"
        installation
    elif [ "$compare_status" = '1' ]; then
        echo "${YELLOW}Local version $current_version is greater than remote version $latest_version, ${RESET}"
        echo "${GREEN}If you still want to install, use force-install arg anyway.${RESET}"
        exit 0
    else
        echo "${GREEN}Upgrading dae version $current_version to version $latest_version... ${RESET}"
        installation
    fi
}

show_helps() {
    echo -e "${GREEN}""\033[1;4mUsage:\033[0m""${RESET}"
    echo "  $0 [command]"
    echo ' '
    echo -e "${GREEN}""\033[1;4mAvailable commands:\033[0m""${RESET}"
    echo "  use-cdn             use Cloudflare Worker and jsDelivr CDN to download files"
    echo "  install             install/update dae, default behavior"
    echo "  force-install       install/update latest version of dae without checking local version"
    echo "  update-geoip        update GeoIP database"
    echo "  update-geosite      update GeoSite database"
    echo "  help                show this help message"
}

# Main
current_dir=$(pwd)
cd /tmp/ || (echo "${YELLOW}Failed to cd /tmp/${RESET}"; exit 1)
if [ "$1" = "" ] || [ "$1" = "use-cdn" ]; then
    if [ "$1" = "use-cdn" ]; then
        use_cdn='yes'
    fi
    should_we_install_dae
fi
while [ $# != 0 ] ; do
    case "$1" in
        use-cdn)
            use_cdn='yes'
            shift
            ;;
        install)
            normal_install='yes'
            shift
            ;;
        force-install)
            force_install='yes'
            shift
            ;;
        update-geoip)
            geoip_should_update='yes'
            shift
            ;;
        update-geosite)
            geosite_should_update='yes'
            shift
            ;;
        help)
            show_help='yes'
            shift
            ;;
        *)
            error_help='yes'
            echo "${RED}error: Unknown command: $1${RESET}"
            shift
            ;;
    esac
done
if [ "$show_help" = 'yes' ];then
    show_helps
    exit 0
fi
if [ "$error_help" = 'yes' ];then
    show_helps
    exit 1
fi
if [ "$force_install" = 'yes' ] || [ "$normal_install" = 'yes' ];then
    should_we_install_dae
fi
if [ "$geoip_should_update" = 'yes' ];then
    get_download_urls
    download_geoip
    update_geoip
fi
if [ "$geosite_should_update" = 'yes' ];then
    get_download_urls
    download_geosite
    update_geosite
fi

trap 'cd "$current_dir"' 0 1 2 3

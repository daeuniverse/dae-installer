#!/usr/bin/env sh

set -e

## Color
echo_red() {
  printf '\033[31m%s\033[0m\n' "$*"
}
echo_red_bold() {
  printf "\033[1;31m%s\033[0m\n" "$1"
}
echo_yellow() {
  printf '\033[33m%s\033[0m\n' "$*"
}
echo_yellow_bold() {
  printf "\033[1;33m%s\033[0m\n" "$1"
}
echo_green() {
  printf '\033[32m%s\033[0m\n' "$*"
}
echo_green_bold() {
  printf "\033[1;32m%s\033[0m\n" "$1"
}

## Check System
if [ "$(uname)" != 'Linux' ]; then
    echo_red "error: This script only support Linux!"
    exit 1
fi

## Check root
user_id="$(id -u "$(whoami)")"
if [ "$user_id" -ne 0 ]; then
    echo_red "error: This script must be run as root!"
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
if ! command -v systemd-detect-virt >/dev/null 2>&1; then
    tool_need="virt-what"
fi
for tool in curl unzip; do
    if ! command -v $tool >/dev/null 2>&1; then
        tool_need="$tool"" ""$tool_need"
    fi
done
if [ -n "$tool_need" ]; then
    if command -v apt >/dev/null 2>&1; then
        command_install_tool="apt update; apt install $tool_need -y"
    elif command -v dnf >/dev/null 2>&1; then
        command_install_tool="dnf check-update; dnf install $tool_need -y"
    elif command -v yum >/dev/null 2>&1; then
        command_install_tool="yum install $tool_need -y"
    elif command -v zypper >/dev/null 2>&1; then
        command_install_tool="zypper --non-interactive install $tool_need"
    elif command -v pacman >/dev/null 2>&1; then
        command_install_tool="pacman -Sy $tool_need --noconfirm"
    elif command -v apk >/dev/null 2>&1; then
        command_install_tool="apk add $tool_need"
    else
        echo_red "You should install ""$tool_need""then try again."
        exit 1
    fi
    if ! /bin/sh -c "$command_install_tool"; then
        echo_red "Use system package manager to install $tool_need failed,"
        echo_red "You should install ""$tool_need""then try again."
        exit 1
    fi
fi

echo_dae() {
    echo '
   __| | __ _  ___       Copyright (C) REAL_YEAR@daeuniverse
  / _` |/ _` |/ _ \      https://github.com/daeuniverse/dae
 | (_| | (_| |  __/      dae is an open-source software, liscensed
  \__,_|\__,_|\___|      under the AGPL-3.0 License

This software comes with ABSOLUTELY NO WARRANTY, use at your own risk.' | sed "s/REAL_YEAR/$(date +%Y)/g"
}

check_virtualization() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        case "$(systemd-detect-virt)" in
        openvz | lxc | lxc-libvirt | wsl | docker | podman | systemd-nspawn | proot | rkt | rouch)
            is_container='yes'
            ;;
        qemu | kvm | amazon | zvm | vmware | microsoft | oracle | powervm | xen | bochs | uml | parallels | bhyve | qnx | acrn | apple | sre | google)
            is_virt='yes'
            ;;
        none | *)
            is_virt='no'
            ;;
        esac
    elif command -v virt-what >/dev/null 2>&1; then
        case "$(virt-what)" in
        openvz | linux_vserver | lxc | lxc-libvirt | wsl | docker | podman | systemd-nspawn | proot | rkt | rouch)
            is_container='yes'
            ;;
        hyprv | ibm_systemz | ibm_systemz-direct | ibm_systemz-lpar | ibm_systemz-zvm | kvm | parallels | powervm_lx86 | qemu | virtage | virtualbox | vmware | xen)
            is_virt='yes'
            ;;
        *)
            is_virt='no'
            ;;
        esac
    fi
    if [ "$is_container" = 'yes' ]; then
        echo_red "warning: dae doesn't support any container, stop installation."
        exit 1
    fi
}

get_download_urls() {
    if [ "$use_cdn" = 'yes' ]; then
        systemd_service_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/install/dae.service"
        openrc_service_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae-installer/OpenRC/dae"
        dae_url="https://github.abskoop.workers.dev/https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip"
        dae_hash_url="https://github.abskoop.workers.dev/https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip.dgst"
        example_config_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/example.dae"
        bash_completion_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/install/shell-completion/dae.bash"
        zsh_completion_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/install/shell-completion/dae.zsh"
        fish_completion_url="https://cdn.jsdelivr.net/gh/daeuniverse/dae@$latest_version/install/shell-completion/dae.fish"
        geoip_url="https://cdn.jsdelivr.net/gh/v2rayA/dist-v2ray-rules-dat/geoip.dat"
        geosite_url="https://cdn.jsdelivr.net/gh/v2rayA/dist-v2ray-rules-dat/geosite.dat"
    else
        systemd_service_url="https://github.com/daeuniverse/dae/raw/$latest_version/install/dae.service"
        openrc_service_url="https://github.com/daeuniverse/dae-installer/raw/main/OpenRC/dae"
        dae_url="https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip"
        dae_hash_url="https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip.dgst"
        example_config_url="https://github.com/daeuniverse/dae/raw/$latest_version/example.dae"
        bash_completion_url="https://github.com/daeuniverse/dae/raw/$latest_version/install/shell-completion/dae.bash"
        zsh_completion_url="https://github.com/daeuniverse/dae/raw/$latest_version/install/shell-completion/dae.zsh"
        fish_completion_url="https://github.com/daeuniverse/dae/raw/$latest_version/install/shell-completion/dae.fish"
        geoip_url="https://github.com/v2rayA/dist-v2ray-rules-dat/raw/master/geoip.dat"
        geosite_url="https://github.com/v2rayA/dist-v2ray-rules-dat/raw/master/geosite.dat"
    fi
}

notice_installled_tool() {
    if [ -n "$tool_need" ]; then
        echo_green "You have installed the following tools during installation:"
        echo "$tool_need"
        echo_green "You can uninstall them now if you want."
    fi
}

download_systemd_service() {
    systemd_service_temp_dir=$(mktemp -d /tmp/dae.XXXXXX)
    echo_green "Download systemd service..."
    if ! curl -L -# "$systemd_service_url" -o "$systemd_service_temp_dir"/dae.service; then
        echo_red "error: Failed to download Systemd Service!"
        echo_red "Please check your network and try again."
        exit 1
    fi
}

install_systemd_service() {
    echo_green "Installing/updating systemd service..."
    sed 's|usr/bin|usr/local/bin|g' < "$systemd_service_temp_dir"/dae.service | sed 's|etc|usr/local/etc|g' | tee /etc/systemd/system/dae.service
    systemctl daemon-reload
    echo_green "Systemd service installed/updated."
    rm -rf "$systemd_service_temp_dir"
}

download_openrc_service() {
    openrc_service_temp_dir=$(mktemp -d /tmp/dae.XXXXXX)
    echo_green "Download OpenRC service..."
    if ! curl -L -# $openrc_service_url -o "$openrc_service_temp_dir"/dae-openrc.sh; then
        echo_red "error: Failed to download OpenRC Service!"
        echo_red "Please check your network and try again."
        exit 1
    fi
}

install_openrc_service() {
    echo_green "Installing/updating OpenRC service..."
    tee /etc/init.d/dae < "$openrc_service_temp_dir"/dae-openrc.sh
    chmod +x /etc/init.d/dae
    echo_green "OpenRC service installed/updated"
    rm -rf "$openrc_service_temp_dir"
}

download_service() {
    if [ -f /usr/lib/systemd/systemd ]; then
        download_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        download_openrc_service
    fi
}

install_service() {
    if [ -f /usr/lib/systemd/systemd ]; then
        install_systemd_service
    elif [ -f /sbin/openrc-run ]; then
        install_openrc_service
    else
        echo_yellow "warning: There is no Systemd or OpenRC on this system, no service would be installed."
        echo_yellow "You should write service file/script by yourself."
    fi
}

check_local_version() {
    if ! command -v /usr/local/bin/dae >/dev/null 2>&1; then
        current_version=0
    else
        current_version=$(/usr/local/bin/dae --version | awk 'NR==1' | awk '{print $3}')
    fi
}

check_online_version() {
    if [ "$allow_prereleases" = 'yes' ]; then
        if [ "$use_cdn" = 'yes' ]; then
            tags_url="https://github.abskoop.workers.dev/https://github.com/daeuniverse/dae/tags"
        else
            tags_url="https://github.com/daeuniverse/dae/tags"
        fi
        temp_file="$(mktemp /tmp/dae.XXXXXX)"
        if ! curl -s "$tags_url" -o "$temp_file"; then
            echo_red "error: Failed to get the latest version of dae!"
            echo_red "Please check your network and try again."
            exit 1
        else
            latest_version="$(grep '/daeuniverse/dae/archive/refs/tags/' "$temp_file" | head -n 1 | awk -F '/tags/' '{print $2}' | awk -F '.zip' '{print $1}')"
            rm "$temp_file"
        fi
    else
        if [ "$use_cdn" = 'yes' ]; then
            releases_url="https://github.abskoop.workers.dev/https://github.com/daeuniverse/dae/releases/latest"
        else
            releases_url="https://github.com/daeuniverse/dae/releases/latest"
        fi
        temp_file="$(mktemp /tmp/dae.XXXXXX)"
        if ! curl -sL "$releases_url" | \
             grep '<h1 data-view-component="true" class="d-inline mr-3">' | \
             awk -F ' <h1 data-view-component="true" class="d-inline mr-3">' '{print $2}' | \
             awk -F '</h1>' '{print $1}' | \
             tee "$temp_file" >> /dev/null; then
            echo_red "error: Failed to get the latest version of dae!"
            echo_red "Please check your network and try again."
            exit 1
        else
            latest_version="$(cat "$temp_file" | head -n 1)"
            rm "$temp_file"
        fi
    fi
}

compare_version() {
    if [ "$latest_version" = "$current_version" ]; then
        compare_status=0            # Don't need update
    elif  [ "$(echo "$current_version" | grep -Eo "v[0-9]+\.[0-9]+\.[0-9]+" )" = "$(echo "$latest_version" | grep -Eo "v[0-9]+\.[0-9]+\.[0-9]+")" ]; then
        if ! grep -q -E 'rc' < "$latest_version"; then
            compare_status=2        # Local version is less than remote version
        fi
    elif [ "$(printf '%s\n' "$current_version" "$latest_version" | sort -V | head -n1)" = "$current_version" ]; then
        compare_status=2            # Local version is less than remote version
    elif [ "$(printf '%s\n' "$current_version" "$latest_version" | sort -rV | head -n1)" = "$current_version" ]; then
        compare_status=1            # Local version is greater than remote version
    else
        compare_status=2            # Local version is less than remote version
    fi
}

check_arch() {
    if [ "$(uname)" = 'Linux' ]; then
        if [ -n "$MACHINE" ]; then
            return
        fi
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
            echo_red "error: The architecture is not supported."
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
        echo_red "error: The operating system is not supported."
        exit 1
    fi
}

check_share_dir() {
    if [ ! -d /usr/local/share/dae ]; then
        mkdir -p /usr/local/share/dae
    fi
}

download_geoip() {
    geoip_temp_dir=$(mktemp -d /tmp/dae.XXXXXX)
    echo_green "Downloading GeoIP database..."
    echo_green "Downloading from: $geoip_url"
    if ! curl -L "$geoip_url" -o "$geoip_temp_dir"/geoip.dat --progress-bar; then
        echo_red "error: Failed to download GeoIP database!"
        echo_red "Please check your network and try again."
        exit 1
    fi
    if ! curl -sL "$geoip_url".sha256sum -o "$geoip_temp_dir"/geoip.dat.sha256sum; then
        echo_red "error: Failed to download the checksum file of GeoIP database!"
        echo_red "Please check your network and try again."
        rm -f geoip.dat
        exit 1
    fi
    geoip_local_sha256=$(SHA256SUM "$geoip_temp_dir"/geoip.dat)
    geoip_remote_sha256=$(awk -F ' ' '{print $1}' < "$geoip_temp_dir"/geoip.dat.sha256sum)
    if [ "$geoip_local_sha256" != "$geoip_remote_sha256" ]; then
        echo_red "error: The checksum of the downloaded GeoIP database does not match!"
        echo_red "Local SHA256: $geoip_local_sha256"
        echo_red "Remote SHA256: $geoip_remote_sha256"
        echo_red "Please check your network and try again."
        rm -rf "$geoip_temp_dir"
        exit 1
    fi
}
update_geoip() {
    check_share_dir
    cp "$geoip_temp_dir"/geoip.dat /usr/local/share/dae/
    rm -rf "$geoip_temp_dir"
    echo_green "GeoIP database have been installed/updated."
}

download_geosite() {
    geosite_temp_dir=$(mktemp -d /tmp/dae.XXXXXX)
    echo_green "Downloading GeoSite database..."
    echo_green "Downloading from: $geosite_url"
    if ! curl -L "$geosite_url" -o "$geosite_temp_dir"/geosite.dat --progress-bar; then
        echo_red "error: Failed to download GeoSite database!"
        echo_red "Please check your network and try again."
        exit 1
    fi
    if ! curl -sL "$geosite_url".sha256sum -o "$geosite_temp_dir"/geosite.dat.sha256sum; then
        echo_red "error: Failed to download the checksum file of GeoSite database!"
        echo_red "Please check your network and try again."
        rm -rf "$geosite_temp_dir"
        exit 1
    fi
    geosite_local_sha256=$(SHA256SUM "$geosite_temp_dir"/geosite.dat)
    geosite_remote_sha256=$(awk -F ' ' '{print $1}' < "$geosite_temp_dir"/geosite.dat.sha256sum)
    if [ "$geosite_local_sha256" != "$geosite_remote_sha256" ]; then
        echo_red "error: The checksum of the downloaded GeoSite database does not match!"
        echo_red "Local SHA256: $geosite_local_sha256"
        echo_red "Remote SHA256: $geosite_remote_sha256"
        echo_red "Please check your network and try again."
        rm -rf "$geosite_temp_dir"
        exit 1
    fi
}

update_geosite() {
    check_share_dir
    cp "$geosite_temp_dir"/geosite.dat /usr/local/share/dae/
    rm -rf "$geosite_temp_dir"
    echo_green "GeoSite database have been installed/updated."
}

stop_dae() {
    if command -v systemctl >/dev/null 2>&1 && [ "$(systemctl is-active dae)" = "active" ]; then
        echo_green "Stopping dae..."
        systemctl stop dae
        dae_stopped='1'
        echo_green "Stopped dae"
    fi
    if [ -f /etc/init.d/dae ] && [ -f /run/dae.pid ] && [ -n "$(cat /run/dae.pid)" ]; then
        echo_green "Stopping dae..."
        /etc/init.d/dae stop
        dae_stopped='1'
        echo_green "Stopped dae"
    fi
}

start_dae() {
    if [ -f /etc/systemd/system/dae.service ] && [ "$dae_stopped" = "1" ]; then
        echo_green "Starting dae..."
        if ! systemctl start dae; then
            echo_red "Failed to start dae!"
            echo_red "You should check your configuration file and try again."
        else
            echo_green "Started dae"
        fi
    fi
    if [ -f /etc/init.d/dae ] && [ "$dae_stopped" = "1" ]; then
        echo_green "Starting dae..."
        if ! (/etc/init.d/dae start); then
            echo_red "Failed to start dae!"
            echo_red "You should check your configuration file and try again."
        else
            echo_green "Started dae"
        fi
    fi
}

download_dae() {
    echo_green "Downloading dae..."
    echo_green "Downloading from: $dae_url"
    if ! curl -LO "$dae_url" --progress-bar; then
        echo_red "error: Failed to download dae!"
        echo_red "Please check your network and try again."
        exit 1
    fi
    local_sha256=$(SHA256SUM dae-linux-"$MACHINE".zip | awk -F ' ' '{print $1}')
    if [ -z "$local_sha256" ]; then
        echo_red "error: Failed to get the checksum of the downloaded file!"
        echo_red "Please check your network and try again."
        rm -f dae-linux-"$MACHINE".zip
        exit 1
    fi
    if ! curl -sL "$dae_hash_url" -o dae-linux-"$MACHINE".zip.dgst; then
        echo_red "error: Failed to download the checksum file!"
        echo_red "Please check your network and try again."
        rm -f dae-linux-"$MACHINE".zip.dgst
        exit 1
    fi
    remote_sha256=$(cat ./dae-linux-"$MACHINE".zip.dgst | awk -F "./dae-linux-$MACHINE.zip" 'NR==3' | awk '{print $1}')
    if [ "$local_sha256" != "$remote_sha256" ]; then
        echo_red "error: The checksum of the downloaded file does not match!"
        echo_red "Local SHA256: $local_sha256"
        echo_red "Remote SHA256: $remote_sha256"
        echo_red "Please check your network and try again."
        rm -f dae-linux-"$MACHINE".zip
        exit 1
    fi
    rm -f dae-linux-"$MACHINE".zip.dgst
}

install_dae() {
    temp_dir="$(mktemp -d /tmp/dae.XXXXXX)"
    echo_green "unzipping dae's zip file..."
    unzip dae-linux-"$MACHINE".zip -d "$temp_dir" >>/dev/null
    cp "$temp_dir""/dae-linux-""$MACHINE" /usr/local/bin/dae
    chmod +x /usr/local/bin/dae
    rm -f dae-linux-"$MACHINE".zip
    echo_green "dae have been installed/updated."
    rm -rf "$temp_dir"
}

download_example_config() {
    echo_green "Downloading dae's template configuration file..."
    echo_green "Downloading from: $example_config_url"
    if [ ! -d /usr/local/etc/dae ]; then
        mkdir -p /usr/local/etc/dae
    fi
    if ! curl -L "$example_config_url" -o /usr/local/etc/dae/example.dae --progress-bar; then
        notify_example="yes"
    fi
}

download_bash_completion() {
    [ -d /usr/share/bash-completion/completions ] || mkdir -p /usr/share/bash-completion/completions
    echo_green "Downloading bash completion file..."
    echo_green "Downloading from: $bash_completion_url"
    if ! curl -L "$bash_completion_url" -o /usr/share/bash-completion/completions/dae --progress-bar; then
        echo_yellow "Failed to download bash completion file."
    fi
}

download_zsh_completion() {
    [ -d /usr/share/zsh/site-functions ] || mkdir -p /usr/share/zsh/site-functions
    echo_green "Downloading zsh completion file..."
    echo_green "Downloading from: $zsh_completion_url"
    if ! curl -L "$zsh_completion_url" -o /usr/share/zsh/site-functions/_dae --progress-bar; then
        echo_yellow "Failed to download zsh completion file."
    fi
}

download_fish_completion() {
    [ -d /usr/share/fish/vendor_completions.d ] || mkdir -p /usr/share/fish/vendor_completions.d
    echo_green "Downloading fish completion file..."
    echo_green "Downloading from: $fish_completion_url"
    if ! curl -L "$fish_completion_url" -o /usr/share/fish/vendor_completions.d/dae.fish --progress-bar; then
        echo_yellow "Failed to download fish completion file."
    fi
}

download_completions() {
    if command -v bash >/dev/null 2>&1; then
        download_bash_completion
    fi
    if command -v zsh >/dev/null 2>&1; then
        download_zsh_completion
    fi
    if command -v fish >/dev/null 2>&1; then
        download_fish_completion
    fi
}

notify_configuration() {
    echo '----------------------------------------------------------------------'
    if [ "$notify_example" = 'yes' ]; then
        echo '----------------------------------------------------------------------'
        echo_yellow "warning: Failed to download example config file."
        echo_yellow "You can download it from:
        https://github.com/daeuniverse/dae/raw/$latest_version/example.dae"
        echo '----------------------------------------------------------------------'
    fi
    echo '----------------------------------------------------------------------'
    echo_green "dae have been installed/updated, installed version:"
    echo "$latest_version"
    if command -v systemctl >/dev/null 2>&1; then
        echo_green "You can start dae by running:"
        echo "systemctl start dae.service"
        echo_green "You can enable dae service so it can be started at system boot:"
        echo "systemctl enable dae.service"
    elif command -v openrc-run >/dev/null 2>&1; then
        echo_green "You can start dae by running:"
        echo "/etc/init.d/dae start"
        echo_green "You can enable dae service so it can be started at system boot:"
        echo "rc-update add dae default"
    else
        echo_yellow "No service installed beacuse of missing Systemd/OpenRC,
        you should write a service script/config for your service
        manager by yourself."
    fi
    echo '----------------------------------------------------------------------'
    echo '----------------------------------------------------------------------'
    echo_green "Your configuration file is:"
    echo "/usr/local/etc/dae/config.dae"
    echo_green "And this file should be read by root only, you should"
    echo_green "change the permission of this file by running:"
    echo "chmod 600 /usr/local/etc/dae/config.dae"
    echo '----------------------------------------------------------------------'
    echo '----------------------------------------------------------------------'
}

installation() {
    echo_dae
    download_dae
    download_geoip
    download_geosite
    download_example_config
    download_service
    download_completions
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
        echo_green "dae is already installed, current version: $current_version"
        notice_installled_tool
    elif [ "$current_version" = '0' ]; then
        echo_green "Installing dae version $latest_version... "
        installation
    elif [ "$compare_status" = '1' ]; then
        echo_yellow "Local version $current_version is greater than remote version $latest_version, "
        echo_green "If you still want to install, use force-install arg anyway."
        exit 0
    else
        echo_green "Upgrading dae version $current_version to version $latest_version... "
        installation
    fi
}

show_helps() {
    echo_green_bold "Usage:"
    echo "  $0 [command]"
    echo ' '
    echo_green_bold "Available commands:"
    echo "  use-cdn                 use Cloudflare Worker and jsDelivr CDN to download files"
    echo "  install                 install/update dae, default behavior"
    echo "  install-prerelease      install/update to the latest version of dae even if it's a prerelease"
    echo "  install-prereleases     alias for install-prerelease"
    echo "  force-install           install/update latest version of dae without checking local version"
    echo "  update-geoip            update GeoIP database"
    echo "  update-geosite          update GeoSite database"
    echo "  help                    show this help message"
}

# Main
current_dir=$(pwd)
cd /tmp/ || (
    echo_yellow "Failed to cd /tmp/"
    exit 1
)
if [ "$1" = "" ] || [ "$1" = "use-cdn" ]; then
    if [ "$1" = "use-cdn" ]; then
        use_cdn='yes'
    fi
    should_we_install_dae
fi
while [ $# != 0 ]; do
    case "$1" in
    install-prerelease | install-prereleases)
        allow_prereleases='yes'
        shift
        ;;
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
        echo_red "error: Unknown command: $1"
        shift
        ;;
    esac
done
if [ "$show_help" = 'yes' ]; then
    show_helps
    exit 0
fi
if [ "$error_help" = 'yes' ]; then
    show_helps
    exit 1
fi
if [ "$force_install" = 'yes' ] || [ "$normal_install" = 'yes' ] || [ "$allow_prereleases" = "yes" ]; then
    should_we_install_dae
fi
if [ "$geoip_should_update" = 'yes' ]; then
    get_download_urls
    download_geoip
    update_geoip
fi
if [ "$geosite_should_update" = 'yes' ]; then
    get_download_urls
    download_geosite
    update_geosite
fi

trap 'cd "$current_dir"' 0 1 2 3

#!/bin/bash

## Color
if command -v tput > /dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

## Check curl, unzip, jq
for tool_need in curl unzip jq; do
    if ! command -v $tool_need > /dev/null 2>&1; then
        if command -v apt > /dev/null 2>&1; then
        apt update; apt install $tool_need -y
        elif command -v dnf > /dev/null 2>&1; then
        dnf install $tool_need -y
        elif command -v yum > /dev/null  2>&1; then
        yum install $tool_need -y
        elif command -v zypper > /dev/null 2>&1; then
        zypper install --non-interactive $tool_need
        elif command -v pacman > /dev/null 2>&1; then
        pacman -S $tool_need --noconfirm
        else
        echo "$tool_need not installed, stop installation, please install $tool_need and try again!"
        we_should_exit=1
        fi
    fi
done


install_systemd_service() {
    echo "${GREEN}Installing systemd service...${RESET}"
    echo '[Unit]
Description=dae Service
Documentation=https://github.com/daeuniverse/dae
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=notify
User=root
LimitNPROC=512
LimitNOFILE=1048576
ExecStartPre=/usr/local/bin/dae validate -c /usr/local/etc/dae/config.dae
ExecStart=/usr/local/bin/dae run --disable-timestamp -c /usr/local/etc/dae/config.dae
ExecReload=/usr/bin/local/dae reload $MAINPID
Restart=on-abnormal

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/dae.service
    systemctl daemon-reload
    echo "${GREEN}Systemd service installed${RESET}"
}

check_version(){
    if ! command -v /usr/local/bin/dae > /dev/null 2>&1; then
    current_version=0
    else
    current_version=$(/usr/local/bin/dae --version | awk '{print $3}')
    fi
    if ! curl -s 'https://api.github.com/repos/daeuniverse/dae/releases/latest' -o /tmp/dae.json; then
        echo "${RED}error: Failed to get the latest version of dae.${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        we_should_exit=1
    else
        latest_version=$(jq -r '.tag_name' /tmp/dae.json)
        rm -f /tmp/dae.json
    fi
}

check_arch() {
if [[ $(uname) == 'Linux' ]]; then
case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='x86_32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='x86_64'
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
else
    echo "${RED}error: The operating system is not supported.${RESET}"
    exit 1
fi
}

install_dae() {
    current_dir=$(pwd)
    echo "${GREEN}Installing dae...${RESET}"
    cd /tmp/
    curl -LO https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip --progress-bar
    local_sha256=$(sha256sum dae-linux-$MACHINE.zip | awk -F ' ' '{print $1}')
    remote_sha256=$(curl -sL https://github.com/daeuniverse/dae/releases/download/$latest_version/dae-linux-$MACHINE.zip.dgst | awk -F "./dae-linux-$MACHINE.zip" 'NR==3' | awk '{print $1}')
    if [ "$local_sha256" != "$remote_sha256" ]; then
        echo "${RED}error: The checksum of the downloaded file does not match!${RESET}"
        echo "${RED}Local SHA256: $local_sha256${RESET}"
        echo "${RED}Remote SHA256: $remote_sha256${RESET}"
        echo "${RED}Please check your network and try again.${RESET}"
        rm -f dae-linux-$MACHINE.zip
        exit 1
    fi
    unzip dae-linux-$MACHINE.zip -d /usr/local/bin/
    mv /usr/local/bin/dae-linux-$MACHINE /usr/local/bin/dae
    chmod +x /usr/local/bin/dae
    rm -f dae-linux-$MACHINE.zip
    echo "${GREEN}dae installed${RESET}"
    cd $current_dir
}

# Main
check_version
if [ "$current_version" == "$latest_version" ]; then
    echo "${GREEN}dae is already installed, current version: $current_version${RESET}"
    exit 0
fi
if [ "$we_should_exit" == "1" ]; then
    exit 1
fi
check_arch
install_dae
install_systemd_service
echo "${GREEN}dae installed, installed version: $latest_version${RESET}"
echo "${GREEN}You can start dae by running: systemctl start dae${RESET}"

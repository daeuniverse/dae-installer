# dae-installer
dae's install script, you can use it to eat dae! 😊

## Usage

This script requires `curl`, `unzip` and `virt-what` to work, these tools can be installed automaticly during installation in most Linux systems.

### Install dae

NOTICE: If you are using Alpine Linux, `doas` might be the replacement of `sudo`.

Install with curl:

```sh
sudo sh -c "$(curl -sL https://github.com/daeuniverse/dae-installer/raw/main/installer.sh)" @ install
```

Install with wget:

```sh
sudo sh -c "$(wget -O- https://github.com/daeuniverse/dae-installer/raw/main/installer.sh)" @ install
```

### Uninstall dae

```sh
sudo sh -c "$(curl -sL https://raw.githubusercontent.com/daeuniverse/dae-installer/main/uninstaller.sh)"
```

Use `wget -O-` instead of `curl -sL` if you want to use `wget` rather than `curl`.

## Commands

Use `update-geoip` to update geoip without updating dae, use `update-geosite` to update geosite without updating dae, use `install` to install/update dae, and when installing/updating dae, geoip and geosite will also be updated.

## System Service

### Systemd

```ini
[Unit]
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
WantedBy=multi-user.target
```

### OpenRC

WARNING: Don't use OpenRC service script on OpenWrt, they are NOT same.

```sh
#!/sbin/openrc-run
description="dae Service"
command="/usr/local/bin/dae"
command_args="run -c /usr/local/etc/dae/config.dae"
pidfile="/run/${RC_SVCNAME}.pid"
command_background="yes"
output_log="/var/log/dae/access.log"
error_log="/var/log/dae/error.log"
supervisor="supervise-daemon"
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
      eerror "checking config file /usr/local/etc/dae/config.dae failed, exiting..."
      return 1
   fi
}

reload() {
    pid_dae="$(cat /run/${RC_SVCNAME}.pid)"
    if [ -n "$pid_dae" ];then
        ebegin "Reloading $RC_SVCNAME"
        /usr/local/bin/dae reload $pid_dae
        eend $?
    fi
}
```

## Thanks to

1. Project V's script: https://github.com/v2fly/fhs-install-v2ray
2. Project X's script: https://github.com/XTLS/Xray-install
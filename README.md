# dae-installer
dae's install script, you can use it to eat dae! 😊

## Usage

This script requires `curl`, `unzip` and `virt-what` to work, these tools can be installed automaticly during installation in most Linux systems.

### Install dae

NOTICE: If you are using Alpine Linux, `doas` might be the replacement of `sudo`; if you are root, then you don't need to use `sudo` or `doas`.

Install with curl:

```sh
sudo sh -c "$(curl -sL https://github.com/daeuniverse/dae-installer/raw/main/installer.sh)" @ install
```

Install with wget:

```sh
sudo sh -c "$(wget -qO- https://github.com/daeuniverse/dae-installer/raw/main/installer.sh)" @ install
```

### Uninstall dae

```sh
sudo sh -c "$(curl -sL https://raw.githubusercontent.com/daeuniverse/dae-installer/main/uninstaller.sh)"
```

Use `wget -qO-` instead of `curl -sL` if you want to use `wget` rather than `curl`.

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
    if [ -d /sys/fs/bpf ] && ! mountinfo -q /sys/fs/bpf; then
        error "bpf filesystem not mounted, exiting..."
        return 1
    fi
    if [ -d /sys/fs/cgroup ] && ! mountinfo -q /sys/fs/cgroup/; then
        error "cgroup filesystem not mounted, exiting..."
        return 1
    fi
    if [ ! -d "/tmp/dae/" ]; then 
        mkdir "/tmp/dae" 
    fi
    if [ ! -L "/var/log/dae" ]; then
        ln -s "/tmp/dae/" "/var/log/"
    fi
    if ! /usr/local/bin/dae validate -c /usr/local/etc/dae/config.dae; then
        eerror "checking config file /usr/local/etc/dae/config.dae failed, exiting..."
        return 1
    fi
}
```

## Classic Sysvinit

```sh
#!/bin/sh
#
# dae service
#
# chkconfig: 345 99 01
# description: Dae Daemon
#

DAEMON=/usr/local/bin/dae
PIDFILE=/var/run/dae-daemon.pid
CONFIG="/usr/local/etc/dae/config.dae"
PARAMS="run -c $CONFIG"

check_config() {
    if ! $DAEMON validate -c $CONFIG; then
        echo "checking config file $CONFIG failed, exiting..."
        exit 1
    fi
}

check_status() {
    if [ -f "$PIDFILE" ];then
        if [ "$(pidof "$DAEMON")" = "$(cat "$PIDFILE")" ];then
            echo "dae service is running."
        fi
    elif [ ! -f "$PIDFILE" ] || [ -z "$(cat "$PIDFILE")" ];then
        if [ -z "$(pidof $DAEMON)" ]; then
            echo "dae service is not running".
        else
            echo "A dae progress is running, but dae service is not running."
        fi
    fi
}

start() {
    check_config
    echo "Starting dae service..."
    start-stop-daemon --start --background --pidfile $PIDFILE --make-pidfile --exec $DAEMON -- $PARAMS
    echo "dae service started."
}

stop() {
    echo "Stopping dae service..."
    if [ -f $PIDFILE ]; then
        start-stop-daemon --stop --pidfile $PIDFILE
        rm -f $PIDFILE
    fi
    echo "dae service stopped."
}

reload() {
    echo "Reloading dae service..."
    if [ -f $PIDFILE ]; then
        $DAEMON reload $(cat $PIDFILE)
        echo "dae service reloaded."
    else
        echo "dae service is not running."
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    reload)
        reload
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status}"
        exit 1
esac

exit 0
```

## Thanks to

1. Project V's script: https://github.com/v2fly/fhs-install-v2ray
2. Project X's script: https://github.com/XTLS/Xray-install
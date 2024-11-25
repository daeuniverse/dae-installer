# dae-installer
dae's install script, you can use it to eat dae! 😊

## Usage

This script requires `curl`, `unzip` and `virt-what` to work, these tools can be installed automaticly during installation in most Linux systems.

### Install dae

NOTICE: If you are using Alpine Linux, `doas` might be the replacement of `sudo`; if you are root, then you don't need to use `sudo` or `doas`.

Open a Terminal and type in:

```sh
sudo sh -c "$(wget -qO- https://github.com/daeuniverse/dae-installer/raw/main/installer.sh)" @ install
```

If you have difficulty accessing GitHub, you can use this command instead: 

```sh
sudo sh -c "$(wget -qO- https://cdn.jsdelivr.net/gh/daeuniverse/dae-installer/installer.sh)" @ install use-cdn
```

If this script recognizes the wrong `$MACHINE`, you can manually specify it:

```sh
sudo MACHINE="x86_64" sh -c "$(wget -qO- https://github.com/daeuniverse/dae-installer/raw/main/installer.sh)" @ install
```

### Uninstall dae

```sh
sudo sh -c "$(curl -sL https://raw.githubusercontent.com/daeuniverse/dae-installer/main/uninstaller.sh)"
```

Use `curl -sL` instead of `wget -qO-` if you want to use `curl` rather than `wget`.

## Commands

### Usage:

```sh
./installer.sh [command]
```
 
### Available commands:

```
use-cdn                 use Cloudflare Worker and jsDelivr CDN to download files
install                 install/update dae, default behavior
install-prerelease      install/update to the latest version of dae even if it's a prerelease
install-prereleases     alias for install-prerelease
force-install           install/update latest version of dae without checking local version
update-geoip            update GeoIP database
update-geosite          update GeoSite database
help                    show this help message
```

## System Service

### Systemd

See [Systemd](Systemd)

### OpenRC

See [OpenRC](OpenRC)

### Classic SysVinit script

A SysVinit service can work with SysVinit, OpenRC, OpenWrt's Procd and Systemd (with `systemd-sysvcompat` installed), `start-stop-daemon` should be installed to run this script.

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
    start-stop-daemon -S -b -p $PIDFILE -m -x $DAEMON -- $PARAMS
    echo "dae service started."
}

stop() {
    echo "Stopping dae service..."
    if [ -f $PIDFILE ]; then
        start-stop-daemon -K -p $PIDFILE
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

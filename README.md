# dae-installer
dae's install script, you can use it to eat dae! 😊

## Usage

This script requires `curl`, `unzip` and `virt-what` to work, these tools can be installed automaticly during installation in most Linux systems.

### Install dae

If you are root:

```sh
bash <(curl -s https://raw.githubusercontent.com/daeuniverse/dae-installer/main/installer.sh) install
```

If you are not root but you can use `sudo`:

```sh
sudo bash -c "$(curl -s https://raw.githubusercontent.com/daeuniverse/dae-installer/main/installer.sh)" @ install
```

### Uninstall dae

```sh
curl -s https://raw.githubusercontent.com/daeuniverse/dae-installer/main/uninstaller.sh | bash
```

Use `sudo bash` if you are not root but you can use `sudo`.

## Commands

Use `update-geoip` to update geoip without updating dae, use `update-geosite` to update geosite without updating dae, use `install` to install/update dae, and when installing/updating dae, geoip and geosite will also be updated.

## Thanks to

1. Project V's script: https://github.com/v2fly/fhs-install-v2ray
2. Project X's script: https://github.com/XTLS/Xray-install
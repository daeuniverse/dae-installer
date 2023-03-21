# dae-installer
dae's install script, you can use it to eat dae! 😊

## Usage

If you are root:

```sh
bash <(curl -s https://raw.githubusercontent.com/daeuniverse/dae-installer/main/installer.sh)
```

If you are not root but you can use sudo:

```sh
sudo bash -c 'bash <(curl -s https://raw.githubusercontent.com/daeuniverse/dae-installer/main/installer.sh)'
```

## Commands

Use `update-geoip` to update geoip without updating dae, use `update-geosite` to update geosite without updating dae, use `install` to install/update dae, and when installing/updating dae, geoip and geosite will also be updated.

## Thanks to

1. Project V's script: https://github.com/v2fly/fhs-install-v2ray
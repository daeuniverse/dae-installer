# About Systemd Service

Systemd service is from this example:

<https://github.com/daeuniverse/dae/blob/main/install/dae.service>

This installer will replace the `/usr/bin` into `/usr/local/bin` and set config dir to `/usr/local/etc/dae`, you should put a config file into `/usr/local/etc/dae/` and rename it to `config.dae` after installation, then you should set its permission to 600:

```sh
sudo chmod 600 /usr/local/etc/dae/config.dae
```

Then you can start/enable dae service by `systemctl`:

```sh
sudo systemctl enable dae
sudo systemctl start dae
```
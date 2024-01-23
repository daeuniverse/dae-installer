# About OpenRC Service

[OpenRC](https://github.com/OpenRC/openrc) is a service manager maintained by the Gentoo developers, it is also a dependency-based init system that works with the system-provided init program, normally `/sbin/init`.

OpenRC might not mount eBPF file system and CGroup file system defaultly, for how to run dae on an OpenRC powered Linux system, please see:

<https://github.com/daeuniverse/dae/blob/main/docs/en/tutorials/run-on-alpine.md>

Don't use OpenRC service on OpenWrt, OpenWrt uses Procd as the services manager, OpenRC and Procd have different service style, even though they both use `/etc/init.d` as their services dir.
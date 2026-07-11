# Grafana Alloy for Home Assistant

![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fjsmith432%2Fha-addon-alloy%2Frefs%2Fheads%2Fmain%2Falloy%2Fconfig.yaml&query=%24.version&label=Ver)
![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg) ![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)

![No Support for armhf Architecture](https://img.shields.io/badge/armhf-no-red.svg)
![No Support for armv7 Architecture](https://img.shields.io/badge/armv7-no-red.svg)
![No Support for i386 Architecture](https://img.shields.io/badge/i386-no-red.svg)

[![ci](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml)
[![release](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml)

Ship Home Assistant OS systemd journal logs to Grafana Loki using Grafana Alloy.

Replaces the deprecated Promtail add-on which fails on HAOS 11+ due to systemd 252+ compact journal format incompatibility.

For full documentation, see the **Documentation** tab after installing.

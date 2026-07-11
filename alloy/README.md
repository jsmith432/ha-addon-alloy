# Grafana Alloy for Home Assistant


![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg) ![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)



[![ci](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml)
[![release](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml)

Ship Home Assistant OS systemd journal logs to Grafana Loki using Grafana Alloy.

Replaces the deprecated Promtail add-on which fails on HAOS 11+ due to systemd 252+ compact journal format incompatibility.

For full documentation, see the **Documentation** tab after installing.

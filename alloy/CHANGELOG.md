# Changelog

## 1.0.1 - 2026-07-07

### Changed
- Pass `--disable-reporting` to `alloy run` to disable anonymous usage
  reporting. This also stops the constant "failed to send usage report" log
  spam on networks where stats.grafana.org is unreachable or DNS-blocked.

## 1.0.0 - 2026-02-21

### Added
- Initial release
- Grafana Alloy v1.13.1
- Systemd journal log shipping to Loki
- Journal field relabeling (unit, hostname, syslog_identifier, transport, container_name, level)
- Debug UI on port 12345
- Configurable Loki URL, log level, and additional config
- Watchdog health check via Alloy's `/-/ready` endpoint
- Support for amd64 and aarch64 architectures

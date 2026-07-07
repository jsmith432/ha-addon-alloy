# Changelog

## 1.1.0 - 2026-07-07

### Added
- `journal_priority_as_level` option (default `true`). Set to `false` to skip
  the journal-priority → `level` label rule — Docker's journald driver assigns
  a fixed priority per stream (stdout=info, stderr=err), so for container logs
  the label reflects the stream, not the real level. (from upstream PR #7)
- `parse_ha_log_level` option (default `false`). Extracts the Python log level
  from Home Assistant Core / Supervisor lines into an `ha_level` label, scoped
  via `stage.match` so other journal streams are unaffected. (from upstream PR #5)

### Changed
- Alloy upgraded 1.13.1 → 1.17.1 (no breaking changes to the components this
  addon uses; breaking changes in 1.14/1.15 are limited to loki.secretfilter
  and otelcol.*).

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

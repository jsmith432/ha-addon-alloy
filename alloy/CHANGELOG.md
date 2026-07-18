# Changelog

## 1.5.1 - 2026-07-18

### Fixed
- Reject zero or negative `journal_max_age` values at startup with a clear error. `max_age` also acts as the saved-cursor staleness limit in Alloy's journal source: with `0h`, the saved position is discarded as "too old" on every start and the fallback (`Since = 0`) reads the journal from the beginning — so every restart re-shipped the entire journal retention as duplicate records.

## 1.5.0 - 2026-07-18

### Added
- `drop_message_regex` option (optional, default unset): RE2 regex dropping matching journal messages before they are shipped. Runs after ANSI stripping and before multiline joining and level parsing. Useful for high-volume journal noise such as bluetoothd BLE discovery messages or kernel audit records.

## 1.4.1 - 2026-07-14

### Added
- Add-on icon and logo (official Grafana Alloy artwork) shown in the Home Assistant add-on store and info page.

## 1.4.0 - 2026-07-14

### Added
- `multiline_python_logs` option (default `true`): re-joins multi-line Python log records (tracebacks) that journald stores as one entry per line, so they arrive in the log backend as a single record instead of dozens of fragments. Applies to the same containers as `parse_ha_log_level` (`homeassistant`, `hassio_supervisor`, plus any `parse_python_log_containers` extension). A new record starts at the leading timestamp or bracket prefix; continuation lines are appended, with a 3-second flush and a 256-line cap per record.

## 1.3.0 - 2026-07-11

### Added
- `strip_ansi_colors` option (default `true`): removes ANSI terminal color escape sequences from log messages before shipping, improving search and display in the log backend.
- `parse_python_log_containers` option: extends the `parse_ha_log_level` parser to additional containers that log Python-style leading severities (for example ESPHome or Matter Server). Takes a container-name regex fragment such as `addon_5c53de3b_esphome|addon_core_matter_server`.
- The Python-log parser now recognizes `WARN` (normalized to `warning`) and tolerates ANSI color codes between the timestamp and the severity, covering Matter Server's log format.

### Changed
- Replaced the deprecated `build.yaml` with a multi-platform `FROM` default (`ghcr.io/home-assistant/base-debian:bookworm`) directly in the Dockerfile, per the Supervisor BuildKit migration.

### Fixed
- AppArmor profile now grants `setgid`/`setuid` so the nginx ingress proxy no longer logs an `initgroups` error at startup.

## 1.2.5 - 2026-07-11

### Fixed
- `parse_ha_log_level` regex now tolerates the ANSI color codes that HA Core and Supervisor prepend to their journald lines. Since 1.2.3 the anchored regex never matched colored lines, so HA/Supervisor `INFO` records written to stderr fell back to the journald priority and were shipped with `level=error`.

## 1.2.4 - 2026-07-11

### Added
- Added custom, strict AppArmor profile to secure the container execution environment with least-privilege access.
- Enforced Unix `LF` line endings via `.gitattributes` to prevent cross-platform CI linting failures on Windows hosts.

### Changed
- Expanded and updated root README documentation to cover Ingress UI, CI/CD, and AppArmor features.

## 1.2.3 - 2026-07-11

### Added
- Added fully integrated Home Assistant Ingress UI using an internal NGINX reverse proxy. The Alloy web interface can now be accessed securely from the Home Assistant sidebar.
- Added automated CI/CD GitHub Actions workflows (`ci.yaml` and `release.yml`) for robust configuration testing, linting, and semantic releases.

### Changed
- Graduated the add-on stage from `experimental` to `stable`.
- Removed manual host port mapping requirements; `ports` and `webui` configuration are completely superseded by Ingress.
- Replaced outdated Debug UI documentation in `DOCS.md` with Ingress UI instructions.

## 1.2.2 - 2026-07-10

### Fixed
- Removed `pipefail` shell option from the final build stage, as Debian's
  default `/bin/sh` (`dash`) does not support it, which caused the build
  to fail on Home Assistant deployments.

## 1.2.1 - 2026-07-10

### Fixed
- Detect Alpine vs Debian base image at build time so the correct package
  manager (`apk` or `apt-get`) is used. Fixes the `apk: command not found`
  build failure when the Home Assistant Supervisor supplies a Debian base image.
- Remove obsolete `boot` and `watchdog` config keys flagged by the HA add-on
  linter; add a native Docker `HEALTHCHECK` directive instead.
- Set executable permissions on all shell scripts.

## 1.2.0 - 2026-07-10

### Added
- Optional advanced authentication, disabled by default, with mutually exclusive
  Basic and bearer modes.
- Optional Loki tenant ID and custom CA PEM settings for authenticated endpoints.
- Configurable `journal_max_age` with a seven-hour default.
- Home Assistant configuration and network translations.
- Automated render tests, real Alloy configuration validation, shell linting,
  app metadata linting, and amd64/arm64 image builds in CI.

### Changed
- New installations must provide `loki_url`; the unusable container-local
  `localhost` default has been removed. URL-only local-LAN operation remains the
  default and does not require authentication.
- The Alloy diagnostic host port is now disabled by default and must be
  explicitly enabled in Network settings.
- Home Assistant log levels are extracted from the leading timestamp/level
  fields instead of matching severity words anywhere in the message.
- Generic embedded app levels now run after HA parsing, matching the documented
  precedence.
- Journal priority is retained as `journal_priority` and its common synonyms are
  normalized into the `level` label.
- Embedded app severity synonyms such as `warn`, `fatal`, and `panic` are
  normalized to the same stable level vocabulary.
- Migrated to the current multi-platform BuildKit build model and removed the
  obsolete `build.yaml`.

### Security
- Verify downloaded Alloy release archives against pinned publisher SHA-256
  digests before installing them.
- Stop logging the Loki destination URL and render dynamic values as escaped
  Alloy string literals.
- Write generated configuration with mode `0600` and validate it before service
  startup.
- Replace the disabled AppArmor setting with a custom profile and remove the
  unused writable `addon_config` mount.

## 1.1.4 - 2026-07-08

### Changed
- `parse_ha_log_level` now sets both `ha_level` (`DEBUG`, `INFO`, etc.) and the
  normalized lowercase `level` label (`debug`, `info`, etc.) for Home Assistant
  Core and Supervisor logs. This lets HA's application-level severity override
  Docker/journald stream priority, matching the behavior of
  `parse_app_log_level` for `level=...` application logs.

### Documentation
- Expanded README and add-on documentation for every configuration toggle,
  including when to enable/disable each log-level parser and how precedence
  works between journald priority and application-provided severity.

## 1.1.3 - 2026-07-08

### Fixed
- Replace the `parse_app_log_level` guarded `stage.match` selector with a plain
  `stage.regex` using `labels_from_groups = true`. This avoids Alloy selector
  escaping failures while still only overriding `level` when an embedded
  lowercase application severity is present.

## 1.1.2 - 2026-07-08

### Added
- `parse_app_log_level` option (default `true`). Extracts common embedded
  application severities such as `level=info`, `level=warn`, and `level:error`
  into the normalized `level` label.

### Fixed
- Application-provided log levels now override Docker/journald stream priority.
  This prevents add-ons that write normal info output to stderr, such as
  CrowdSec LAPI access logs, from being mislabeled as `level="error"` in
  VictoriaLogs while preserving journald priority as a fallback for messages
  without embedded severity.

## 1.1.1 - 2026-07-07

### Fixed
- Trim leading/trailing whitespace from `loki_url` before rendering the
  config. A pasted leading space previously crash-looped Alloy with
  `first path segment in URL cannot contain colon`.

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

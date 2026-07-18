# Grafana Alloy for Home Assistant

[![Home Assistant Add-on](https://img.shields.io/badge/home_assistant-add--on-blue.svg?logo=homeassistant&logoColor=white)](https://github.com/jsmith432/ha-addon-alloy)
![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fjsmith432%2Fha-addon-alloy%2Frefs%2Fheads%2Fmain%2Falloy%2Fconfig.yaml&query=%24.version&label=Ver)
![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg) ![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)

[![ci](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml)
[![release](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml)

Ship Home Assistant OS logs to [Grafana Loki](https://grafana.com/oss/loki/) or another Loki-compatible endpoint, such as [VictoriaLogs](https://victorialogs.com/), using [Grafana Alloy](https://grafana.com/docs/alloy/latest/).

Maintained fork of [ecohash-co/ha-addon-alloy](https://github.com/ecohash-co/ha-addon-alloy) featuring several major improvements:
* **Fully Integrated Ingress UI**: Access the Grafana Alloy web interface securely and directly from the Home Assistant sidebar without needing to expose manual ports.
* **Automated CI/CD Pipelines**: Automated GitHub Actions workflows for robust linting, configuration testing, and semantic version releases.
* **Strict AppArmor Security**: Implements a custom AppArmor profile that heavily restricts system calls, ensuring the container runs with least-privilege access and protecting the host environment.
* **Core Enhancements**: Usage reporting disabled by default, upgraded Alloy versions, whitespace-hardened configurations, and robust log-level normalization options.

## Why use Grafana Alloy?

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) is the official successor to [Promtail](https://grafana.com/docs/loki/latest/send/promtail/), [Grafana Agent](https://grafana.com/docs/agent/latest/), and [Grafana Agent Flow](https://grafana.com/docs/agent/latest/flow/). It uses a component-based pipeline architecture and has native systemd journal support that works with all journal formats.

## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https://github.com/jsmith432/ha-addon-alloy)

1. Open **Settings** > **Add-ons** > **Add-on Store**
2. Click the overflow menu (three dots, top-right) > **Repositories**
3. Paste: `https://github.com/jsmith432/ha-addon-alloy`
4. Click **Add** > **Close**
5. Find **Grafana Alloy** in the store and click **Install**

## Configuration

Example for [VictoriaLogs](https://victorialogs.com):

```yaml
loki_url: "http://[IP_ADDRESS]/insert/loki/api/v1/push"
advanced_auth: false
log_level: info
journal_priority_as_level: true
parse_app_log_level: true
parse_ha_log_level: true
journal_max_age: 7h
```

### `loki_url`

Required. The full Loki-compatible push endpoint. For VictoriaLogs, use `/insert/loki/api/v1/push`.

By default, Alloy sends to this URL without authentication. This is the simplest and recommended mode for a trusted local-LAN Loki or VictoriaLogs endpoint.

### Advanced authentication

Authentication is disabled by default. Set `advanced_auth: true` only when the remote endpoint requires it.

Basic authentication:

```yaml
advanced_auth: true
auth_type: basic
auth_username: "123456"
auth_password: "secret"
```

Bearer authentication:

```yaml
advanced_auth: true
auth_type: bearer
bearer_token: "secret-token"
```

The two authentication types are mutually exclusive. Advanced mode also supports:

- `tenant_id`: optional Loki tenant identifier (`X-Scope-OrgID`)
- `tls_ca_pem`: optional PEM-encoded CA certificate for a private HTTPS endpoint

Incomplete advanced authentication prevents the app from starting. The destination URL and credentials are never printed to the app log.

### `log_level`

Controls Alloy's own logging verbosity, not the logs being shipped.

Allowed values:

```text
debug, info, warn, error
```

Default: `info`.

### `journal_priority_as_level`

Preserves systemd/journald priority as `journal_priority` and maps it to the normalized `level` label.

Default: `true`.

This is useful as a fallback for host/systemd logs that do not include their own severity. Docker/HAOS container logs can be misleading here because stderr is often stamped as `err`, so keep the app-level parsers enabled to override this when a real application severity is present.

Priority synonyms are normalized into `debug`, `info`, `warning`, or `error`, while the original keyword remains available in `journal_priority`.

### `parse_app_log_level`

Parses embedded lowercase app severities such as:

```text
level=info
level=warn
level:error
level="error"
```

Default: `true`.

When matched, this overrides the journald fallback `level`. This fixes add-ons such as CrowdSec where routine LAPI logs contain `level=info` but are written on a stream journald labels as error.

Values are normalized as follows: `trace`/`debug` → `debug`, `warn`/`warning` → `warning`, and `fatal`/`panic` → `critical`.

### `parse_ha_log_level`

Parses Home Assistant Core and Supervisor Python log levels:

```text
DEBUG, INFO, WARNING, ERROR, CRITICAL
```

Default: `false`.

When enabled, it sets:

- `ha_level` to the original HA level, for example `INFO`
- `level` to normalized lowercase severity, for example `info`

This makes HA Core/Supervisor application severity override Docker/journald stream priority.

The parser only accepts a severity in the leading timestamp-and-level portion of a Core or Supervisor record. Severity words appearing later in the message do not change the label. ANSI color codes around the timestamp and severity are tolerated, and `WARN` is recognized and normalized to `warning`.

Note that the `journal_priority` label always preserves the raw journald priority keyword, so HA/Supervisor records written to stderr keep `journal_priority=error` even after this parser corrects `level`. Alert on `level`, not `journal_priority`.

### `parse_python_log_containers`

Optional container-name regex fragment that extends the `parse_ha_log_level` parser to additional containers logging Python-style leading severities:

```yaml
parse_ha_log_level: true
parse_python_log_containers: "addon_5c53de3b_esphome|addon_core_matter_server"
```

This fixes add-ons such as ESPHome (which uses the same colorlog format as HA Core) and Matter Server shipping routine `INFO`/`WARN` records as `level=error` because they write to stderr. Only letters, digits, and basic regex characters are accepted. Extends both the `parse_ha_log_level` parser and the `multiline_python_logs` joiner.

### `strip_ansi_colors`

Removes ANSI terminal color escape sequences (for example `\x1b[32m`) from log messages before shipping.

Default: `true`.

HA Core, Supervisor, and many add-ons colorize their output; the raw escape codes pollute full-text search and rendering in the log backend. Disable only if you want byte-identical original messages.

### `multiline_python_logs`

Re-joins multi-line Python log records (tracebacks) into a single record before shipping.

Default: `true`.

Journald stores one entry per stderr line, so a Python traceback from HA Core otherwise arrives as dozens of separate fragment records. A new record starts at the leading timestamp that every real log line carries; continuation lines are appended to the previous record, with a 3-second flush timeout and a 256-line cap.

Applies to the same containers as `parse_ha_log_level` (`homeassistant`, `hassio_supervisor`, plus any `parse_python_log_containers` extension), but works independently of that toggle.

### `drop_message_regex`

Optional [RE2](https://github.com/google/re2/wiki/Syntax) regular expression. Journal messages matching it are dropped before shipping — they never reach the log backend.

Default: unset (nothing is dropped).

Use this to silence high-volume noise at the source, for example bluetoothd BLE discovery spam and kernel audit records:

```yaml
drop_message_regex: "Unable to (create object for found device|register device interface for) |proctitle=2F63726F"
```

The regex is matched against the message after ANSI stripping and before multiline joining and level parsing. A partial match anywhere in the message drops the record; anchor with `^`/`$` for whole-line matching. Combine multiple patterns with `|`. Dropped records are gone permanently — prefer patterns tight enough that they cannot match anything you might later need.

### `journal_max_age`

Controls how far Alloy looks back in the journal when it has no saved position. Use an Alloy duration such as `7h` or `24h`.

Default: `7h`.

The journal position survives restarts, rebuilds, and updates (it is stored in the add-on's persistent `/data`). Uninstalling and reinstalling the add-on wipes `/data`, so the next start re-ships the last `journal_max_age` of journal entries, which appear as duplicate records in the destination.

### `additional_config`

Optional raw Alloy config appended to the generated config. This can define independent additional components but cannot modify the generated journal and write components. A syntax error here prevents Alloy from starting.

The complete generated configuration is validated before the Alloy service starts.

## Level precedence

When all normalization toggles are enabled, the effective `level` label is determined in this order:

1. Generic embedded app severity from `parse_app_log_level`.
2. HA Core/Supervisor severity from `parse_ha_log_level`.
3. Journald priority fallback from `journal_priority_as_level`.

This keeps useful severity labels for host logs while preventing add-ons from being falsely labeled as errors just because they wrote to stderr.

## What gets shipped

All systemd journal entries from HAOS, including:

- Home Assistant Core logs
- Add-on/app container logs
- Supervisor logs
- Host system logs such as kernel and network services

Labels applied when available:

```text
unit, hostname, syslog_identifier, transport, container_name, journal_priority, level, ha_level
```

## Ingress UI

The Grafana Alloy pipeline inspector is fully integrated into Home Assistant. Simply click on the add-on in your sidebar or click **Open Web UI** to view component health, the pipeline DAG, and live-stream logs.

## License

MIT

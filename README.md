# Home Assistant App: Grafana Alloy

[![Home Assistant Add-on](https://img.shields.io/badge/home_assistant-add--on-blue.svg?logo=homeassistant&logoColor=white)](https://github.com/jsmith432/ha-addon-alloy)
![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fjsmith432%2Fha-addon-alloy%2Frefs%2Fheads%2Fmain%2Falloy%2Fconfig.yaml&query=%24.version&label=Ver)
![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg) ![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)

[![ci](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/ci.yaml)
[![release](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml/badge.svg)](https://github.com/jsmith432/ha-addon-alloy/actions/workflows/release.yml)

Ship Home Assistant OS logs to [Grafana Loki](https://grafana.com/oss/loki/) or another Loki-compatible endpoint, such as VictoriaLogs, using [Grafana Alloy](https://grafana.com/docs/alloy/latest/).

Maintained fork of [ecohash-co/ha-addon-alloy](https://github.com/ecohash-co/ha-addon-alloy) featuring several major improvements:
* **Fully Integrated Ingress UI**: Access the Grafana Alloy web interface securely and directly from the Home Assistant sidebar without needing to expose manual ports.
* **Automated CI/CD Pipelines**: Automated GitHub Actions workflows for robust linting, configuration testing, and semantic version releases.
* **Strict AppArmor Security**: Implements a custom AppArmor profile that heavily restricts system calls, ensuring the container runs with least-privilege access and protecting the host environment.
* **Core Enhancements**: Usage reporting disabled by default, upgraded Alloy versions, whitespace-hardened configurations, and robust log-level normalization options.

## Why?

The official Promtail add-on (v2.2.0) bundles Promtail 2.6.1, which cannot read the compact journal format introduced in systemd 252+ (HAOS 11+). This means **Promtail silently fails to ship logs on modern HAOS installations**.

Grafana Alloy is the official successor to Promtail, Grafana Agent, and Grafana Agent Flow. It uses a component-based pipeline architecture and has native systemd journal support that works with all journal formats.

## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https://github.com/jsmith432/ha-addon-alloy)

1. Open **Settings** > **Add-ons** > **Add-on Store**
2. Click the overflow menu (three dots, top-right) > **Repositories**
3. Paste: `https://github.com/jsmith432/ha-addon-alloy`
4. Click **Add** > **Close**
5. Find **Grafana Alloy** in the store and click **Install**

## Configuration

Example for VictoriaLogs:

```yaml
loki_url: "http://10.1.1.31:9428/insert/loki/api/v1/push"
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

The parser only accepts a severity in the leading timestamp-and-level portion of a Core or Supervisor record. Severity words appearing later in the message do not change the label.

### `journal_max_age`

Controls how far Alloy looks back in the journal when it has no saved position. Use an Alloy duration such as `7h` or `24h`.

Default: `7h`.

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

## Debug UI

The host port is disabled by default because Alloy's diagnostic HTTP endpoints do not provide their own authentication. To use the pipeline inspector, assign host port `12345` under the app's **Network** settings, then open:

```text
http://<haos-ip>:12345
```

## License

MIT

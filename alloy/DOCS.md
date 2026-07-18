# Grafana Alloy for Home Assistant

Ship Home Assistant OS logs to a remote [Loki](https://grafana.com/oss/loki/) compatible endpoint using [Grafana Alloy](https://grafana.com/docs/alloy/latest/). VictoriaLogs is supported through its Loki ingestion endpoint.

This add-on replaces the deprecated Promtail add-on, which is incompatible with modern HAOS versions (11+) due to systemd 252+ compact journal format changes.

## What it collects

The add-on reads the HAOS systemd journal through the Supervisor `journald: true` permission. On HAOS, that journal includes:

- Home Assistant Core logs
- Supervisor logs
- Add-on/app container logs
- Host OS/service logs

## Configuration

### Required

#### `loki_url`

The full Loki-compatible push endpoint.

Examples:

```yaml
loki_url: "http://192.168.1.45:3100/loki/api/v1/push"
loki_url: "http://10.1.1.31:9428/insert/loki/api/v1/push" # VictoriaLogs
```

Notes:

- Leading/trailing whitespace is trimmed before Alloy starts.
- Authentication is disabled by default for local-LAN endpoints.
- If this URL is wrong or unreachable, Alloy can start but log delivery will fail.

### Advanced authentication

Set `advanced_auth: true` only when the Loki-compatible endpoint requires authentication. URL-only, unauthenticated operation remains the default.

#### Basic authentication

```yaml
loki_url: "https://logs.example.net/loki/api/v1/push"
advanced_auth: true
auth_type: basic
auth_username: "123456"
auth_password: "secret"
```

#### Bearer authentication

```yaml
loki_url: "https://gateway.example.net/loki/api/v1/push"
advanced_auth: true
auth_type: bearer
bearer_token: "secret-token"
```

Basic and bearer authentication are mutually exclusive. When advanced authentication is enabled, the selected mode's required fields must be present or the app will stop with a configuration error.

Optional advanced endpoint fields:

- `tenant_id`: Loki tenant identifier (`X-Scope-OrgID`)
- `tls_ca_pem`: PEM-encoded CA certificate for a private HTTPS endpoint

Credential fields are masked in the Home Assistant configuration UI. The app never writes the destination URL, password, or token to its log.

### Optional toggles

#### `log_level`

Controls Alloy's own log verbosity, not the verbosity of logs being shipped.

Default:

```yaml
log_level: info
```

Allowed values:

```yaml
debug | info | warn | error
```

Use `debug` only while troubleshooting Alloy itself; it can be noisy.

#### `journal_priority_as_level`

Preserves systemd/journald priority in `journal_priority` and maps it into the normalized `level` label.

Default:

```yaml
journal_priority_as_level: true
```

Why this exists:

- Many host/systemd journal entries do not contain an application-level severity in the message body.
- Journald priority is often the best available severity for host services.
- Keeping this enabled preserves useful queries such as `level="error"` for logs with no embedded severity.
- Priority synonyms are normalized into `debug`, `info`, `warning`, or `error`; the original keyword remains in `journal_priority`.

Caveat:

- Docker/HAOS container logs can inherit priority from the output stream: stdout often maps to `info`, stderr often maps to `err`.
- Some add-ons write normal informational output to stderr, so journald priority alone can mislabel routine logs as `level="error"`.

Recommended setting:

- Keep enabled when `parse_app_log_level` and `parse_ha_log_level` are also enabled.
- Application-level parsers override this fallback when they recognize a real app severity.
- Disable only if you want no journald fallback `level` label at all.

#### `parse_app_log_level`

Parses embedded lowercase application severities from generic app logs and writes them to the normalized `level` label.

Default:

```yaml
parse_app_log_level: true
```

Recognized examples:

```text
level=info
level=warn
level:error
level="error"
level=fatal
```

Recognized values:

```text
trace, debug, info, warn, warning, error, fatal, panic
```

Normalized values:

- `trace`, `debug` → `debug`
- `info` → `info`
- `warn`, `warning` → `warning`
- `error` → `error`
- `fatal`, `panic` → `critical`

Why this exists:

- Some add-ons, such as CrowdSec, include the true app severity in the log line (`level=info`) while Docker/journald marks the stream as `err`.
- This parser makes the embedded application severity authoritative.

Precedence:

- If a line contains a recognized `level=...` or `level:...`, that value becomes `level`.
- If no embedded app level exists, the existing `level` label is left alone, usually from `journal_priority_as_level`.

Recommended setting:

- Keep enabled for most installations.
- Disable only if an application uses `level=` for something that is not severity.

#### `parse_ha_log_level`

Parses Home Assistant Core and Supervisor Python log levels and writes both labels:

- `ha_level`: original HA spelling (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`)
- `level`: normalized lowercase severity (`debug`, `info`, `warning`, `error`, `critical`)

Default:

```yaml
parse_ha_log_level: false
```

Recognized HA levels:

```text
DEBUG, INFO, WARNING, ERROR, CRITICAL
```

Scope:

- Applies to `homeassistant` and `hassio_supervisor` container logs.
- Additional containers can be included via `parse_python_log_containers`.

Why this exists:

- HA Core/Supervisor messages can be written through a stream that journald marks as error even when the message is `INFO`.
- This parser makes HA's own application-level severity authoritative while retaining `ha_level` for HA-specific dashboarding.
- The severity must appear in the leading timestamp-and-level portion of the record, so severity words in the message body cannot overwrite the real level.
- Leading ANSI color codes are tolerated: HA Core and Supervisor colorize their journald output (for example `ESC[32m` before an `INFO` line), and the parser matches through them. `WARN` is also recognized and normalized to `warning`.
- The `journal_priority` label always keeps the raw journald keyword. Records written to stderr keep `journal_priority=error` even after this parser sets `level` correctly, so alerting and filtering should use `level`.

Recommended setting:

- Enable if you query or alert on `level` for Home Assistant/Supervisor logs.
- Leave disabled only if you want journald stream priority to remain the sole `level` source for HA Core/Supervisor.

#### `parse_python_log_containers`

Optional container-name regex fragment that extends the `parse_ha_log_level` parser to additional containers logging Python-style leading severities.

Example:

```yaml
parse_ha_log_level: true
parse_python_log_containers: "addon_5c53de3b_esphome|addon_core_matter_server"
```

Why this exists:

- Add-ons such as ESPHome use the same colorlog format as HA Core, and Matter Server logs a leading timestamp and severity; without parsing, their routine `INFO`/`WARN` records ship as `level=error` because they are written to stderr.

Notes:

- Extends both the `parse_ha_log_level` parser and the `multiline_python_logs` joiner; it has no effect if both of those are disabled.
- Only letters, digits, and the regex characters `_ . - | * + ? ( ) [ ] { } ^ $` are accepted. Anything else fails validation before Alloy starts.

#### `strip_ansi_colors`

Removes ANSI terminal color escape sequences from log messages before any parsing or shipping.

Default:

```yaml
strip_ansi_colors: true
```

Why this exists:

- HA Core, Supervisor, and many add-ons colorize their output. The raw escape codes (for example `ESC[32m`) pollute full-text search, waste storage, and render as noise in log UIs.

Recommended setting:

- Keep enabled. Disable only if you need byte-identical original messages.

#### `multiline_python_logs`

Re-joins multi-line Python log records — most importantly tracebacks — into a single record before shipping.

Default:

```yaml
multiline_python_logs: true
```

Why this exists:

- Docker's journald logging driver stores one journal entry per stderr line, so a Python traceback from HA Core arrives in the log backend as dozens of separate fragment records with no context.
- This stage buffers lines per container stream: a new record starts at the leading timestamp (or bracket prefix) that every real Python-style log line carries; lines without one (traceback frames, continuation lines) are appended to the previous record.

Scope:

- Applies to `homeassistant` and `hassio_supervisor` container logs, plus any containers added via `parse_python_log_containers` — the same selector as `parse_ha_log_level`, but it works independently of that toggle.

Behavior details:

- A partial record is flushed after 3 seconds of no continuation, and records are capped at 256 lines.
- The joined record carries the timestamp and (with `parse_ha_log_level`) the severity of its first line, so a whole traceback ships as one `level=error` record.
- Buffering adds up to 3 seconds of delivery latency to the last record in a burst from these containers.

Recommended setting:

- Keep enabled. Disable only if you need strict one-journal-entry-per-record shipping.

#### `drop_message_regex`

Optional [RE2](https://github.com/google/re2/wiki/Syntax) regular expression. Journal messages matching it are dropped before shipping.

Default: unset (nothing is dropped).

Example — silence bluetoothd BLE discovery spam and kernel audit records:

```yaml
drop_message_regex: "Unable to (create object for found device|register device interface for) |proctitle=2F63726F"
```

Behavior details:

- Matched against the message after ANSI stripping (when enabled) and before multiline joining and level parsing.
- A partial match anywhere in the message drops the record; anchor with `^`/`$` for whole-line matching.
- Combine multiple patterns with `|`.
- Dropped records never reach the log backend — prefer tight patterns over broad ones, since there is no way to recover a dropped record later.
- An invalid regex prevents Alloy from starting; the app validates the generated configuration at startup and logs the error.

#### `journal_max_age`

Controls the oldest journal entries Alloy reads when it has no saved position.

Default:

```yaml
journal_max_age: 7h
```

Use a **positive** Alloy duration such as `7h` or `24h`. A larger value can replay more historical records on first start and may cause the remote Loki endpoint to reject entries that are older than its ingestion window.

Warning — this value also limits how old a saved journal position may be:

- Alloy discards the saved position when the entry it points at is older than `journal_max_age`, and falls back to time-based seeking. Do not set it shorter than the longest add-on downtime you expect, or a long outage will replay `journal_max_age` of history instead of resuming precisely.
- Zero or negative values are rejected at startup. With `0h`, every saved position would be "too old", and the zero fallback reads the journal **from the beginning** — every restart would re-ship the entire journal retention as duplicates.

The journal position is stored in the add-on's persistent `/data` and survives restarts, rebuilds, and updates. Uninstalling and reinstalling the add-on wipes `/data`, so the next start re-ships the last `journal_max_age` of entries — these arrive as duplicate records in the destination.

#### `additional_config`

Raw Alloy config appended verbatim to the generated config.

Default: unset.

Warning:

- This is an escape hatch for advanced users.
- It can define independent additional components but cannot modify the generated journal and write components.
- Syntax errors here will prevent Alloy from starting.
- The complete generated configuration is validated before the Alloy service starts.
- Prefer built-in options when possible.

## Level precedence

When all normalization toggles are enabled, `level` is resolved in this order:

1. `parse_app_log_level` — generic embedded app severity such as `level=info`.
2. `parse_ha_log_level` — HA Core/Supervisor `DEBUG`/`INFO`/`WARNING`/`ERROR`/`CRITICAL`.
3. `journal_priority_as_level` — journald priority fallback for messages without embedded severity.

This keeps useful journald severity for host logs while preventing app logs from being mislabeled because they were written to stderr.

## Labels

All journal entries are shipped with these labels when available:

| Label | Source |
|-------|--------|
| `job` | Static value: `systemd-journal` |
| `unit` | systemd unit name |
| `hostname` | journal hostname |
| `syslog_identifier` | process/add-on identifier |
| `transport` | journal transport type |
| `container_name` | Docker container name for add-ons |
| `journal_priority` | original systemd journal priority keyword when priority parsing is enabled |
| `level` | normalized severity from app parser, HA parser, or journald fallback |
| `ha_level` | original HA Core/Supervisor Python level when `parse_ha_log_level` is enabled |

## Grafana Alloy UI

The Alloy diagnostic UI is fully integrated into Home Assistant via Ingress. Once the add-on is started, a new **Grafana Alloy** link will appear in your Home Assistant sidebar.

Clicking this link will securely open the Alloy UI directly within Home Assistant, requiring no additional network port configurations or separate authentication.

Use it to inspect component health, view the pipeline DAG, live-stream component logs, and troubleshoot issues.

## Troubleshooting

- **No logs in Loki/VictoriaLogs**: verify `loki_url` is reachable from HAOS and check Alloy logs for write errors.
- **App stops before Alloy starts**: check for a missing URL, incomplete advanced authentication, an unavailable journal mount, or an Alloy validation error.
- **Authentication rejected**: confirm `advanced_auth`, `auth_type`, and the selected mode's credential fields. Do not place credentials directly in `loki_url`.
- **App crashes on start**: check the app log for Alloy config errors. Set `log_level: debug` only if needed.
- **`level="error"` on routine add-on logs**: keep `journal_priority_as_level: true`, but enable `parse_app_log_level` and/or `parse_ha_log_level` so app severity overrides stream priority.
- **"timestamp too old" in Loki**: normal on first start if Alloy reads older journal entries; usually resolves once it catches up.

## Support

Report issues at: https://github.com/jsmith432/ha-addon-alloy/issues

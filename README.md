# Home Assistant App: Grafana Alloy

Ship Home Assistant OS logs to [Grafana Loki](https://grafana.com/oss/loki/) using [Grafana Alloy](https://grafana.com/docs/alloy/latest/) — the modern replacement for the deprecated Promtail add-on.

Maintained fork of [ecohash-co/ha-addon-alloy](https://github.com/ecohash-co/ha-addon-alloy) with usage reporting disabled, newer Alloy, whitespace-hardened config, and log-level normalization options.

## Why?

The official Promtail add-on (v2.2.0) bundles Promtail 2.6.1, which cannot read the compact journal format introduced in systemd 252+ (HAOS 11+). This means **Promtail silently fails to ship logs on modern HAOS installations**.

Grafana Alloy is the official successor to Promtail, Grafana Agent, and Grafana Agent Flow. It uses a component-based pipeline architecture and has native systemd journal support that works with all journal formats.

## Installation

1. Open **Settings** > **Add-ons** > **Add-on Store**
2. Click the overflow menu (three dots, top-right) > **Repositories**
3. Paste: `https://github.com/jsmith432/ha-addon-alloy`
4. Click **Add** > **Close**
5. Find **Grafana Alloy** in the store and click **Install**

## Configuration

Set `loki_url` to your Loki push endpoint:

```yaml
loki_url: "http://192.168.1.45:3100/loki/api/v1/push"
log_level: info
journal_priority_as_level: true
parse_app_log_level: true
parse_ha_log_level: false
```

`parse_app_log_level` is enabled by default. It extracts embedded application
severities such as `level=info` or `level:error` into the normalized `level`
label, overriding Docker/journald stream priority when the application provides
its own level. Journald priority remains useful as a fallback for messages that
do not include an application-level severity.

## What gets shipped

All systemd journal entries from HAOS, including:
- Home Assistant Core logs
- Add-on/app container logs
- Supervisor logs
- Host system logs (kernel, networkd, etc.)

Labels applied: `unit`, `hostname`, `syslog_identifier`, `transport`, `container_name`, `level`.

## Debug UI

Access the Alloy pipeline inspector at `http://<haos-ip>:12345`.

## License

MIT

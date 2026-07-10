# Alloy add-on hardening design

## Goals

- Preserve URL-only, unauthenticated Loki access as the default for trusted LANs.
- Make Basic and bearer authentication explicitly opt-in behind `advanced_auth`.
- Correct log-level parsing and make parser precedence match the documentation.
- Reduce the add-on's default network and filesystem exposure.
- Make builds reproducible and continuously validate every generated Alloy configuration.

## Configuration contract

`loki_url` remains the only setting needed for the default mode. New installs must provide it rather than silently using a loopback URL that normally points at nothing inside the add-on container.

`advanced_auth` defaults to `false`. When false, the renderer ignores all advanced credential fields and emits a plain `loki.write` endpoint. When true, `auth_type` selects exactly one of:

- `basic`: requires `auth_username` and `auth_password`.
- `bearer`: requires `bearer_token`.

Both modes may additionally set `tenant_id` and `tls_ca_pem`. Password and token fields use Home Assistant's masked `password` schema type. Arbitrary headers remain available through the existing `additional_config` escape hatch rather than expanding the normal schema.

## Runtime design

The initialization service validates option combinations, renders dynamic values as escaped Alloy string literals, writes the generated configuration with mode `0600`, and runs `alloy validate` before the long-running service starts. Logs state which authentication mode is active but never print the destination URL or credentials.

Home Assistant severity is parsed only from an anchored timestamp-and-level prefix within Core and Supervisor container logs. Its extracted uppercase level is retained as `ha_level` and normalized to lowercase `level`. The generic embedded `level=...` parser runs afterward, giving it the documented higher precedence.

The Alloy HTTP port remains available internally for the watchdog, but its host mapping is disabled by default. Users may explicitly publish the port from Home Assistant's Network settings when they need the diagnostic UI.

## Build and security design

The Dockerfile becomes the build source of truth, uses BuildKit's target architecture, and verifies the Alloy release ZIP with its publisher-provided SHA-256 digest. The obsolete `build.yaml` is removed. The unused writable `addon_config` mount is removed and a custom AppArmor profile grants the journal reader, persistent storage, and network access required by Alloy.

## Verification

Repository tests render the unauthenticated default plus Basic and bearer configurations, reject incomplete advanced authentication, verify parser ordering and anchored HA matching, and check that secrets are absent from logs. CI runs those tests, ShellCheck, the Home Assistant app linter, Alloy configuration validation, and multi-architecture image builds.

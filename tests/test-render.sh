#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RENDERER=${ROOT_DIR}/alloy/rootfs/usr/local/bin/render-alloy-config
TMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file=$1
    local expected=$2
    grep -Fq -- "${expected}" "${file}" || fail "${file} does not contain: ${expected}"
}

assert_not_contains() {
    local file=$1
    local unexpected=$2
    if grep -Fq -- "${unexpected}" "${file}"; then
        fail "${file} unexpectedly contains: ${unexpected}"
    fi
}

render_case() {
    local name=$1
    local validate=${2:-true}
    local options=${TMP_DIR}/${name}.json
    local output=${TMP_DIR}/${name}.alloy
    local log=${TMP_DIR}/${name}.log

    "${RENDERER}" "${options}" "${output}" /var/log/journal >"${log}" 2>&1
    if [[ "${validate}" == "true" && -n "${ALLOY_BIN:-}" ]]; then
        "${ALLOY_BIN}" validate "${output}"
    fi
}

command -v jq >/dev/null || fail "jq is required"
bash -n "${RENDERER}"

cat >"${TMP_DIR}/plain.json" <<'JSON'
{
  "loki_url": "http://10.0.0.20:3100/loki/api/v1/push",
  "advanced_auth": false,
  "auth_type": "basic",
  "auth_username": "ignored-user",
  "auth_password": "ignored-secret",
  "log_level": "info",
  "journal_priority_as_level": true,
  "parse_ha_log_level": true,
  "parse_app_log_level": true,
  "journal_max_age": "24h"
}
JSON
render_case plain
assert_contains "${TMP_DIR}/plain.alloy" 'url = "http://10.0.0.20:3100/loki/api/v1/push"'
assert_contains "${TMP_DIR}/plain.alloy" 'max_age       = "24h"'
assert_contains "${TMP_DIR}/plain.log" 'authentication: none'
assert_not_contains "${TMP_DIR}/plain.alloy" 'basic_auth'
assert_not_contains "${TMP_DIR}/plain.alloy" 'bearer_token'
assert_not_contains "${TMP_DIR}/plain.alloy" 'ignored-secret'
assert_not_contains "${TMP_DIR}/plain.log" '10.0.0.20'
[[ $(stat -c '%a' "${TMP_DIR}/plain.alloy") == 600 ]] || fail "rendered config is not mode 0600"

ha_line=$(grep -n -m1 '(?P<ha_level>' "${TMP_DIR}/plain.alloy" | cut -d: -f1)
app_line=$(grep -n -m1 '(?P<app_level>' "${TMP_DIR}/plain.alloy" | cut -d: -f1)
strip_line=$(grep -n -m1 'stage.replace' "${TMP_DIR}/plain.alloy" | cut -d: -f1)
multiline_line=$(grep -n -m1 'stage.multiline' "${TMP_DIR}/plain.alloy" | cut -d: -f1)
((ha_line < app_line)) || fail "generic app parsing must run after HA parsing"
((strip_line < ha_line)) || fail "ANSI stripping must run before HA parsing"
((strip_line < multiline_line)) || fail "ANSI stripping must run before multiline joining"
((multiline_line < ha_line)) || fail "multiline joining must run before HA parsing"
assert_contains "${TMP_DIR}/plain.alloy" 'firstline     = "^(?:\\x1b\\[[0-9;]*m)*(?:\\[[^]]+\\]|[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2})"'
assert_contains "${TMP_DIR}/plain.alloy" 'max_wait_time = "3s"'
assert_contains "${TMP_DIR}/plain.alloy" 'expression = "(\\x1b\\[[0-9;]*m)"'
assert_contains "${TMP_DIR}/plain.alloy" 'expression = "^(?:\\x1b\\[[0-9;]*m)*(?:\\[[^]]+\\]|[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][^ ]+)\\s+'
assert_contains "${TMP_DIR}/plain.alloy" '(?P<ha_level>DEBUG|INFO|WARNING|WARN|ERROR|CRITICAL)'
assert_contains "${TMP_DIR}/plain.alloy" '{{ if eq .ha_level \"WARN\" }}warning{{ else }}{{ ToLower .ha_level }}{{ end }}'
assert_contains "${TMP_DIR}/plain.alloy" 'selector = "{container_name=~\"homeassistant|hassio_supervisor\"}"'
assert_not_contains "${TMP_DIR}/plain.alloy" '|= \" ERROR \"'
assert_contains "${TMP_DIR}/plain.alloy" 'target_label  = "journal_priority"'
assert_contains "${TMP_DIR}/plain.alloy" 'regex         = "emerg|alert|crit|critical|err|error"'
assert_contains "${TMP_DIR}/plain.alloy" 'else if or (eq .app_level \"warn\") (eq .app_level \"warning\") }}warning'
assert_contains "${TMP_DIR}/plain.alloy" 'else }}critical{{ end }}'

for journal_priority in true false; do
    for parse_ha in true false; do
        for parse_app in true false; do
            name="matrix-${journal_priority}-${parse_ha}-${parse_app}"
            jq -n \
                --argjson journal_priority "${journal_priority}" \
                --argjson parse_ha "${parse_ha}" \
                --argjson parse_app "${parse_app}" \
                '{
                  loki_url: "http://loki.local:3100/loki/api/v1/push",
                  advanced_auth: false,
                  journal_priority_as_level: $journal_priority,
                  parse_ha_log_level: $parse_ha,
                  parse_app_log_level: $parse_app
                }' >"${TMP_DIR}/${name}.json"
            render_case "${name}"
        done
    done
done
assert_not_contains "${TMP_DIR}/matrix-false-false-false.alloy" 'target_label  = "journal_priority"'
assert_not_contains "${TMP_DIR}/matrix-false-false-false.alloy" '(?P<ha_level>'
assert_not_contains "${TMP_DIR}/matrix-false-false-false.alloy" '(?P<app_level>'

cat >"${TMP_DIR}/no-strip.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "strip_ansi_colors": false
}
JSON
render_case no-strip
assert_not_contains "${TMP_DIR}/no-strip.alloy" 'stage.replace'

cat >"${TMP_DIR}/no-multiline.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "multiline_python_logs": false
}
JSON
render_case no-multiline
assert_not_contains "${TMP_DIR}/no-multiline.alloy" 'stage.multiline'

# drop_message_regex is absent by default: only the blank-line drop exists
[[ $(grep -Fc 'stage.drop' "${TMP_DIR}/plain.alloy") == 1 ]] \
    || fail "default config must contain exactly one stage.drop (blank-line filter)"

cat >"${TMP_DIR}/drop-regex.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "drop_message_regex": "Unable to (create object|register device interface) |proctitle=2F63726F"
}
JSON
render_case drop-regex
assert_contains "${TMP_DIR}/drop-regex.alloy" 'expression = "Unable to (create object|register device interface) |proctitle=2F63726F"'
[[ $(grep -Fc 'stage.drop' "${TMP_DIR}/drop-regex.alloy") == 2 ]] \
    || fail "drop_message_regex must add a second stage.drop"
drop_line=$(grep -n 'proctitle=2F63726F' "${TMP_DIR}/drop-regex.alloy" | cut -d: -f1)
strip_line=$(grep -n -m1 'stage.replace' "${TMP_DIR}/drop-regex.alloy" | cut -d: -f1)
multiline_line=$(grep -n -m1 'stage.multiline' "${TMP_DIR}/drop-regex.alloy" | cut -d: -f1)
((strip_line < drop_line)) || fail "user drop must run after ANSI stripping"
((drop_line < multiline_line)) || fail "user drop must run before multiline joining"

# Quotes and backslashes in the regex must be escaped, not break the config
cat >"${TMP_DIR}/drop-escape.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "drop_message_regex": "said \"hi\" \\d+ times$"
}
JSON
render_case drop-escape
assert_contains "${TMP_DIR}/drop-escape.alloy" 'expression = "said \"hi\" \\d+ times$"'

cat >"${TMP_DIR}/python-extra.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "parse_ha_log_level": true,
  "parse_python_log_containers": "addon_5c53de3b_esphome|addon_core_matter_server"
}
JSON
render_case python-extra
assert_contains "${TMP_DIR}/python-extra.alloy" 'selector = "{container_name=~\"homeassistant|hassio_supervisor|addon_5c53de3b_esphome|addon_core_matter_server\"}"'
# The extended selector must apply to both the multiline stage and the HA parser
[[ $(grep -Fc 'selector = "{container_name=~\"homeassistant|hassio_supervisor|addon_5c53de3b_esphome|addon_core_matter_server\"}"' "${TMP_DIR}/python-extra.alloy") == 2 ]] \
    || fail "extended python selector must appear in both the multiline and HA parsing stages"

cat >"${TMP_DIR}/python-invalid.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "parse_ha_log_level": true,
  "parse_python_log_containers": "bad\"container"
}
JSON
if "${RENDERER}" "${TMP_DIR}/python-invalid.json" "${TMP_DIR}/python-invalid.alloy" /var/log/journal >"${TMP_DIR}/python-invalid.log" 2>&1; then
    fail "parse_python_log_containers with a quote was accepted"
fi
assert_contains "${TMP_DIR}/python-invalid.log" 'parse_python_log_containers may only contain'

cat >"${TMP_DIR}/basic.json" <<'JSON'
{
  "loki_url": "https://logs.example.test/loki/api/v1/push",
  "advanced_auth": true,
  "auth_type": "basic",
  "auth_username": "user\"name",
  "auth_password": "p@ss\\word",
  "parse_ha_log_level": false,
  "parse_app_log_level": true
}
JSON
render_case basic
assert_contains "${TMP_DIR}/basic.alloy" 'basic_auth {'
assert_contains "${TMP_DIR}/basic.alloy" 'username = "user\"name"'
assert_contains "${TMP_DIR}/basic.alloy" 'password = "p@ss\\word"'
assert_contains "${TMP_DIR}/basic.log" 'authentication: basic'
assert_not_contains "${TMP_DIR}/basic.log" 'p@ss'
assert_not_contains "${TMP_DIR}/basic.log" 'logs.example.test'

cat >"${TMP_DIR}/bearer.json" <<'JSON'
{
  "loki_url": "https://gateway.example.test/loki/api/v1/push",
  "advanced_auth": true,
  "auth_type": "bearer",
  "bearer_token": "token-value",
  "tenant_id": "home-lab",
  "parse_ha_log_level": false,
  "parse_app_log_level": false
}
JSON
render_case bearer
assert_contains "${TMP_DIR}/bearer.alloy" 'bearer_token = "token-value"'
assert_contains "${TMP_DIR}/bearer.alloy" 'tenant_id = "home-lab"'
assert_contains "${TMP_DIR}/bearer.log" 'authentication: bearer'
assert_not_contains "${TMP_DIR}/bearer.log" 'token-value'
assert_not_contains "${TMP_DIR}/bearer.log" 'gateway.example.test'

ca_pem=$(awk '/BEGIN CERTIFICATE/{found=1} found{print} /END CERTIFICATE/{if(found) exit}' /etc/ssl/certs/ca-certificates.crt)
jq -n --arg ca_pem "${ca_pem}" '{
  loki_url: "https://loki.example.test/loki/api/v1/push",
  advanced_auth: true,
  auth_type: "bearer",
  bearer_token: "token-value",
  tls_ca_pem: $ca_pem
}' >"${TMP_DIR}/custom-ca.json"
render_case custom-ca
assert_contains "${TMP_DIR}/custom-ca.alloy" 'tls_config {'
assert_contains "${TMP_DIR}/custom-ca.alloy" 'ca_pem = "-----BEGIN CERTIFICATE-----\n'

cat >"${TMP_DIR}/additional.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "additional_config": "// custom marker\nlogging { format = \"json\" }"
}
JSON
render_case additional false
assert_contains "${TMP_DIR}/additional.alloy" '// --- Additional user config ---'
assert_contains "${TMP_DIR}/additional.alloy" '// custom marker'

cat >"${TMP_DIR}/missing-basic.json" <<'JSON'
{
  "loki_url": "https://logs.example.test/loki/api/v1/push",
  "advanced_auth": true,
  "auth_type": "basic",
  "auth_username": "user"
}
JSON
if "${RENDERER}" "${TMP_DIR}/missing-basic.json" "${TMP_DIR}/missing-basic.alloy" /var/log/journal >"${TMP_DIR}/missing-basic.log" 2>&1; then
    fail "incomplete Basic authentication was accepted"
fi
assert_contains "${TMP_DIR}/missing-basic.log" 'requires auth_username and auth_password'

cat >"${TMP_DIR}/missing-bearer.json" <<'JSON'
{
  "loki_url": "https://logs.example.test/loki/api/v1/push",
  "advanced_auth": true,
  "auth_type": "bearer"
}
JSON
if "${RENDERER}" "${TMP_DIR}/missing-bearer.json" "${TMP_DIR}/missing-bearer.alloy" /var/log/journal >"${TMP_DIR}/missing-bearer.log" 2>&1; then
    fail "incomplete bearer authentication was accepted"
fi
assert_contains "${TMP_DIR}/missing-bearer.log" 'requires bearer_token'

for bad_age in "0h" "0" "0h0m" "-5h"; do
    jq -n --arg age "${bad_age}" '{
      loki_url: "http://loki.local:3100/loki/api/v1/push",
      advanced_auth: false,
      journal_max_age: $age
    }' >"${TMP_DIR}/bad-age.json"
    if "${RENDERER}" "${TMP_DIR}/bad-age.json" "${TMP_DIR}/bad-age.alloy" /var/log/journal >"${TMP_DIR}/bad-age.log" 2>&1; then
        fail "journal_max_age '${bad_age}' was accepted"
    fi
    assert_contains "${TMP_DIR}/bad-age.log" 'journal_max_age must be a positive duration'
done

# Fractional durations with a leading zero are valid and must not be rejected
cat >"${TMP_DIR}/frac-age.json" <<'JSON'
{
  "loki_url": "http://loki.local:3100/loki/api/v1/push",
  "advanced_auth": false,
  "journal_max_age": "0.5h"
}
JSON
render_case frac-age
assert_contains "${TMP_DIR}/frac-age.alloy" 'max_age       = "0.5h"'

cat >"${TMP_DIR}/missing-url.json" <<'JSON'
{
  "advanced_auth": false
}
JSON
if "${RENDERER}" "${TMP_DIR}/missing-url.json" "${TMP_DIR}/missing-url.alloy" /var/log/journal >"${TMP_DIR}/missing-url.log" 2>&1; then
    fail "missing loki_url was accepted"
fi
assert_contains "${TMP_DIR}/missing-url.log" 'loki_url must be configured'

printf 'All render tests passed\n'

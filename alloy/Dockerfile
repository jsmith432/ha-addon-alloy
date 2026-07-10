ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23

FROM alpine:3.23 AS alloy-downloader

ARG TARGETARCH
ARG BUILD_ARCH
ARG ALLOY_VERSION=1.17.1
ARG ALLOY_SHA256_AMD64=b92bfa2815a0a2c51477b4965d1ace3bf2ffc7b841e1361bd4cda6069e8c65bd
ARG ALLOY_SHA256_ARM64=730d41d959c2e759d088c8b3d2dab6e8fa37b39ab04dd6a6a9ddbcc3eddb5836

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk add --no-cache ca-certificates curl unzip

RUN set -eux; \
    target_arch="${TARGETARCH:-${BUILD_ARCH:-}}"; \
    case "${target_arch}" in \
        amd64) alloy_arch="linux-amd64"; alloy_sha256="${ALLOY_SHA256_AMD64}" ;; \
        arm64|aarch64) alloy_arch="linux-arm64"; alloy_sha256="${ALLOY_SHA256_ARM64}" ;; \
        *) echo "Unsupported target architecture: ${target_arch}" >&2; exit 1 ;; \
    esac; \
    archive="alloy-${alloy_arch}.zip"; \
    curl -fsSL "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/${archive}" -o "/tmp/${archive}"; \
    printf '%s  %s\n' "${alloy_sha256}" "/tmp/${archive}" | sha256sum -c -; \
    unzip "/tmp/${archive}" -d /tmp/alloy; \
    mkdir -p /out; \
    mv "/tmp/alloy/alloy-${alloy_arch}" /out/alloy; \
    chmod 0755 /out/alloy

FROM ${BUILD_FROM}

ARG BUILD_VERSION=dev

RUN apk add --no-cache ca-certificates jq

COPY --from=alloy-downloader /out/alloy /usr/bin/alloy
COPY rootfs /

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:12345/-/ready || exit 1

LABEL \
    io.hass.type="app" \
    io.hass.name="Grafana Alloy" \
    io.hass.description="Ship HAOS logs to Loki via Grafana Alloy" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="Home Assistant App: Grafana Alloy" \
    org.opencontainers.image.description="Ship Home Assistant OS logs to Loki via Grafana Alloy" \
    org.opencontainers.image.source="https://github.com/jsmith432/ha-addon-alloy" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="${BUILD_VERSION}"

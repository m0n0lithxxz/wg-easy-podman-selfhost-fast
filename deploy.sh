#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${REPO_DIR}/.env"
SYSTEMD_DIR="/etc/containers/systemd"
PASSWORD_FILE="${HOME}/.wg-easy/credentials"

log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[deploy][error]\033[0m %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

# --- resolve sudo -----------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  sudo -n true 2>/dev/null || die "need passwordless sudo (sudo -n). Run as a non-root user with passwordless sudo."
  SUDO="sudo"
fi
priv() { $SUDO "$@"; }

# --- load .env --------------------------------------------------------------
[ -f "$ENV_FILE" ] || die "missing .env (cp .env.example .env and edit)"
set -a
. "$ENV_FILE"
set +a

# --- defaults ---------------------------------------------------------------
WG_PORT="${WG_PORT:-51820}"
WEB_UI_PORT="${WEB_UI_PORT:-51821}"
DNS="${DNS:-9.9.9.9,149.112.112.112}"
ALLOWED_IPS="${ALLOWED_IPS:-0.0.0.0/0,::/0}"
IPV4_CIDR="${IPV4_CIDR:-10.8.0.0/24}"
IPV6_CIDR="${IPV6_CIDR:-fd00:db8::/64}"
WG_USERNAME="${WG_USERNAME:-admin}"
WG_CONFIG="${WG_CONFIG:-/srv/wg-easy/config}"
CADDY_CONFIG="${CADDY_CONFIG:-/srv/wg-easy/caddy}"
ACME_EMAIL="${ACME_EMAIL:-}"
TORRENT_PORT="${TORRENT_PORT:-}"
TORRENT_CLIENT_IP="${TORRENT_CLIENT_IP:-}"

[ -n "${WG_HOST:-}" ] || die "WG_HOST is required (your domain)."

if [ -r /etc/os-release ]; then
  . /etc/os-release
  log "host: ${PRETTY_NAME:-unknown}"
fi

# --- dependency check ------------------------------------------------------
log "checking dependencies..."
for cmd in bash grep awk sed tr; do
  command -v "$cmd" >/dev/null 2>&1 || die "missing required tool: $cmd"
done

if ! command -v podman >/dev/null 2>&1; then
  log "installing podman..."
  priv apt-get update -y
  priv apt-get install -y podman
fi
log "podman version: $(podman --version 2>/dev/null | awk '{print $3}')"

log "ensuring wireguard kernel module..."
if ! priv modprobe wireguard 2>/dev/null; then
  log "installing linux-modules-extra-$(uname -r)..."
  priv apt-get install -y "linux-modules-extra-$(uname -r)"
  priv modprobe wireguard || die "failed to load wireguard kernel module"
fi

if ! command -v ufw >/dev/null 2>&1; then
  log "installing ufw..."
  priv apt-get install -y ufw
fi

# --- sysctls ---------------------------------------------------------------
log "applying sysctls..."
priv tee /etc/sysctl.d/99-wg-easy.conf >/dev/null <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF
priv sysctl --system >/dev/null

# --- firewall (ufw) --------------------------------------------------------
SSH_PORT="$(awk '/^[[:space:]]*Port[[:space:]]+/{print $2; exit}' /etc/ssh/sshd_config 2>/dev/null)"
SSH_PORT="${SSH_PORT:-22}"
log "configuring ufw (allowing ssh ${SSH_PORT}/tcp)..."
priv ufw allow "${SSH_PORT}/tcp"
priv ufw allow 80/tcp
priv ufw allow 443/tcp
priv ufw allow "${WG_PORT}/udp"
if [ -n "${TORRENT_PORT:-}" ]; then
  priv ufw allow "${TORRENT_PORT}/tcp"
  priv ufw allow "${TORRENT_PORT}/udp"
fi
if ! priv ufw status 2>/dev/null | grep -q "Status: active"; then
  log "enabling ufw..."
  priv ufw --force enable
fi

# --- admin password ---------------------------------------------------------
mkdir -p "$(dirname "$PASSWORD_FILE")"
umask 077
if [ -z "${WG_PASSWORD:-}" ]; then
  if [ -f "$PASSWORD_FILE" ]; then
    WG_PASSWORD="$(grep -oP '^WG_PASSWORD=\K.*' "$PASSWORD_FILE" || true)"
  else
    WG_PASSWORD="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'WG_PASSWORD=%s\n' "$WG_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    log "generated admin password -> $PASSWORD_FILE"
  fi
fi

# --- directories -----------------------------------------------------------
log "preparing directories..."
priv mkdir -p "$WG_CONFIG" "$CADDY_CONFIG/data" "$CADDY_CONFIG/config"

# --- systemd unit directory ------------------------------------------------
priv mkdir -p "$SYSTEMD_DIR"

# --- decide whether this is an initial deployment ---------------------------
WITH_INIT=0
[ -f "${WG_CONFIG}/wg0.conf" ] || WITH_INIT=1

write_wg_unit() {
  local include_init="$1"
  if [ "$include_init" = "1" ]; then
    priv tee "$SYSTEMD_DIR/wg-easy.container" >/dev/null <<EOF
[Unit]
Description=wg-easy (WireGuard + Web UI)
Wants=network-online.target
After=network-online.target

[Container]
Image=ghcr.io/wg-easy/wg-easy:15
ContainerName=wg-easy
Network=host
Volume=${WG_CONFIG}:/etc/wireguard
Volume=/lib/modules:/lib/modules:ro
AddCapability=NET_ADMIN SYS_MODULE NET_RAW
Environment=PORT=${WEB_UI_PORT}
Environment=HOST=0.0.0.0
Environment=INSECURE=true
Environment=DISABLE_IPV6=false
Environment=INIT_ENABLED=true
Environment=INIT_USERNAME=${WG_USERNAME}
Environment=INIT_PASSWORD=${WG_PASSWORD}
Environment=INIT_HOST=${WG_HOST}
Environment=INIT_PORT=51820
Environment=INIT_DNS=${DNS}
Environment=INIT_IPV4_CIDR=${IPV4_CIDR}
Environment=INIT_IPV6_CIDR=${IPV6_CIDR}
Environment=INIT_ALLOWED_IPS=${ALLOWED_IPS}
Label=io.containers.autoupdate=registry

[Service]
Restart=unless-stopped
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF
  else
    priv tee "$SYSTEMD_DIR/wg-easy.container" >/dev/null <<EOF
[Unit]
Description=wg-easy (WireGuard + Web UI)
Wants=network-online.target
After=network-online.target

[Container]
Image=ghcr.io/wg-easy/wg-easy:15
ContainerName=wg-easy
Network=host
Volume=${WG_CONFIG}:/etc/wireguard
Volume=/lib/modules:/lib/modules:ro
AddCapability=NET_ADMIN SYS_MODULE NET_RAW
Environment=PORT=${WEB_UI_PORT}
Environment=HOST=0.0.0.0
Environment=INSECURE=true
Environment=DISABLE_IPV6=false
Label=io.containers.autoupdate=registry

[Service]
Restart=unless-stopped
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF
  fi
}

write_caddy_unit() {
  priv tee "$SYSTEMD_DIR/caddy.container" >/dev/null <<EOF
[Unit]
Description=Caddy reverse proxy for wg-easy
Wants=network-online.target
After=network-online.target
Requires=wg-easy.service
After=wg-easy.service

[Container]
Image=docker.io/library/caddy:2-alpine
ContainerName=caddy
Network=host
Volume=${CADDY_CONFIG}/Caddyfile:/etc/caddy/Caddyfile:ro
Volume=${CADDY_CONFIG}/data:/data
Volume=${CADDY_CONFIG}/config:/config
Label=io.containers.autoupdate=registry

[Service]
Restart=unless-stopped
[Install]
WantedBy=multi-user.target
EOF
}

write_caddyfile() {
  if [ -n "$ACME_EMAIL" ]; then
    priv tee "${CADDY_CONFIG}/Caddyfile" >/dev/null <<EOF
{
    email ${ACME_EMAIL}
}
${WG_HOST} {
    reverse_proxy 127.0.0.1:${WEB_UI_PORT}
}
EOF
  else
    priv tee "${CADDY_CONFIG}/Caddyfile" >/dev/null <<EOF
${WG_HOST} {
    reverse_proxy 127.0.0.1:${WEB_UI_PORT}
}
EOF
  fi
}

setup_dnat() {
  if [ -z "${TORRENT_PORT:-}" ] && [ -z "${TORRENT_CLIENT_IP:-}" ]; then
    return
  fi
  if [ -z "${TORRENT_PORT:-}" ] || [ -z "${TORRENT_CLIENT_IP:-}" ]; then
    err "TORRENT_PORT and TORRENT_CLIENT_IP must both be set to enable port forwarding; skipping"
    return
  fi
  log "adding iptables DNAT ${TORRENT_PORT} (tcp+udp) -> ${TORRENT_CLIENT_IP}"
  for proto in tcp udp; do
    if ! priv iptables -t nat -C PREROUTING -p "$proto" --dport "$TORRENT_PORT" -j DNAT --to-destination "${TORRENT_CLIENT_IP}:${TORRENT_PORT}" 2>/dev/null; then
      priv iptables -t nat -I PREROUTING 1 -p "$proto" --dport "$TORRENT_PORT" -j DNAT --to-destination "${TORRENT_CLIENT_IP}:${TORRENT_PORT}"
    fi
    if ! priv iptables -C FORWARD -d "$TORRENT_CLIENT_IP" -p "$proto" --dport "$TORRENT_PORT" -j ACCEPT 2>/dev/null; then
      priv iptables -I FORWARD 1 -d "$TORRENT_CLIENT_IP" -p "$proto" --dport "$TORRENT_PORT" -j ACCEPT
    fi
  done
}

log "writing unit files..."
write_wg_unit "$WITH_INIT"
write_caddy_unit
write_caddyfile

log "reloading systemd and starting services..."
priv systemctl daemon-reload
priv systemctl start wg-easy.service
priv systemctl start caddy.service
priv systemctl enable --now podman-auto-update.timer
setup_dnat

# --- strip INIT_PASSWORD after first successful setup ------------------------
if [ "$WITH_INIT" = "1" ]; then
  log "waiting for wg-easy initial setup..."
  found=0
  for _ in $(seq 1 60); do
    if [ -f "${WG_CONFIG}/wg0.conf" ]; then
      found=1
      break
    fi
    sleep 2
  done
  if [ "$found" = "1" ]; then
    log "initial setup complete; removing INIT_PASSWORD from unit..."
    write_wg_unit "0"
    priv systemctl daemon-reload
    priv systemctl restart wg-easy.service
  else
    err "wg0.conf not detected after startup; check logs: sudo journalctl -u wg-easy.service"
  fi
fi

log "verifying..."
priv podman ps --filter name=wg-easy --filter name=caddy --format 'table {{.Names}}\t{{.Status}}'
log "done. WireGuard UDP ${WG_PORT}, web UI at https://${WG_HOST}"

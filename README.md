# wg-easy-podman-selfhost-fast

Deploy [wg-easy](https://github.com/wg-easy/wg-easy) (WireGuard + web admin UI) on Ubuntu, rootful Podman, Caddy HTTPS. Idempotent, opinionated, systemd.

## Architecture

- wg-easy container: `ghcr.io/wg-easy/wg-easy:15`. Publish WireGuard UDP port only.
- Caddy container: `caddy:2-alpine`. Publish 80/443, terminate TLS, proxy to wg-easy web UI.
- Both on shared Podman network `wg-easy-net`, Quadlet `.container` files in `/etc/containers/systemd/`.
- Images auto-update via `podman-auto-update.timer`.

## Prereq

- Ubuntu 24.04+ VPS. Non-root user w/ passwordless sudo (`sudo -n`).
- Domain A/AAAA record to host.
- Firewall open `80/tcp`, `443/tcp`, `51820/udp`. Script configure via ufw.
- `wireguard` kernel module. Script install `linux-modules-extra-$(uname -r)` if missing.

## Usage

```bash
cp .env.example .env      # set WG_HOST (optional ACME_EMAIL)
./deploy.sh
```

First run: generates strong random admin password, writes `~/.wg-easy/credentials` (mode 600). Strips `INIT_PASSWORD` from unit after setup.

Open `https://<WG_HOST>` to login, manage clients.

## Config

See `.env.example`. Opinionated defaults:

- IPv6 on.
- Full tunnel `0.0.0.0/0,::/0`.
- Quad9 DNS `9.9.9.9,149.112.112.112`.
- Unattended setup via `INIT_*`.
- Config bind mount `/srv/wg-easy`.

## Re-run

`deploy.sh` idempotent. Re-run safe for config change / after reboot. If `wg0.conf` exists in config, skip unattended setup + password strip.

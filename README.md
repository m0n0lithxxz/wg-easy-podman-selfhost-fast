# wg-easy-podman-selfhost-fast

Deploy [wg-easy](https://github.com/wg-easy/wg-easy) (WireGuard + web admin UI) on Ubuntu, rootful Podman, Caddy HTTPS. Idempotent, opinionated, systemd.

## Architecture

- wg-easy container: `ghcr.io/wg-easy/wg-easy:15`. Host network mode; wg0 on host netns.
- Caddy container: `caddy:2-alpine`. Host network mode; 80/443 bind host, proxy to `127.0.0.1:51821`, TLS.
- Quadlet `.container` files in `/etc/containers/systemd/`.
- Images auto-update via `podman-auto-update.timer`.
- Torrent DNAT: iptables forward `TORRENT_PORT` (tcp+udp) to `TORRENT_CLIENT_IP`.

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

## Torrenting (port forward)

Client behind CGNAT? wg-easy run on VPS public IP. Bind torrent client to WireGuard interface, get inbound via forwarded port.

1. In wg-easy Web UI, add torrent client. Note its WireGuard IP (e.g. `10.8.0.2`).
2. Create client config, import, bind torrent client to `wg0` interface.
3. Set `.env`:
   ```
   TORRENT_PORT=51413
   TORRENT_CLIENT_IP=10.8.0.2
   ```
4. `./deploy.sh`. Script open port in ufw, add iptables DNAT tcp+udp to client IP.

Full tunnel default already route all torrent traffic via VPS.

## Config

See `.env.example`. Opinionated defaults:

- IPv6 on.
- Full tunnel `0.0.0.0/0,::/0`.
- Quad9 DNS `9.9.9.9,149.112.112.112`.
- Unattended setup via `INIT_*`.
- Config bind mount `/srv/wg-easy`.

## Re-run

`deploy.sh` idempotent. Re-run safe for config change / after reboot. If `wg0.conf` exists in config, skip unattended setup + password strip.

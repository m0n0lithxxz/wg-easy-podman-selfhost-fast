# wg-easy-podman-selfhost-fast

Deploy [wg-easy](https://github.com/wg-easy/wg-easy) (WireGuard + web admin UI) on Ubuntu with rootful Podman, fronted by Caddy for automatic HTTPS. Idempotent, opinionated defaults, and managed as systemd services.

## Architecture

- **wg-easy** container: `ghcr.io/wg-easy/wg-easy:15`, publishes the WireGuard UDP port only.
- **Caddy** container: `caddy:2-alpine`, publishes ports 80/443 and terminates TLS, proxying to the wg-easy web UI.
- Both run on a shared Podman network (`wg-easy-net`), defined by Quadlet `.container` files in `/etc/containers/systemd/`.
- Images auto-update via `podman-auto-update.timer`.

## Prerequisites

- Ubuntu 24.04+ host (a remote VPS), run as a non-root user with passwordless sudo (`sudo -n`).
- A domain with an `A`/`AAAA` record pointing at the host.
- Firewall open on `80/tcp`, `443/tcp`, and `51820/udp` (host-level or cloud firewall).
- The `wireguard` kernel module available (script installs `linux-modules-extra-$(uname -r)` if needed).

## Usage

```bash
cp .env.example .env      # edit WG_HOST (and ACME_EMAIL if you want cert expiry emails)
./deploy.sh
```

The first run generates a strong random admin password and writes it to `~/.wg-easy/credentials` (mode 600). The `INIT_PASSWORD` is stripped from the unit after the initial setup completes.

After a successful deploy, open `https://<WG_HOST>` to log in and manage clients.

## Configuration

See `.env.example` for all options. The defaults are opinionated:

- IPv6 enabled (dual-stack).
- Full tunnel (`0.0.0.0/0,::/0`).
- Quad9 DNS (`9.9.9.9,149.112.112.112`).
- Unattended setup via `INIT_*` variables.
- Config bind mounts under `/srv/wg-easy`.

## Re-running

`deploy.sh` is idempotent; it is safe to run again to apply config changes or after a reboot. If the config directory already contains `wg0.conf`, it skips the unattended setup and the password removal step.

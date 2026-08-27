# Bind-mount config under /srv/wg-easy and pick opinionated defaults

Configuration is persisted with bind mounts (`WG_CONFIG` to `/etc/wireguard`, `CADDY_CONFIG` for Caddy) rather than named volumes, so the data is easy to back up. Defaults are opinionated: IPv6 enabled, full tunnel (`0.0.0.0/0,::/0`), Quad9 DNS, unattended `INIT_*` setup, and a strong random admin password stored in `~/.wg-easy/credentials`.

Considered and rejected: named volumes (harder to back up), split-tunnel (less convenient), IPv6 disabled (less capable).

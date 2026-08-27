# wg-easy Podman Selfhost Fast

Self-hosted WireGuard VPN with a web admin UI, deployed on Ubuntu via rootful Podman, fronted by Caddy for automatic HTTPS, and managed as systemd services with opinionated defaults.

## Language

**wg-easy**:
The container running WireGuard plus its web admin UI, bundled in a single image.
_Avoid_: wg_easy, wgeasy, wireguard-easy

**Quadlet**:
A `.container` (or `.network`) file describing a Podman container as a systemd service. Podman's generator turns it into a systemd unit.
_Avoid_: compose file, generic systemd unit file

**Rootful Podman**:
Podman running as root, so services run as system units and can create network interfaces and load kernel modules directly.
_Avoid_: rootless (the opposite mode)

**Caddy**:
A separate container that terminates TLS with automatically issued certificates and reverse-proxies the wg-easy web UI.
_Avoid_: generic reverse proxy

**INSECURE**:
The wg-easy flag that serves the web UI over plain HTTP so an external reverse proxy can terminate TLS.
_Avoid_: insecure (colloquial)

**WG_HOST**:
The public domain or IP that VPN clients connect to. Used both as the WireGuard endpoint and as the Caddy certificate domain.
_Avoid_: host, domain (ambiguous)

**Unattended setup (INIT_\*)**:
Environment variables that configure wg-easy automatically on first start, skipping the setup wizard.
_Avoid_: wizard, init script

**Full tunnel**:
VPN routing mode where all client traffic is routed through the server.
_Avoid_: full vpn, all traffic

**AllowedIPs**:
The client-side routing list controlling which destinations traverse the VPN.
_Avoid_: routes, allowed ips

**Quad9**:
The default DNS resolver handed to clients (`9.9.9.9`, `149.112.112.112`).
_Avoid_: DNS resolver (ambiguous)

**Bind mount**:
A host directory mapped into the container; wg-easy config lives at `WG_CONFIG`, Caddy config at `CADDY_CONFIG`.
_Avoid_: named volume (the opposite), volume (generic)

**Auto-update**:
Podman's `io.containers.autoupdate=registry` label combined with the `podman-auto-update.timer`, which pulls new images on a schedule.
_Avoid_: watchtower, cron

**Host network mode**:
The wg-easy and Caddy containers share the host network namespace, so the WireGuard interface `wg0` lives on the host and host iptables can forward a public port to a WireGuard peer.
_Avoid_: bridge network (the mode that puts `wg0` inside a container netns)

**DNAT**:
An iptables rule that rewrites a public TCP/UDP port to a target address, used here to forward an incoming torrent port to a client's WireGuard IP.
_Avoid_: port redirect, NAT rule (generic)

**Port forwarding (torrent)**:
Routing an incoming public port on the VPS to a client's WireGuard interface, so a client behind CGNAT can accept inbound torrent connections.
_Avoid_: inbound connections, open port (generic)

**CGNAT**:
A client environment with no public IP address. The reason traffic is routed through the VPS, which has one.
_Avoid_: double NAT (narrower)

**TORRENT_PORT / TORRENT_CLIENT_IP**:
Configuration for the forwarded public port and the WireGuard IP of the torrent client.
_Avoid_: listen port, client ip (ambiguous on their own)

# Terminate TLS with a separate Caddy container

wg-easy only serves HTTP, and we own a domain and want automatic certificates. We run a Caddy container that publishes ports 80 and 443, reverse-proxies the wg-easy web UI on the internal port, and leaves wg-easy running with `INSECURE=true`. The wg-easy web UI is therefore only reachable over HTTPS through Caddy, not directly on the host.

Consequences: an extra container and shared Podman network, and the admin UI cannot be reached over plain HTTP on the LAN.

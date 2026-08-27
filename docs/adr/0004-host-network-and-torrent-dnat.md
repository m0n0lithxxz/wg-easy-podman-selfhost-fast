# Use host network mode and iptables DNAT for torrent port forwarding

The client sits behind CGNAT, so torrenting needs inbound connections. In bridge network mode the WireGuard interface is created inside the container netns, which the host cannot DNAT to; a public port cannot be forwarded to a WireGuard peer. We run wg-easy and Caddy in host network mode so `wg0` lives in the host netns, and we add idempotent iptables DNAT rules forwarding the chosen torrent port (TCP and UDP) to the torrent client's WireGuard IP.

Considered and rejected: bridge mode with a host route into the container (fragile, asymmetric). Consequences: less container isolation, and wg-easy manages host iptables rules alongside ufw.

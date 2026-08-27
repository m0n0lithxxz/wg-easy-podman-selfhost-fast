# Use Podman Quadlet systemd services instead of a compose file

wg-easy ships an official `docker-compose.yml`, but the target host is Ubuntu and we want services that start on boot, are idempotent to deploy, and need no extra tooling beyond Podman itself. We use Quadlet `.container` files in `/etc/containers/systemd`, which Podman's generator turns into systemd units, and enable `podman-auto-update.timer` for image updates.

Considered and rejected: `docker-compose` / `podman-compose`. They require an additional plugin and provide weaker, non-native systemd integration.

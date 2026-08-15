# Template for qbt's config, rendered on demand by the `qbt` wrapper in .zshrc.
# Credentials are 1Password references resolved by `op inject` into a FIFO, so
# no rendered copy of this file should ever exist on disk or in this repo.
[qbittorrent]
addr       = "http://127.0.0.1:8113" # via ssh-tunnel-proxy; the public host is behind Authelia
login      = "{{ op://Private/e7ybn66467d3xwtphfh3svy3i4/username }}"
password   = "{{ op://Private/e7ybn66467d3xwtphfh3svy3i4/password }}"

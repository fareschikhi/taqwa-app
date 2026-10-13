# Caddy with the DuckDNS plugin, so it can prove it owns the domain through
# DNS. That gets a certificate without the router having to open port 80.
FROM caddy:2.10.2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/duckdns

FROM caddy:2.10.2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

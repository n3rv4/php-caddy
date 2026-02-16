# php-caddy

Docker image that bundles **PHP-FPM** and **Caddy** in a single container, supervised by **supervisord**.

This repository is primarily intended to build/publish the image `n3rv4/php-caddy` (see `.github/workflows/docker-image.yml`).

## Image tags

The CI workflow builds and pushes these tags:

- `n3rv4/php-caddy:8.5`
- `n3rv4/php-caddy:<git-sha>`

## What's inside

- Base: `php:8.5-fpm-alpine`
- Web server: Caddy (built via `xcaddy`)
- Process manager: supervisord (runs PHP-FPM + Caddy)
- Document root: `/app` (public directory is typically `/app/public`)
- Included PHP extensions (see `Dockerfile` for the full list): `gd`, `intl`, `zip`, `xsl`, `opcache`, `ldap`, `mbstring`, `pdo_mysql`, `redis`, `pcntl`, `sysvsem`, plus Composer

## Quick start (Docker Compose)

The repo includes a minimal example under `test/`.

1. Update the site address in `test/Caddyfile` to match your machine (for example, use `localhost` or `:80`).
2. Start the container:

```bash
docker compose up
```

3. Open:
- HTTP: `http://localhost`
- HTTPS (if enabled by your Caddyfile): `https://localhost`

Notes:
- `compose.yaml` mounts `test/public` into `/app/public` and `test/Caddyfile` into `/etc/caddy/Caddyfile`.
- If you don't publish a `latest` tag, pin the image in `compose.yaml` (for example `n3rv4/php-caddy:8.5`).
- `tty: true` is enabled in `compose.yaml` to make logs easier to read in dev; remove it for production usage.

## Running without Compose

Prerequisite: the Dockerfile uses Docker Hardened Images (`dhi.io/*`). Authenticate first:

```bash
docker login dhi.io
```

Build locally:

```bash
docker build -t php-caddy:local .
```

Run with bind-mounts for your Caddyfile and public directory:

```bash
docker run --rm -p 80:80 -p 443:443 \
  -v "$PWD/test/Caddyfile:/etc/caddy/Caddyfile" \
  -v "$PWD/test/public:/app/public" \
  php-caddy:local
```

## Caddyfile notes (PHP)

- Caddy reads `/etc/caddy/Caddyfile`.
- PHP-FPM runs inside the same container. Your Caddyfile must point `php_fastcgi` to the PHP-FPM listener you configured.
  - If you use the provided pool config `config/fpm-pool.conf`, PHP-FPM listens on the unix socket `/run/php/php-fpm.sock`.
  - If you prefer TCP (for example `127.0.0.1:9000`), adjust the PHP-FPM pool configuration accordingly.

Example (unix socket):

```caddyfile
localhost {
    root * /app/public
    php_fastcgi unix//run/php/php-fpm.sock
    file_server
}
```

## Customization

- PHP settings: edit `config/php.ini` (or build a derived image that overwrites `/usr/local/etc/php/conf.d/custom.ini`).
- PHP-FPM pool: edit `config/fpm-pool.conf` (or build a derived image that overwrites `/usr/local/etc/php-fpm.d/zzz.conf`).
- supervisord: the main config is `config/supervisord.conf`. Additional programs can be dropped into `/.config/supervisord/*.conf` (mount a volume or extend the image).
- Startup hook: `/.config/startup/startup.sh` runs `/.config/startup/init_app.sh` before starting supervisord. Override `init_app.sh` if you need app-specific init (migrations, cache warmup, etc.).

## Ports

- `80/tcp` HTTP
- `443/tcp` HTTPS

## Logs

- PHP-FPM logs to stdout/stderr via supervisord.
- Caddy logs are configured in `config/supervisord.conf` (see `/var/log/caddy.out.log` and `/var/log/caddy.err.log` inside the container).

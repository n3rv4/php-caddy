# Install Caddy
FROM docker.io/caddy:builder-alpine AS caddy-builder
ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct
RUN xcaddy build


# Install PHP
FROM docker.io/alpine
# Setup document root
WORKDIR /app

RUN apk add mariadb-client

# Get caddy
COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy

# Install packages and remove default server definition
RUN apk add --no-cache \
  curl \
  php83 \
  php83-ctype \
  php83-curl \
  php83-dom \
  php83-fpm \
  php83-gd \
  php83-intl \
  php83-sodium \
  php83-mbstring \
  php83-mysqli \
  php83-opcache \
  php83-openssl \
  php83-phar \
  php83-session \
  php83-xml \
  php83-xmlreader \
  php83-zlib \
  php83-redis \
  php83-tokenizer \
  php83-fileinfo \
  php83-zip \
  php83-pdo \
  php83-pdo_mysql \
  php83-pdo_pgsql \
  php83-exif \
  php83-xmlwriter \
  php83-simplexml \
  php83-sysvsem \
  php83-iconv \
  php83-bcmath \
  supervisor \
  icu-data-full

# Create symlink so programs depending on `php` still function
RUN ln -sf /usr/bin/php83 /usr/bin/php

# Configure PHP-FPM
COPY ./config/fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY ./config/php.ini /etc/php83/conf.d/custom.ini

# Configure supervisord
COPY ./config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN mkdir /.config /.local /app/_startup_config /app/_startup_config/supervisord
RUN chown -R nobody.nobody /app /run /.config /.local

COPY ./init_app.sh 	/app/_startup_config/
RUN chmod a+x /app/_startup_config/*.sh

# Expose the port nginx is reachable on
EXPOSE 80 443

# Let supervisord start caddy & php-fpm
#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
COPY ./docker-entrypoint /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]


# Switch to use a non-root user from here on
USER nobody

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping
# Install Caddy
FROM docker.io/caddy:builder-alpine AS caddy-builder

ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct
RUN xcaddy build


# Install PHP
FROM php:8.3-fpm-alpine

ARG APP_ENV=dev

RUN apk upgrade && apk add --no-cache  \
    bash \
    py3-openpyxl \
    mariadb-client \
    supervisor \
    unzip \
    p7zip \
    ;

# Setup document root
WORKDIR /app

# Get caddy
COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
    gd \
    intl \
    zip \
    xsl \
    opcache \
    ldap \
    mbstring \
    pcntl \
    pdo_mysql \
    redis \
    sysvsem \
    @composer \
    ;

RUN if [ "$APP_ENV" = "dev" ] ; then install-php-extensions xdebug ; fi


# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN mkdir /.config /.config/supervisord /.config/startup

# Configure PHP-FPM
COPY ./config/fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY ./config/php.ini /etc/php83/conf.d/custom.ini

# Configure supervisord
COPY ./config/supervisord.conf /.config/supervisord.conf

# Configure application
COPY ./init_app.sh 	/.config/startup
RUN chmod a+x /.config/startup/*.sh

# Expose the port caddy is reachable on
EXPOSE 80 443

# Let supervisord start caddy & php-fpm
COPY ./docker-entrypoint /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

# Switch to use a non-root user from here on
RUN chown -R nobody.nobody /app /run /.config /var/log

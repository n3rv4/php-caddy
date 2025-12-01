# Install Caddy
FROM docker.io/caddy:builder-alpine AS caddy-builder

ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct
RUN xcaddy build

FROM php:8.4-fpm-alpine

#ARG APP_ENV=dev

# Installer supervisord et les dépendances nécessaires
RUN apk update && \
    apk add --no-cache  \
          supervisor  \
          curl  \
          bash \
          py3-openpyxl \
          mariadb-client \
          unzip \
          p7zip \
          wget \
          ca-certificates \
        && update-ca-certificates;

# Installer Caddy
COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

ENV INSTALL_PHP_EXTENSIONS_DEBUG=1
RUN install-php-extensions \
    gd \
    intl \
    zip \
    xsl \
    opcache \
    ldap \
    mbstring \
    mysqlnd \
    pcntl \
    pdo_mysql \
    redis \
    sysvsem \
    @composer \
    ;

#RUN if [ "$APP_ENV" = "dev" ] ; then install-php-extensions xdebug ; fi

# Créer les répertoires nécessaires
RUN mkdir -p /etc/caddy /.config /.config/php /.config/supervisord /.config/caddy /.config/startup /run/php

# Copier les fichiers de configuration
COPY ./config/supervisord.conf /etc/supervisord.conf
COPY ./config/fpm-pool.conf /usr/local/etc/php-fpm.d/zzz.conf
COPY ./config/php.ini /usr/local/etc/php/conf.d/custom.ini
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Exposer le port 80
EXPOSE 80 443

# Setup document root
WORKDIR /app

# Configure application
COPY ./init_app.sh 	/.config/startup
COPY ./startup.sh /.config/startup
RUN chmod a+x /.config/startup/*.sh

# Switch to use a non-root user from here on
RUN chown -R www-data:www-data /app /run /.config /var/log /run

#RUN export SUPERVISOR_CONFIG=/etc/supervisor/conf.d/supervisord.conf

CMD ["/.config/startup/startup.sh"]
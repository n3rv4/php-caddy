# Caddy (Docker Hardened Image)
FROM dhi.io/caddy:2.10.2 AS caddy

# PHP (Docker Hardened Image)
#
# Note: using a `-dev` tag to keep a package manager available during build
# (supervisor + various OS packages + php-extension installer dependencies).
FROM dhi.io/php:8.5.2-debian13-dev

#ARG APP_ENV=dev

# Install supervisord and required OS dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
          supervisor \
          curl \
          bash \
          python3-openpyxl \
          mariadb-client \
          unzip \
          p7zip-full \
          wget \
          ca-certificates \
        && update-ca-certificates && \
        rm -rf /var/lib/apt/lists/*

# Install Caddy
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy

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
RUN if [ -f "$PHP_INI_DIR/php.ini-production" ]; then mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; fi

# Exposer le port 80
EXPOSE 80 443

# Setup document root
WORKDIR /app

# Configure application
COPY ./init_app.sh 	/.config/startup
COPY ./startup.sh /.config/startup
RUN chmod a+x /.config/startup/*.sh

# Ensure `www-data` exists (supervisord config runs Caddy as `www-data`)
RUN if ! getent passwd www-data >/dev/null; then \
      groupadd -g 82 www-data && useradd -u 82 -g 82 -M -s /usr/sbin/nologin www-data; \
    fi

# Switch to use a non-root user from here on
RUN chown -R www-data:www-data /app /run /.config /var/log /run

#RUN export SUPERVISOR_CONFIG=/etc/supervisor/conf.d/supervisord.conf

CMD ["/.config/startup/startup.sh"]

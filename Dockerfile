# Syntax: docker/dockerfile:1
FROM php:8.3-fpm-alpine

# Set build arguments
ARG NEXTCLOUD_VERSION=30.0.4
ARG TIGRIS_VERSION=v1.2.1

# 1. System Dependencies (Minimal)
RUN apk add --no-cache \
    curl bash ca-certificates caddy supervisor fuse \
    freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev \
    icu-dev postgresql-dev gmp-dev imagemagick imagemagick-dev linux-headers

# 2. PHP Extension Compilation (Required ones)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd intl zip pdo_pgsql opcache gmp bcmath pcntl exif sysvsem

# 3. Redis Extension
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# 4. Install TigrisFS
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
    TIGRIS_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
    TIGRIS_ARCH="arm64"; \
    else \
    TIGRIS_ARCH="amd64"; \
    fi && \
    curl -L "https://github.com/tigrisdata/tigrisfs/releases/download/${TIGRIS_VERSION}/tigrisfs_${TIGRIS_VERSION#v}_linux_${TIGRIS_ARCH}.tar.gz" \
    -o /tmp/tigrisfs.tar.gz && \
    tar -xzf /tmp/tigrisfs.tar.gz -C /usr/local/bin/ && \
    rm /tmp/tigrisfs.tar.gz && \
    chmod +x /usr/local/bin/tigrisfs

# 5. Config Injection (No Nextcloud source here!)
WORKDIR /var/www/html
COPY Caddyfile /etc/caddy/Caddyfile
COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY config/overrides.config.php /tmp/overrides.config.php
RUN chmod +x /entrypoint.sh

# 6. Environment Setup
RUN mkdir -p /mnt/r2/data && chown -R www-data:www-data /mnt/r2 && chown www-data:www-data /var/www/html
ENV NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION}

# 7. Execution Command
CMD ["/entrypoint.sh"]

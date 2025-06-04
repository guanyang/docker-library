FROM php:7.4-fpm-alpine

# 安装系统依赖
RUN apk add --no-cache \
    git \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    bash

# 安装编译工具（临时）
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    g++ \
    make

# 安装 PHP 扩展
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    zip \
    gd \
    opcache

# 创建 Xdebug 日志文件并设置权限
RUN mkdir -p /var/log \
    && touch /var/log/xdebug.log \
    && chown -R www-data:www-data /var/log/xdebug.log \
    && chmod 755 /var/log/xdebug.log

# 安装 Xdebug
RUN pecl install xdebug-3.1.6 && docker-php-ext-enable xdebug

# 清理编译工具
RUN apk del .build-deps

# 安装 Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 设置工作目录
WORKDIR /var/www/html

# 设置权限
RUN chown -R www-data:www-data /var/www/html
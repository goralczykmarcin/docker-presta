FROM php:8.1-fpm

# PHP
RUN apt-get update \
    && apt-get install -y libmcrypt-dev \
        libjpeg62-turbo-dev \
        libpcre3-dev \
        libpng-dev \
        libwebp-dev \
        libfreetype6-dev \
        libxml2-dev \
        libicu-dev \
        libzip-dev \
        default-mysql-client \
        wget \
        unzip \
        libonig-dev

RUN rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ --with-webp=/usr/include
RUN docker-php-ext-install iconv intl pdo_mysql mbstring soap gd zip bcmath

RUN docker-php-source extract \
    && if [ -d "/usr/src/php/ext/mysql" ]; then docker-php-ext-install mysql; fi \
    && if [ -d "/usr/src/php/ext/mcrypt" ]; then docker-php-ext-install mcrypt; fi \
    && if [ -d "/usr/src/php/ext/opcache" ]; then docker-php-ext-install opcache; fi \
    && docker-php-source delete

# Prestashop
ENV PS_VERSION=8.1.4 \
DB_SERVER="<to be defined>" \
DB_PORT=3306 \
DB_NAME=prestashop \ 
DB_USER=root \
DB_PASSWD=admin \
DB_PREFIX=ps_ \
PS_DEV_MODE=0 \
PS_HOST_MODE=0 \
ADMIN_MAIL=demo@prestashop.com \
ADMIN_PASSWD=prestashop_demo \
PS_LANGUAGE=en \
PS_COUNTRY=GB \
PS_FOLDER_ADMIN=admin

# Prepare install and CMD script
COPY config_files/ps-extractor.sh config_files/docker_run.sh /tmp/

ADD https://github.com/PrestaShop/PrestaShop/releases/download/8.1.4/prestashop_8.1.4.zip /tmp/prestashop.zip

RUN mkdir -p /tmp/data-ps \
	&& unzip -q /tmp/prestashop.zip -d /tmp/data-ps/ \
	&& bash /tmp/ps-extractor.sh /tmp/data-ps \
	&& rm /tmp/prestashop.zip

# Run
CMD ["/tmp/docker_run.sh"]

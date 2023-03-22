FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND="noninteractive"
ENV TZ=America/Sao_Paulo
ENV SITE_PATH=/var/www/html/

ARG PHP_VER=8.1

RUN set -ex; \
    AptInstall=" \
        cron \
        git \
        nginx \
        openssl \
        postfix \
        unzip \
        vim \
        zip \
    "; \
    PHPInstall=" \
        php${PHP_VER} \
        php${PHP_VER}-bcmath \
        php${PHP_VER}-bz2 \
        php${PHP_VER}-cgi \
        php${PHP_VER}-cli \
        php${PHP_VER}-common \
        php${PHP_VER}-curl \
        php${PHP_VER}-dba \
        php${PHP_VER}-dom \
        php${PHP_VER}-enchant \
        php${PHP_VER}-fpm \
        php${PHP_VER}-gd \
        php${PHP_VER}-gmp \
        php${PHP_VER}-iconv \
        php${PHP_VER}-interbase \
        php${PHP_VER}-intl \
        php${PHP_VER}-mbstring \
        php${PHP_VER}-mysql \
        php${PHP_VER}-odbc \
        php${PHP_VER}-opcache \
        php${PHP_VER}-pdo \
        php${PHP_VER}-pgsql \
        php${PHP_VER}-phar \
        php${PHP_VER}-pspell \
        php${PHP_VER}-readline \
        php${PHP_VER}-redis \
        php${PHP_VER}-soap \
        php${PHP_VER}-tidy \
        php${PHP_VER}-xml \
        php${PHP_VER}-xsl \
        php${PHP_VER}-zip \
    "; \
    BuildDeps=" \
        apt-transport-https \
        ca-certificates \
        curl \
        procps \
        supervisor \
        tzdata \
        wget \
    "; \
    TempBuildDeps=" \
        apt-utils \
        dirmngr \
        gnupg \
        software-properties-common \
    "; \
    apt update; \
    apt install --no-install-recommends -qy $BuildDeps $TempBuildDeps; \
    wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add -; \
    echo "deb https://packages.sury.org/php/ $(lsb_release -cs) main" >> /etc/apt/sources.list.d/php.list; \
    wget http://nginx.org/keys/nginx_signing.key; apt-key add nginx_signing.key; \
    echo "deb http://nginx.org/packages/debian/ $(lsb_release -cs) nginx" >> /etc/apt/sources.list.d/nginx.list; \
    apt update -q; apt install --no-install-recommends -qy $PHPInstall $AptInstall; \
    \
    mkdir -p /var/log/supervisor; mkdir /run/php; \
    ln -s /usr/sbin/php-fpm${PHP_VER} /usr/sbin/php-fpm; \
    cp /usr/share/zoneinfo/${TZ} /etc/localtime; echo "${TZ}" > /etc/timezone; \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; \
    \
    apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    apt-get purge -y --auto-remove $TempBuildDeps

WORKDIR ${SITE_PATH}

# RUN chown -R nginx:nginx ${SITE_PATH}; \
#     find ${SITE_PATH} -type d -exec chmod 755 {} \; && \
#     find ${SITE_PATH} -type f -exec chmod 644 {} \;

ENV NON_ROOT_USER=magneto
ENV NON_ROOT_GID="103" \
    NON_ROOT_UID="1003" \    
    NON_ROOT_WORK_DIR=/opt/local/${NON_ROOT_USER} \    
    NON_ROOT_HOME_DIR=/home/${NON_ROOT_USER}
    RUN groupadd -g 65532 nonroot && useradd -m -s $NON_ROOT_HOME_DIR -u 65532 $NON_ROOT_USER -g nonroot; \
        usermod -a -G www-data ${NON_ROOT_USER}

RUN chown -R ${NON_ROOT_USER}:www-data ${SITE_PATH} && chmod -R 755 ${SITE_PATH} && \
        chown -R ${NON_ROOT_USER}:www-data /var/cache/nginx && \
        chown -R ${NON_ROOT_USER}:www-data /var/log/nginx && \
        chown -R ${NON_ROOT_USER}:www-data /etc/nginx/conf.d && \
        mkdir /etc/supervisord && \
        chown -R ${NON_ROOT_USER}:www-data /etc/supervisord && \
        chown -R ${NON_ROOT_USER}:www-data /var/run/

RUN touch /var/run/supervisord.pid && \
        chown -R ${NON_ROOT_USER}:www-data /var/run/supervisord.pid;

RUN touch /var/run/nginx.pid && \
        chown -R ${NON_ROOT_USER}:www-data /var/run/nginx.pid; \
        chmod g+wx /var/log/; \    
        mkdir /opt/local/ && chmod g+wx /opt/local/

USER ${NON_ROOT_USER}

COPY ./config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./config/nginx.conf /etc/nginx/nginx.conf
COPY ./config/nginx-default.conf /etc/nginx/conf.d/default.conf
COPY ./config/php-fpm.conf /etc/php/${PHP_VER}/fpm/pool.d/zzz-custom.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
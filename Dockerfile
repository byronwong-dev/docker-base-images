FROM php:7.4.13-fpm AS base

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    ca-certificates \
    openssh-client \
    curl \ 
    dos2unix \
    git \
    gnupg2 \
    dirmngr \
    g++ \	
    jq \
    libedit-dev \
    libfcgi0ldbl \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpq-dev \
    libssl-dev \
    libpng-dev \
    zlib1g-dev \
    gcc \
    libbz2-dev \
    ssh \
    supervisor \
    unzip \
    zip \
    libxml2-dev \
    cron \
    nano \
    libzip-dev \
    less \
    && rm -r /var/lib/apt/lists/*

RUN docker-php-ext-install \
    pdo_mysql \
    mysqli \
    json \
    gd \
    intl \
    opcache \
    bcmath \
    bz2 \
    soap \
    zip \
    ctype

# set version to install
ENV COMPOSER_VERSION=2.0.8 \
    NGINX_VERSION=1.18.0-2~buster \
    NJS_VERSION=1.18.0.0.4.4-2~buster \
    NODE_VERSION=14.15.2 \
    YARN_VERSION=1.22.5

# install nginx (copied from official nginx Dockerfile)
RUN NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	echo "deb http://nginx.org/packages/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						nginx=${NGINX_VERSION} \
						nginx-module-xslt=${NGINX_VERSION} \
						nginx-module-geoip=${NGINX_VERSION} \
						nginx-module-image-filter=${NGINX_VERSION} \
						nginx-module-njs=${NJS_VERSION} \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

# forward nginx request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

# install composer so we can run dump-autoload at entrypoint startup in dev
# copied from official composer Dockerfile

ENV PATH="/composer/vendor/bin:$PATH" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_VENDOR_DIR=/var/www/vendor \
    COMPOSER_HOME=/composer

RUN curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/76a7060ccb93902cd7576b67264ad91c8a2700e2/web/installer \
 && php -r " \
    \$signature = '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5'; echo \$signature; \$hash = hash('sha384', file_get_contents('/tmp/installer.php')); \
    if (!hash_equals(\$signature, \$hash)) { \
      unlink('/tmp/installer.php'); \
      echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
      exit(1); \
    }" \
 && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
 && rm /tmp/installer.php \
 && composer --ansi --version --no-interaction

# install node for running gulp at container entrypoint startup in dev
# copied from official node Dockerfile
# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    1C050899334244A8AF75E53792EF661D867B9DFA \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done

ENV NPM_CONFIG_LOGLEVEL info

RUN curl -fsSLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && npm --version

RUN set -ex \
    && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" \
    ; done  

RUN curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
    && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && mkdir -p /opt \
    && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
    && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && yarn --version

ENV PATH /var/www/node_modules/.bin:$PATH

RUN mkdir -p /root/logs

# COPY ALIASES https://github.com/laradock/laradock/blob/master/workspace/Dockerfile ##

USER root

# important so that php-fpm works correctly with nginx
# we add www-data into wsl2 file system group (1000) so that it will have sufficient write permission
RUN groupmod -g 1000 www-data

ARG USER

# change your username so that during editing the file permission will not have an issue during save/ overwrite
ENV USER ${USER}

# this is to add user so that wsl2 will not have permission issue when saving or using files
# we use group id 1000 due to www-data be default is using 1000 group id. which we try to keep it consistent
RUN addgroup --gid 1024 $USER && \
    adduser --disabled-password --gecos "" --force-badname --gid 1024 --gid 1000 $USER

# install bash aliases
USER root
COPY ./docker/aliases.sh /home/$USER/aliases.sh
RUN sed -i 's/\r//' /home/$USER/aliases.sh && \
    chown 1024:$USER /home/$USER/aliases.sh

# copy apply aliases
USER $USER
RUN echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
	echo "" >> ~/.bashrc

USER root
WORKDIR /var/www

################################################################################################
##  DEVELOPMENT USE DOCKER COMPOSE TO RUN
##  
################################################################################################


###############################################################################################
##  STAGING MULTI-STAGE BUILD
##
###############################################################################################

FROM base AS staging

COPY ./composer.json /var/www/composer.json

RUN composer install --no-scripts --no-autoloader --ansi --no-interaction

COPY ./package.json /var/www/package.json

RUN npm install

# copy config files
COPY ./docker/staging/laravel-pool.conf /usr/local/etc/php-fpm.d/
COPY ./docker/staging/cron /etc/cron.d/cron
COPY ./docker/staging/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./docker/staging/laravel-worker.conf /etc/supervisor/conf.d/laravel-worker.conf
COPY ./docker/staging/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/staging/default.conf /etc/nginx/conf.d/default.conf
COPY ./docker/staging/closurv.test.conf /etc/nginx/conf.d/closurv.test.conf

RUN chmod -R 644 /etc/cron.d

# copy & apply bash aliases
USER root
COPY ./docker/aliases.sh /home/$USER/aliases.sh
RUN sed -i 's/\r//' /home/$USER/aliases.sh && \
    chown 1024:$USER /home/$USER/aliases.sh

USER $USER
RUN echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
	echo "" >> ~/.bashrc

# copy env
USER root
WORKDIR /var/www

RUN chown -R www-data:www-data . && chown 775 -R .
COPY --chown=1024:$USER . .
COPY --chown=1024:$USER .env.prod .env

# install dependencies
WORKDIR /var/www
RUN composer dump-autoload

RUN php artisan config:cache && php artisan route:cache

RUN npm run production
RUN chown -R www-data:www-data /var/www/vendor
RUN chown -R www-data:www-data /var/www/node_modules

# supposed to be entry point content but lightsail needs faster boot time

# ensure bind mount permissions are what we need
RUN chown -R :www-data /var/www/bootstrap \
	/var/www/storage \
	/var/www/public/ 

RUN chmod -R g+w /var/www/bootstrap \
	/var/www/public/ \
	/var/www/storage

RUN crontab -u www-data /etc/cron.d/cron

COPY --chown=1024:$USER entrypoint .

RUN chmod +x /var/www/entrypoint

ENTRYPOINT [ "/var/www/entrypoint" ]

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

################################################################################################

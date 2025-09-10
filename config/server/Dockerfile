FROM php:8.3-apache

# Build arguments
ARG FOG_VERSION=1.5.10.1673
ARG FOG_GIT_REPO_URL=https://github.com/FOGProject/fogproject.git
ARG FOG_GIT_REF=1.5.10.1673

LABEL maintainer="Progressive Sealing <lucas@progressive-sealing.com>"
LABEL version="${FOG_VERSION}"
LABEL description="FOG Project Server with Supervisor - Multi-service container"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    bc \
    build-essential \
    curl \
    gawk \
    gcc \
    git \
    htmldoc \
    isolinux \
    lftp \
    m4 \
    mariadb-client \
    nfs-common \
    openssh-server \
    iproute2 \
    net-tools \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libldap2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libmcrypt-dev \
    tar \
    tftpd-hpa \
    unzip \
    vsftpd \
    wakeonlan \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install PHP extensions using docker-php-ext-install
RUN docker-php-ext-install \
    bcmath \
    pdo_mysql \
    mysqli \
    gd \
    ldap \
    zip \
    gettext \
    ftp \
    pcntl \
    posix 


# Download and prepare FOG source
RUN cd /opt && \
    git clone --depth 1 --branch ${FOG_GIT_REF} ${FOG_GIT_REPO_URL} fogproject && \
    chmod +x /opt/fogproject/bin/installfog.sh

# Create all needed directories
RUN mkdir -p /opt/fog/log /opt/fog/snapins /opt/fog/service \
    && mkdir -p /var/www/html/fog/management /var/www/html/fog/service /var/www/html/fog/commons \
    && mkdir -p /tftpboot \
    && mkdir -p /images \
    && mkdir -p /opt/fog/service/etc \
    && mkdir -p /var/lib/php/sessions \
    && chown -R www-data:www-data /var/lib/php/sessions

# Copy all TFTP boot files from FOG source to the tftpboot directory
RUN cp -a /opt/fogproject/packages/tftp/. /tftpboot/

# Copy FOG service files
RUN cp -r /opt/fogproject/packages/service/* /opt/fog/service/

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY apache-fog.conf /apache-fog.conf
COPY ports.conf /ports.conf
COPY fog-config.php /fog-config.php
COPY entrypoint.sh /entrypoint.sh

# Set ownership for all copied files
RUN chown -R www-data:www-data /opt/fog/service && \
    chown -R www-data:www-data /tftpboot

# Set permissions for all copied files
RUN chmod +x /opt/fog/service/*/* && \
    chmod +x /entrypoint.sh

# Configure PHP sessions
RUN echo "session.save_handler = files" >> /usr/local/etc/php/conf.d/sessions.ini && \
    echo "session.save_path = '/var/lib/php/sessions'" >> /usr/local/etc/php/conf.d/sessions.ini && \
    echo "session.cookie_httponly = 1" >> /usr/local/etc/php/conf.d/sessions.ini && \
    echo "session.cookie_secure = 0" >> /usr/local/etc/php/conf.d/sessions.ini && \
    echo "session.use_strict_mode = 1" >> /usr/local/etc/php/conf.d/sessions.ini

# Create FOG service config file
RUN echo "<?php define('WEBROOT','/var/www/html/fog/');" > /opt/fog/service/etc/config.php && \
    chown -R www-data:www-data /opt/fog/service/etc

# Set correct permissions (do this LAST in the build)
RUN chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /opt/fog/snapins \
    && chmod -R 755 /var/www/html \
    && chmod -R 755 /opt/fog

# Expose HTTP port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost/fog/management/ || exit 1

# Entry point
ENTRYPOINT ["/entrypoint.sh"] 
# FOG Docker - Two-Stage Build
# Stage 1: Build FOG from source
FROM debian:13 AS fog-builder

# Set up working environment
ENV LANG="C.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    apt-get -q install --no-install-recommends -y \
        ca-certificates \
        git \
        wget \
        curl \
        build-essential \
        gcc \
        g++ \
        make \
        autoconf \
        automake \
        libtool \
        pkg-config \
        liblzma-dev \
        libc6-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        zlib1g-dev \
        libncurses5-dev \
        libncursesw5-dev \
        bison \
        flex \
        libelf-dev \
        libdw-dev \
        libaudit-dev \
        libslang2-dev \
        libperl-dev \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-venv \
        locales \
        tzdata \
        sudo \
        && rm -rf /var/lib/apt/lists/*

# Create fog user for building
RUN useradd -d /home/fog -m fog -u 1000 && \
    echo 'fog ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

USER fog
WORKDIR /home/fog

# Build arguments for FOG source
ARG FOG_GIT_URL=https://github.com/FOGProject/fogproject.git
ARG FOG_GIT_REF=stable

# Clone and checkout FOG source
RUN git clone "$FOG_GIT_URL" fogproject && \
    cd fogproject && \
    git checkout -b current "$FOG_GIT_REF"

WORKDIR /home/fog/fogproject

# Create FOG installation tarball
RUN cd /home/fog && \
    tar -czf /tmp/fog-installation.tar.gz fogproject/ && \
    echo "FOG installation tarball created"

# Stage 2: Production image
FROM debian:13

ENV FOG_VERSION="stable"

# Install all FOG dependencies
RUN apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -q install --no-install-recommends -y \
        # Web server and PHP
        apache2 \
        php \
        php-cli \
        php-fpm \
        php-mysql \
        php-curl \
        php-gd \
        php-json \
        php-ldap \
        php-mbstring \
        php-xml \
        php-zip \
        php-bcmath \
        libapache2-mod-php \
        # Database
        mariadb-client \
        # Network services
        tftpd-hpa \
        tftp-hpa \
        nfs-kernel-server \
        vsftpd \
        isc-dhcp-server \
        iproute2 \
        net-tools \
        # System utilities
        curl \
        wget \
        git \
        build-essential \
        gcc \
        g++ \
        make \
        autoconf \
        automake \
        libtool \
        pkg-config \
        liblzma-dev \
        libc6-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        zlib1g-dev \
        libncurses5-dev \
        libncursesw5-dev \
        bison \
        flex \
        libelf-dev \
        libdw-dev \
        libaudit-dev \
        libslang2-dev \
        libperl-dev \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-venv \
        # Secure Boot tools
        sbsigntool \
        efitools \
        openssl \
        shim-signed \
        grub-efi-amd64-signed \
        # FAT32 filesystem tools
        dosfstools \
        util-linux \
        # System utilities
        locales \
        tzdata \
        sudo \
        supervisor \
        cron \
        && rm -rf /var/lib/apt/lists/*

# Create fog user
RUN useradd -d /home/fog -m fog -u 1000 && \
    echo 'fog ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create FOG directories
RUN mkdir -p /var/www/html/fog \
             /tftpboot \
             /opt/fog/snapins \
             /opt/fog/log \
             /opt/fog/service \
             /opt/fog/secure-boot/keys \
             /opt/fog/secure-boot/scripts \
             /opt/fog/secure-boot/shim \
             "/images" \
             "/tftpboot" \
             "/opt/fog/snapins" \
             "/opt/fog/log" \
             "/opt/fog/ssl" \
             "/opt/fog/config" \
             "/opt/fog/secure-boot"

# Copy FOG installation from builder stage
COPY --from=fog-builder /tmp/fog-installation.tar.gz /tmp/
RUN cd /opt && \
    tar -xzf /tmp/fog-installation.tar.gz && \
    rm -f /tmp/fog-installation.tar.gz && \
    mv fogproject fog

# Copy shim and MOK manager from Debian packages
RUN cp /usr/lib/shim/shimx64.efi /opt/fog/secure-boot/shim/shimx64.efi && \
    cp /usr/lib/shim/mmx64.efi /opt/fog/secure-boot/shim/mmx64.efi

# Copy FOG web files
RUN if [ -d "/opt/fog/fogproject/packages/web" ]; then \
        cp -r /opt/fog/fogproject/packages/web/* /var/www/html/fog/ && \
        chown -R www-data:www-data /var/www/html/fog; \
    else \
        echo "Warning: FOG web directory not found"; \
    fi

# Copy TFTP files
RUN if [ -d "/opt/fog/fogproject/packages/tftp" ]; then \
        cp -r /opt/fog/fogproject/packages/tftp/* /tftpboot/ && \
        chown -R www-data:www-data /tftpboot; \
    else \
        echo "Warning: FOG TFTP directory not found"; \
    fi

# Copy snapins
RUN if [ -d "/opt/fog/fogproject/packages/snapins" ]; then \
        cp -r /opt/fog/fogproject/packages/snapins/* /opt/fog/snapins/ && \
        chown -R www-data:www-data /opt/fog/snapins; \
    else \
        echo "Warning: FOG snapins directory not found"; \
    fi

# Copy FOG service files to expected location
RUN if [ -d "/opt/fog/fogproject/packages/service" ]; then \
        cp -r /opt/fog/fogproject/packages/service/* /opt/fog/service/ && \
        chown -R www-data:www-data /opt/fog/service && \
        chmod +x /opt/fog/service/*/*; \
    else \
        echo "Warning: FOG service directory not found"; \
    fi


# Set up Apache modules
RUN a2enmod rewrite headers ssl && \
    a2dissite 000-default

# Create symlinks for FOG compatibility
RUN ln -sf /var/www/html/fog /var/www/html/fog/fog

# Copy configuration templates
COPY templates/ /opt/fog/templates/

# Copy entrypoint and scripts
COPY entrypoint.sh /sbin/entrypoint.sh
COPY scripts/ /opt/fog/scripts/

# Make scripts executable
RUN chmod +x /sbin/entrypoint.sh && \
    chmod +x /opt/fog/scripts/*.sh

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html/fog /tftpboot /opt/fog/snapins && \
    chmod -R 755 /var/www/html/fog /tftpboot /opt/fog/snapins

# Remove configuration files that will be generated at runtime
RUN rm -f /etc/apache2/sites-available/*.conf \
          /etc/apache2/sites-enabled/*.conf \
          /var/www/html/fog/lib/fog/config.class.php \
          /etc/tftpd-hpa/tftpd-hpa.conf \
          /etc/exports \
          /etc/dhcp/dhcpd.conf

# Download FOG kernel files (bzImage, init.xz, etc.)
RUN mkdir -p /tmp/fog-kernels && \
    cd /tmp/fog-kernels && \
    # Download kernel files from FOG releases
    curl -L -o bzImage https://github.com/FOGProject/fos/releases/latest/download/bzImage && \
    curl -L -o bzImage32 https://github.com/FOGProject/fos/releases/latest/download/bzImage32 && \
    curl -L -o init.xz https://github.com/FOGProject/fos/releases/latest/download/init.xz && \
    curl -L -o init_32.xz https://github.com/FOGProject/fos/releases/latest/download/init_32.xz && \
    curl -L -o arm_Image https://github.com/FOGProject/fos/releases/latest/download/arm_Image && \
    curl -L -o arm_init.cpio.gz https://github.com/FOGProject/fos/releases/latest/download/arm_init.cpio.gz && \
    # Copy kernel files to the correct location
    cp bzImage bzImage32 init.xz init_32.xz arm_Image arm_init.cpio.gz /var/www/html/fog/service/ipxe/ && \
    chown www-data:www-data /var/www/html/fog/service/ipxe/bzImage* /var/www/html/fog/service/ipxe/init* /var/www/html/fog/service/ipxe/arm_* && \
    rm -rf /tmp/fog-kernels

# Copy iPXE files to TFTP directory
RUN mkdir -p /tftpboot && \
    cp -r /opt/fog/fogproject/packages/tftp/* /tftpboot/ && \
    chown -R www-data:www-data /tftpboot

# Create volume mount points
VOLUME ["/images", "/tftpboot", "/opt/fog/snapins", "/opt/fog/log", "/opt/fog/ssl", "/opt/fog/config", "/opt/fog/secure-boot"]
EXPOSE 80 443 69 2049 21

ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]

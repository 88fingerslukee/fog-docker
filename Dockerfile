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

# Create temporary fog user for building
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
    git fetch --all && \
    git checkout "$FOG_GIT_REF"

WORKDIR /home/fog/fogproject

# Create FOG installation tarball
RUN cd /home/fog && \
    tar -czf /tmp/fog-installation.tar.gz fogproject/ && \
    echo "FOG installation tarball created"

# Stage 2: Production image
FROM debian:13

# Pass the Git reference as the version
ARG FOG_GIT_REF=stable
ENV FOG_VERSION="${FOG_GIT_REF}"

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
        # Secure Boot tools (architecture-specific)
        sbsigntool \
        efitools \
        openssl \
        # FAT32 filesystem tools
        dosfstools \
        util-linux \
        # System utilities
        locales \
        tzdata \
        sudo \
        supervisor \
        cron \
        bind9-dnsutils \
        && rm -rf /var/lib/apt/lists/*

# Install architecture-specific secure boot packages
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        apt-get -q update && \
        DEBIAN_FRONTEND=noninteractive apt-get -q install --no-install-recommends -y \
            shim-signed \
            grub-efi-amd64-signed \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Create fog user
RUN useradd -d /home/fog -m fog -u 1000 && \
    echo 'fog ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create all FOG directories
RUN mkdir -p \
    /var/www/html/fog \
    /var/www/html/fog/service/ipxe \
    /var/lib/nfs/rpc_pipefs \
    /tftpboot \
    /opt/fog/snapins \
    /opt/fog/snapins/ssl \
    /opt/fog/log \
    /opt/fog/service \
    /opt/fog/service/etc \
    /opt/fog/secure-boot \
    /opt/fog/secure-boot/keys \
    /opt/fog/secure-boot/scripts \
    /opt/fog/secure-boot/shim \
    /opt/fog/ssl \
    /opt/fog/config \
    /images \
    /opt/migration

# Set up NFS filesystem mounts in fstab
RUN echo "rpc_pipefs  /var/lib/nfs/rpc_pipefs  rpc_pipefs  defaults  0  0" >> /etc/fstab && \
    echo "nfsd        /proc/fs/nfsd            nfsd        defaults  0  0" >> /etc/fstab

# Copy FOG installation from builder stage
COPY --from=fog-builder /tmp/fog-installation.tar.gz /tmp/
RUN cd /opt && \
    tar -xzf /tmp/fog-installation.tar.gz && \
    rm -f /tmp/fog-installation.tar.gz && \
    mv fogproject fog

# Copy shim and MOK manager from Debian packages (if available)
RUN if [ -f "/usr/lib/shim/shimx64.efi" ]; then \
        cp /usr/lib/shim/shimx64.efi /opt/fog/secure-boot/shim/shimx64.efi; \
    fi && \
    if [ -f "/usr/lib/shim/mmx64.efi" ]; then \
        cp /usr/lib/shim/mmx64.efi /opt/fog/secure-boot/shim/mmx64.efi; \
    fi

# Copy FOG web files
RUN if [ -d "/opt/fog/fogproject/packages/web" ]; then \
        cp -r /opt/fog/fogproject/packages/web/* /var/www/html/fog/; \
    else \
        echo "Warning: FOG web directory not found"; \
    fi

# Copy TFTP files
RUN if [ -d "/opt/fog/fogproject/packages/tftp" ]; then \
        cp -r /opt/fog/fogproject/packages/tftp/* /tftpboot/; \
    else \
        echo "Warning: FOG TFTP directory not found"; \
    fi

# Copy snapins
RUN if [ -d "/opt/fog/fogproject/packages/snapins" ]; then \
        cp -r /opt/fog/fogproject/packages/snapins/* /opt/fog/snapins/; \
    else \
        echo "Warning: FOG snapins directory not found"; \
    fi

# Copy FOG service files to expected location
RUN if [ -d "/opt/fog/fogproject/packages/service" ]; then \
        cp -r /opt/fog/fogproject/packages/service/* /opt/fog/service/; \
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

# Remove configuration files that will be generated at runtime
RUN rm -f /etc/apache2/sites-available/*.conf \
          /etc/apache2/sites-enabled/*.conf \
          /var/www/html/fog/lib/fog/config.class.php \
          /etc/tftpd-hpa/tftpd-hpa.conf \
          /etc/exports \
          /etc/dhcp/dhcpd.conf

# Download FOG kernel files directly to iPXE directory
RUN cd /var/www/html/fog/service/ipxe && \
    # Download kernel files from FOG releases (with error handling)
    (curl -L -o bzImage https://github.com/FOGProject/fos/releases/latest/download/bzImage || echo "bzImage download failed") && \
    (curl -L -o bzImage32 https://github.com/FOGProject/fos/releases/latest/download/bzImage32 || echo "bzImage32 download failed") && \
    (curl -L -o init.xz https://github.com/FOGProject/fos/releases/latest/download/init.xz || echo "init.xz download failed") && \
    (curl -L -o init_32.xz https://github.com/FOGProject/fos/releases/latest/download/init_32.xz || echo "init_32.xz download failed") && \
    (curl -L -o arm_Image https://github.com/FOGProject/fos/releases/latest/download/arm_Image || echo "arm_Image download failed") && \
    (curl -L -o arm_init.cpio.gz https://github.com/FOGProject/fos/releases/latest/download/arm_init.cpio.gz || echo "arm_init.cpio.gz download failed")

# Download FOG client files to client directory
RUN cd /var/www/html/fog/client && \
    # Get the FOG client version from the system class
    CLIENT_VERSION=$(grep -o "define('FOG_CLIENT_VERSION', '[^']*')" /var/www/html/fog/lib/fog/system.class.php | cut -d"'" -f4) && \
    echo "Downloading FOG client version: $CLIENT_VERSION" && \
    # Download client files from FOG client releases
    (curl -L -o FOGService.msi "https://github.com/FOGProject/fog-client/releases/download/${CLIENT_VERSION}/FOGService.msi" || echo "FOGService.msi download failed") && \
    (curl -L -o SmartInstaller.exe "https://github.com/FOGProject/fog-client/releases/download/${CLIENT_VERSION}/SmartInstaller.exe" || echo "SmartInstaller.exe download failed") && \
    # Also download additional client utilities if they exist
    (curl -L -o FogPrep.zip "https://github.com/FOGProject/fog-client/releases/download/${CLIENT_VERSION}/FogPrep.zip" || echo "FogPrep.zip not available") && \
    (curl -L -o FOGCrypt.zip "https://github.com/FOGProject/fog-client/releases/download/${CLIENT_VERSION}/FOGCrypt.zip" || echo "FOGCrypt.zip not available") && \
    # Set proper permissions
    chown www-data:www-data *.msi *.exe *.zip 2>/dev/null || true && \
    chmod 644 *.msi *.exe *.zip 2>/dev/null || true

# Create CA certificate that matches FOG source exactly
# This will be used by the entrypoint script when SSL is enabled
RUN mkdir -p /opt/fog/snapins/ssl/CA && \
    # Create CA key (4096-bit RSA, matching FOG source)
    openssl genrsa -out /opt/fog/snapins/ssl/CA/.fogCA.key 4096 && \
    # Create CA certificate (3650 days, matching FOG source)
    openssl req -x509 -new -sha512 -nodes -key /opt/fog/snapins/ssl/CA/.fogCA.key \
    -days 3650 -out /opt/fog/snapins/ssl/CA/.fogCA.pem \
    -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG Server CA" && \
    # Create web-accessible DER format (matching FOG source process)
    mkdir -p /var/www/html/fog/management/other && \
    cp /opt/fog/snapins/ssl/CA/.fogCA.pem /var/www/html/fog/management/other/ca.cert.pem && \
    openssl x509 -outform der -in /var/www/html/fog/management/other/ca.cert.pem \
    -out /var/www/html/fog/management/other/ca.cert.der && \
    # Set proper ownership
    chown -R www-data:www-data /opt/fog/snapins/ssl/CA /var/www/html/fog/management/other

# Set all permissions and ownership after all copy operations are complete
RUN chmod +x /sbin/entrypoint.sh && \
    chmod +x /opt/fog/scripts/*.sh && \
    chmod +x /opt/fog/service/*/* && \
    chmod -R 755 /var/www/html/fog /tftpboot /opt/fog/snapins && \
    chown -R www-data:www-data \
        /var/www/html/fog \
        /tftpboot \
        /opt/fog/snapins \
        /opt/fog/service \
        /opt/fog/secure-boot \
        /opt/fog/ssl \
        /opt/fog/config \
        /opt/migration

# Clean up temporary fog user used for building
RUN userdel -r fog && \
    sed -i '/fog ALL=(ALL:ALL) NOPASSWD:ALL/d' /etc/sudoers

# Create volume mount points for persistent data
VOLUME ["/images", "/tftpboot", "/opt/fog/snapins", "/opt/fog/log", "/opt/fog/ssl", "/opt/fog/config", "/opt/fog/secure-boot"]

# Expose ports that are always needed and not configurable
# Note: Apache ports (80/443) are configurable via environment variables
EXPOSE 69/udp 2049 21 111 32765 32767

ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]

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

# Shared helper: extract FOG define() pins without brittle single-quote grep.
COPY scripts/extract-fog-define.py /usr/local/bin/extract-fog-define.py

USER fog
WORKDIR /home/fog

# Build arguments for FOG source
ARG FOG_GIT_URL=https://github.com/FOGProject/fogproject.git
ARG FOG_GIT_REF=stable

# Clone and checkout FOG source
# Handle null/empty FOG_GIT_REF by defaulting to stable
RUN FOG_REF="${FOG_GIT_REF:-stable}" && \
    if [ "$FOG_REF" = "null" ] || [ -z "$FOG_REF" ]; then \
        FOG_REF="stable"; \
    fi && \
    git clone "$FOG_GIT_URL" fogproject && \
    cd fogproject && \
    git fetch --all && \
    git checkout "$FOG_REF"

WORKDIR /home/fog/fogproject

# Locate FOG version pins: 1.5 uses lib/fog/system.class.php, 1.6+ uses src/Base/System.php.
# Newer FOG trees no longer commit iPXE binaries. Download the release pinned by
# FOG_IPXE_VERSION so /tftpboot is not left with only default.ipxe.
RUN SYSTEM_FILE="" && \
    for f in packages/web/src/Base/System.php packages/web/lib/fog/system.class.php; do \
        if [ -f "$f" ]; then SYSTEM_FILE="$f"; break; fi; \
    done && \
    if [ -z "$SYSTEM_FILE" ]; then \
        echo "ERROR: FOG system file not found (expected System.php or system.class.php)"; \
        exit 1; \
    fi && \
    echo "Using FOG system file: $SYSTEM_FILE" && \
    if [ ! -f packages/tftp/undionly.kkpxe ]; then \
        IPXE_VER=$(python3 /usr/local/bin/extract-fog-define.py "$SYSTEM_FILE" FOG_IPXE_VERSION) && \
        if [ -z "$IPXE_VER" ]; then \
            echo "ERROR: iPXE binaries are missing and FOG_IPXE_VERSION is unset in $SYSTEM_FILE"; \
            exit 1; \
        fi && \
        echo "Downloading iPXE binaries ${IPXE_VER}" && \
        mkdir -p packages/tftp && \
        tmpdir=$(mktemp -d) && \
        base="https://github.com/FOGProject/fog-ipxe/releases/download/${IPXE_VER}" && \
        curl -fL -o "${tmpdir}/fog-ipxe-${IPXE_VER}.tar.gz" "${base}/fog-ipxe-${IPXE_VER}.tar.gz" && \
        curl -fL -o "${tmpdir}/fog-ipxe-${IPXE_VER}.tar.gz.sha256" "${base}/fog-ipxe-${IPXE_VER}.tar.gz.sha256" && \
        (cd "$tmpdir" && sha256sum -c "fog-ipxe-${IPXE_VER}.tar.gz.sha256") && \
        tar -xzf "${tmpdir}/fog-ipxe-${IPXE_VER}.tar.gz" -C packages/tftp && \
        if curl -fL -o "${tmpdir}/fog-ipxe-secureboot-${IPXE_VER}.tar.gz" "${base}/fog-ipxe-secureboot-${IPXE_VER}.tar.gz" && \
           curl -fL -o "${tmpdir}/fog-ipxe-secureboot-${IPXE_VER}.tar.gz.sha256" "${base}/fog-ipxe-secureboot-${IPXE_VER}.tar.gz.sha256" && \
           (cd "$tmpdir" && sha256sum -c "fog-ipxe-secureboot-${IPXE_VER}.tar.gz.sha256"); then \
            tar -xzf "${tmpdir}/fog-ipxe-secureboot-${IPXE_VER}.tar.gz" -C packages/tftp; \
        else \
            echo "Warning: Secure Boot iPXE asset unavailable for ${IPXE_VER}"; \
        fi && \
        rm -rf "$tmpdir" && \
        test -f packages/tftp/undionly.kkpxe; \
    fi && \
    # FOG 1.6+ ships plugins from FOGProject/fog-plugins (ADR 0009), not in-tree.
    PLUGINS_VER=$(python3 /usr/local/bin/extract-fog-define.py "$SYSTEM_FILE" FOG_PLUGINS_VERSION || true) && \
    if [ -n "$PLUGINS_VER" ]; then \
        echo "Downloading FOG plugins ${PLUGINS_VER}" && \
        tmpdir=$(mktemp -d) && \
        base="https://github.com/FOGProject/fog-plugins/releases/download/${PLUGINS_VER}" && \
        curl -fL -o "${tmpdir}/fog-plugins-${PLUGINS_VER}.tar.gz" "${base}/fog-plugins-${PLUGINS_VER}.tar.gz" && \
        curl -fL -o "${tmpdir}/fog-plugins-${PLUGINS_VER}.tar.gz.sha256" "${base}/fog-plugins-${PLUGINS_VER}.tar.gz.sha256" && \
        (cd "$tmpdir" && sha256sum -c "fog-plugins-${PLUGINS_VER}.tar.gz.sha256") && \
        rm -rf packages/web/lib/plugins && \
        mkdir -p packages/web/lib/plugins && \
        tar -xzf "${tmpdir}/fog-plugins-${PLUGINS_VER}.tar.gz" -C packages/web/lib/plugins && \
        echo "$PLUGINS_VER" > packages/web/lib/plugins/.fog-plugins-version && \
        rm -rf "$tmpdir"; \
    else \
        echo "No FOG_PLUGINS_VERSION pin; skipping plugin download"; \
    fi

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
        libtirpc-dev \
        vsftpd \
        isc-dhcp-server \
        iproute2 \
        udpcast \
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

# Optional userland NFSv3 server. Kernel NFS remains the default.
ARG UNFS3_VERSION=0.11.0
ARG UNFS3_SHA256=42ef63cd949b65a4ead30bee269703059a8c4269bef6aa1533215ad1c2a26d6f
RUN curl -fL -o /tmp/unfs3.tar.gz "https://github.com/unfs3/unfs3/releases/download/unfs3-${UNFS3_VERSION}/unfs3-${UNFS3_VERSION}.tar.gz" && \
    echo "${UNFS3_SHA256}  /tmp/unfs3.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/unfs3.tar.gz -C /tmp && \
    cd "/tmp/unfs3-${UNFS3_VERSION}" && \
    ./configure && \
    make && \
    make install && \
    test -x /usr/local/sbin/unfsd && \
    rm -rf /tmp/unfs3.tar.gz "/tmp/unfs3-${UNFS3_VERSION}"

# FOG expects udp-sender under /usr/local (1.5: bin, 1.6: sbin). Debian puts it in /usr/bin.
RUN ln -sf /usr/bin/udp-sender /usr/local/bin/udp-sender && \
    ln -sf /usr/bin/udp-sender /usr/local/sbin/udp-sender

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
    /opt/fog/sessions \
    /opt/fog/cache \
    /opt/fog/plugins \
    /opt/fog/service \
    /opt/fog/service/etc \
    /opt/fog/secure-boot \
    /opt/fog/secure-boot/keys \
    /opt/fog/secure-boot/scripts \
    /opt/fog/secure-boot/shim \
    /opt/fog/snapins/ssl \
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

# Copy FOG web / TFTP / service trees and require key artifacts on disk.
# Soft "Warning: not found" used to let incomplete images ship successfully.
RUN set -eu; \
    if [ ! -d "/opt/fog/fogproject/packages/web" ]; then \
        echo "ERROR: FOG web directory not found at /opt/fog/fogproject/packages/web"; \
        exit 1; \
    fi && \
    cp -r /opt/fog/fogproject/packages/web/* /var/www/html/fog/ && \
    if [ ! -f /var/www/html/fog/index.php ]; then \
        echo "ERROR: /var/www/html/fog/index.php missing after web copy"; \
        exit 1; \
    fi && \
    if [ ! -f /var/www/html/fog/src/Base/System.php ] && \
       [ ! -f /var/www/html/fog/lib/fog/system.class.php ]; then \
        echo "ERROR: FOG system file missing after web copy (System.php or system.class.php)"; \
        exit 1; \
    fi && \
    if [ ! -d "/opt/fog/fogproject/packages/tftp" ]; then \
        echo "ERROR: FOG TFTP directory not found at /opt/fog/fogproject/packages/tftp"; \
        exit 1; \
    fi && \
    cp -a /opt/fog/fogproject/packages/tftp/. /tftpboot/ && \
    for boot_file in undionly.kkpxe undionly.kpxe ipxe.efi snponly.efi; do \
        if [ ! -f "/tftpboot/${boot_file}" ]; then \
            echo "ERROR: required TFTP boot file missing after copy: ${boot_file}"; \
            exit 1; \
        fi; \
    done && \
    mkdir -p /opt/fog/bundled-tftpboot && \
    cp -a /tftpboot/. /opt/fog/bundled-tftpboot/ && \
    if [ -d "/opt/fog/fogproject/packages/snapins" ]; then \
        cp -r /opt/fog/fogproject/packages/snapins/* /opt/fog/snapins/; \
    else \
        echo "Note: FOG snapins directory not present in this FOG tree"; \
    fi && \
    if [ ! -d "/opt/fog/fogproject/packages/service" ]; then \
        echo "ERROR: FOG service directory not found at /opt/fog/fogproject/packages/service"; \
        exit 1; \
    fi && \
    cp -r /opt/fog/fogproject/packages/service/* /opt/fog/service/ && \
    for svc in FOGMulticastManager FOGImageReplicator FOGTaskScheduler; do \
        if [ ! -d "/opt/fog/service/${svc}" ]; then \
            echo "ERROR: required FOG service missing after copy: ${svc}"; \
            exit 1; \
        fi; \
    done && \
    echo "FOG web / TFTP / service artifacts verified"


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
COPY scripts/extract-fog-define.py /usr/local/bin/extract-fog-define.py


# Remove configuration files that will be generated at runtime
RUN rm -f /etc/apache2/sites-available/*.conf \
          /etc/apache2/sites-enabled/*.conf \
          /var/www/html/fog/lib/fog/config.class.php \
          /var/www/html/fog/commons/config.class.php \
          /var/www/html/fog/commons/fogpaths.php \
          /etc/tftpd-hpa/tftpd-hpa.conf \
          /etc/exports \
          /etc/dhcp/dhcpd.conf

# Download FOG OS kernels. Fail the build if any required artifact is missing/empty.
RUN set -eu; \
    cd /var/www/html/fog/service/ipxe && \
    base="https://github.com/FOGProject/fos/releases/latest/download" && \
    require_file() { \
        name="$1"; min_bytes="$2"; \
        curl -fL -o "$name" "${base}/${name}"; \
        size=$(wc -c < "$name"); \
        if [ "$size" -lt "$min_bytes" ]; then \
            echo "ERROR: ${name} is too small (${size} bytes; expected >= ${min_bytes})"; \
            exit 1; \
        fi; \
        echo "✓ ${name} (${size} bytes)"; \
    } && \
    require_file bzImage 100000 && \
    require_file bzImage32 100000 && \
    require_file init.xz 100000 && \
    require_file init_32.xz 100000 && \
    require_file arm_Image 100000 && \
    require_file arm_init.cpio.gz 10000

# Download FOG client files. MSI + SmartInstaller are required; FogPrep/FOGCrypt optional.
RUN set -eu; \
    SYSTEM_FILE="" && \
    for f in /var/www/html/fog/src/Base/System.php /var/www/html/fog/lib/fog/system.class.php; do \
        if [ -f "$f" ]; then SYSTEM_FILE="$f"; break; fi; \
    done && \
    if [ -z "$SYSTEM_FILE" ]; then \
        echo "ERROR: FOG system file not found for client version pin"; \
        exit 1; \
    fi && \
    CLIENT_VERSION=$(python3 /usr/local/bin/extract-fog-define.py "$SYSTEM_FILE" FOG_CLIENT_VERSION) && \
    if [ -z "$CLIENT_VERSION" ]; then \
        echo "ERROR: FOG_CLIENT_VERSION unset in $SYSTEM_FILE"; \
        exit 1; \
    fi && \
    echo "Downloading FOG client version: $CLIENT_VERSION" && \
    cd /var/www/html/fog/client && \
    base="https://github.com/FOGProject/fog-client/releases/download/${CLIENT_VERSION}" && \
    curl -fL -o FOGService.msi "${base}/FOGService.msi" && \
    curl -fL -o SmartInstaller.exe "${base}/SmartInstaller.exe" && \
    size_msi=$(wc -c < FOGService.msi) && \
    size_smart=$(wc -c < SmartInstaller.exe) && \
    if [ "$size_msi" -lt 100000 ] || [ "$size_smart" -lt 10000 ]; then \
        echo "ERROR: FOG client artifacts too small (msi=${size_msi}, smart=${size_smart})"; \
        exit 1; \
    fi && \
    if curl -fL -o FogPrep.zip "${base}/FogPrep.zip"; then \
        echo "✓ FogPrep.zip"; \
    else \
        echo "Note: FogPrep.zip not available for ${CLIENT_VERSION}"; \
        rm -f FogPrep.zip; \
    fi && \
    if curl -fL -o FOGCrypt.zip "${base}/FOGCrypt.zip"; then \
        echo "✓ FOGCrypt.zip"; \
    else \
        echo "Note: FOGCrypt.zip not available for ${CLIENT_VERSION}"; \
        rm -f FOGCrypt.zip; \
    fi && \
    chown www-data:www-data FOGService.msi SmartInstaller.exe && \
    chmod 644 FOGService.msi SmartInstaller.exe && \
    for optional in FogPrep.zip FOGCrypt.zip; do \
        if [ -f "$optional" ]; then \
            chown www-data:www-data "$optional"; \
            chmod 644 "$optional"; \
        fi; \
    done && \
    echo "✓ FOGService.msi (${size_msi} bytes) SmartInstaller.exe (${size_smart} bytes)"

# Set all permissions and ownership after all copy operations are complete
RUN chmod +x /sbin/entrypoint.sh && \
    chmod +x /opt/fog/scripts/*.sh && \
    chmod +x /opt/fog/service/*/* && \
    chmod -R 755 /var/www/html/fog /tftpboot /opt/fog/snapins && \
    chown -R www-data:www-data \
        /var/www/html/fog \
        /tftpboot \
        /opt/fog/snapins \
        /opt/fog/snapins/ssl \
        /opt/fog/service \
        /opt/fog/secure-boot \
        /opt/fog/config \
        /opt/migration

# Clean up temporary fog user used for building
RUN userdel -r fog && \
    sed -i '/fog ALL=(ALL:ALL) NOPASSWD:ALL/d' /etc/sudoers

# Create volume mount points for persistent data
VOLUME ["/images", "/tftpboot", "/opt/fog/snapins", "/opt/fog/log", "/opt/fog/config", "/opt/fog/secure-boot"]

# Expose ports that are always needed and not configurable
# Note: Apache ports (80/443) are configurable via environment variables
EXPOSE 69/udp 2049 21 111 32765 32767

ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]

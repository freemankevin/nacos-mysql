FROM mysql:8.3.0

# Add Nacos MySQL schema
ADD https://raw.githubusercontent.com/alibaba/nacos/develop/distribution/conf/mysql-schema.sql /docker-entrypoint-initdb.d/nacos-mysql.sql
RUN chown -R mysql:mysql /docker-entrypoint-initdb.d/nacos-mysql.sql

# Set up schema-related security repositories
ENV releasever 8
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
        aarch64) basearch='aarch64' ;; \
        x86_64) basearch='x86_64' ;; \
        *) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; \
    esac; \
    { \
        echo "[ol8_update4_security_$basearch]"; \
        echo "name=Oracle Linux $releasever Update 4 - $basearch - security validation"; \
        echo "baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/4/security/validation/$basearch/"; \
        echo "enabled=1"; \
        echo "gpgcheck=1"; \
        echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle"; \
    } | tee /etc/yum.repos.d/ol8_update4_security.repo

# Security updates
RUN set -eux; \
    microdnf update -y gnutls libgcrypt; \
    microdnf clean all

# Python security library updates
RUN pip3 install --upgrade pip;\
    pip3 install --upgrade cryptography;\
    pip3 install --upgrade paramiko;\
    pip3 cache purge

# Install dependencies for building OpenSSL
RUN microdnf install -y \
    gcc \
    make \
    perl \
    zlib1g-dev \
    wget

# Download and install OpenSSL
RUN cd /tmp/ && \
    wget https://www.openssl.org/source/openssl-3.2.1.tar.gz && \
    tar -zxf openssl-3.2.1.tar.gz && \
    cd openssl-3.2.1 && \
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib && \
    make && \
    make install

# Configure system to use the newly installed OpenSSL
RUN echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/openssl-3.2.1.conf && \
    ldconfig && \
    echo 'export PATH="/usr/local/openssl/bin:$PATH"' >> /etc/profile && \
    echo 'export LD_LIBRARY_PATH="/usr/local/openssl/lib:$LD_LIBRARY_PATH"' >> /etc/profile

# Cleanup to reduce image size
RUN microdnf clean && \
    rm -rf /tmp/*

# Verify OpenSSL installation
RUN ["/bin/bash", "-c", "source /etc/profile && openssl version"]

EXPOSE 3306

CMD ["mysqld", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci"]
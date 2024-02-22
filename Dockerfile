FROM mysql:8.3.0

# Add Nacos MySQL schema
ADD https://raw.githubusercontent.com/alibaba/nacos/develop/distribution/conf/mysql-schema.sql /docker-entrypoint-initdb.d/nacos-mysql.sql
RUN chown -R mysql:mysql /docker-entrypoint-initdb.d/nacos-mysql.sql

# Set up schema-related security repositories
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
RUN pip3 install --upgrade cryptography==42.0.2;\
    pip3 install --upgrade paramiko==3.4.0;\
    pip3 cache purge

EXPOSE 3306

CMD ["mysqld", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci"]
FROM postgres:9.6.24

# Fix for Debian Stretch EOL (End of Life)
# 1. Remove the broken pgdg repository
# 2. Point sources.list to the archive.debian.org mirrors
RUN rm -rf /etc/apt/sources.list.d/pgdg.list && \
    echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    # Tell apt to ignore the fact that the archive certificates are expired
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update && \
    apt-get install -y openssl sudo && \
    rm -rf /var/lib/apt/lists/*

# Grant the postgres user permission to handle cert directories
RUN echo "postgres ALL=(root) NOPASSWD: /usr/bin/mkdir, /bin/chown, /usr/bin/openssl" > /etc/sudoers.d/postgres

# Copy scripts as before
COPY --chmod=755 init-ssl.sh /docker-entrypoint-initdb.d/init-ssl.sh
COPY --chmod=755 wrapper.sh /usr/local/bin/wrapper.sh

ENTRYPOINT ["/usr/local/bin/wrapper.sh"]
CMD ["postgres"]

# Using the last official 9.6 release
FROM postgres:9.6.24

# Install tools needed for SSL and permissions
RUN apt-get update && apt-get install -y openssl sudo && rm -rf /var/lib/apt/lists/*

# Grant the postgres user permission to handle cert directories
RUN echo "postgres ALL=(root) NOPASSWD: /usr/bin/mkdir, /bin/chown, /usr/bin/openssl" > /etc/sudoers.d/postgres

# Copy our Railway-style scripts
# These go into /docker-entrypoint-initdb.d/ to run during database creation
COPY --chmod=755 init-ssl.sh /docker-entrypoint-initdb.d/init-ssl.sh
COPY --chmod=755 wrapper.sh /usr/local/bin/wrapper.sh

# Set the entrypoint to our custom wrapper
ENTRYPOINT ["/usr/local/bin/wrapper.sh"]

# Default command to start the server
CMD ["postgres"]
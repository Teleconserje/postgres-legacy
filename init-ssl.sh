#!/bin/bash
set -e

# Path setup - PGDATA is provided by the official postgres:9.6 image
SSL_DIR="$PGDATA/certs"
SSL_SERVER_CRT="$SSL_DIR/server.crt"
SSL_SERVER_KEY="$SSL_DIR/server.key"
SSL_SERVER_CSR="$SSL_DIR/server.csr"
SSL_ROOT_KEY="$SSL_DIR/root.key"
SSL_ROOT_CRT="$SSL_DIR/root.crt"
SSL_V3_EXT="$SSL_DIR/v3.ext"
POSTGRES_CONF_FILE="$PGDATA/postgresql.conf"

# Ensure directory exists with correct permissions
sudo mkdir -p "$SSL_DIR"
sudo chown postgres:postgres "$SSL_DIR"

echo "Generating Railway-compatible SSL Chain for Postgres 9.6..."

# 1. Generate Root CA
openssl req -new -x509 -days "${SSL_CERT_DAYS:-820}" -nodes -text \
    -out "$SSL_ROOT_CRT" \
    -keyout "$SSL_ROOT_KEY" \
    -subj "/CN=root-ca"

chmod og-rwx "$SSL_ROOT_KEY"

# 2. Generate Server Certificate Signing Request (CSR)
openssl req -new -nodes -text \
    -out "$SSL_SERVER_CSR" \
    -keyout "$SSL_SERVER_KEY" \
    -subj "/CN=localhost"

chmod og-rwx "$SSL_SERVER_KEY"

# 3. Create X509v3 extensions file (crucial for modern client drivers)
cat >| "$SSL_V3_EXT" <<EOF
[v3_req]
authorityKeyIdentifier = keyid, issuer
basicConstraints = critical, CA:TRUE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = DNS:localhost
EOF

# 4. Sign the Server Cert with the Root CA
openssl x509 -req -in "$SSL_SERVER_CSR" -extfile "$SSL_V3_EXT" -extensions v3_req \
    -text -days "${SSL_CERT_DAYS:-820}" \
    -CA "$SSL_ROOT_CRT" -CAkey "$SSL_ROOT_KEY" -CAcreateserial \
    -out "$SSL_SERVER_CRT"

sudo chown postgres:postgres "$SSL_SERVER_CRT" "$SSL_SERVER_KEY"

# 5. Apply Configuration to postgresql.conf
# Note: shared_preload_libraries is supported in 9.6
cat >> "$POSTGRES_CONF_FILE" <<EOF
ssl = on
ssl_cert_file = '$SSL_SERVER_CRT'
ssl_key_file = '$SSL_SERVER_KEY'
ssl_ca_file = '$SSL_ROOT_CRT'
shared_preload_libraries = 'pg_stat_statements'
listen_addresses = '*'
EOF

# 6. Adjust HBA to allow SSL connections
echo "hostssl all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
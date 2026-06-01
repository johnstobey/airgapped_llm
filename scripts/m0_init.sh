#!/bin/bash
# CAAA M0 Initialization Script
# Generates PKI certificates and validates workspace structure

set -euo pipefail

echo "=== CAAA M0 Initialization ==="
echo "Generating self-signed PKI certificates for mTLS..."

# Determine installation directory
INSTALL_DIR="${CAAA_INSTALL_DIR:-/opt/caaa}"
PKI_DIR="${INSTALL_DIR}/pki"

# Create directories
sudo mkdir -p "${PKI_DIR}"
sudo chown "$(whoami)": "$(whoami)" "${INSTALL_DIR}"

# Run PKI generation (using cargo run for now, will be standalone binary in M1)
echo "Initializing PKI infrastructure..."
cargo run --bin caaa-pki-init --release 2>/dev/null || {
    echo "Warning: caaa-pki-init binary not yet built. Using fallback openssl method..."
    
    # Fallback: Generate CA
    openssl genrsa -out "${PKI_DIR}/ca.key" 4096 2>/dev/null
    openssl req -x509 -new -nodes -key "${PKI_DIR}/ca.key" -sha256 -days 365 \
        -out "${PKI_DIR}/ca.crt" \
        -subj "/O=CAAA Air-Gapped System/CN=CAAA Root CA" 2>/dev/null
    
    # Generate Server Cert
    openssl genrsa -out "${PKI_DIR}/server.key" 4096 2>/dev/null
    openssl req -new -key "${PKI_DIR}/server.key" \
        -out "${PKI_DIR}/server.csr" \
        -subj "/O=CAAA Air-Gapped System/CN=caaa-core.local" 2>/dev/null
    
    cat > "${PKI_DIR}/server.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:caaa-core.local,IP:127.0.0.1
EOF
    
    openssl x509 -req -in "${PKI_DIR}/server.csr" -CA "${PKI_DIR}/ca.crt" \
        -CAkey "${PKI_DIR}/ca.key" -CAcreateserial \
        -out "${PKI_DIR}/server.crt" -days 365 -sha256 \
        -extfile "${PKI_DIR}/server.ext" 2>/dev/null
    
    # Generate Client Cert
    openssl genrsa -out "${PKI_DIR}/client.key" 4096 2>/dev/null
    openssl req -new -key "${PKI_DIR}/client.key" \
        -out "${PKI_DIR}/client.csr" \
        -subj "/O=CAAA Air-Gapped System/CN=caaa-applet.local" 2>/dev/null
    
    cat > "${PKI_DIR}/client.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF
    
    openssl x509 -req -in "${PKI_DIR}/client.csr" -CA "${PKI_DIR}/ca.crt" \
        -CAkey "${PKI_DIR}/ca.key" -CAcreateserial \
        -out "${PKI_DIR}/client.crt" -days 365 -sha256 \
        -extfile "${PKI_DIR}/client.ext" 2>/dev/null
    
    # Cleanup intermediate files
    rm -f "${PKI_DIR}"/*.csr "${PKI_DIR}"/*.ext "${PKI_DIR}"/*.srl
}

# Verify certificates
echo "Verifying certificate chain..."
if [ -f "${PKI_DIR}/ca.crt" ] && [ -f "${PKI_DIR}/server.crt" ] && [ -f "${PKI_DIR}/client.crt" ]; then
    echo "✓ CA Certificate: ${PKI_DIR}/ca.crt"
    echo "✓ Server Certificate: ${PKI_DIR}/server.crt"
    echo "✓ Client Certificate: ${PKI_DIR}/client.crt"
    
    # Validate server cert against CA
    openssl verify -CAfile "${PKI_DIR}/ca.crt" "${PKI_DIR}/server.crt" >/dev/null 2>&1 && \
        echo "✓ Server certificate validated against CA" || \
        echo "✗ Server certificate validation failed"
    
    # Validate client cert against CA
    openssl verify -CAfile "${PKI_DIR}/ca.crt" "${PKI_DIR}/client.crt" >/dev/null 2>&1 && \
        echo "✓ Client certificate validated against CA" || \
        echo "✗ Client certificate validation failed"
    
    echo ""
    echo "=== M0 Initialization Complete ==="
    echo "Next steps:"
    echo "  1. Build caaa-core: cargo build --release -p caaa-core"
    echo "  2. Build caaa-applet: cargo build --release -p caaa-applet"
    echo "  3. Run tests: cargo test --workspace"
    echo ""
else
    echo "✗ Certificate generation failed!"
    exit 1
fi

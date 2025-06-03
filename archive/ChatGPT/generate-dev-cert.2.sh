#!/bin/bash
# === Configuration ===
DOMAIN=$1
DAYS_VALID=825
CERTS_DIR="./certs"
ROOT_CA_KEY="$CERTS_DIR/rootCA.key"
ROOT_CA_CERT="$CERTS_DIR/rootCA.pem"
# === Check for domain argument ===
if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <domain>"
  exit 1
fi
mkdir -p "$CERTS_DIR"
# === Step 1: Create Root CA if it doesn't exist ===
if [[ ! -f "$ROOT_CA_KEY" || ! -f "$ROOT_CA_CERT" ]]; then
  echo "Generating Root CA..."
  openssl genrsa -out "$ROOT_CA_KEY" 4096
  openssl req -x509 -new -nodes -key "$ROOT_CA_KEY" -sha256 -days 3650 \
    -out "$ROOT_CA_CERT" -subj "/C=US/ST=Local/L=Dev/O=MyOrg/OU=DevCA/CN=MyRootCA"
else
  echo "Root CA already exists. Skipping CA generation."
fi
# === Step 2: Create OpenSSL config with SANs ===
CERT_CNF="$CERTS_DIR/$DOMAIN.cnf"
cat > "$CERT_CNF" <<EOF
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext
[ dn ]
C  = US
ST = Local
L  = Dev
O  = MyOrg
OU = Dev
CN = $DOMAIN
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = $DOMAIN
DNS.2 = www.$DOMAIN
IP.1  = 127.0.0.1
EOF
# === Step 3: Generate private key and CSR ===
openssl genrsa -out "$CERTS_DIR/$DOMAIN.key" 2048
openssl req -new -key "$CERTS_DIR/$DOMAIN.key" -out "$CERTS_DIR/$DOMAIN.csr" -config "$CERT_CNF"
# === Step 4: Sign the certificate with the Root CA ===
openssl x509 -req -in "$CERTS_DIR/$DOMAIN.csr" \
  -CA "$ROOT_CA_CERT" -CAkey "$ROOT_CA_KEY" -CAcreateserial \
  -out "$CERTS_DIR/$DOMAIN.crt" -days $DAYS_VALID -sha256 \
  -extensions req_ext -extfile "$CERT_CNF"
# === Step 5: Create PEM bundle ===
cat "$CERTS_DIR/$DOMAIN.crt" "$CERTS_DIR/$DOMAIN.key" > "$CERTS_DIR/$DOMAIN.pem"
# === Step 6: Create PFX (PKCS#12) bundle ===
openssl pkcs12 -export \
  -out "$CERTS_DIR/$DOMAIN.pfx" \
  -inkey "$CERTS_DIR/$DOMAIN.key" \
  -in "$CERTS_DIR/$DOMAIN.crt" \
  -certfile "$ROOT_CA_CERT" \
  -passout pass:
# === Done ===
echo ""
echo "Generated for $DOMAIN:"
echo "  - Private Key     : $CERTS_DIR/$DOMAIN.key"
echo "  - Certificate     : $CERTS_DIR/$DOMAIN.crt"
echo "  - PEM Bundle      : $CERTS_DIR/$DOMAIN.pem"
echo "  - PFX Bundle      : $CERTS_DIR/$DOMAIN.pfx (no password)"
echo "  - Root CA Cert    : $ROOT_CA_CERT"
echo ""
echo "Remember to trust the Root CA once in your system/browser."

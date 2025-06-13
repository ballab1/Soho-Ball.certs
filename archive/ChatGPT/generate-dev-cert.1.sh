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
echo ""
echo "Certificate for $DOMAIN generated:"
echo "  - $CERTS_DIR/$DOMAIN.key"
echo "  - $CERTS_DIR/$DOMAIN.crt"
echo "  - Root CA: $ROOT_CA_CERT (trust this once)"

Usage
chmod +x generate-dev-cert.sh
./generate-dev-cert.sh myapp.local
This generates:
	•	myapp.local.crt and myapp.local.key
	•	Signed by rootCA.pem (which you trust once)

Optional: Add a Hosts Entry
sudo echo "127.0.0.1 myapp.local" >> /etc/hosts


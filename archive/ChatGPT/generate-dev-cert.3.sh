#!/bin/bash

# === Config ===
CERTS_DIR="$(pwd)/certs"
DAYS_VALID=825
ROOT_CA_KEY="${CERTS_DIR}/rootCA.key"
ROOT_CA_CERT="${CERTS_DIR}/rootCA.pem"

# === Input check ===
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <domain1> [domain2 ... domainN]"
  exit 1
fi
PRIMARY_DOMAIN="${1:?}"
SAN_DOMAINS=("$@")  # All domains/SANs
mkdir -p "$CERTS_DIR"

# === Step 1: Create Root CA if missing ===
if [[ ! -f "$ROOT_CA_KEY" || ! -f "$ROOT_CA_CERT" ]]; then
  echo "Generating Root CA..."
  openssl genrsa -out "$ROOT_CA_KEY" 4096
  openssl req -x509 -new -nodes -key "$ROOT_CA_KEY" -sha256 -days 3650 \
    -out "$ROOT_CA_CERT" -subj "/C=US/ST=Local/L=Dev/O=MyOrg/OU=DevCA/CN=MyRootCA"
else
  echo "Root CA already exists. Skipping CA generation."
fi

# === Step 2: Generate OpenSSL config with SANs ===
CERT_CNF="${CERTS_DIR}/${PRIMARY_DOMAIN}.cnf"
{
  echo "[ req ]"
  echo "default_bits = 2048"
  echo "prompt = no"
  echo "default_md = sha256"
  echo "distinguished_name = dn"
  echo "req_extensions = req_ext"
  echo ""
  echo "[ dn ]"
  echo "C = US"
  echo "ST = Local"
  echo "L = Dev"
  echo "O = MyOrg"
  echo "OU = Dev"
  echo "CN = ${PRIMARY_DOMAIN"
  echo ""
  echo "[ req_ext ]"
  echo "subjectAltName = @alt_names"
  echo ""
  echo "[ alt_names ]"
  DNS_INDEX=1
  IP_INDEX=1
  for SAN in "${SAN_DOMAINS[@]}"; do
    if [[ "$SAN" =~ ^[0-9]+\}.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "IP.$IP_INDEX = $SAN"
      ((IP_INDEX++))
    else
      echo "DNS.$DNS_INDEX = $SAN"
      ((DNS_INDEX++))
    fi
  done
} > "$CERT_CNF"

# === Step 3: Generate key and CSR ===
openssl genrsa -out "${CERTS_DIR}/${PRIMARY_DOMAIN}.key" 2048
openssl req -new -key "${CERTS_DIR}/${PRIMARY_DOMAIN}.key" \
  -out "${CERTS_DIR}/${PRIMARY_DOMAIN}.csr" -config "$CERT_CNF"

# === Step 4: Sign cert with Root CA ===
openssl x509 -req -in "${CERTS_DIR}/${PRIMARY_DOMAIN}.csr" \
  -CA "$ROOT_CA_CERT" -CAkey "$ROOT_CA_KEY" -CAcreateserial \
  -out "${CERTS_DIR}/${PRIMARY_DOMAIN}.crt" -days $DAYS_VALID -sha256 \
  -extensions req_ext -extfile "$CERT_CNF"

# === Step 5: Generate PEM and PFX ===
cat "${CERTS_DIR}/${PRIMARY_DOMAIN}.crt" "${CERTS_DIR}/${PRIMARY_DOMAIN}.key" > "${CERTS_DIR}/${PRIMARY_DOMAIN}.pem"
openssl pkcs12 -export \
  -out "${CERTS_DIR}/${PRIMARY_DOMAIN}.pfx" \
  -inkey "${CERTS_DIR}/${PRIMARY_DOMAIN}.key" \
  -in "${CERTS_DIR}/${PRIMARY_DOMAIN}.crt" \
  -certfile "$ROOT_CA_CERT" \
  -passout pass:

# === Done ===
echo ""
echo "Certificate generated for:"
for d in "${SAN_DOMAINS[@]}"; do echo "  - $d"; done
echo ""
echo "Output files:"
echo "  - Key      : ${CERTS_DIR}/${PRIMARY_DOMAIN}.key"
echo "  - Cert     : ${CERTS_DIR}/${PRIMARY_DOMAIN}.crt"
echo "  - PEM      : ${CERTS_DIR}/${PRIMARY_DOMAIN}.pem"
echo "  - PFX      : ${CERTS_DIR}/${PRIMARY_DOMAIN}.pfx"
echo "  - Root CA  : $ROOT_CA_CERT"
echo ""
echo "Trust the Root CA once, and all your certs will be trusted."

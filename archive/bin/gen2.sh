#!/bin/bash
source ~/.bin/trap.bashlib

declare -ri KEYLENGTH=2048
declare -ri VALID_DAYS=300065
declare -r PASSPHRASE='pass:wxyz'

declare -r CERTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
declare -r CA_PASS_KEY="${CERTS_DIR}/dummy-pass.key"
declare -r CA_ROOT_KEY="${CERTS_DIR}/dummy-root.key"
declare -r CA_ROOT_CRT="${CERTS_DIR}/dummy-root.crt"

declare -r HOST_KEY="${CERTS_DIR}/dummy-host.key"
declare -r HOST_CSR="${CERTS_DIR}/dummy-host.csr"
declare -r HOST_CRT="${CERTS_DIR}/dummy-host.crt"

declare -r CHAIN_CRT="${CERTS_DIR}/dummy-chain.crt"

#declare -r SERVER_CRT="${CERTS_DIR}/server.crt"
#declare -r PARAM_PEM="${CERTS_DIR}/dhparam.pem"

for f in CA_PASS_KEY CA_ROOT_KEY CA_ROOT_CRT CLASS2_KEY CLASS2_CSR CLASS2_CRT HOST_KEY HOST_CSR HOST_CRT CHAIN_CRT; do
  [ -e "${!f}" ] && rm "${!f}"
done

declare CFG_FILE="${CERTS_DIR}/gen.host.cfg"
set -ev

# generate a "$KEYLENGTH-bit" RSA key file for ROOT key
openssl genrsa -des3 -passout "$PASSPHRASE" -out "$CA_PASS_KEY" "$KEYLENGTH"

# use rsa_keyfile to generate our ROOT key
openssl rsa -passin "$PASSPHRASE" -in "$CA_PASS_KEY" -out "$CA_ROOT_KEY"

# Signing our root Certificate
openssl req -x509 -key "$CA_ROOT_KEY" -days "$VALID_DAYS" -config "$CFG_FILE" -extensions root_exts -out "$CA_ROOT_CRT"

# generate a "$KEYLENGTH-bit" RSA key file for HOST key
openssl genrsa -out "$HOST_KEY" "$KEYLENGTH"

# generate a new Certificate Signing Request (CSR) file using our key
openssl req -new -config "$CFG_FILE" -key "$HOST_KEY" -extensions req_ext -out "$HOST_CSR"


# Signing our own Certificate
openssl x509 -req -in "$HOST_CSR" -days "$VALID_DAYS" -CAkey "$CA_ROOT_KEY" -CA "$CA_ROOT_CRT" -CAcreateserial -extfile "$CFG_FILE" -extensions server_exts -out "$HOST_CRT"

cat "$HOST_CRT" "$CA_ROOT_CRT" > "$CHAIN_CRT"

openssl verify -CAfile "$CA_ROOT_CRT" "$HOST_CRT"
openssl x509 -text -ext extendedKeyUsage -in "$CA_ROOT_CRT" -noout
openssl x509 -text -ext extendedKeyUsage -in "$CHAIN_CRT" -noout


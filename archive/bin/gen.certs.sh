#!/bin/bash
source ~/.bin/trap.bashlib

function main() {

    local -ri KEYLENGTH=2048
    local -ri VALID_DAYS=300065
    local -r PASSPHRASE='pass:wxyz'

    local -r CERTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    local -r CA_PASS_KEY="${CERTS_DIR}/gen.certs-pass.key"
    local -r CA_ROOT_KEY="${CERTS_DIR}/gen.certs-root.key"
    local -r CA_ROOT_CRT="${CERTS_DIR}/gen.certs-root.crt"

    local -r HOST_KEY="${CERTS_DIR}/gen.certs-host.key"
    local -r HOST_CSR="${CERTS_DIR}/gen.certs-host.csr"
    local -r HOST_CRT="${CERTS_DIR}/gen.certs-host.crt"

    local -r CHAIN_CRT="${CERTS_DIR}/gen.certs-chain.crt"

#    local -r SERVER_CRT="${CERTS_DIR}/server.crt"
#    local -r PARAM_PEM="${CERTS_DIR}/dhparam.pem"

    for f in CA_PASS_KEY CA_ROOT_KEY CA_ROOT_CRT CLASS2_KEY CLASS2_CSR CLASS2_CRT HOST_KEY HOST_CSR HOST_CRT CHAIN_CRT; do
      [ -e "${!f}" ] && rm "${!f}"
    done

    local CFG_FILE="${CERTS_DIR}/gen.certs.cfg"
    set -ev

    # generate a "$KEYLENGTH" RSA key file for ROOT key
    openssl genrsa -des3 -passout "$PASSPHRASE" -out "$CA_PASS_KEY" "$KEYLENGTH"

    # use CA_PASS_KEY to generate our ROOT key
    openssl rsa -passin "$PASSPHRASE" -in "$CA_PASS_KEY" -out "$CA_ROOT_KEY"

    # Signing our root Certificate
    openssl req -x509 -key "$CA_ROOT_KEY" -days "$VALID_DAYS" -config "$CFG_FILE" -extensions root_exts -out "$CA_ROOT_CRT"
    #------------------------------------------------------------------------------------------
    # generate a "$KEYLENGTH" RSA key file for HOST key
    echo
    echo "openssl genrsa -out '$HOST_KEY' $KEYLENGTH"
    openssl genrsa -out "$HOST_KEY" "$KEYLENGTH"

    # generate a new Certificate Signing Request (CSR) file using our key
    echo
    echo "openssl req -new -config '$CFG_FILE' -key '$HOST_KEY' -extensions req_ext -out '$HOST_CSR'"
    openssl req -new -config "$CFG_FILE" -key "$HOST_KEY" -extensions req_ext -out "$HOST_CSR"


    # Signing our own Certificate
    echo
    echo "openssl x509 -req -in '$HOST_CSR' -days $VALID_DAYS -CAkey '$CA_ROOT_KEY' -CA '$CA_ROOT_CRT' -CAcreateserial -extfile '$CFG_FILE' -extensions server_exts -out '$HOST_CRT'"
    openssl x509 -req -in "$HOST_CSR" -days "$VALID_DAYS" -CAkey "$CA_ROOT_KEY" -CA "$CA_ROOT_CRT" -CAcreateserial -extfile "$CFG_FILE" -extensions server_exts -out "$HOST_CRT"

    cat "$HOST_CRT" "$CA_ROOT_CRT" > "$CHAIN_CRT"

    openssl verify -CAfile "$CA_ROOT_CRT" "$HOST_CRT"
    openssl x509 -text -ext extendedKeyUsage -in "$CA_ROOT_CRT" -noout
    openssl x509 -text -ext extendedKeyUsage -in "$CHAIN_CRT" -noout
}

main "$@"

#!/bin/bash

    declare -r dc_json="$(lib.yamlToJson "${WORKSPACE_DIR}/docker-compose.yml")"
    declare -A CERTS=()
    for key in 'dhparam.pem' 'server.key' 'server.crt' 'server.csr'; do
        CERTS["$key"]=${WORKSPACE_DIR}/$(jq --compact-output --monochrome-output --raw-output 'try .secrets."'$key'".file' <<< "$dc_json")
        [[ "${CERTS[$key]:-}" && "${CERTS['$key']}" != 'null' ]] && continue
        CERTS["$key"]="${secrets_dir}/$key"
    done


    # ensure we have self signed certs (incase they are not include in secrets dir
    if [ ! -e "${CERTS['dhparam.pem']}" ] || [ ! -e "${CERTS['server.key']}" ] || [ ! -e "${CERTS['server.crt']}" ]; then
        term.log '>> GENERATING SSL CERT\n' 'lt_magenta'

        declare tmp=$(mktemp -d)
        openssl genrsa -des3 -passout pass:wxyz -out "${tmp}/server.pass.key" 2048
        openssl rsa -passin pass:wxyz -in "${tmp}/server.pass.key" -out "${CERTS['server.key']}"

        openssl dhparam -out "${CERTS['dhparam.pem']}" 2048
        openssl req -new -key "${CERTS['server.key']}" -subj "/C=US/ST=Massachusetts/L=Mansfield/O=soho_ball/OU=home/OU=docker.nginx.io/CN=$(hostname)" -out "${CERTS['server.csr']}"
        openssl x509 -req -sha256 -days 300065 -in "${CERTS['server.csr']}" -signkey "${CERTS['server.key']}" -out "${CERTS['server.crt']}"

        openssl genrsa -des3 -passout pass:wxyz -out "${tmp}/client.pass.key" 2048
        openssl rsa -passin pass:wxyz -in "${tmp}/client.pass.key" -out client.key
        rm client.pass.key

        openssl req -new -key client.key -subj "/C=US/ST=Massachusetts/L=Mansfield/O=soho_ball/OU=home/OU=docker.nginx.io/CN=$(hostname)" -out client.csr
        openssl x509 -req -days 3650 -in client.csr -CA root.pem -CAkey root.key -set_serial 01 -out client.pem

        rm -rf "$tmp"
        term.log '>> GENERATING SSL CERT ... DONE\n' 'lt_magenta'
    fi


# https://github.com/Heziode/Simple-TLS-Client-Server-with-Node.js
if test $# -ne 3
then
    echo "Wrong number of arguments"
    exit 1
fi

ROOTPATH="$1"
FQDN=$2
PASSWORD=$3
RSABITS=4096

# make directories to work from
mkdir -p $ROOTPATH/certs/{server,client,ca,tmp}

PATH_CA=$ROOTPATH/certs/ca
PATH_SERVER=$ROOTPATH/certs/server
PATH_CLIENT=$ROOTPATH/certs/client
PATH_TMP=$ROOTPATH/certs/tmp

######
# CA #
######

openssl genrsa -des3 -passout pass:$PASSWORD -out $PATH_TMP/ca.key $RSABITS

# Create Authority Certificate
openssl req -new -x509 -days 365 -key $PATH_TMP/ca.key -out $PATH_CA/ca.crt -passin pass:$PASSWORD -subj "/C=FR/ST=./L=./O=ACME Signing Authority Inc/CN=."

##########
# SERVER #
##########

# Generate server key
openssl genrsa -out $PATH_SERVER/server.key $RSABITS

# Generate server cert
openssl req -new -key $PATH_SERVER/server.key -out $PATH_TMP/server.csr -passout pass:$PASSWORD -subj "/C=FR/ST=./L=./O=ACME Signing Authority Inc/CN=$FQDN"

# Sign server cert with self-signed cert
openssl x509 -req -days 365 -passin pass:$PASSWORD -in $PATH_TMP/server.csr -CA $PATH_CA/ca.crt -CAkey $PATH_TMP/ca.key -set_serial 01 -out $PATH_SERVER/server.crt

##########
# CLIENT #
##########

openssl genrsa -out $PATH_CLIENT/client.key $RSABITS

openssl req -new -key $PATH_CLIENT/client.key -out $PATH_TMP/client.csr -passout pass:$PASSWORD -subj "/C=FR/ST=./L=./O=ACME Signing Authority Inc/CN=CLIENT"

openssl x509 -req -days 365 -passin pass:$PASSWORD -in $PATH_TMP/client.csr -CA $PATH_CA/ca.crt -CAkey $PATH_TMP/ca.key -set_serial 01 -out $PATH_CLIENT/client.crt

exit 0
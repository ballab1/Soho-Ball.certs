#!/bin/bash

# THIS SCRIPT WAS CREATED FROM INFO EXTRACTED FROM CHATGPT

declare -ri SHOW_OPENSSL="${1:-0}"
declare -r CIPHER="${CIPHER:-}"
declare -r PASSPHRASE="${PASSPHRASE:-}"   # if PASSPHRASE is empty, CIPHER must also be empty
#declare -r CIPHER="${CIPHER:--aes256}"
#declare -r PASSPHRASE="${PASSPHRASE:-pass:wxyz}"
declare -ri KEYLENGTH="${KEYLENGTH:-4096}"
declare -ri VALID_DAYS="${VALID_DAYS:-300065}"
declare -r MYCA_DIR="${MYCA_DIR:-./myCA}"

declare -r CONFIG_FILE="${CONFIG_FILE:-${MYCA_DIR}/config.cnf}"
declare -r CA_ROOT_KEY="${CA_ROOT_KEY:-${MYCA_DIR}/private/SohoBall_CA.key}"
declare -r CA_ROOT_CRT="${CA_ROOT_CRT:-${MYCA_DIR}/certs/SohoBall_CA.crt}"
declare -r SERVER_KEY="${SERVER_KEY:-${MYCA_DIR}/private/SohoBall-Server.key}"
declare -r SERVER_CRT="${SERVER_CRT:-${MYCA_DIR}/certs/SohoBall-Server.crt}"
declare -r SERVER_CSR="${SERVER_CSR:-${MYCA_DIR}/csr/SohoBall-Server.csr}"
declare -r SERVER_DHPARAM="${SERVER_DHPARAM:-${MYCA_DIR}/dhparam.dh}"
declare -r MYCA_INTERMITTENT_DIR="${MYCA_INTERMITTENT_DIR:-${MYCA_DIR}/intermediate}"
declare -r INTERMEDIATE_CA_KEY="${INTERMEDIATE_CA_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall-K8sBackend_CA.key}"
declare -r INTERMEDIATE_CA_CRT="${INTERMEDIATE_CA_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sBackend_CA.crt}"
declare -r INTERMEDIATE_CA_CSR="${INTERMEDIATE_CA_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall-K8sBackend_CA.csr}"
declare -r INTERMEDIATE_CA_CHAIN="${INTERMEDIATE_CA_CHAIN:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sBackend_CA-Chain.crt}"
declare -r INTERMEDIATE_CA_SERVER_KEY="${INTERMEDIATE_CA_SERVER_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall_BE-server.key}"
declare -r INTERMEDIATE_CA_SERVER_CRT="${INTERMEDIATE_CA_SERVER_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall_BE-server.crt}"
declare -r INTERMEDIATE_CA_SERVER_CSR="${INTERMEDIATE_CA_SERVER_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall_BE-server.csr}"
declare -r INTERMEDIATE_PKS="${INTERMEDIATE_PKS:-${MYCA_INTERMITTENT_DIR}/SohoBall_BE.pks}"
declare -r INTERMEDIATE_CA_2_KEY="${INTERMEDIATE_CA_2_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall-K8sFrontend_CA.key}"
declare -r INTERMEDIATE_CA_2_CRT="${INTERMEDIATE_CA_2_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sFrontend_CA.crt}"
declare -r INTERMEDIATE_CA_2_CSR="${INTERMEDIATE_CA_2_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall-K8sFrontend_CA.csr}"
declare -r INTERMEDIATE_CA_2_CHAIN="${INTERMEDIATE_CA_2_CHAIN:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sFrontend_CA-Chain.crt}"
declare -r INTERMEDIATE_CA_2_SERVER_KEY="${INTERMEDIATE_2_CA_SERVER_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall_FE-server.key}"
declare -r INTERMEDIATE_CA_2_SERVER_CRT="${INTERMEDIATE_2_CA_SERVER_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall_FE-server.crt}"
declare -r INTERMEDIATE_CA_2_SERVER_CSR="${INTERMEDIATE_2_CA_SERVER_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall_FE-server.csr}"
declare -r INTERMEDIATE_2_PKS="${INTERMEDIATE_2_PKS:-${MYCA_INTERMITTENT_DIR}/SohoBall_FE.pks}"

declare -r BLUE='\x1b[94m'
declare -r GREEN='\x1b[32m'
declare -r GREY='\x1b[90m'
declare -r MAGENTA='\x1b[95m'
declare -r RED='\x1b[31m'
declare -r RESET='\x1b[0m'
declare -r WHITE='\x1b[97m'

#------------------------------------------------------------------------------
function gen_certs::displayCertificateContents() {

    [ "${SHOW_OPENSSL:-0}" -ne 0 ] && return

    local -r certificate="${1:?}"

    if [ ! -f "$certificate" ]; then
        printf '\n%sDisplay CERTIFICATE failed. %s does not exist.%s\n' "$RED" "$certificate" "$RESET" >&2
        exit
    fi
    printf '\n\n%s\n' "$certificate"

    # display contents of our own Certificates
    "$OPENSSL" x509 -in "$certificate" -noout -text
}

#------------------------------------------------------------------------------
function gen_certs::displayCertificateSigningRequest() {

    [ "${SHOW_OPENSSL:-0}" -ne 0 ] && return

    local -r csr="${1:?}"

    if [ ! -f "$csr" ]; then
        printf '\n%sDisplay CSR failed. %s does not exist.%s\n' "$RED" "$csr" "$RESET" >&2
        exit
    fi
    printf '\n\n%s\n' "$csr"

    "$OPENSSL" req -in "$csr" -noout -text
}

#------------------------------------------------------------------------------
function gen_certs::displayKeyContents() {

    [ "${SHOW_OPENSSL:-0}" -ne 0 ] && return

    local -r key="${1:?}"

    if [ ! -f "$key" ]; then
        printf '\n%sDisplay KEY failed. %s does not exist.%s\n' "$RED" "$key" "$RESET" >&2
        exit
    fi
    printf '\n\n%s\n' "$key"

    # display contents of our key
    local -a params=()
    [ "${PASSPHRASE:-}" ] && parans=( '-passin' "$PASSPHRASE" )
    "$OPENSSL" pkey -in "$key" -noout -text "${params[@]}"
}

#------------------------------------------------------------------------------
function gen_certs::displayDhContents() {

    [ "${SHOW_OPENSSL:-0}" -ne 0 ] && return
    local -r pem="${1:?}"


    if [ ! -f "$pem" ]; then
        printf '\n%sDisplay DH failed. %s does not exist.%s\n' "$RED" "$pem" "$RESET" >&2
        exit
    fi
    printf '\n\n%s\n' "$pem"

    # display contents of our key
    "$OPENSSL" dhparam -in "$pem" -noout -text
}

#------------------------------------------------------------------------------
function gen_certs::displayPem() {

    [ "${SHOW_OPENSSL:-0}" -ne 0 ] && return

    local -r pem="${1:?}"

    if [ ! -f "$pem" ]; then
        printf '\n%sDisplay PEM failed. %s does not exist.%s\n' "$RED" "$key" "$RESET" >&2
        exit
    fi

    local -r out="${MYCA_DIR}/crl/$(basename "$pem").inf"
    case "${pem##*.}" in
       csr)
          gen_certs::displayCertificateSigningRequest "$pem" > "$out";;
       crt)
          gen_certs::displayCertificateContents "$pem" > "$out";;
       dh)
          gen_certs::displayDhContents "$pem" > "$out";;
       key)
          gen_certs::displayKeyContents "$pem" > "$out";;
       *)
          printf '%sFile with invalid extension, must be csr|crt|key|dh%s\n' "$RED" "$RESET";;
    esac
}

#------------------------------------------------------------------------------
function gen_certs::run() {
  {
    echo -en "$GREY"
    for p in "$@"; do
      printf '%s ' "$p"
    done
    echo -e "$RESET"
  } >&2
  "$@"
}

if [ "${SHOW_OPENSSL:-1}" -ne 1 ]; then
   function RUN() {
     gen_certs::run 'openssl' "$@"
   }
   declare -r OPENSSL='RUN'
else
   declare -r OPENSSL='openssl'
fi

#------------------------------------------------------------------------------
function gen_certs::title() {

    local -r title="${1:?}"

    echo -e '\n\n-------------------------------------------------------------\n\n'
    echo -e "${WHITE}${title}${RESET}"
}

#------------------------------------------------------------------------------

echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS${RESET}"

set -ve

# Prepare Environment
export MSYS_NO_PATHCONV=1
export MSYS2_ENV_CONV_EXCL='*'
[ -d "$MYCA_DIR" ] && rm -rf "$MYCA_DIR"
mkdir -p "$MYCA_DIR"/{certs,crl,newcerts,private,csr}
mkdir -p "$MYCA_INTERMITTENT_DIR"/{certs,crl,newcerts,private,csr}
chmod 700 "$MYCA_DIR"/private
chmod 700 "$MYCA_INTERMITTENT_DIR"/private
touch "$MYCA_DIR"/index.txt
touch "$MYCA_INTERMITTENT_DIR"/index.txt
echo 1000 > "$MYCA_DIR"/serial
echo 1000 > "$MYCA_INTERMITTENT_DIR"/serial
echo 1000 > "$MYCA_INTERMITTENT_DIR"/crlnumber

set +ve

echo -e "${BLUE}Create OpenSSL configuration file to configure OpenSSL:${RESET} '$(basename $CONFIG_FILE)'"
#   This enables proper CA management.
cat << EOF > "$CONFIG_FILE"
[ ca ]
default_ca = rootca

[ rootca ]
dir                 = $MYCA_DIR
database            = \$dir/index.txt
serial              = \$dir/serial
new_certs_dir       = \$dir/newcerts
certificate         = $CA_ROOT_CRT
private_key         = $CA_ROOT_KEY
default_days        = $VALID_DAYS
default_md          = sha256
default_bits        = $KEYLENGTH
distinguished_name  = rootca_distinguished_name
x509_extensions     = v3_rootca
prompt              = no
policy              = policy_match  # or policy_anything / policy_loose

[ policy_match ]
countryName         = match
stateOrProvinceName = optional
organizationName    = match
commonName          = supplied

[ intermediate_ca ]
dir                = $MYCA_INTERMITTENT_DIR
database           = \$dir/index.txt
serial             = \$dir/serial
new_certs_dir      = \$dir/newcerts
certificate        = $INTERMEDIATE_CA_CRT
private_key        = $INTERMEDIATE_CA_KEY
default_md         = sha256
policy             = policy_loose
default_days       = $VALID_DAYS
default_bits       = $KEYLENGTH
x509_extensions    = v3_rootca
distinguished_name = intermediate_distinguished_name
prompt             = no

[ intermediate_ca_2 ]
dir                = $MYCA_INTERMITTENT_DIR
database           = \$dir/index.txt
serial             = \$dir/serial
new_certs_dir      = \$dir/newcerts
certificate        = $INTERMEDIATE_CA_2_CRT
private_key        = $INTERMEDIATE_CA_2_KEY
default_md         = sha256
policy             = policy_loose
default_days       = $VALID_DAYS
default_bits       = $KEYLENGTH
x509_extensions    = v3_rootca
distinguished_name = intermediate_2_distinguished_name
prompt             = no

[ v3_csr ]
default_days       = $VALID_DAYS
default_md         = sha256
default_bits       = $KEYLENGTH
x509_extensions    = v3_rootca
#distinguished_name = server_distinguished_name
prompt             = no

[ v3_req ]
default_days       = $VALID_DAYS
default_md         = sha256
default_bits       = $KEYLENGTH
x509_extensions    = v3_rootca
distinguished_name = distinguished_name
prompt             = no

[ v3_req2 ]
default_days       = $VALID_DAYS
default_md         = sha256
default_bits       = $KEYLENGTH
x509_extensions    = v3_rootca
distinguished_name = server_distinguished_name
prompt             = no

[ v3_req2_2 ]
default_days       = $VALID_DAYS
default_md         = sha256
default_bits       = $KEYLENGTH
x509_extensions    = v3_rootca
distinguished_name = server_2_distinguished_name
prompt             = no

[ v3_rootca ]
basicConstraints       = critical, CA:true
subjectKeyIdentifier   = hash
keyUsage               = critical, keyCertSign, cRLSign
authorityKeyIdentifier = keyid:always, issuer:always
crlDistributionPoints  = URI:http://example.home/crl.pem
1.3.6.1.5.5.7.1.9      = ASN1:NULL

[ intermediate_exts ]
basicConstraints        = critical, CA:false
subjectKeyIdentifier    = hash
#authorityKeyIdentifier = keyid, issuer
#extendedKeyUsage       = serverAuth, clientAuth
extendedKeyUsage        = serverAuth
keyUsage                = keyEncipherment, dataEncipherment, digitalSignature

[ server_exts ]
basicConstraints        = critical, CA:false
subjectKeyIdentifier    = hash
#authorityKeyIdentifier = keyid, issuer
#extendedKeyUsage       = serverAuth, clientAuth
extendedKeyUsage        = serverAuth
keyUsage                = keyEncipherment, dataEncipherment, digitalSignature
subjectAltName          = @alt_names

[ rootca_distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
commonName              = Ballantyne home-network CA
emailAddress            = ballantyne.robert@gmail.com

[ intermediate_distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
commonName              = Ballantyne k8s-backend Intermediate CA
emailAddress            = ballantyne.robert@gmail.com

[ intermediate_2_distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
commonName              = Ballantyne k8s-frontend Intermediate CA
emailAddress            = ballantyne.robert@gmail.com

[ server_distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
commonName              = Ballantyne k8s-backend
emailAddress            = ballantyne.robert@gmail.com

[ server_2_distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
commonName              = Ballantyne k8s-frontend
emailAddress            = ballantyne.robert@gmail.com

[ distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
commonName              = Ballantyne home
emailAddress            = ballantyne.robert@gmail.com

[ alt_names ]
DNS.1 = *.home
DNS.2 = *.ubuntu.home
DNS.3 = *.k8s.home
DNS.4 = *.prod.k8s.home
DNS.5 = *.dev.k8s.home
IP.1  = 127.0.0.1

EOF
declare -a passin=() passout=()
if [ "${PASSPHRASE:-}" ]; then
    passin=( '-passin' "$PASSPHRASE" )
    passout=( '-passout' "$PASSPHRASE" )
fi


gen_certs::title 'Create a Root CA Certificate and Key'
echo -e "${BLUE}Generate key file:${RESET} '$(basename $CA_ROOT_KEY)'"
#  - **Use strong encryption** (`aes256`) to protect the private key.
#  - Keep this key **secure**—compromising it weakens the CA.
"$OPENSSL" genrsa "$CIPHER" -out "$CA_ROOT_KEY" "${passout[@]}" "$KEYLENGTH"
gen_certs::displayPem "$CA_ROOT_KEY"
echo -e "${BLUE}Create Certificate '$(basename $CA_ROOT_CRT)' & sign with '$(basename $CA_ROOT_KEY)'${RESET}"
"$OPENSSL" req -x509 -new -noenc -key "$CA_ROOT_KEY" -section 'rootca' -out "$CA_ROOT_CRT" -config "$CONFIG_FILE" "${passin[@]}"
gen_certs::displayPem "$CA_ROOT_CRT"



gen_certs::title 'Issue a Certificate for a Server'
echo -e "${BLUE}Generate key file:${RESET} '$(basename $SERVER_KEY)'"
"$OPENSSL" genrsa -out "$SERVER_KEY" "$KEYLENGTH"
echo -e "${BLUE}Create Certificate Signing Request (CSR): ${RESET}'$(basename $SERVER_CSR)'"
"$OPENSSL" req -new -key "$SERVER_KEY" -section 'v3_req' -out "$SERVER_CSR" -config "$CONFIG_FILE"
gen_certs::displayPem "$SERVER_CSR"
echo -e "${BLUE}Using '$(basename $SERVER_CSR)' CSR, create certificate:${RESET} '$(basename $SERVER_CRT)'"
"$OPENSSL" ca -batch -notext -extensions 'server_exts' -out "$SERVER_CRT" -in "$SERVER_CSR" -config "$CONFIG_FILE" "${passin[@]}"
#   - The resulting "$SERVER_CRT" is now a valid CA-signed certificate.
gen_certs::displayPem "$SERVER_CRT"
echo "Verifying Certificate: '$(basename $SERVER_CRT)'"
"$OPENSSL" verify -verbose -CAfile "$CA_ROOT_CRT" -show_chain "$SERVER_CRT"



gen_certs::title 'Create Intermediate CA Certificate, CSR and Key'
echo -e "${BLUE}Generate key file:${RESET} '$(basename $INTERMEDIATE_CA_KEY)'"
#  - Since the intermediate CA handles most certificate signing, securing its key is crucial:
"$OPENSSL" genrsa "$CIPHER" -out "$INTERMEDIATE_CA_KEY" "${passout[@]}" "$KEYLENGTH"
gen_certs::displayPem "$INTERMEDIATE_CA_KEY"
echo -e "${BLUE}Create Certificate Signing Request (CSR):${RESET} '$(basename $INTERMEDIATE_CA_CSR)'"
"$OPENSSL" req -new -key "$INTERMEDIATE_CA_KEY" -section 'intermediate_ca' -out "$INTERMEDIATE_CA_CSR" -config "$CONFIG_FILE" "${passin[@]}"
gen_certs::displayPem "$INTERMEDIATE_CA_CSR"
echo -e "${BLUE}Using '$(basename $INTERMEDIATE_CA_CSR)' CSR, create Intermediate-CA certificate:${RESET} '$(basename $INTERMEDIATE_CA_CRT)'"
#   - The **root CA** signs the intermediate CSR, and issues an intermediate certificate:
"$OPENSSL" ca -batch -notext -extensions 'intermediate_exts' -out "$INTERMEDIATE_CA_CRT" -in "$INTERMEDIATE_CA_CSR" -config "$CONFIG_FILE" "${passin[@]}"
#   - The resulting "$INTERMEDIATE_CA_CRT" is now a valid CA-signed certificate.
gen_certs::displayPem "$INTERMEDIATE_CA_CRT"

echo -e "${BLUE}Establish the Certificate Chain:${RESET} '$INTERMEDIATE_CA_CHAIN'"
#  - To validate the chain of trust, combine the root and intermediate certificates:
[ "${SHOW_OPENSSL:-0}" -ne 0 ] && (echo -e "${GREY}cat '$INTERMEDIATE_CA_CRT' '$CA_ROOT_CRT' > '$INTERMEDIATE_CA_CHAIN'${RESET}" >&2)
cat "$INTERMEDIATE_CA_CRT" "$CA_ROOT_CRT" > "$INTERMEDIATE_CA_CHAIN"
echo "Verifying Certificate: '$(basename $INTERMEDIATE_CA_CRT)'"
"$OPENSSL" verify -verbose -CAfile "$CA_ROOT_CRT" -show_chain "$INTERMEDIATE_CA_CRT"



gen_certs::title 'Issue a Certificate for a Server based on intermediate CA #1'
echo -e "${BLUE}Generate key file:${RESET} '$(basename $INTERMEDIATE_CA_SERVER_KEY)'"
"$OPENSSL" genrsa -out "$INTERMEDIATE_CA_SERVER_KEY" "$KEYLENGTH"
echo -e "${BLUE}Create Certificate Signing Request (CSR): ${RESET}'$(basename $INTERMEDIATE_CA_SERVER_CSR)'"
"$OPENSSL" req -new -key "$INTERMEDIATE_CA_SERVER_KEY" -section 'v3_req2' -out "$INTERMEDIATE_CA_SERVER_CSR" -config "$CONFIG_FILE"
gen_certs::displayPem "$INTERMEDIATE_CA_SERVER_CSR"
echo -e "${BLUE}Using '$(basename $INTERMEDIATE_CA_SERVER_CSR)' CSR, create certificate:${RESET} '$(basename $INTERMEDIATE_CA_SERVER_CRT)'"
# Sign the CSR with the Intermediate CA:
"$OPENSSL" ca -batch -notext -extensions 'server_exts' -out "$INTERMEDIATE_CA_SERVER_CRT" -in "$INTERMEDIATE_CA_SERVER_CSR" -config "$CONFIG_FILE" "${passin[@]}"
#  - The resulting "$INTERMEDIATE_CA_SERVER_CRT" is now signed and trusted through the "$INTERMEDIATE_CA_CHAIN".
gen_certs::displayPem "$INTERMEDIATE_CA_SERVER_CRT"
echo "Verifying Certificate: '$(basename $INTERMEDIATE_CA_SERVER_CRT)'"
"$OPENSSL" verify -verbose -CAfile "$INTERMEDIATE_CA_CHAIN" -show_chain "$INTERMEDIATE_CA_SERVER_CRT"



gen_certs::title 'Create Intermediate CA_2 Certificate, CSR and Key'
echo -e "${BLUE}Generate key file:${RESET} '$(basename $INTERMEDIATE_CA_2_KEY)'"
#  - Since the intermediate CA_2 handles most certificate signing, securing its key is crucial:
"$OPENSSL" genrsa "$CIPHER" -out "$INTERMEDIATE_CA_2_KEY" "${passout[@]}" "$KEYLENGTH"
gen_certs::displayPem "$INTERMEDIATE_CA_2_KEY"
echo -e "${BLUE}Create Certificate Signing Request (CSR):${RESET} '$(basename $INTERMEDIATE_CA_2_CSR)'"
"$OPENSSL" req -new -key "$INTERMEDIATE_CA_2_KEY" -section 'intermediate_ca_2' -out "$INTERMEDIATE_CA_2_CSR" -config "$CONFIG_FILE" "${passin[@]}"
gen_certs::displayPem "$INTERMEDIATE_CA_2_CSR"
echo -e "${BLUE}Using '$(basename $INTERMEDIATE_CA_2_CSR)' CSR, create Intermediate-CA certificate:${RESET} '$(basename $INTERMEDIATE_CA_2_CRT)'"
#   - The **root CA_2** signs the intermediate CSR, and issues an intermediate certificate:
"$OPENSSL" ca -batch -notext -extensions 'intermediate_exts' -out "$INTERMEDIATE_CA_2_CRT" -in "$INTERMEDIATE_CA_2_CSR" -config "$CONFIG_FILE" "${passin[@]}"
#   - The resulting "$INTERMEDIATE_CA_2_CRT" is now a valid CA_2-signed certificate.
gen_certs::displayPem "$INTERMEDIATE_CA_2_CRT"


echo -e "${BLUE}Establish the Certificate Chain:${RESET} '$INTERMEDIATE_CA_2_CHAIN'"
#  - To validate the chain of trust, combine the root and intermediate certificates:
[ "${SHOW_OPENSSL:-0}" -ne 0 ] && (echo -e "${GREY}cat '$INTERMEDIATE_CA_2_CRT' '$CA_ROOT_CRT' > '$INTERMEDIATE_CA_2_CHAIN'${RESET}" >&2)
cat "$INTERMEDIATE_CA_2_CRT" "$CA_ROOT_CRT" > "$INTERMEDIATE_CA_2_CHAIN"
echo "Verifying Certificate: '$(basename $INTERMEDIATE_CA_2_CRT)'"
"$OPENSSL" verify -verbose -CAfile "$CA_ROOT_CRT" -show_chain "$INTERMEDIATE_CA_2_CRT"



gen_certs::title 'Issue a Certificate for a Server based on intermediate CA #2'
echo -e "${BLUE}Generate key file:${RESET} '$(basename $INTERMEDIATE_CA_2_SERVER_KEY)'"
"$OPENSSL" genrsa -out "$INTERMEDIATE_CA_2_SERVER_KEY" "$KEYLENGTH"
echo -e "${BLUE}Create Certificate Signing Request (CSR): ${RESET}'$(basename $INTERMEDIATE_CA_2_SERVER_CSR)'"
"$OPENSSL" req -new -key "$INTERMEDIATE_CA_2_SERVER_KEY" -section 'v3_req2_2' -out "$INTERMEDIATE_CA_2_SERVER_CSR" -config "$CONFIG_FILE"
gen_certs::displayPem "$INTERMEDIATE_CA_2_SERVER_CSR"
echo -e "${BLUE}Using '$(basename $INTERMEDIATE_CA_2_SERVER_CSR)' CSR, create certificate:${RESET} '$(basename $INTERMEDIATE_CA_2_SERVER_CRT)'"
# Sign the CSR with the Intermediate CA_2:
"$OPENSSL" ca -batch -notext -extensions 'server_exts' -out "$INTERMEDIATE_CA_2_SERVER_CRT" -in "$INTERMEDIATE_CA_2_SERVER_CSR" -config "$CONFIG_FILE" "${passin[@]}"
#  - The resulting "$INTERMEDIATE_CA_2_SERVER_CRT" is now signed and trusted through the "$INTERMEDIATE_CA_2_CHAIN".
gen_certs::displayPem "$INTERMEDIATE_CA_2_SERVER_CRT"
echo "Verifying Certificate: '$(basename $INTERMEDIATE_CA_2_SERVER_CRT)'"
"$OPENSSL" verify -verbose -CAfile "$INTERMEDIATE_CA_2_CHAIN" -show_chain "$INTERMEDIATE_CA_2_SERVER_CRT"



#echo -e "${BLUE}Generate DHPARAM file:${RESET} '$(basename $SERVER_DHPARAM)'"
#"$OPENSSL" dhparam -out "$SERVER_DHPARAM" "$KEYLENGTH"
#gen_certs::displayPem "$SERVER_DHPARAM"


#set +ve
# Distribute & Trust the CA Certificates:
#  - Deploy **`ca-chain.crt`** so clients trust certificates signed by the intermediate CA.
#  - Protect **`intermediate.key`** carefully; compromise could lead to unauthorized certificates.



echo 'Trust the Root CA once, and all your certs will be trusted.'

echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS ... DONE${RESET}\\n"

exit

##################################################################################################

# Provide guidance on fine-tuning certificate extensions for security (e.g., SAN, key usage)?

Fine-tuning certificate extensions enhances security and ensures certificates meet specific usage requirements. Here’s how to refine **Subject Alternative Name (SAN), Key Usage, and Extended Key Usage** effectively.

---

### **1. Subject Alternative Name (SAN)**
SAN defines multiple domain names/IPs that a certificate is valid for, preventing browser warnings.

#### **Example SAN Configuration**
Modify OpenSSL config file (`openssl.cnf`):
```ini
[ req ]
req_extensions = v3_req

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = example.com
DNS.2 = www.example.com
IP.1 = 192.168.1.10
```
Generate the certificate with:
```sh
openssl req -new -key server.key -out server.csr -config openssl.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -extensions v3_req -extfile openssl.cnf
```
This ensures the certificate works for both domain and IP-based access.

---

### **2. Key Usage**
Key Usage enforces **what operations the certificate key can perform** (e.g., signing, encryption).

#### **Common Key Usage Values**
```ini
keyUsage = digitalSignature, keyEncipherment, keyCertSign, cRLSign
```
- `digitalSignature` -> Needed for TLS authentication (server certificates).
- `keyEncipherment` -> Enables encryption of symmetric session keys.
- `keyCertSign, cRLSign` -> Used by CA certificates.

---

### **3. Extended Key Usage (EKU)**
EKU refines **the intended purpose** of a certificate.

#### **Common EKU Values**
```ini
extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection
```
- `serverAuth` -> Enables HTTPS connections.
- `clientAuth` -> Supports mutual TLS (MTLS).
- `codeSigning` -> Signs software binaries.
- `emailProtection` -> Secures email communication.

---

### **Best Practices**
 -  Always include `SAN` to prevent mismatches.
 -  Ensure **Key Usage restrictions** align with security needs (avoid over-permissive values).
 -  Use **EKU settings** to prevent misuse (e.g., a server cert shouldn’t sign code).
 -  Validate **certificate extensions before deployment** using:
```sh
openssl x509 -in server.crt -text -noout | grep -A 5 "X509v3"
```

Would you like help configuring an OpenSSL template to automate certificate issuance?

#!/bin/bash

#------------------------------------------------------------------------------
function ::files_to_publish() {

    mkdir -p "${MYCA_DIR}/nginx" ||:
    cp "${MYCA_DIR}/private"/* "${MYCA_DIR}/nginx/"
    cp "${MYCA_DIR}/certs"/* "${MYCA_DIR}/nginx/"
    pushd  "${MYCA_DIR}/nginx" &> /dev/null || exit
    [ -f 'dhparam.dh' ] && mv 'dhparam.dh' 'dhparam.pem'
    tar czf ../certs.tgz ./*
    popd &> /dev/null || exit
    rm -rf "${MYCA_DIR}/nginx"

    mkdir -p "${MYCA_DIR}/k8s" ||:
    cp "${MYCA_DIR}/private/SohoBall-K8sBackend_CA.key" "${MYCA_DIR}/k8s/ca.key"
    cp "${MYCA_DIR}/private/SohoBall-K8sFrontend_CA.key" "${MYCA_DIR}/k8s/front-proxy-ca.key"
    cp "${MYCA_DIR}/private/SohoBall_BE-server.key" "${MYCA_DIR}/k8s/server.key"
    cp "${MYCA_DIR}/certs/SohoBall-K8sBackend_CA.crt" "${MYCA_DIR}/k8s/ca.crt"
    cp "${MYCA_DIR}/certs/SohoBall-K8sFrontend_CA.crt" "${MYCA_DIR}/k8s/front-proxy-ca.crt"
    cp "${MYCA_DIR}/certs/SohoBall_BE-server.crt" "${MYCA_DIR}/k8s/server.crt"
    pushd  "${MYCA_DIR}/k8s" &> /dev/null || exit
    tar czf ../k8s.tgz ./*
    popd &> /dev/null || exit
    rm -rf "${MYCA_DIR}/k8s"
}
#------------------------------------------------------------------------------


# Use the Unofficial Bash Strict Mode
#shellcheck disable=SC2034
declare -ri SHOW_OPENSSL="${1:-0}"
#shellcheck disable=SC1091
source gen-certs.bashlib
trap gen_certs::onExit EXIT


echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS${RESET}"


#shellcheck disable=SC2034
declare -ri CLEAN_ALL=1
# if PASSPHRASE is empty, CIPHER must also be empty
declare -r CIPHER="${CIPHER:-}"
declare -r PASSPHRASE="${PASSPHRASE:-}"
#declare -r CIPHER="${CIPHER:-aes256}"
#declare -r PASSPHRASE="${PASSPHRASE:-pass:wxyz}"
declare -ri KEYLENGTH="${KEYLENGTH:-4096}"
declare -ri VALID_DAYS="${VALID_DAYS:-300065}"
declare -r MYCA_DIR="${MYCA_DIR:-./myCA}"
declare -r MYCA_INTERMITTENT_DIR="${MYCA_INTERMITTENT_DIR:-${MYCA_DIR}/intermediate}"
declare -r CONFIG_FILE="${CONFIG_FILE:-${MYCA_DIR}/config.cnf}"
declare -r CA_ROOT_CRT="${CA_ROOT_CRT:-${MYCA_DIR}/certs/SohoBall_CA.crt}"
declare -r CA_ROOT_KEY="${CA_ROOT_KEY:-${MYCA_DIR}/private/SohoBall_CA.key}"
declare -r CA_INTERMEDIATE_BE_CRT="${CA_INTERMEDIATE_BE_CRT:-${MYCA_DIR}/certs/SohoBall-K8sBackend_CA.crt}"
declare -r CA_INTERMEDIATE_BE_KEY="${CA_INTERMEDIATE_BE_KEY:-${MYCA_DIR}/private/SohoBall-K8sBackend_CA.key}"
declare -r CA_INTERMEDIATE_FE_CRT="${CA_INTERMEDIATE_FE_CRT:-${MYCA_DIR}/certs/SohoBall-K8sFrontend_CA.crt}"
declare -r CA_INTERMEDIATE_FE_KEY="${CA_INTERMEDIATE_FE_KEY:-${MYCA_DIR}/private/SohoBall-K8sFrontend_CA.key}"


declare CONFIG="
[ ca ]
default_ca = rootca

# ---------- parameters for ROOT CA ---------------
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
prompt              = no
policy              = policy_match  # or policy_anything / policy_loose
x509_extensions     = rootca_x509_extns
#distinguished_name = distinguished_name   # dynamically generated with unique 'commonName'

[ policy_match ]
countryName         = match
stateOrProvinceName = optional
organizationName    = match
commonName          = supplied

[ rootca_x509_extns ]  # x509_extensions
basicConstraints       = critical, CA:true
subjectKeyIdentifier   = hash
keyUsage               = critical, keyCertSign, cRLSign
authorityKeyIdentifier = keyid:always, issuer:always
crlDistributionPoints  = URI:http://example.home/crl.pem
1.3.6.1.5.5.7.1.9      = ASN1:NULL
certificatePolicies    = 2.5.29.32.0
authorityInfoAccess    = OCSP;URI:http://example.home/ocsp


# ---------- parameters for K8S Intermediate CA ---------------
[ ca_intermediate ]
dir                = $MYCA_INTERMITTENT_DIR
database           = \$dir/index.txt
serial             = \$dir/serial
new_certs_dir      = \$dir/newcerts
#certificate        = $CA_INTERMEDIATE_BE_CRT or $CA_INTERMEDIATE_FE_CRT
#private_key        = $CA_INTERMEDIATE_BE_KEY or $CA_INTERMEDIATE_FE_KEY
default_md         = sha256
policy              = policy_match  # or policy_anything / policy_loose
default_days       = $VALID_DAYS
default_bits       = $KEYLENGTH
prompt             = no
#distinguished_name = distinguished_name   # dynamically generated with unique 'commonName'
#x509_extensions    = ca_intermediate_x509_exts

[ ca_intermediate_x509_exts ]  # x509_extensions
basicConstraints       = critical, CA:true
subjectKeyIdentifier   = hash
keyUsage               = critical, keyCertSign, cRLSign
authorityKeyIdentifier = keyid:always, issuer:always
crlDistributionPoints  = URI:http://example.home/crl.pem
1.3.6.1.5.5.7.1.9      = ASN1:NULL
certificatePolicies    = 2.5.29.32.0
authorityInfoAccess    = OCSP;URI:http://example.home/ocsp
#extendedKeyUsage        = serverAuth
#keyUsage                = keyEncipherment, dataEncipherment, digitalSignature

# ---------- parameters for servers ---------------
[ server_section ]
default_days       = $VALID_DAYS
default_md         = sha256
default_bits       = $KEYLENGTH
prompt             = no
#distinguished_name = distinguished_name   # dynamically generated with unique 'commonName'
#x509_extensions    = server_x509_exts

[ server_x509_exts ]  #x509_extensions for all servers
basicConstraints        = critical, CA:false
subjectKeyIdentifier    = hash
#extendedKeyUsage       = serverAuth, clientAuth
extendedKeyUsage        = serverAuth
keyUsage                = keyEncipherment, dataEncipherment, digitalSignature
subjectAltName          = @alt_names

# ---------- parameters for subject/issuer ---------------
[ distinguished_name ]
countryName             = US
stateOrProvinceName     = Massachusetts
localityName            = Mansfield
organizationName        = soho_ball
organizationalUnitName  = home
#commonName              = TBD      # passed to dynamic '-subj' function
emailAddress            = ballantyne.robert@gmail.com

[ alt_names ]
DNS.1 = *.home
DNS.2 = *.ubuntu.home
DNS.3 = *.k8s.home
DNS.4 = *.prod.k8s.home
DNS.5 = *.dev.k8s.home
IP.1  = 127.0.0.1

"

#=============================================================================
# === Step 1: Prepare Environment & Generate OpenSSL "$CFG_FILE" with SANs ===
#shellcheck disable=SC2034
declare -rA CFG_PARAMS=( ['cfg_file']="$CONFIG_FILE"
                         ['config']="$CONFIG" )
gen_certs::genConfig 'CFG_PARAMS'


# === Step 2: Create Root CA ===
gen_certs::title 'Create a Root CA Certificate and Key'
#shellcheck disable=SC2034
declare -rA CA_ROOT=( ['key_file']="$CA_ROOT_KEY"
                      ['crt_file']="$CA_ROOT_CRT"
                      ['cipher']="$CIPHER"
                      ['section']='rootca'
                      ['keylength']="$KEYLENGTH"
                      ['passphrase']="$PASSPHRASE"
                      ['subject']="${CN_ROOT:-Ballantyne home-network CA}"
                      ['cfg_file']="$CONFIG_FILE" )
gen_certs::genRootCertificate 'CA_ROOT'


#=============================================================================
# === Step 3: Generate Server key and certificate then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for a Server'
#shellcheck disable=SC2034
declare -rA SERVER=( ['signing_key']="$CA_ROOT_CRT"
                     ['key_file']="${SERVER_KEY:-${MYCA_DIR}/private/SohoBall-Server.key}"
                     ['crt_file']="${SERVER_CRT:-${MYCA_DIR}/certs/SohoBall-Server.crt}"
                     ['csr_file']="${SERVER_CSR:-${MYCA_DIR}/csr/SohoBall-Server.csr}"
#                     ['dh_file']="${SERVER_DHPARAM:-${MYCA_DIR}/certs/dhparam.dh}"
                     ['csr_extns']='root_server_section'
                     ['crt_extns']='server_x509_exts'
                     ['keylength']="$KEYLENGTH"
                     ['passphrase']="$PASSPHRASE"
                     ['subject']="${CN_SERVER:-Ballantyne home}"
                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'SERVER'
[ -f 'Soho-Ball_CA/certs/dhparam.dh' ] && cp 'Soho-Ball_CA/certs/dhparam.dh' "${MYCA_DIR}/certs/dhparam.dh"


#=============================================================================
# === Step 4: Generate Intermediate BE key and Intermediate BE certificate then sign cert with Root CA & verify ===
gen_certs::title 'Create BE Intermediate CA Certificate, CSR and Key'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_BE_CA=( ['signing_key']="$CA_ROOT_CRT"
                                 ['key_file']="$CA_INTERMEDIATE_BE_KEY"
                                 ['crt_file']="$CA_INTERMEDIATE_BE_CRT"
                                 ['csr_file']="${INTERMEDIATE_BE_CA_CSR:-${MYCA_DIR}/csr/SohoBall-K8sBackend_CA.csr}"
                                 ['chain']="${INTERMEDIATE_BE_CA_CHAIN:-${MYCA_DIR}/certs/SohoBall-K8sBackend_CA-Chain.crt}"
#                                 ['pks']="${INTERMEDIATE_BE_CA_PKS:-${MYCA_DIR}/certs/SohoBall-K8sBackend_CA.pks}")
                                 ['cipher']="$CIPHER"
                                 ['csr_extns']='ca_intermediate'
                                 ['crt_extns']='ca_intermediate_x509_exts'
                                 ['keylength']="$KEYLENGTH"
                                 ['passphrase']="$PASSPHRASE"
                                 ['subject']="${CN_INTERMEDIATE_BE:-Ballantyne k8s-backend Intermediate CA}"
                                 ['cfg_file']="$CONFIG_FILE" )
gen_certs::genIntermediateCertificate 'INTERMEDIATE_BE_CA'


# === Step 5: Generate Server key and Intermediate certificate then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for a Server based on BE intermediate CA'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_BE_SERVER=( ['signing_key']="${INTERMEDIATE_BE_CA['chain']}"
                                     ['key_file']="${INTERMEDIATE_BE_SERVER_KEY:-${MYCA_DIR}/private/SohoBall_BE-server.key}"
				     ['crt_file']="${INTERMEDIATE_BE_SERVER_CRT:-${MYCA_DIR}/certs/SohoBall_BE-server.crt}"
                                     ['csr_file']="${INTERMEDIATE_BE_SERVER_CSR:-${MYCA_DIR}/csr/SohoBall_BE-server.csr}"
#                                     ['dh_file']="${INTERMEDIATE_BE_SERVER_DHPARAM:-${MYCA_DIR}/certs/SohoBall_BE-server.dhparam.dh}"
                                     ['csr_extns']='server_section'
                                     ['crt_extns']='server_x509_exts'
                                     ['keylength']="$KEYLENGTH"
                                     ['passphrase']="$PASSPHRASE"
                                     ['subject']="${CN_BE_SERVER:-Ballantyne k8s-backend}"
                                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'INTERMEDIATE_BE_SERVER'




#=============================================================================
# === Step 6: Generate FE Intermediate key and FE Intermediate certificate then sign cert with Root CA & verify ===
gen_certs::title 'Create FE Intermediate Certificate, CSR and Key'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_FE_CA=( ['signing_key']="$CA_ROOT_CRT"
                                 ['key_file']="$CA_INTERMEDIATE_FE_KEY"
                                 ['crt_file']="$CA_INTERMEDIATE_FE_CRT"
                                 ['csr_file']="${INTERMEDIATE_FE_CA_CSR:-${MYCA_DIR}/csr/SohoBall-K8sFrontend_CA.csr}"
                                 ['chain']="${INTERMEDIATE_FE_CA_CHAIN:-${MYCA_DIR}/certs/SohoBall-K8sFrontend_CA-Chain.crt}"
#                                 ['pks']="${INTERMEDIATE_FE_CA_PKS:-${MYCA_DIR}/certs/SohoBall-K8sFrontend_CA.pks}")
                                 ['cipher']="$CIPHER"
                                 ['csr_extns']='ca_intermediate'
                                 ['crt_extns']='ca_intermediate_x509_exts'
                                 ['keylength']="$KEYLENGTH"
                                 ['passphrase']="$PASSPHRASE"
                                 ['subject']="${CN_INTERMEDIATE_FE:-Ballantyne k8s-frontend Intermediate CA}"
                                 ['cfg_file']="$CONFIG_FILE" )
gen_certs::genIntermediateCertificate 'INTERMEDIATE_FE_CA'


# === Step 7: Generate Server key and Intermediate certificate #2 then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for a Server based on intermediate FE CA'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_FE_SERVER=( ['signing_key']="${INTERMEDIATE_FE_CA['chain']}"
                                     ['key_file']="${INTERMEDIATE_FE_SERVER_KEY:-${MYCA_DIR}/private/SohoBall_FE-server.key}"
				     ['crt_file']="${INTERMEDIATE_FE_SERVER_CRT:-${MYCA_DIR}/certs/SohoBall_FE-server.crt}"
                                     ['csr_file']="${INTERMEDIATE_FE_SERVER_CSR:-${MYCA_DIR}/csr/SohoBall_FE-server.csr}"
#                                     ['dh_file']="${INTERMEDIATE_FE_SERVER_DHPARAM:-${MYCA_DIR}/certs/SohoBall_FE-server.dhparam.dh}"
                                     ['csr_extns']='server_section'
                                     ['crt_extns']='server_x509_exts'
                                     ['keylength']="$KEYLENGTH"
                                     ['passphrase']="$PASSPHRASE"
                                     ['subject']="${CN_FE_SERVER:-Ballantyne k8s-frontend}"
                                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'INTERMEDIATE_FE_SERVER'


# === Step 8: pull out files for nginx & k8s and crreate zips ===
gen_certs::title 'Pull out files for nginx & k8s and crreate zips'
::files_to_publish

echo 'Trust the Root CA once, and all your certs will be trusted.'

echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS ... DONE${RESET}\\n"


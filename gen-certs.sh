#!/bin/bash

#------------------------------------------------------------------------------
function ::files_to_publish() {

    mkdir -p "${MYCA_DIR}/nginx" ||:
    cp "${MYCA_DIR}/private"/* "${MYCA_DIR}/nginx/"
    cp "${MYCA_DIR}/certs"/* "${MYCA_DIR}/nginx/"
    pushd  "${MYCA_DIR}/nginx" &> /dev/null || exit
    [ -f 'dhparam.dh' ] && mv 'dhparam.dh' 'dhparam.pem'
    : > certs.inf
    while read -r file; do
        {
            [ -f "../crl/${file}.inf" ] || continue
#            printf '\n%s\n' "${file}"
            cat "../crl/${file}.inf"
        } >> certs.inf
    done < <(find . -name '*.crt' -or -name '*.key' -or -name '*.pem' | grep -v 'Chain' | cut -d '/' -f 2)
    tar czf ../certs.tgz ./*
    popd &> /dev/null || exit
    rm -rf "${MYCA_DIR}/nginx"

    pushd  "${MYCA_DIR}/K8S" &> /dev/null || exit
    tar czf ../K8S.tgz ./*
    popd &> /dev/null || exit
}
#------------------------------------------------------------------------------
function ::__init() {
    mkdir -p "${MYCA_DIR}/K8S" ||:
}
#------------------------------------------------------------------------------

# Use the Unofficial Bash Strict Mode
#shellcheck disable=SC2034
declare -ri SHOW_OPENSSL="${1:-0}"
#shellcheck disable=SC1090
source "$(dirname "$0")/gen-certs.bashlib"
trap gen_certs::onExit EXIT


{
echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS${RESET}"


#shellcheck disable=SC2034
declare -ri CLEAN_ALL=1
#shellcheck disable=SC2034
declare -ri FAST_DHPARAMS=1
# if PASSPHRASE is empty, CIPHER must also be empty
declare -r CIPHER="${CIPHER:-}"
declare -r PASSPHRASE="${PASSPHRASE:-}"
declare -ri KEYLENGTH="${KEYLENGTH:-4096}"
declare -ri VALID_DAYS="${VALID_DAYS:-3653}"
declare -r MYCA_DIR="${MYCA_DIR:-./myCA}"
declare -r MYCA_INTERMITTENT_DIR="${MYCA_INTERMITTENT_DIR:-${MYCA_DIR}/intermediate}"
declare -r CONFIG_FILE="${CONFIG_FILE:-${MYCA_DIR}/config.cnf}"
declare -r CA_ROOT_CRT="${CA_ROOT_CRT:-${MYCA_DIR}/certs/SohoBall_CA.crt}"
declare -r CA_ROOT_KEY="${CA_ROOT_KEY:-${MYCA_DIR}/private/SohoBall_CA.key}"


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
policy              = policy_match
x509_extensions     = rootca_x509_extns

[ policy_match ]
countryName         = optional
stateOrProvinceName = optional
organizationName    = optional
commonName          = supplied

[ policy_loose ]
countryName         = optional
stateOrProvinceName = optional
organizationName    = optional
commonName          = optional

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
default_md         = sha256
policy              = policy_match  # or policy_anything / policy_loose
default_days       = $VALID_DAYS
default_bits       = $KEYLENGTH
prompt             = no

[ ca_intermediate_x509_exts ]  # x509_extensions
basicConstraints       = critical, CA:true
subjectKeyIdentifier   = hash
keyUsage               = critical, keyCertSign, cRLSign
authorityKeyIdentifier = keyid:always, issuer:always
crlDistributionPoints  = URI:http://example.home/crl.pem
1.3.6.1.5.5.7.1.9      = ASN1:NULL
certificatePolicies    = 2.5.29.32.0
authorityInfoAccess    = OCSP;URI:http://example.home/ocsp

# ---------- parameters for servers ---------------
[ server_section ]
default_days       = $VALID_DAYS
default_md         = sha256
default_bits       = $KEYLENGTH
prompt             = no

[ server_x509_exts ]  #x509_extensions for all servers
basicConstraints        = critical, CA:false
subjectKeyIdentifier    = hash
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
emailAddress            = ballantyne.robert@gmail.com

[ alt_names ]
DNS.1 = *.home
DNS.2 = *.ubuntu.home
DNS.3 = *.K8S.home
DNS.4 = *.prod.K8S.home
DNS.5 = *.dev.K8S.home
IP.1  = 127.0.0.1

# ---------- parameters for K8S ---------------
[ K8S_intermediate_ca ]
dir                = $MYCA_INTERMITTENT_DIR
database           = \$dir/index.txt
serial             = \$dir/serial
new_certs_dir      = \$dir/newcerts
default_bits        = 2048
default_days        = $VALID_DAYS
default_md          = sha256
policy              = policy_match
prompt              = no

[ K8S_intermediate_ca_x509_exts ]  # x509_extensions
basicConstraints       = critical, CA:true
subjectKeyIdentifier   = hash
#authorityKeyIdentifier = keyid:always, issuer:always

[ K8S_req ]
default_bits        = 2048
prompt              = no
default_md          = sha256
default_days        = 3000

[ K8S_req_v3_ext ]
#authorityKeyIdentifier = keyid,issuer:always
basicConstraints       = CA:FALSE
keyUsage               = keyEncipherment,dataEncipherment,digitalSignature
extendedKeyUsage       = serverAuth,clientAuth
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
                      ['common_name']="${CN_ROOT:-Ballantyne home-network CA}"
                      ['cfg_file']="$CONFIG_FILE" )
gen_certs::genRootCertificate 'CA_ROOT'


#=============================================================================
# === Step 3: Generate Server key and certificate then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for network server'
#shellcheck disable=SC2034
declare -rA SERVER=( ['section']='rootca'
                     ['signing_key']="$CA_ROOT_KEY"
                     ['signing_crt']="$CA_ROOT_CRT"
                     ['key_file']="${SERVER_KEY:-${MYCA_DIR}/private/SohoBall-Server.key}"
                     ['crt_file']="${SERVER_CRT:-${MYCA_DIR}/certs/SohoBall-Server.crt}"
                     ['csr_file']="${SERVER_CSR:-${MYCA_DIR}/csr/SohoBall-Server.csr}"
                     ['dh_file']="${SERVER_DHPARAM:-${MYCA_DIR}/certs/dhparam.dh}"
                     ['csr_extns']='root_server_section'
                     ['crt_extns']='server_x509_exts'
                     ['keylength']="$KEYLENGTH"
                     ['passphrase']="$PASSPHRASE"
                     ['common_name']="${CN_SERVER:-Ballantyne home}"
                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'SERVER'



#=============================================================================
# === Step 4: Generate Intermediate key and certificate for (FE) K8S "front-proxy-ca" then sign cert with Root CA & verify ===
gen_certs::title 'Create Intermediate Certificate, CSR and Key for K8S "front-proxy-ca"'
#shellcheck disable=SC2034
declare -rA K8S_FRONT_PROXY_CA=( ['section']='rootca'
                                 ['signing_key']="$CA_ROOT_KEY"
                                 ['signing_crt']="$CA_ROOT_CRT"
                                 ['key_file']="${K8S_FRONT_PROXY_CA_KEY:-${MYCA_DIR}/K8S/front-proxy-ca.key}"
                                 ['crt_file']="${K8S_FRONT_PROXY_CA_CRT:-${MYCA_DIR}/K8S/front-proxy-ca.crt}"
                                 ['csr_file']="${K8S_FRONT_PROXY_CA_CSR:-${MYCA_DIR}/K8S/front-proxy-ca.csr}"
                                 ['chain']="${K8S_FRONT_PROXY_CA_CHAIN:-${MYCA_DIR}/certs/front-proxy-ca-Chain.crt}"
#                                 ['pks']="${K8S_FRONT_PROXY_CA_PKS:-${MYCA_DIR}/K8S/front-proxy-ca.pks}"
                                 ['cipher']="$CIPHER"
                                 ['csr_extns']='K8S_intermediate_ca'
                                 ['crt_extns']='K8S_intermediate_ca_x509_exts'
                                 ['keylength']=2048
                                 ['passphrase']="$PASSPHRASE"
                                 ['subject']="${DN_K8S_FRONT_PROXY_CA:-/CN=front-proxy-ca}"
                                 ['cfg_file']="$CONFIG_FILE" )
gen_certs::genIntermediateCertificate 'K8S_FRONT_PROXY_CA'


# === Step 5: Generate K8S 'front-proxy-client' key and certificate then sign with Intermediate K8S 'front-proxy-ca' & verify ===
gen_certs::title 'Issue K8S "front-proxy-client" Certificate for a K8S based on intermediate K8S_FRONT_PROXY_CA'
#shellcheck disable=SC2034
declare -rA K8S_FRONT_PROXY_CLIENT=( ['section']="${K8S_FRONT_PROXY_CA['csr_extns']}"
                                     ['signing_key']="${K8S_FRONT_PROXY_CA['key_file']}"
                                     ['signing_crt']="${K8S_FRONT_PROXY_CA['crt_file']}"
                                     ['key_file']="${K8S_FRONT_PROXY_CLIENT_KEY:-${MYCA_DIR}/K8S/front-proxy-client.key}"
				     ['crt_file']="${K8S_FRONT_PROXY_CLIENT_CRT:-${MYCA_DIR}/K8S/front-proxy-client.crt}"
                                     ['csr_file']="${K8S_FRONT_PROXY_CLIENT_CSR:-${MYCA_DIR}/csr/front-proxy-client.csr}"
#                                     ['dh_file']="${K8S_FRONT_PROXY_CLIENT_DHPARAM:-${MYCA_DIR}/K8S/front-proxy-client.dhparam.dh}"
                                     ['csr_extns']='K8S_req'
                                     ['crt_extns']='K8S_req_v3_ext'
                                     ['keylength']=2048
                                     ['passphrase']="$PASSPHRASE"
                                     ['subject']="${DN_K8S_FRONT_PROXY_CLIENT:-/CN=front-proxy-client}"
                                     ['verify_crt']="${K8S_FRONT_PROXY_CA['chain']}"
                                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_FRONT_PROXY_CLIENT'



#=============================================================================
# === Step 6: Generate Intermediate key and certificate for (BE) K8S CA then sign cert with Root CA & verify ===
gen_certs::title 'Create Intermediate Certificate, CSR and Key for K8S CA'
#shellcheck disable=SC2034
declare -rA K8S_CA=( ['section']='rootca'
                     ['signing_key']="$CA_ROOT_KEY"
                     ['signing_crt']="$CA_ROOT_CRT"
                     ['key_file']="${K8S_CA_KEY:-${MYCA_DIR}/K8S/ca.key}"
                     ['crt_file']="${K8S_CA_CRT:-${MYCA_DIR}/K8S/ca.crt}"
                     ['csr_file']="${K8S_CA_CSR:-${MYCA_DIR}/csr/ca.csr}"
                     ['chain']="${K8S_CA_CHAIN:-${MYCA_DIR}/certs/ca-Chain.crt}"
#                     ['pks']="${K8S_CA_PKS:-${MYCA_DIR}/certs/ca.pks}"
                     ['cipher']="$CIPHER"
                     ['csr_extns']='K8S_intermediate_ca'
                     ['crt_extns']='K8S_intermediate_ca_x509_exts'
                     ['keylength']=2048
                     ['passphrase']="$PASSPHRASE"
                     ['subject']="${DN_K8S_CA:-/CN=10.152.183.1}"
                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genIntermediateCertificate 'K8S_CA'


# === Step 7: Generate K8S 'client' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "client" Certificate for a K8S based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_CLIENT=( ['section']="${K8S_CA['csr_extns']}"
                         ['signing_key']="${K8S_CA['key_file']}"
                         ['signing_crt']="${K8S_CA['crt_file']}"
                         ['key_file']="${K8S_CLIENT_KEY:-${MYCA_DIR}/K8S/client.key}"
			 ['crt_file']="${K8S_CLIENT_CRT:-${MYCA_DIR}/K8S/client.crt}"
                         ['csr_file']="${K8S_CLIENT_CSR:-${MYCA_DIR}/csr/client.csr}"
#                         ['dh_file']="${K8S_CLIENT_DHPARAM:-${MYCA_DIR}/K8S/client.dhparam.dh}"
                         ['csr_extns']='K8S_req'
#                         ['crt_extns']='K8S_req_v3_ext'
                         ['keylength']=2048
                         ['passphrase']="$PASSPHRASE"
                         ['subject']="${DN_K8S_CLIENT:-/CN=admin/O=system:masters}"
                         ['verify_crt']="${K8S_CA['chain']}"
                         ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_CLIENT'


# === Step 8: Generate K8S 'controller' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "controller" Certificate based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_CONTROLLER=( ['section']="${K8S_CA['csr_extns']}"
                             ['signing_key']="${K8S_CA['key_file']}"
                             ['signing_crt']="${K8S_CA['crt_file']}"
                             ['key_file']="${K8S_CONTROLLER_KEY:-${MYCA_DIR}/K8S/controller.key}"
			     ['crt_file']="${K8S_CONTROLLER_CRT:-${MYCA_DIR}/K8S/controller.crt}"
                             ['csr_file']="${K8S_CONTROLLER_CSR:-${MYCA_DIR}/csr/controller.csr}"
#                             ['dh_file']="${K8S_CONTROLLER_DHPARAM:-${MYCA_DIR}/K8S/controller.dhparam.dh}"
                             ['csr_extns']='K8S_req'
#                             ['crt_extns']='K8S_req_v3_ext'
                             ['keylength']=2048
                             ['passphrase']="$PASSPHRASE"
                             ['subject']="${DN_K8S_CONTROLLER:-/CN=system:kube-controller-manager}"
                             ['verify_crt']="${K8S_CA['chain']}"
                             ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_CONTROLLER'


# === Step 9: Generate K8S 'scheduler' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "scheduler" Certificate based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_SCHEDULER=( ['section']="${K8S_CA['csr_extns']}"
                            ['signing_key']="${K8S_CA['key_file']}"
                            ['signing_crt']="${K8S_CA['crt_file']}"
                            ['key_file']="${K8S_SCHEDULER_KEY:-${MYCA_DIR}/K8S/scheduler.key}"
			    ['crt_file']="${K8S_SCHEDULER_CRT:-${MYCA_DIR}/K8S/scheduler.crt}"
                            ['csr_file']="${K8S_SCHEDULER_CSR:-${MYCA_DIR}/csr/scheduler.csr}"
#                            ['dh_file']="${K8S_SCHEDULER_DHPARAM:-${MYCA_DIR}/K8S/scheduler.dhparam.dh}"
                            ['csr_extns']='K8S_req'
#                            ['crt_extns']='K8S_req_v3_ext'
                            ['keylength']=2048
                            ['passphrase']="$PASSPHRASE"
                            ['subject']="${DN_K8S_SCHEDULER:-/CN=system:kube-scheduler}"
                            ['verify_crt']="${K8S_CA['chain']}"
                            ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_SCHEDULER'


# === Step 10: Generate K8S 'proxy' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "proxy" Certificate based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_PROXY=( ['section']="${K8S_CA['csr_extns']}"
                        ['signing_key']="${K8S_CA['key_file']}"
                        ['signing_crt']="${K8S_CA['crt_file']}"
                        ['key_file']="${K8S_PROXY_KEY:-${MYCA_DIR}/K8S/proxy.key}"
			['crt_file']="${K8S_PROXY_CRT:-${MYCA_DIR}/K8S/proxy.crt}"
                        ['csr_file']="${K8S_PROXY_CSR:-${MYCA_DIR}/csr/proxy.csr}"
#                        ['dh_file']="${K8S_PROXY_DHPARAM:-${MYCA_DIR}/K8S/proxy.dhparam.dh}"
                        ['csr_extns']='K8S_req'
#                        ['crt_extns']='K8S_req_v3_ext'
                        ['keylength']=2048
                        ['passphrase']="$PASSPHRASE"
                        ['subject']="${DN_K8S_PROXY:-/CN=system:kube-proxy}"
                        ['verify_crt']="${K8S_CA['chain']}"
                        ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_PROXY'


# === Step 11: Generate K8S 'apiserver-kubelet-client' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "apiserver-kubelet-client" Certificate based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_APISERVER_KUBLET_CLIENT=( ['section']="${K8S_CA['csr_extns']}"
                                          ['signing_key']="${K8S_CA['key_file']}"
                                          ['signing_crt']="${K8S_CA['crt_file']}"
                                          ['key_file']="${K8S_APISERVER_KUBLET_CLIENT_KEY:-${MYCA_DIR}/K8S/apiserver-kubelet-client.key}"
			                  ['crt_file']="${K8S_APISERVER_KUBLET_CLIENT_CRT:-${MYCA_DIR}/K8S/apiserver-kubelet-client.crt}"
                                          ['csr_file']="${K8S_APISERVER_KUBLET_CLIENT_CSR:-${MYCA_DIR}/csr/apiserver-kubelet-client.csr}"
#                                          ['dh_file']="${K8S_APISERVER_KUBLET_CLIENT_DHPARAM:-${MYCA_DIR}/K8S/apiserver-kubelet-client.dhparam.dh}"
                                          ['csr_extns']='K8S_req'
#                                          ['crt_extns']='K8S_req_v3_ext'
                                          ['keylength']=2048
                                          ['passphrase']="$PASSPHRASE"
                                          ['subject']="${DN_K8S_APISERVER_KUBLET_CLIENT:-/CN=kube-apiserver-kubelet-client/O=system:masters}"
                                          ['verify_crt']="${K8S_CA['chain']}"
                                          ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_APISERVER_KUBLET_CLIENT'


# === Step 12: Generate K8S 'server' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "server" Certificate based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_SERVER=( ['section']="${K8S_CA['csr_extns']}"
                         ['signing_key']="${K8S_CA['key_file']}"
                         ['signing_crt']="${K8S_CA['crt_file']}"
                         ['key_file']="${K8S_SERVER_KEY:-${MYCA_DIR}/K8S/server.key}"
			 ['crt_file']="${K8S_SERVER_CRT:-${MYCA_DIR}/K8S/server.crt}"
                         ['csr_file']="${K8S_SERVER_CSR:-${MYCA_DIR}/K8S/server.csr}"
#                         ['dh_file']="${K8S_SERVER_DHPARAM:-${MYCA_DIR}/K8S/server.dhparam.dh}"
                         ['csr_extns']='K8S_req'
                         ['crt_extns']='K8S_req_v3_ext'
                         ['keylength']=2048
                         ['passphrase']="$PASSPHRASE"
                         ['subject']="${DN_K8S_SERVER:-/C=GB/ST=Canonical/L=Canonical/O=Canonical/OU=Canonical/CN=127.0.0.1}"
                         ['verify_crt']="${K8S_CA['chain']}"
                         ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_SERVER'


# === Step 14: Generate K8S 'kubelet' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
gen_certs::title 'Issue K8S "kubelet" Certificate based on intermediate K8S_CA'
#shellcheck disable=SC2034
declare -rA K8S_KUBELET=( ['section']="${K8S_CA['csr_extns']}"
                          ['signing_key']="${K8S_CA['key_file']}"
                          ['signing_crt']="${K8S_CA['crt_file']}"
                          ['key_file']="${K8S_KUBELET_KEY:-${MYCA_DIR}/K8S/kubelet.key}"
			  ['crt_file']="${K8S_KUBELET_CRT:-${MYCA_DIR}/K8S/kubelet.crt}"
                          ['csr_file']="${K8S_KUBELET_CSR:-${MYCA_DIR}/csr/kubelet.csr}"
#                          ['dh_file']="${K8S_KUBELET_DHPARAM:-${MYCA_DIR}/K8S/kublet.dhparam.dh}"
                          ['csr_extns']='K8S_req'
#                          ['crt_extns']='K8S_req_v3_ext'
                          ['keylength']=2048
                          ['passphrase']="$PASSPHRASE"
                          ['subject']="${DN_KUBELET:-/CN=system:node:s5.ubuntu.home/O=system:nodes}"
                          ['verify_crt']="${K8S_CA['chain']}"
                          ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'K8S_KUBELET'


# === Step 15: pull out files for nginx & K8S and create zips ===
gen_certs::title 'Pull out files for nginx & K8S and create zips'
::files_to_publish

echo 'Trust the Root CA once, and all your certs will be trusted.'

echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS ... DONE${RESET}\\n"

} | tee "${0//.sh}.log"

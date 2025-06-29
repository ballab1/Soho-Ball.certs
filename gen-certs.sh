#!/bin/bash

#------------------------------------------------------------------------------
function ::__config() {
    echo "
[ ca ]
default_ca = rootca

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
DNS.3 = *.k8s.home
DNS.4 = *.prod.k8s.home
DNS.5 = *.dev.k8s.home
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
}
#------------------------------------------------------------------------------
function ::files_to_publish() {

    local -r certs_dir=""${MYCA_DIR}/nginx""
    mkdir -p "$certs_dir" ||:
    cp "${MYCA_DIR}/private"/* "${certs_dir}/"
    cp "${MYCA_DIR}/certs"/* "${certs_dir}/"
    pushd  "$certs_dir" &> /dev/null || return
    [ -f 'dhparam.dh' ] && mv 'dhparam.dh' 'dhparam.pem'
    : > certs.inf
    while read -r file; do
        {
            [ -f "../crl/${file}.inf" ] || continue
            cat "../crl/${file}.inf"
        } >> certs.inf
    done < <(find . -name '*.crt' -or -name '*.key' -or -name '*.pem' | grep -v 'Chain' | cut -d '/' -f 2)
    tar czf ../certs.tgz ./*
    popd &> /dev/null || return
    rm -rf "$certs_dir"

    if [ -d "$K8S_CERT_DIR" ]; then
        pushd  "$K8S_CERT_DIR" &> /dev/null || return
        tar czf "../$(basename "$K8S_CERT_DIR").tgz" ./*
        popd &> /dev/null || return
     fi
}

#------------------------------------------------------------------------------
function ::gen_basic() {
    # === Step 2: Create Root CA ===
    gen_certs::title 'Create a Root CA Certificate and Key'
    #shellcheck disable=SC2034
    local -rA CA_ROOT=( ['key_file']="$CA_ROOT_KEY"
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
    local -rA SERVER=( ['section']='rootca'
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

    # === Step 3 - 14: generate certs for microk8s ===
#    ::microk8s_certs

    # === Step 15: pull out files for nginx & K8S and create zips ===
    gen_certs::title 'Pull out files for nginx & K8S and create zips'
    ::files_to_publish
}

#------------------------------------------------------------------------------
function ::gen_k8s() {

    #=============================================================================
    # === Step 3: Generate Server key and certificate then sign cert with Root CA & verify ===
    gen_certs::title 'Issue a Certificate for network server'
    #shellcheck disable=SC2034
    local -rA K8S_DEV=( ['section']='rootca'
                        ['signing_key']="$CA_ROOT_KEY"
                        ['signing_crt']="$CA_ROOT_CRT"
                        ['key_file']="${K8S_DEV_KEY:-${MYCA_DIR}/private/SohoBall-k8s.key}"
                        ['crt_file']="${K8S_DEV_CRT:-${MYCA_DIR}/certs/SohoBall-k8s.crt}"
                        ['csr_file']="${K8S_DEV_CSR:-${MYCA_DIR}/csr/SohoBall-k8s.csr}"
#                        ['dh_file']="${K8S_DEV_DHPARAM:-${MYCA_DIR}/certs/dhparam.dh}"
                        ['csr_extns']='root_server_section'
                        ['crt_extns']='server_x509_exts'
                        ['keylength']="$KEYLENGTH"
                        ['passphrase']="$PASSPHRASE"
                        ['common_name']="${CN_K8S_DEV:-Ballantyne kubernetes}"
                        ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_DEV'

return

    #=============================================================================
    # === Step 3: Generate Server key and certificate then sign cert with Root CA & verify ===
    gen_certs::title 'Issue a Certificate for network server'
    #shellcheck disable=SC2034
    local -rA K8S_PROD=( ['section']='rootca'
                         ['signing_key']="$CA_ROOT_KEY"
                         ['signing_crt']="$CA_ROOT_CRT"
                         ['key_file']="${K8S_PROD_KEY:-${MYCA_DIR}/private/SohoBall-Server.key}"
                         ['crt_file']="${K8S_PROD_CRT:-${MYCA_DIR}/certs/SohoBall-Server.crt}"
                         ['csr_file']="${K8S_PROD_CSR:-${MYCA_DIR}/csr/SohoBall-Server.csr}"
#                         ['dh_file']="${K8S_PROD_DHPARAM:-${MYCA_DIR}/certs/dhparam.dh}"
                         ['csr_extns']='root_server_section'
                         ['crt_extns']='server_x509_exts'
                         ['keylength']="$KEYLENGTH"
                         ['passphrase']="$PASSPHRASE"
                         ['common_name']="${CN_K8S_PROD:-Ballantyne PROD kubernetes}"
                         ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_PROD'

}

#------------------------------------------------------------------------------
function ::main() {

    echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS${RESET}"

    # if PASSPHRASE is empty, CIPHER must also be empty
    local -r CIPHER="${CIPHER:-}"
    local -r PASSPHRASE="${PASSPHRASE:-}"
    local -ri KEYLENGTH="${KEYLENGTH:-4096}"
    local -ri VALID_DAYS="${VALID_DAYS:-3653}"
    local -r MYCA_INTERMITTENT_DIR="${MYCA_INTERMITTENT_DIR:-${MYCA_DIR}/intermediate}"
    local -r K8S_CERT_DIR="${MYCA_DIR}/k8s"
    local -r CONFIG_FILE="${CONFIG_FILE:-${MYCA_DIR}/config.cnf}"
    local -r CA_ROOT_CRT="${CA_ROOT_CRT:-${MYCA_DIR}/certs/SohoBall_CA.crt}"
    local -r CA_ROOT_KEY="${CA_ROOT_KEY:-${MYCA_DIR}/private/SohoBall_CA.key}"

    # prevent git-bash from changing CN vars
    export MSYS_NO_PATHCONV=1
    export MSYS2_ENV_CONV_EXCL='*'

    # prepare new environment
    gen_certs::prepareNewEnvironment


    #=============================================================================
    # === Step 1: Prepare Environment & Generate OpenSSL "$CFG_FILE" with SANs ===
    #shellcheck disable=SC2034
    local -rA CFG_PARAMS=( ['cfg_file']="$CONFIG_FILE"
                           ['config']="$( ::__config )" )
    gen_certs::genConfig 'CFG_PARAMS'

    ::gen_basic
#    ::gen_k8s
#    ::microk8s_certs

    echo 'Trust the Root CA once, and all your certs will be trusted.'

    echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS ... DONE${RESET}\\n"
}

#------------------------------------------------------------------------------
function ::microk8s_certs() {

    mkdir -p "$K8S_CERT_DIR" ||:

    #=============================================================================
    # === Step 4: Generate Intermediate key and certificate for (FE) K8S "front-proxy-ca" then sign cert with Root CA & verify ===
    gen_certs::title 'Create Intermediate Certificate, CSR and Key for K8S "front-proxy-ca"'
    #shellcheck disable=SC2034
    local -rA K8S_FRONT_PROXY_CA=( ['section']='rootca'
                                   ['signing_key']="$CA_ROOT_KEY"
                                   ['signing_crt']="$CA_ROOT_CRT"
                                   ['key_file']="${K8S_FRONT_PROXY_CA_KEY:-${K8S_CERT_DIR}/front-proxy-ca.key}"
                                   ['crt_file']="${K8S_FRONT_PROXY_CA_CRT:-${K8S_CERT_DIR}/front-proxy-ca.crt}"
                                   ['csr_file']="${K8S_FRONT_PROXY_CA_CSR:-${K8S_CERT_DIR}/front-proxy-ca.csr}"
                                   ['chain']="${K8S_FRONT_PROXY_CA_CHAIN:-${K8S_CERT_DIR}/front-proxy-ca-Chain.crt}"
#                                   ['pks']="${K8S_FRONT_PROXY_CA_PKS:-${K8S_CERT_DIR}/front-proxy-ca.pks}"
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
    local -rA K8S_FRONT_PROXY_CLIENT=( ['section']="${K8S_FRONT_PROXY_CA['csr_extns']}"
                                       ['signing_key']="${K8S_FRONT_PROXY_CA['key_file']}"
                                       ['signing_crt']="${K8S_FRONT_PROXY_CA['crt_file']}"
                                       ['key_file']="${K8S_FRONT_PROXY_CLIENT_KEY:-${K8S_CERT_DIR}/front-proxy-client.key}"
                                       ['crt_file']="${K8S_FRONT_PROXY_CLIENT_CRT:-${K8S_CERT_DIR}/front-proxy-client.crt}"
                                       ['csr_file']="${K8S_FRONT_PROXY_CLIENT_CSR:-${K8S_CERT_DIR}/front-proxy-client.csr}"
#                                       ['dh_file']="${K8S_FRONT_PROXY_CLIENT_DHPARAM:-${K8S_CERT_DIR}/front-proxy-client.dhparam.dh}"
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
    local -rA K8S_CA=( ['section']='rootca'
                       ['signing_key']="$CA_ROOT_KEY"
                       ['signing_crt']="$CA_ROOT_CRT"
                       ['key_file']="${K8S_CA_KEY:-${K8S_CERT_DIR}/ca.key}"
                       ['crt_file']="${K8S_CA_CRT:-${K8S_CERT_DIR}/ca.crt}"
                       ['csr_file']="${K8S_CA_CSR:-${K8S_CERT_DIR}/ca.csr}"
                       ['chain']="${K8S_CA_CHAIN:-${K8S_CERT_DIR}/ca-Chain.crt}"
#                       ['pks']="${K8S_CA_PKS:-${K8S_CERT_DIR}/ca.pks}"
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
    local -rA K8S_CLIENT=( ['section']="${K8S_CA['csr_extns']}"
                           ['signing_key']="${K8S_CA['key_file']}"
                           ['signing_crt']="${K8S_CA['crt_file']}"
                           ['key_file']="${K8S_CLIENT_KEY:-${K8S_CERT_DIR}/client.key}"
                           ['crt_file']="${K8S_CLIENT_CRT:-${K8S_CERT_DIR}/client.crt}"
                           ['csr_file']="${K8S_CLIENT_CSR:-${K8S_CERT_DIR}/client.csr}"
#                           ['dh_file']="${K8S_CLIENT_DHPARAM:-${K8S_CERT_DIR}/client.dhparam.dh}"
                           ['csr_extns']='K8S_req'
#                           ['crt_extns']='K8S_req_v3_ext'
                           ['keylength']=2048
                           ['passphrase']="$PASSPHRASE"
                           ['subject']="${DN_K8S_CLIENT:-/CN=admin/O=system:masters}"
                           ['verify_crt']="${K8S_CA['chain']}"
                           ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_CLIENT'


    # === Step 8: Generate K8S 'controller' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
    gen_certs::title 'Issue K8S "controller" Certificate based on intermediate K8S_CA'
    #shellcheck disable=SC2034
    local -rA K8S_CONTROLLER=( ['section']="${K8S_CA['csr_extns']}"
                               ['signing_key']="${K8S_CA['key_file']}"
                               ['signing_crt']="${K8S_CA['crt_file']}"
                               ['key_file']="${K8S_CONTROLLER_KEY:-${K8S_CERT_DIR}/controller.key}"
                               ['crt_file']="${K8S_CONTROLLER_CRT:-${K8S_CERT_DIR}/controller.crt}"
                               ['csr_file']="${K8S_CONTROLLER_CSR:-${K8S_CERT_DIR}/controller.csr}"
#                               ['dh_file']="${K8S_CONTROLLER_DHPARAM:-${K8S_CERT_DIR}/controller.dhparam.dh}"
                               ['csr_extns']='K8S_req'
#                               ['crt_extns']='K8S_req_v3_ext'
                               ['keylength']=2048
                               ['passphrase']="$PASSPHRASE"
                               ['subject']="${DN_K8S_CONTROLLER:-/CN=system:kube-controller-manager}"
                               ['verify_crt']="${K8S_CA['chain']}"
                               ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_CONTROLLER'


    # === Step 9: Generate K8S 'scheduler' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
    gen_certs::title 'Issue K8S "scheduler" Certificate based on intermediate K8S_CA'
    #shellcheck disable=SC2034
    local -rA K8S_SCHEDULER=( ['section']="${K8S_CA['csr_extns']}"
                              ['signing_key']="${K8S_CA['key_file']}"
                              ['signing_crt']="${K8S_CA['crt_file']}"
                              ['key_file']="${K8S_SCHEDULER_KEY:-${K8S_CERT_DIR}/scheduler.key}"
                              ['crt_file']="${K8S_SCHEDULER_CRT:-${K8S_CERT_DIR}/scheduler.crt}"
                              ['csr_file']="${K8S_SCHEDULER_CSR:-${K8S_CERT_DIR}/scheduler.csr}"
#                              ['dh_file']="${K8S_SCHEDULER_DHPARAM:-${K8S_CERT_DIR}/scheduler.dhparam.dh}"
                              ['csr_extns']='K8S_req'
#                              ['crt_extns']='K8S_req_v3_ext'
                              ['keylength']=2048
                              ['passphrase']="$PASSPHRASE"
                              ['subject']="${DN_K8S_SCHEDULER:-/CN=system:kube-scheduler}"
                              ['verify_crt']="${K8S_CA['chain']}"
                              ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_SCHEDULER'


    # === Step 10: Generate K8S 'proxy' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
    gen_certs::title 'Issue K8S "proxy" Certificate based on intermediate K8S_CA'
    #shellcheck disable=SC2034
    local -rA K8S_PROXY=( ['section']="${K8S_CA['csr_extns']}"
                          ['signing_key']="${K8S_CA['key_file']}"
                          ['signing_crt']="${K8S_CA['crt_file']}"
                          ['key_file']="${K8S_PROXY_KEY:-${K8S_CERT_DIR}/proxy.key}"
                          ['crt_file']="${K8S_PROXY_CRT:-${K8S_CERT_DIR}/proxy.crt}"
                          ['csr_file']="${K8S_PROXY_CSR:-${K8S_CERT_DIR}/proxy.csr}"
#                          ['dh_file']="${K8S_PROXY_DHPARAM:-${K8S_CERT_DIR}/proxy.dhparam.dh}"
                          ['csr_extns']='K8S_req'
#                          ['crt_extns']='K8S_req_v3_ext'
                          ['keylength']=2048
                          ['passphrase']="$PASSPHRASE"
                          ['subject']="${DN_K8S_PROXY:-/CN=system:kube-proxy}"
                          ['verify_crt']="${K8S_CA['chain']}"
                          ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_PROXY'


    # === Step 11: Generate K8S 'apiserver-kubelet-client' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
    gen_certs::title 'Issue K8S "apiserver-kubelet-client" Certificate based on intermediate K8S_CA'
    #shellcheck disable=SC2034
    local -rA K8S_APISERVER_KUBLET_CLIENT=( ['section']="${K8S_CA['csr_extns']}"
                                            ['signing_key']="${K8S_CA['key_file']}"
                                            ['signing_crt']="${K8S_CA['crt_file']}"
                                            ['key_file']="${K8S_APISERVER_KUBLET_CLIENT_KEY:-${K8S_CERT_DIR}/apiserver-kubelet-client.key}"
                                            ['crt_file']="${K8S_APISERVER_KUBLET_CLIENT_CRT:-${K8S_CERT_DIR}/apiserver-kubelet-client.crt}"
                                            ['csr_file']="${K8S_APISERVER_KUBLET_CLIENT_CSR:-${K8S_CERT_DIR}/apiserver-kubelet-client.csr}"
#                                            ['dh_file']="${K8S_APISERVER_KUBLET_CLIENT_DHPARAM:-${K8S_CERT_DIR}/apiserver-kubelet-client.dhparam.dh}"
                                            ['csr_extns']='K8S_req'
#                                            ['crt_extns']='K8S_req_v3_ext'
                                            ['keylength']=2048
                                            ['passphrase']="$PASSPHRASE"
                                            ['subject']="${DN_K8S_APISERVER_KUBLET_CLIENT:-/CN=kube-apiserver-kubelet-client/O=system:masters}"
                                            ['verify_crt']="${K8S_CA['chain']}"
                                            ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_APISERVER_KUBLET_CLIENT'


    # === Step 12: Generate K8S 'server' key and certificate then sign with Intermediate certificate Root CA 'ca.key' & verify ===
    gen_certs::title 'Issue K8S "server" Certificate based on intermediate K8S_CA'
    #shellcheck disable=SC2034
    local -rA K8S_SERVER=( ['section']="${K8S_CA['csr_extns']}"
                           ['signing_key']="${K8S_CA['key_file']}"
                           ['signing_crt']="${K8S_CA['crt_file']}"
                           ['key_file']="${K8S_SERVER_KEY:-${K8S_CERT_DIR}/server.key}"
                           ['crt_file']="${K8S_SERVER_CRT:-${K8S_CERT_DIR}/server.crt}"
                           ['csr_file']="${K8S_SERVER_CSR:-${K8S_CERT_DIR}/server.csr}"
#                           ['dh_file']="${K8S_SERVER_DHPARAM:-${K8S_CERT_DIR}/server.dhparam.dh}"
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
    local -rA K8S_KUBELET=( ['section']="${K8S_CA['csr_extns']}"
                            ['signing_key']="${K8S_CA['key_file']}"
                            ['signing_crt']="${K8S_CA['crt_file']}"
                            ['key_file']="${K8S_KUBELET_KEY:-${K8S_CERT_DIR}/kubelet.key}"
                            ['crt_file']="${K8S_KUBELET_CRT:-${K8S_CERT_DIR}/kubelet.crt}"
                            ['csr_file']="${K8S_KUBELET_CSR:-${K8S_CERT_DIR}/kubelet.csr}"
#                            ['dh_file']="${K8S_KUBELET_DHPARAM:-${K8S_CERT_DIR}/kublet.dhparam.dh}"
                            ['csr_extns']='K8S_req'
#                            ['crt_extns']='K8S_req_v3_ext'
                            ['keylength']=2048
                            ['passphrase']="$PASSPHRASE"
                            ['subject']="${DN_KUBELET:-/CN=system:node:s5.ubuntu.home/O=system:nodes}"
                            ['verify_crt']="${K8S_CA['chain']}"
                            ['cfg_file']="$CONFIG_FILE" )
    gen_certs::genCertificate 'K8S_KUBELET'
}
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# Use the Unofficial Bash Strict Mode
#shellcheck disable=SC2034
declare -ri SHOW_OPENSSL="${1:-0}"
#shellcheck disable=SC1090
source "$(dirname "$0")/gen-certs.bashlib"
trap gen_certs::onExit EXIT

#shellcheck disable=SC2034
declare -ri CLEAN_ALL=1
#shellcheck disable=SC2034
declare -ri FAST_DHPARAMS=1
declare -r MYCA_DIR="${MYCA_DIR:-./myCA}"

::main 2>&1 | tee "${0//.sh}.log"

#!/bin/bash

#------------------------------------------------------------------------------
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
#shellcheck disable=SC2034
declare -r CONFIG_FILE="${CONFIG_FILE:-${MYCA_DIR}/config.cnf}"
#shellcheck disable=SC2034
declare -r ca_root_crt="${CA_ROOT_CRT:-${MYCA_DIR}/certs/SohoBall_CA.crt}"
#shellcheck disable=SC2034
declare -r ca_root_key="${CA_ROOT_KEY:-${MYCA_DIR}/private/SohoBall_CA.key}"
#shellcheck disable=SC2034
declare -r intermediate_ca_1_crt="${INTERMEDIATE_CA_1_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sBackend_CA.crt}"
#shellcheck disable=SC2034
declare -r intermediate_ca_1_key="${INTERMEDIATE_CA_1_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall-K8sBackend_CA.key}"
#shellcheck disable=SC2034
declare -r intermediate_ca_2_crt="${INTERMEDIATE_CA_1_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sFrontend_CA.crt}"
#shellcheck disable=SC2034
declare -r intermediate_ca_2_key="${INTERMEDIATE_CA_1_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall-K8sFrontend_CA.key}"


#shellcheck disable=SC2034
declare -r CERT_SUBJECT_ROOT="${CERT_SUBJECT_ROOT:-/C=US/ST=Massachusetts/L=Mansfield/O=soho_ball/OU=home/CN=Ballantyne home root certificate/emailAddress=bob.ballantyne@gmail.com}"
#shellcheck disable=SC2034
declare -r CERT_SUBJECT_INTERMEDIATE="${CERT_SUBJECT_INTERMEDIATE:-/C=US/ST=Massachusetts/L=Mansfield/O=soho_ball/OU=home/CN=Ballantyne home intermediate certificate/emailAddress=bob.ballantyne@gmail.com}"
#shellcheck disable=SC2034
declare -r CERT_SUBJECT_SERVER="${CERT_SUBJECT_SERVER:-/C=US/ST=Massachusetts/L=Mansfield/O=soho_ball/OU=home/CN=Ballantyne home server certificate/emailAddress=bob.ballantyne@gmail.com}"


# === Step 1: Prepare Environment & Generate OpenSSL "$CFG_FILE" with SANs ===
#shellcheck disable=SC2034
declare -rA CFG_PARAMS=( ['cfg_file']="$CONFIG_FILE"
                         ['ca_root_crt']="$ca_root_crt"
                         ['ca_root_key']="$ca_root_key"
                         ['intermediate_ca_1_crt']="$intermediate_ca_1_crt"
                         ['intermediate_ca_1_key']="$intermediate_ca_1_key"
                         ['intermediate_ca_2_crt']="$intermediate_ca_2_crt"
                         ['intermediate_ca_2_key']="$intermediate_ca_2_key" )
gen_certs::genConfig 'CFG_PARAMS'


# === Step 2: Create Root CA ===
gen_certs::title 'Create a Root CA Certificate and Key'
#shellcheck disable=SC2034
declare -rA CA_ROOT=( ['key_file']="$ca_root_key"
                      ['crt_file']="$ca_root_crt"
                      ['cipher']="$CIPHER"
                      ['section']='rootca'
                      ['keylength']="$KEYLENGTH"
                      ['passphrase']="$PASSPHRASE"
                      ['cfg_file']="$CONFIG_FILE" )
gen_certs::genRootCertificate 'CA_ROOT'


# === Step 3: Generate Server key and certificate then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for a Server'
#shellcheck disable=SC2034
declare -rA SERVER=( ['signing_key']="${CA_ROOT['crt_file']}"
                     ['key_file']="${SERVER_KEY:-${MYCA_DIR}/private/SohoBall-Server.key}"
                     ['crt_file']="${SERVER_CRT:-${MYCA_DIR}/certs/SohoBall-Server.crt}"
                     ['csr_file']="${SERVER_CSR:-${MYCA_DIR}/csr/SohoBall-Server.csr}"
#                     ['dh_file']="${SERVER_DHPARAM:-${MYCA_DIR}/dhparam.dh}"
                     ['csr_extns']='v3_req'
                     ['crt_extns']='server_exts'
                     ['keylength']="$KEYLENGTH"
                     ['passphrase']="$PASSPHRASE"
                     ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'SERVER'


# === Step 4: Generate Intermediate key and Intermediate certificate then sign cert with Root CA & verify ===
gen_certs::title 'Create Intermediate CA Certificate, CSR and Key'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_CA_1=( ['signing_key']="${CA_ROOT['crt_file']}"
                                ['key_file']="$intermediate_ca_1_key"
                                ['crt_file']="$intermediate_ca_1_crt"
                                ['csr_file']="${INTERMEDIATE_CA_1_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall-K8sBackend_CA.csr}"
                                ['chain']="${INTERMEDIATE_CA_1_CHAIN:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sBackend_CA-Chain.crt}"
#                                ['pks']="${INTERMEDIATE_CA_2_PKS:-${MYCA_INTERMITTENT_DIR}/SohoBall-K8sBackend_CA.pks}")
                                ['cipher']="$CIPHER"
                                ['csr_extns']='intermediate_ca'
                                ['crt_extns']='intermediate_exts'
                                ['keylength']="$KEYLENGTH"
                                ['passphrase']="$PASSPHRASE"
                                ['cfg_file']="$CONFIG_FILE" )
gen_certs::genIntermediateCertificate 'INTERMEDIATE_CA_1'


# === Step 5: Generate Server key and Intermediate certificate then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for a Server based on intermediate CA #1'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_CA_1_SERVER=( ['signing_key']="${INTERMEDIATE_CA_1['chain']}"
                                       ['key_file']="${INTERMEDIATE_CA_1_SERVER_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall_BE-server.key}"
				       ['crt_file']="${INTERMEDIATE_CA_1_SERVER_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall_BE-server.crt}"
                                       ['csr_file']="${INTERMEDIATE_CA_1_SERVER_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall_BE-server.csr}"
#                                       ['dh_file']="${INTERMEDIATE_CA_1_SERVER_DHPARAM:-${MYCA_DIR}/SohoBall_BE-server.dhparam.dh}"
                                       ['csr_extns']='v3_req2'
                                       ['crt_extns']='server_exts'
                                       ['keylength']="$KEYLENGTH"
                                       ['passphrase']="$PASSPHRASE"
                                       ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'INTERMEDIATE_CA_1_SERVER'


# === Step 6: Generate Intermediate key #2 and Intermediate certificate #2 then sign cert with Root CA & verify ===
gen_certs::title 'Create Intermediate CA_2 Certificate, CSR and Key'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_CA_2=( ['signing_key']="${CA_ROOT['crt_file']}"
                                ['key_file']="$intermediate_ca_2_key"
                                ['crt_file']="$intermediate_ca_2_crt"
                                ['csr_file']="${INTERMEDIATE_CA_2_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall-K8sFrontend_CA.csr}"
                                ['chain']="${INTERMEDIATE_CA_2_CHAIN:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall-K8sFrontend_CA-Chain.crt}"
#                                ['pks']="${INTERMEDIATE_CA_2_PKS:-${MYCA_INTERMITTENT_DIR}/SohoBall-K8sFrontend_CA.pks}")
                                ['cipher']="$CIPHER"
                                ['csr_extns']='intermediate_ca_2'
                                ['crt_extns']='intermediate_exts'
                                ['keylength']="$KEYLENGTH"
                                ['passphrase']="$PASSPHRASE"
                                ['cfg_file']="$CONFIG_FILE" )
gen_certs::genIntermediateCertificate 'INTERMEDIATE_CA_2'


# === Step 7: Generate Server key and Intermediate certificate #2 then sign cert with Root CA & verify ===
gen_certs::title 'Issue a Certificate for a Server based on intermediate CA #2'
#shellcheck disable=SC2034
declare -rA INTERMEDIATE_CA_2_SERVER=( ['signing_key']="${INTERMEDIATE_CA_2['chain']}"
                                       ['key_file']="${INTERMEDIATE_CA_2_SERVER_KEY:-${MYCA_INTERMITTENT_DIR}/private/SohoBall_FE-server.key}"
				       ['crt_file']="${INTERMEDIATE_CA_2_SERVER_CRT:-${MYCA_INTERMITTENT_DIR}/certs/SohoBall_FE-server.crt}"
                                       ['csr_file']="${INTERMEDIATE_CA_2_SERVER_CSR:-${MYCA_INTERMITTENT_DIR}/csr/SohoBall_FE-server.csr}"
#                                       ['dh_file']="${INTERMEDIATE_CA_2_SERVER_DHPARAM:-${MYCA_DIR}/SohoBall_FE-server.dhparam.dh}"
                                       ['csr_extns']='v3_req2_2'
                                       ['crt_extns']='server_exts'
                                       ['keylength']="$KEYLENGTH"
                                       ['passphrase']="$PASSPHRASE"
                                       ['cfg_file']="$CONFIG_FILE" )
gen_certs::genCertificate 'INTERMEDIATE_CA_2_SERVER'


echo 'Trust the Root CA once, and all your certs will be trusted.'

echo -e "\\n${MAGENTA}>> GENERATING SSL CERTS ... DONE${RESET}\\n"


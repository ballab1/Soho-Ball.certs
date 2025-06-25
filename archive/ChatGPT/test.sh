#!/usr/bin/bash

function RUN() {
    local file="${1:?}"

    echo "./${file}.sh 2 &> ${file}.log"
    [ -e "${file}.log" ] && rm "${file}.log"
    "./${file}.sh" 2 &> "${file}.log"
    while [ ! -s "${file}.log" ]; do sleep 2; done

    echo "sed -E -i -e 's|\x1b\[[0-9;]*m?||g' ${file}.log"
    sed -E -i -e 's|\x1b\[[0-9;]*m?||g' "${file}.log"
    while [ "$(\grep -Pc '\x1b\[' "${file}.log")" -gt 0 ]; do sleep 2; done

    echo "grep -E '(openssl|cat) ' ${file}.log &> ${file}.openssl.log"
    [ -e "${file}.openssl.log" ] && rm "${file}.openssl.log"
    grep -E '(openssl|cat) ' "${file}.log" &> "${file}.openssl.log"
    while [ ! -s "${file}.openssl.log" ]; do sleep 2; done

    echo
}

function test() {

    local -r mode="${1:?}"

    find ./myCA -type f -not -name '*.cnf' -delete
    chmod 700 ./myCA/private
    chmod 700 ./myCA/intermediate/private
    touch ./myCA/index.txt
    touch ./myCA/intermediate/index.txt
    echo 1000 > ./myCA/serial
    echo 1000 > ./myCA/intermediate/serial
    echo 1000 > ./myCA/intermediate/crlnumber

    echo "testing ${mode} openssl"
set -ve
    source "${mode}.openssl.log" > "${mode}.openssl-2.log"
set +ve
}


RUN 'genCA'
RUN 'gen-certs'
echo "debugBashScript ./gen-certs.sh 1"
debugBashScript ./gen-certs.sh
test genCA
test gen-certs
exit

powershell.exe -Command "Remove-Item -Path Cert:\CurrentUser\Root\Ballantyne home-network CA"
powershell.exe -Command "Import-Certificate -FilePath 'C:/path/to/your/certificate.cer' -CertStoreLocation Cert:\CurrentUser\Root"
powershell.exe -Command "Get-ChildItem Cert:\CurrentUser\Root | Format-List Subject, 'Ballantyne home-network CA'"

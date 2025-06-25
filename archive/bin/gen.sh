#!/bin/bash
source ~/.bin/trap.bashlib

set -ev

days=100

openssl genrsa -out dummy-root.key 2048
openssl req -x509 -key dummy-root.key -days $days \
        -config gen.host.cfg -extensions root_exts \
        -subj '/C=US/ST=TX/O=foo/OU=bar/CN=dummy-root.com' \
        -out dummy-root.crt

openssl genrsa -out dummy-class2.key 2048
openssl req -new -key dummy-class2.key \
        -subj '/C=US/ST=TX/O=foo/OU=bar/CN=dummy-class2.com' \
        -out dummy-class2.csr
openssl x509 -req -in dummy-class2.csr -out dummy-class2.crt -days $days \
        -CAkey dummy-root.key -CA dummy-root.crt -CAcreateserial \
        -extfile gen.host.cfg -extensions intermediate_exts

openssl genrsa -out dummy-host.key 2048
openssl req -new -key dummy-host.key \
        -subj '/C=US/ST=TX/O=foo/OU=bar/CN=dummy-host.com' \
        -out dummy-host.csr
openssl x509 -req -in dummy-host.csr -days $days \
        -CAkey dummy-class2.key -CA dummy-class2.crt -CAcreateserial \
        -extfile gen.host.cfg -extensions server_exts \
         -out dummy-host.crt

rm *.csr
cat dummy-{host,class2,root}.crt > dummy-chain.crt

openssl verify -CAfile dummy-root.crt -untrusted dummy-class2.crt dummy-host.crt
openssl x509 -noout -ext extendedKeyUsage -in dummy-host.crt


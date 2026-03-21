#!/bin/bash

# ensure this script is run as root
if [[ $EUID != 0 ]]; then
   sudo --preserve-env "$0" "$@"
   exit
fi

declare file
while read -r file;do
    rm "/etc/ssl/certs/$file"
done < <(ls -l /etc/ssl/certs/ | grep -i 'ball'  | awk '{print substr($0,44)}' | cut -d ' ' -f 1)

rm /usr/local/share/ca-certificates/*
cd /etc/ssl/certs
update-ca-certificates

cp /mnt/GIT/Soho-Ball.certs/Soho-Ball_CA/certs/SohoBall_CA.crt /usr/local/share/ca-certificates/
update-ca-certificates


#!/usr/bin/bash

set -ve
rm -rf .git
git init
git crypt init
git remote add origin https://github.com/ballab1/Soho-Ball.certs.git
rm ~/src/keys/Soho-Ball.certs.key
git crypt export-key ~/src/keys/Soho-Ball.certs.key

MYCA_DIR=Soho-Ball_CA ./gen-certs.sh &> /dev/null
git add -A
git commit -m 'initial commit'
cat Soho-Ball_CA/index.txt

git crypt unlock ~/src/keys/Soho-Ball.certs.key
git crypt lock
cat Soho-Ball_CA/index.txt

git crypt unlock ~/src/keys/Soho-Ball.certs.key
cat Soho-Ball_CA/index.txt


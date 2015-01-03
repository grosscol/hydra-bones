#!/bin/sh
apt-get update
apt-get install -y curl
alias curl-check="curl --write-out '%{http_code}\n' -s -o /dev/null"
echo "127.0.0.1\t$(hostname)" | tee --append /etc/hosts
echo "Welcome to the Back Host." | tee /home/admin/back.txt
echo "Hostname: $(hostname)" | tee --append /home/admin/back.txt

# Grab setup scripts for solr and fedora
wget https://s3.amazonaws.com/grosscol-hydra-scripts/setup-deb-fedora.sh -O /home/admin/fedora-setup.sh
wget https://s3.amazonaws.com/grosscol-hydra-scripts/setup-deb-solr.sh -O /home/admin/solr-setup.sh

#!/bin/sh
apt-get update
apt-get install -y curl
alias curl-check="curl --write-out '%{http_code}\n' -s -o /dev/null"
echo "127.0.0.1\t$HOSTNAME" | tee --append /etc/hosts
echo "Welcome to the Web Host." | tee /home/admin/web.txt
echo "Hostname: $HOSTNAME" | tee --append /home/admin/web.txt

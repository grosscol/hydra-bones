#!/bin/sh
apt-get update
apt-get install -y curl

cat <<EOF | tee --append /home/admin/.bashrc
alias curl-check="curl --write-out '%{http_code}\n' -s -o /dev/null"
EOF

echo "127.0.0.1\t$(hostname)" | tee --append /etc/hosts
echo "Welcome to the Web Host." | tee /home/admin/web.txt
echo "Hostname: $(hostname)" | tee --append /home/admin/web.txt

#!/bin/sh
# Log the output of this script
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update apt reposisotyr data.  Install curl and alias a useful curl shortcut.
apt-get update
apt-get install -y curl
cat <<EOF | tee --append /home/admin/.bashrc
alias curl-check="curl --write-out '%{http_code}\n' -s -o /dev/null"
EOF

# Fix hostname issue so sudo doesn't complain & write a back.txt file to admin home directory
echo "127.0.0.1\t$(hostname)" | tee --append /etc/hosts
echo "Welcome to the Back Host." | tee /home/admin/back.txt
echo "Hostname: $(hostname)" | tee --append /home/admin/back.txt

# Grab setup scripts for solr and fedora
wget https://s3.amazonaws.com/grosscol-hydra-scripts/setup-deb-fedora.sh -O /home/admin/fedora-setup.sh
wget https://s3.amazonaws.com/grosscol-hydra-scripts/setup-deb-solr.sh -O /home/admin/solr-setup.sh

# Force use of backports repo for tomcat8. 
apt-get -y -t wheezy-backports install tomcat8

# Run setp script for fedora
source /home/admin/fedora-setup.sh


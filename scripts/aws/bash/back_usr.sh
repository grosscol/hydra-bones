#!/bin/sh
# Log the output of this script

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
wget https://s3.amazonaws.com/grosscol.hydra-scripts.bash/setup-deb-fedora.sh -O /home/admin/fedora-setup.sh
wget https://s3.amazonaws.com/grosscol.hydra-scripts.bash/setup-deb-solr.sh -O /home/admin/solr-setup.sh

# Change permissions and ownership for scripts
chmod +x /home/admin/*.sh
chown -R admin:admin /home/admin/*.sh

# Run setup script for fedora
/home/admin/fedora-setup.sh

# Run setup script for solr
/home/admin/solr-setup.sh

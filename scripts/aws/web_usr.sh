#!/bin/sh
apt-get update
apt-get install -y curl unzip

cat <<EOF | tee --append /home/admin/.bashrc
alias curl-check="curl --write-out '%{http_code}\n' -s -o /dev/null"
EOF

echo "127.0.0.1\t$(hostname)" | tee --append /etc/hosts
echo "Welcome to the Web Host." | tee /home/admin/web.txt
echo "Hostname: $(hostname)" | tee --append /home/admin/web.txt

# Grab setup scripts for torquebox3
wget https://s3.amazonaws.com/grosscol-hydra-scripts/setup-deb-torque3.sh -O /home/admin/torque3-setup.sh

# Change permissions and ownership for scripts
chmod +x /home/admin/*.sh
chown -R admin:admin /home/admin/*.sh

# Install rbenv globally and related accoutrements
apt-get install -y --no-install-recommends curl openjdk-7-jdk git make gcc g++
git clone https://github.com/sstephenson/rbenv.git /usr/local/rbenv
git clone https://github.com/sstephenson/ruby-build.git /usr/local/rbenv/plugins/ruby-build

# Add rbenv/bin to $PATH
export RBENV_ROOT=/usr/local/rbenv
export PATH="$RBENV_ROOT/bin:$PATH"
export PATH=/usr/local/rbenv/shims:$PATH
eval "$(rbenv init -)"

# Install Jruby & set as global ruby version
rbenv install jruby-1.7.18
rbenv global jruby-1.7.18

# Append command to automatically load rbenv to admin's bashrc.
# Escape $ so that tee doesn't expand them when writing to file.
cat <<EOF | tee --append /home/admin/.bashrc
export RBENV_ROOT=/usr/local/rbenv
export PATH="\$RBENV_ROOT/bin:\$PATH"
export PATH="\$RBENV_ROOT/shims:\$PATH"
eval "\$(rbenv init -)"
# Allow local Gem management
#export GEM_HOME="\$HOME/.gem"
#export GEM_PATH="\$HOME/.gem"
#export PATH="\$HOME/.gem/bin:\$PATH"
EOF

# Append command to automatically load rbenv to root profile
cat <<EOF | tee --append /root/.bashrc
export RBENV_ROOT=/usr/local/rbenv
export PATH="\$RBENV_ROOT/bin:\$PATH"
export PATH="\$RBENV_ROOT/shims:\$PATH"
eval "\$(rbenv init -)"
EOF

# Run script for torquebox3 setup
/home/admin/torque3-setup.sh


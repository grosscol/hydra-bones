#!/bin/sh

TOR3_TAR_LOC='https://s3.amazonaws.com/cag-tb/torquebox-dist-3.1.1-bin.zip'

# Create dir to store torquebox binary
mkdir -p /usr/local/torquebox3

# Retrieve torquebox file from s3 storage and decompress
if [ -e /usr/local/torquebox3/torquebox3.tgz ]
then
  echo "torquebox3.tgz already present"
else
  wget $TOR3_TAR_LOC -O /usr/local/torquebox3/torquebox3.tgz
fi

if [ -e /usr/local/torquebox3/torquebox3.tgz ]
then
  # Unzip becase the tb3 guys are funny and it's actually a zip file.
  unzip -u /usr/local/torquebox3/torquebox3.tgz 
else
  echo "Unable to obtain torquebox3 from ${TOR3_TAR_LOC}"
  exit 1
fi

# Environment variables for TB3 for both root and admin
# TB3 wants to have it's own copy of jruby.  So about that... no.
tb3_profile_adds='
export TORQUEBOX_HOME=/usr/local/torquebox3/torquebox-3.1.1
export JBOSS_HOME=\${TORQUEBOX_HOME}/jboss
export JRUBY_HOME=/usr/local/rbenv/versions/jruby-1.7.18'

echo "$tb3_profile_adds" | tee --append /home/admin/.bashrc
echo "$tb3_profile_adds" | tee --append /root/.bashrc

# Install torquebox-server gem
gem install torquebox-server -v 3.1.1
gem install rails

# Create sample application to test if this worked.
EXAMPLE_DIR=/opt/tb_example/rails_example
mkdir -p ${EXAMPLE_DIR}
cd ${EXAMPLE_DIR}
rails new .

rails g scaffold post title body:text
rake db:migrate

torquebox deploy

# torquebox run


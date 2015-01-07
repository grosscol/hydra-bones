#!/bin/sh

TOR3_TAR_LOC='https://s3.amazonaws.com/cag-tb/torquebox-dist-3.1.1-bin.zip'

# Create dir to store torquebox binary
mkdir -p /usr/local/torquebox3

# Retrieve torquebox file from s3 storage and decompress
if [ -e /usr/local/torquebox3/torquebox3.tgz ]
then
  echo "torquebox3.tgz already present"
else
  wget $TOR3_TAR_LOC /usr/local/torquebox3/torquebox3.tgz
fi

if [ -e /usr/local/torquebox3/torquebox3.tgz ]
then
  tar -xzf /usr/local/torquebox3/torquebox3.tgz --keep-newer-files
else
  echo "Unable to obtain torquebox3 from ${TOR3_TAR_LOC}"
  exit 1
fi

# Install torquebox-server gem
#gem install torquebox-server -v 3.1.1
#gem install rails


#!/bin/sh

# Obtain required packages
sudo apt-get update
sudo apt-get install -y -R curl openjdk-7-jre openjdk-7-jdk tomcat8 tomcat8-admin git

# Configure environment variables, and append to bash.rc

[ -z "$CATALINA_HOME" ] && CATALINA_HOME="/usr/share/tomcat8"
if env | grep -q '^CATALINA_HOME=' > /dev/null
then
  # Var already exported
else
  export CATALINA_HOME
  echo "export CATALINA_HOME=/usr/share/tomcat8" >> ~/.bashrc
fi

[ -z "$JAVA_HOME" ] && JAVA_HOME="/usr/lib/jvm/java-7-openjdk-amd64"
if env | grep -q '^JAVA_HOME=' > /dev/null
then
  # Var already exported
else
  export JAVA_HOME
  echo "export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64" >> ~/.bashrc
fi

# just get the WAR files.
mkdir sudo /usr/local/fcrepo
cd /usr/local/fcrepo
wget http://repo1.maven.org/maven2/org/fcrepo/fcrepo-webapp/4.0.0-beta-04/fcrepo-webapp-4.0.0-beta-04-auth.war
wget http://repo1.maven.org/maven2/org/fcrepo/fcrepo-webapp/4.0.0-beta-04/fcrepo-webapp-4.0.0-beta-04.war

# Install/Update Fedora 4 Repository
# if [ -e /usr/local/fcrepo4/.git ]
# then
#   cd /usr/local/fcrepo4
#   sudo git pull
#   sudo mvn compile
# else
#   cd /usr/local
#   sudo git clone https://github.com/fcrepo4/fcrepo4.git
#   sudo mvn install
# fi

# Make directory for Fedora data on this instance
sudo mkdir -p /usr/local/fedora-data
sudo chown -R tomcat8:tomcat8 /usr/local/fedora-data

# Copy the fedora war file to the default CATALINA_BASE directory
sudo cp /usr/local/fcrepo/fcrepo-webapp-4.0.0-beta-04.war /var/lib/tomcat8/webapps/fcrepo

# Modify the /etc/default/tomcat8 file so that the fedora home directory is writable by tomcat8
# JAVA_OPTS="${JAVA_OPTS} -Dfcrepo.home=/usr/local/fedora-data" 
# TODO: YOU ARE HERE:  As soon as you figure this part out, the bash script to bring up a new debian box should be good to go


# Restart the tomcat service
# sudo service tomcat8 restart

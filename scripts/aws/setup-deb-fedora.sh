#!/bin/sh

# Obtain required packages
apt-get update
apt-get install -y --no-install-recommends curl less openjdk-7-jre tomcat8 tomcat8-admin git
# If you were going to build fedora4 also get the openjdk-jdk
# apt-get install -y --no-install-recommends openjdk-7-jdk 

# Configure environment variables, and append to bash.rc

[ -z "$CATALINA_HOME" ] && CATALINA_HOME="/usr/share/tomcat8"
if [ `env | grep -q '^CATALINA_HOME='` -gt 0 ]
then
  # Var already exported
  echo "CATLINA_HOME already exported: $CATALINA_HOME"
else
  export CATALINA_HOME
  echo "export CATALINA_HOME=/usr/share/tomcat8" >> ~/.bashrc
fi

[ -z "$JAVA_HOME" ] && JAVA_HOME="/usr/lib/jvm/java-7-openjdk-amd64"
if [ `env | grep -q '^JAVA_HOME='` -gt 0 ]
then
  # Var already exported
  echo "JAVA_HOME already exported: $JAVA_HOME"
else
  export JAVA_HOME
  echo "export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64" >> ~/.bashrc
fi

# Make directory to hold fcrepo wars
mkdir -p /usr/local/fcrepo

# Just get the WAR files.
#FCWARA_LOC=http://repo1.maven.org/maven2/org/fcrepo/fcrepo-webapp/4.0.0-beta-03/fcrepo-webapp-4.0.0-beta-03-auth.war
FCWARA_LOC=https://s3.amazonaws.com/cag-fed-deb/fcrepo-webapp-4.0.0-beta-03-auth.war
cd /usr/local/fcrepo
if [ -e /usr/local/fcrepo/fcrepo-webapp-4.0.0-beta-03-auth.war ]
then
  echo "fcrepo-webapp-4.0.0-beta-03-auth.war already present"
else
  wget ${FCWARA_LOC}
fi

# FCWAR_LOC=http://repo1.maven.org/maven2/org/fcrepo/fcrepo-webapp/4.0.0-beta-03/fcrepo-webapp-4.0.0-beta-03.war
FCWAR_LOC=https://s3.amazonaws.com/cag-fed-deb/fcrepo-webapp-4.0.0-beta-03.war
if [ -e /usr/local/fcrepo/fcrepo-webapp-4.0.0-beta-03.war ]
then
  echo "fcrepo-webapp-4.0.0-beta-03.war already present"
else
  wget ${FCWAR_LOC}
fi


# Install/Update Fedora 4 Repository
# if [ -e /usr/local/fcrepo4/.git ]
# then
#   cd /usr/local/fcrepo4
#   git pull
#   mvn compile
# else
#   cd /usr/local
#   git clone https://github.com/fcrepo4/fcrepo4.git
#   mvn install
# fi

# Make directory for Fedora data on this instance
mkdir -p /usr/local/fedora-data
chown -R tomcat8:tomcat8 /usr/local/fedora-data

# Copy the fedora war file to the default CATALINA_BASE directory
if [ -e /var/lib/tomcat8/webapps/fcrepo.war ]
then
  echo "fcrepo-webapp-4.0.0-beta-03.war already deployed to /var/lib/tomcat8/webapps/fcrepo.war"
else
  cp /usr/local/fcrepo/fcrepo-webapp-4.0.0-beta-03.war /var/lib/tomcat8/webapps/fcrepo.war
fi

# Modify permissions file so that the web app directory is writable by tomcat8
chown -R tomcat8:tomcat8 /var/lib/tomcat8/webapps/fcrepo
chmod -R 0774 /var/lib/tomcat8/webapps/fcrepo

# Modify the /etc/default/tomcat8 to have JAVA_OPTS include the fcrepo.home.
if [ `grep -c -e '-Dfcrepo.home' < /etc/default/tomcat8` -gt 0 ]
then
  echo "fcrepo.home option already appended to /etc/default/tomcat8"
else
  echo "\n# Add the fcrepo.home option.  Without this, fedora4 will not start." | tee --append /etc/default/tomcat8
  echo "JAVA_OPTS=\"\${JAVA_OPTS} -Dfcrepo.home=/usr/local/fedora-data\"" | tee --append /etc/default/tomcat8
fi

# Restart the tomcat service
service tomcat8 restart

# Check that fedora4 is up and running.
echo "Checking if fedora4 is up and running..."
resp=`curl --write-out '%{http_code}\n' -s -o /dev/null http://localhost:8080/fcrepo/rest`
if [ ${resp} -eq 200 ]
then
  echo "Response code: ${resp}. Fedora repo is up and running."
else
  echo "Response code: ${resp}."
fi

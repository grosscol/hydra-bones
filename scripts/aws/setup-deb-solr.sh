#!/bin/sh

SOLR_MIRROR="http://psg.mtu.edu/pub/apache/lucene/solr"
SOLR_VER="solr-4.10.2"
SOLR_TAR_LOC="https://s3.amazonaws.com/cag-fed-deb/${SOLR_VER}.tgz"
SOLR_HOME=/opt/solr/schemaless/solr
SOLR_DATA=/opt/solr/schemaless/data

# Obtain required packages
apt-get update
apt-get install -y --no-install-recommends
apt-get install -y --no-install-recommends curl less openjdk-7-jre tomcat8 tomcat8-admin git

# just get the WAR files.
mkdir -p /usr/local/solr
cd /usr/local/solr

# Get Solr from one of the mirrors.  This location will need to be updated with local copy of solr
if [ -e /usr/local/solr/${SOLR_VER}.tgz ]
then
  echo "${SOLR_VER}.tgz already present"
else
  wget $SOLR_TAR_LOC /usr/local/solr/${SOLR_VER}.tgz
fi
# Check that Solr was obtained from the location
if [ -e /usr/local/solr/${SOLR_VER}.tgz ]
then
  tar -xzf ${SOLR_VER}.tgz --keep-newer-files
else
  echo "Unable to obtain solr from $SOLR_TAR_LOC"
  exit 1
fi

# Copy the solr war file to the default CATALINA_BASE directory
if [ -e /var/lib/tomcat8/webapps/solr.war ]
then
  echo "solr.war already deployed to /var/lib/tomcat8/webapps/solr.war"
else
  cp /usr/local/solr/${SOLR_VER}/dist/${SOLR_VER}.war  /var/lib/tomcat8/webapps/solr.war
fi

# Modify the /etc/default/tomcat8 to have JAVA_OPTS include solr.solr.home.
if [ `grep -c -e '-Dsolr.solr.home' < /etc/default/tomcat8` -gt 0 ]
then
  echo "solr.solr.home option already appended to /etc/default/tomcat8"
else
  echo "\n# Add the solr.solr.home option.  Without this, Solr will not start." | tee --append /etc/default/tomcat8
  echo "JAVA_OPTS=\"\${JAVA_OPTS} -Dsolr.solr.home=${SOLR_HOME}\"" | tee --append /etc/default/tomcat8
fi

# Modify the /etc/default/tomcat8 to have JAVA_OPTS include solr.data.dir.
if [ `grep -c -e '-Dsolr.data.dir' < /etc/default/tomcat8` -gt 0 ]
then
  echo "solr.data.dir option already appended to /etc/default/tomcat8"
else
  echo "\n# Add the solr.data.dir option.  Without this, Solr will not start." | tee --append /etc/default/tomcat8
  echo "JAVA_OPTS=\"\${JAVA_OPTS} -Dsolr.data.dir=${SOLR_DATA}\"" | tee --append /etc/default/tomcat8
fi

# Create solr home and data location
mkdir -p ${SOLR_DATA}
chown -R tomcat8:tomcat8 ${SOLR_DATA}

# Copy schemaless files from solr package over to /opt/solr/schemaless
cp -r /usr/local/solr/${SOLR_VER}/example/example-schemaless/* /opt/solr/schemaless

# Change ownership of solr dir to tomcat8
chown -R tomcat8:tomcat8 ${SOLR_HOME}

# Copy required library jars to tomcat
cp /usr/local/solr/${SOLR_VER}/example/lib/ext/* /usr/share/tomcat8/lib

# Remove the log4j libraries, because they prevent Fedora4 from working.
rm /usr/share/tomcat8/lib/log4j*.jar
rm /usr/share/tomcat8/lib/slf4j-log4j*.jar

# Modify the solr.xml to default to port 8080
sed -i s/jetty.port:8983/appserver.port:8080/ ${SOLR_HOME}/solr.xml

# Restart the tomcat service
service tomcat8 restart

# Check if solr is running
echo "Checking if solr is up and running..."
resp=`curl --write-out '%{http_code}\n' -s -o /dev/null http://localhost:8080/solr/#`
if [ ${resp} -eq 200 ]
then
  echo "Response code: ${resp}. Solr is up and running."
else
  echo "Response code: ${resp}."
fi

#!/bin/sh

# Obtain required packages
sudo apt-get update
sudo apt-get install -y --no-install-recommends
sudo apt-get install -y --no-install-recommends curl less openjdk-7-jre tomcat8 tomcat8-admin git

# just get the WAR files.
sudo mkdir -p /usr/local/solr
cd /usr/local/solr

# Get Solr from one of the mirrors.  This location will need to be updated with local copy of solr
if [ -e /usr/local/solr/solr-4.10.1.tgz]
then
  echo "fsolr-4.10.1.tgz already present"
else
  sudo wget http://mirror.metrocast.net/apache/lucene/solr/4.10.1/solr-4.10.1.tgz
  sudo tar -xzf solr-4.10.1.tgz
fi

# Copy the fedora war file to the default CATALINA_BASE directory
if [ -e /var/lib/tomcat8/webapps/solr.war ]
then
  echo "fcrepo-webapp-4.0.0-beta-03.war already deployed to /var/lib/tomcat8/webapps/solr.war"
else
  sudo cp /usr/local/solr/solr-4.10.1/dist/solr-4.10.1.war  /var/lib/tomcat8/webapps/solr.war
fi

# Modify the /etc/default/tomcat8 to have JAVA_OPTS include the fcrepo.home.
if [ `grep -c -e '-Dsolr.solr.home' < /etc/default/tomcat8` -gt 0 ]
then
  echo "solr.solr.home option already appended to /etc/default/tomcat8"
else
  echo "\n# Add the solr.solr.home option.  Without this, Solr will not start." | sudo tee --append /etc/default/tomcat8
  echo "JAVA_OPTS=\"\${JAVA_OPTS} -Dsolr.solr.home=/usr/local/solr/solr-4.10.1\"" | sudo tee --append /etc/default/tomcat8
fi

# Restart the tomcat service
sudo service tomcat8 restart

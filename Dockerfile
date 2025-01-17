FROM ubuntu:jammy

LABEL Daniel Binggeli <db@xbe.ch>

# https://www.sql-ledger.com/cgi-bin/nav.pl?page=misc/faq.html&title=FAQ
## prepare host
# sudo apt-get remove docker docker-engine docker.io
# sudo apt-get update
# sudo apt-get install docker-ce

## build image
# docker build --no-cache --tag ghcr.io/kartalbas/sqlledger_docker:latest --build-arg DOCKER_TAG=latest --file D:\repos\github\sqlledger_docker\Dockerfile .

## login to ghcr.io
# docker login ghcr.io -u kartalbas@gmail.com -p xxxx

## upload image
# docker push ghcr.io/kartalbas/sqlledger_docker:latest

# docker run -p 80:80 --name sqlledger_docker -d ghcr.io/kartalbas/sqlledger_docker:latest
# docker run -p 80:80 --name sqlledger_docker -d -v /opt/postgresql/data:/var/lib/postgresql ghcr.io/kartalbas/sqlledger_docker:latest

# docker run --name sqlledger_docker -it ghcr.io/kartalbas/sqlledger_docker:latest /bin/bash

## get IP for url
# docker ps -q | xargs docker inspect | grep IPAddress | cut -d '"' -f 4

# http://localhost/ledger123/login.pl
# http://localhost/ledger123/admin.pl

ENV postgresversion 15
ENV locale de_CH
ENV postrespassword docker
ARG DEBIAN_FRONTEND=noninteractive

#Packages
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt-get update && apt-get -y upgrade
RUN apt-get -y install vim acpid apache2 openssl ssl-cert \
 libdbix-simple-perl libcgi-simple-perl \
 git postfix mailutils texlive nano libhtml-template-perl \
 libtext-markdown-perl libdbi-perl  libdbd-pg-perl libobject-signature-perl \
 make libtemplate-perl libnumber-format-perl \
 libuser-simple-perl lynx libcgi-formbuilder-perl \
 libmime-lite-perl libtext-markdown-perl libdate-calc-perl libtemplate-plugin-number-format-perl \
 libgd-gd2-perl libdatetime-perl libhtml-format-perl libmime-tools-perl apg libgd-dev build-essential \
 ssh acpid git-core gitweb postfix mailutils texlive \
 libarchive-zip-perl libclone-perl \
 libconfig-std-perl libdatetime-perl libdbd-pg-perl libdbi-perl \
 libemail-address-perl  libemail-mime-perl libfcgi-perl libjson-perl \
 liblist-moreutils-perl libnet-smtp-ssl-perl libnet-sslglue-perl \
 libparams-validate-perl libpdf-api2-perl librose-db-object-perl \
 librose-db-perl librose-object-perl libsort-naturally-perl libpq5 \
 libstring-shellquote-perl libtemplate-perl libtext-csv-xs-perl \
 libtext-iconv-perl liburi-perl libxml-writer-perl libyaml-perl \
 libfile-copy-recursive-perl git build-essential \
 libgd-gd2-perl libimage-info-perl sed supervisor libgd-dev build-essential sudo

# ADD language environment
RUN apt-get -y install language-pack-de-base texlive-lang-german

# ADD ledger
RUN git clone https://github.com/ledger123/ledger123.git /var/www/html/ledger123
RUN git clone https://github.com/ledger123/ledgercart.git  /var/www/html/ledger123/ledgercart

RUN mkdir /var/www/html/ledger123/spool

#Load default users
RUN cd /var/www/html/ledger123/users && wget http://www.sql-ledger-network.com/debian/demo_users.tar.gz --retr-symlinks=no && tar -xvf demo_users.tar.gz
#Load default Templates
RUN cd /var/www/html/ledger123/ && wget http://www.sql-ledger-network.com/debian/demo_templates.tar.gz --retr-symlinks=no && tar -xvf demo_templates.tar.gz

#Change permissions for webserver
RUN chown -hR www-data.www-data /var/www/html/ledger123/users /var/www/html/ledger123/templates /var/www/html/ledger123/css /var/www/html/ledger123/spool

ADD index.html /var/www/html/index.html

#Todo copy the conf to the repo
RUN cp /var/www/html/ledger123/ledgercart/config-default.pl /var/www/html/ledger123/ledgercart/config.pl

RUN echo "AddHandler cgi-script .pl" >> /etc/apache2/apache2.conf
RUN echo "Alias /ledger123/ /var/www/html/ledger123/" >> /etc/apache2/apache2.conf
RUN echo "<Directory /var/www/html/ledger123>" >> /etc/apache2/apache2.conf
RUN echo "Options ExecCGI Includes FollowSymlinks" >> /etc/apache2/apache2.conf
RUN echo "</Directory>" >> /etc/apache2/apache2.conf
RUN echo "<Directory /var/www/html/ledger123/users>" >> /etc/apache2/apache2.conf
RUN echo "Order Deny,Allow" >> /etc/apache2/apache2.conf
RUN echo "Deny from All" >> /etc/apache2/apache2.conf
RUN echo "</Directory>" >> /etc/apache2/apache2.conf

# ADD POSTGRES
# Add the PostgreSQL PGP key to verify their Debian packages.
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null

RUN sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
RUN wget --quiet -O - https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmor -o /etc/apt/trusted.gpg.d/pgadmin.gpg

# Install ``software-properties-common`` and PostgreSQL
RUN apt-get update && apt-get install -y software-properties-common postgresql-${postgresversion} postgresql-client-${postgresversion} postgresql-contrib-${postgresversion} pgadmin4-web
RUN cd ~/ && wget http://www.sql-ledger-network.com/debian/pg_hba.conf --retr-symlinks=no && cp pg_hba.conf /etc/postgresql/${postgresversion}/main/
RUN service postgresql restart

# Run the rest of the commands as the ``postgres`` user created by the ``postgres-${postgresversion}`` package when it was ``apt-get installed``
USER postgres

# Set the locale of the db cluster
RUN pg_dropcluster --stop ${postgresversion} main && pg_createcluster --locale ${locale}.UTF-8 --start ${postgresversion} main

# Create a PostgreSQL role named ``docker`` with ``docker`` as the password and
# then create a database `docker` owned by the ``docker`` role.
RUN /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD '${postrespassword}';" &&\
    psql --command "CREATE USER sqlledger WITH SUPERUSER PASSWORD '${postrespassword}';" &&\
     createdb -O docker docker &&\
     createdb -O sqlledger ledgercart &&\
    psql ledgercart < /var/www/html/ledger123/ledgercart/sql/ledgercart.sql &&\
    psql ledgercart < /var/www/html/ledger123/ledgercart/sql/schema.sql

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN sed -i -e"s/^#listen_addresses =.*$/listen_addresses = '*'/" /etc/postgresql/${postgresversion}/main/postgresql.conf
RUN echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/${postgresversion}/main/pg_hba.conf

RUN service postgresql restart

# Expose the PostgreSQL port
EXPOSE 5432

# ADD APACHE
# Run the rest of the commands as the ``root`` user
USER root

RUN mkdir -p /var/lock/apache2 /var/run/apache2 /var/run/sshd

# SET Servername to localhost
RUN echo "ServerName localhost" >> /etc/apache2/conf-available/servername.conf
RUN a2enconf servername

# Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

RUN chown -R www-data:www-data /var/www &&\
    chmod u+rwx,g+rx,o+rx /var/www &&\
    find /var/www -type d -exec chmod u+rwx,g+rx,o+rx {} + &&\
    find /var/www -type f -exec chmod u+rw,g+rw,o+r {} +

#Perl Modul im Apache laden
RUN a2enmod cgi.load  && a2ensite default-ssl  && service apache2 start && a2enmod ssl && service apache2 restart

EXPOSE 80

# Update the default apache site with the config we created.
ADD sql-ledger /etc/apache2/sites-available/sql-ledger
RUN cd /etc/apache2/sites-enabled/ && ln -s ../sites-available/sql-ledger 001-sql-ledger

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql", "/var/log/apache2"]

# Scripts
ADD supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf
ADD supervisord-apache2.sh /usr/local/bin/supervisord-apache2.sh
ADD supervisord-postgresql.conf /etc/supervisor/conf.d/supervisord-postgresql.conf
ADD supervisord-postgresql.sh /usr/local/bin/supervisord-postgresql.sh
ADD start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/*.sh

RUN sed -i "2 i\BEGIN {push @INC, \'.\';}" /var/www/html/ledger123/*.pl

# By default, simply start apache.
CMD ["/usr/local/bin/start.sh"]

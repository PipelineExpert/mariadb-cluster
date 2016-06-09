FROM debian:jessie

MAINTAINER "Stuart Zurcher" <https://github.com/stuartz-VernonCo>
# using combination of code from official maraidb docker-library


# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added

# install "pwgen" for randomizing passwords
# add repository pinning to make sure dependencies from this MariaDB repo are preferred over Debian dependencies
# libmariadbclient18 : Depends: libmysqlclient18 (= 5.5.42+maria-1~wheezy) but 5.5.43-0+deb7u1 is to be installed

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container

ENV MARIADB_MAJOR 10.1
ENV MARIADB_VERSION 10.1.12+maria-1~jessie
RUN groupadd -r mysql && useradd -r -g mysql mysql \
	&& apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 199369E5404BD5FC7D2FE43BCBCB082A1BB943DB \
	&& echo "deb http://ftp.osuosl.org/pub/mariadb/repo/$MARIADB_MAJOR/debian jessie main" > /etc/apt/sources.list.d/mariadb.list \
	&& { \
		echo 'Package: *'; \
		echo 'Pin: release o=MariaDB'; \
		echo 'Pin-Priority: 999'; \
	} > /etc/apt/preferences.d/mariadb \
	&&{ \
		echo mariadb-server-$MARIADB_MAJOR mysql-server/root_password password 'unused'; \
		echo mariadb-server-$MARIADB_MAJOR mysql-server/root_password_again password 'unused'; \
	} | debconf-set-selections \
	&& apt-get update && apt-get upgrade -y \
	&& apt-get install -y pwgen wget\
		mariadb-server=$MARIADB_VERSION \
		openssl nano netcat-traditional socat pv locate \
	&& wget https://repo.percona.com/apt/percona-release_0.1-3.jessie_all.deb \
	&& dpkg -i percona-release_0.1-3.jessie_all.deb \
	&& apt-get update \
	&& apt-get install -y percona-xtrabackup-24 \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql 
	
	#using volume  to local my.cnf now
	#&& sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
	#&& echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
	#&& mv /tmp/my.cnf /etc/mysql/my.cnf \
	#&& mkdir /var/lib/mysql 
	
COPY my_master.cnf /etc/mysql/my.cnf

COPY docker-entrypoint.sh /
# added chmod because of weird permission issue
RUN mkdir -p /docker-entrypoint-initdb.d && chmod 770 /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 3306 4444 4567 4567/udp 4568
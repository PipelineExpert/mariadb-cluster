#!/bin/bash
# a mix of the official docker-entrypoint.sh and that of
#    https://github.com/diegomarangoni/docker-mariadb-galera
# and https://github.com/severalnines/galera-docker-mariadb/blob/master/entrypoint.sh
# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	CMDARG="$@"
fi

[ -z "$TTL" ] && TTL=10


echo "wsrep_node_address: $node"
#set config in my.cnf
sed -i "s|wsrep_node_address.*|wsrep_node_address = $node|g" /etc/mysql/my.cnf

# Get config
DATADIR="$("mysqld" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
echo >&2 "Content of $DATADIR:"
ls -al $DATADIR

# initialize database if not previously innitialized.
if [ ! -s "$DATADIR/grastate.dat" ]; then

	# set buffer pool size to 80% of Available mem
	mem=$(printf %.0f $(cat /proc/meminfo |grep MemAvailable |awk "{print \$2*.8/1000}"))
	sed -i "s|innodb-buffer-pool-size.*|innodb-buffer-pool-size = ${mem}M|g" /etc/mysql/my.cnf

    if [ -z "$CLUSTER_NAME" ]; then
    	echo >&2 'Error:  You need to specify CLUSTER_NAME'
    	exit 1
    fi
    sed -i "s|wsrep_cluster_name.*|wsrep_cluster_name = $CLUSTER_NAME|g" /etc/mysql/my.cnf
    if [ -z "$node" ]; then
    	echo >&2 'Error:  You need to specify node'
    	exit 1
    fi
    echo "wsrep_node_address: $node"
    #set config in my.cnf
    sed -i "s|wsrep_node_address.*|wsrep_node_address = $node|g" /etc/mysql/my.cnf

	INITIALIZED=1
	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
                    echo >&2 'error: database is uninitialized and password option is not specified '
                    echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
                    exit 1
            fi
	mkdir -p "$DATADIR"
	chown -R mysql:mysql "$DATADIR"

	echo 'Running mysql_install_db'
	mysql_install_db --user=mysql --datadir="$DATADIR" --rpm
	echo 'Finished mysql_install_db'

	mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
	pid="$!"

	mysql=( mysql --protocol=socket -uroot )

	for i in {30..0}; do
		if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
			break
		fi
		echo 'MySQL init process in progress...'
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo >&2 'MySQL init process failed.'
		exit 1
	fi
    [ -z $XTRABACKUP_PASSWORD ] && XTRABACKUP_PASSWORD="$MYSQL_ROOT_PASSWORD"
    echo "xtrabackup | $XTRABACKUP_PASSWORD"
	# sed is for https://bugs.mysql.com/bug.php?id=20545
	mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
	    # set up  datadog
    if [ ! -z "$DATA_DOG_API_KEY" ];then
        echo "$0: running datadog init"; . "/etc/datadog.sh" ;
    fi
    echo "Creating users."

	"${mysql[@]}" <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY '${XTRABACKUP_PASSWORD}';
		GRANT PROCESS, RELOAD, LOCK TABLES,REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
		DROP DATABASE IF EXISTS test ;
		FLUSH PRIVILEGES ;
	EOSQL

    if [ ! -z $MONITOR_PASSWORD ] && [ ! -z $MONITOR_USER ];then
        echo "Creating monitor user: $MONITOR_USER"
    	"${mysql[@]}" <<-EOSQL
            CREATE USER '${MONITOR_USER}'@'localhost' IDENTIFIED BY '${MONITOR_PASSWORD}';
            GRANT REPLICATION CLIENT, SUPER, PROCESS ON *.* TO '${MONITOR_USER}'@'localhost';
            GRANT SELECT ON performance_schema.* TO '${MONITOR_USER}'@'localhost';
    		FLUSH PRIVILEGES ;
    	EOSQL
    fi
	if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
		mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
	fi

	if [ "$MYSQL_DATABASE" ]; then
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
		mysql+=( "$MYSQL_DATABASE" )
	fi

	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

		if [ "$MYSQL_DATABASE" ]; then
			echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
		fi

		echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
	fi

	echo  "Running scripts on initialization"
	# add volume to /docker-entrypoint-initdb.d/* for things like sql users, etc.
	for f in /docker-entrypoint-initdb.d/*; do
		case "$f" in
			*.sh)     echo "$0: running $f"; . "$f" ;;
			*.sql)    echo "$0: running $f"; "${mysql[@]}" < "$f"; echo ;;
			*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${mysql[@]}"; echo ;;
			*)        echo "$0: ignoring $f" ;;
		esac
		echo
	done

	if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
		"${mysql[@]}" <<-EOSQL
			ALTER USER 'root'@'%' PASSWORD EXPIRE;
		EOSQL
	fi
	if ! kill -s TERM "$pid" || ! wait "$pid"; then
		echo >&2 'MySQL init process failed.'
		exit 1
	fi
	echo
	echo 'MySQL init process done. Ready for start up.'
	echo

    sed -i "s|wsrep_sst_auth.*|wsrep_sst_auth = xtrabackup:$XTRABACKUP_PASSWORD|g" /etc/mysql/my.cnf

fi

# always run following...\

chown -R mysql:mysql "$DATADIR"
echo
#used when install sendmail
#apt-get install -y sendmail sendmail-cf m4 \
#	&& rm -r /var/lib/apt/lists/*
# add host to /etc/hosts
[ -z $MAIL_FROM ] && DOMAIN='noreply@vernoncompany.com'
host=`hostname`
line=$(cat /etc/hosts |grep [1]27.0.0.1)
sed  "s|$line|$line $MAIL_FROM $host|g"  /etc/hosts
echo "$host" >> /etc/mail/relay-domains
sed "s|, Addr=127.0.0.1||g" /etc/mail/sendmail.mc
m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf
#start service
sendmail -bd
set -e

echo >&2 ">> Starting mysqld process"
if [ -z $CLUSTER_JOIN ]; then
	export _WSREP_NEW_CLUSTER='--wsrep-new-cluster'
	# set safe_to_bootstrap = 1
	GRASTATE=$DATADIR/grastate.dat
	[ -f $GRASTATE ] && sed -i "s|safe_to_bootstrap.*|safe_to_bootstrap: 1|g" $GRASTATE
else
    sed -i "s|wsrep_cluster_address.*|wsrep_cluster_address = 'gcomm://$CLUSTER_JOIN'|g" /etc/mysql/my.cnf
	export _WSREP_NEW_CLUSTER=''
fi


# these arguments will overide those of /etc/my.cnf
exec mysqld $_WSREP_NEW_CLUSTER $CMDARG

# leave at end of file
echo  "Running scripts for things that are not persistent"
# add volume to /docker-entrypoint-initdb.d/* for things like
# datadog monitoring, etc.
for f in /docker-entrypoint-initdb.d/repeat/*; do
	case "$f" in
		*.sh)     echo "$0: running $f"; . "$f" ;;
		*)        echo "$0: ignoring $f" ;;
	esac
	echo
done

#!/bin/bash
# added supervisord command at end for ssh access from Cluster Control
# a mix of the official docker-entrypoint.sh and that of
#    https://github.com/diegomarangoni/docker-mariadb-galera
set -eo pipefail
# Get config
DATADIR="$(mysqld --verbose --help --log-bin-index=`mktemp -u` 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
ls -l $DATADIR
# if command starts with an option, prepend mysqld
# STARTING WITHOUT mysqld runs through init process if no dir/mysql
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
	sleep 10
	# following doesn't always catch a previous mysql, put sleep to help
	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and password option is not specified '
			echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
			exit 1
		fi

		mkdir -p "$DATADIR"
		chown -R mysql:mysql "$DATADIR"

		var=0
		echo "updating my.cnf with wsrep args before install_db"
		for i in "$@"
		do
			if [[ $i == *"wsrep-new"* ]]
			then
				echo "skipping $i"
				args+=($i)
				((++var))
				continue
			fi
			if [[ $i == *"wsrep"* ]]
			then
				foo=${i#--}
				baz=${foo%=*}
				sed -i.bak s#$baz=#$foo#g /etc/mysql/my.cnf
				echo "$baz updated in /etc/mysql/my.cnf."
			else
				echo "skipping $i"
				args+=($i)
				((++var))
			fi
		done

		echo 'Initializing'
		mysql_install_db --user=mysql --verbose --datadir="$DATADIR" --rpm --no-defaults
		echo 'Database initialized'
		service mysql stop
		if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
			# sed is for https://bugs.mysql.com/bug.php?id=20545
			mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
		fi
		pwd=($(cat /etc/mysql/debian.cnf | grep password | awk {"print \$3"}))
		tempSqlFile='/tmp/mysql-first-time.sql'
cat > "$tempSqlFile" <<-EOSQL
SET @@SESSION.SQL_LOG_BIN=0;
DELETE FROM mysql.user ;
FLUSH PRIVILEGES ;
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
CREATE USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$pwd';
DROP DATABASE IF EXISTS test ;
EOSQL

        if [ "$MYSQL_DATABASE" ]; then
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" >> "$tempSqlFile"
        fi

        if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
            echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"

            if [ "$MYSQL_DATABASE" ]; then
                echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" >> "$tempSqlFile"
            fi
        fi

        echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
		args+=(" --init-file=$tempSqlFile ")
        exec ${args[@]}
	else
		exec "$@"
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
else

	echo "$@"
	exec "$@"
fi

echo  "Running scripts for things that are not persistent"
# add volume to /docker-entrypoint-initdb.d/* for things like datadog monitoring,  etc.
for f in /docker-entrypoint-initdb.d/repeat/*; do
	case "$f" in
		*.sh)     echo "$0: running $f"; . "$f" ;;
		*)        echo "$0: ignoring $f" ;;
	esac
	echo
done

/usr/bin/supervisord
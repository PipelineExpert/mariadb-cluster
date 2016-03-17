#!/bin/bash
# stop mariadb on first server before running this and update applications to new access point
eval $(docker-machine env galera-local)
#create users.sql
python get_user.py username userpasswd &
# copy users.sql to node1 and run
docker cp /tmp/users.sql node1:tmp
time docker exec -it node1 mysql -u root -p$my_pwd -e "use mysql;SET autocommit=0 ; source /tmp/user.sql; COMMIT; SET autocommit=1; "
databases=( "$( mysql -h10.1.1.49 -u root -p -Bse 'show databases;')" )
databases= \'$databases\'
echo "$databases"

for db_name in $databases
do
    echo "$db_name"
    haystack="mysql performance_schema information_schema"
    if [ -z "${haystack##*$db_name*}" ]
    then
	echo "skipping $db_name"
    else
	echo "creating mysqldump of $db_name"
	mysqldump --defaults-file=.my.cnf --no-data --skip-comments --skip-add-drop-table --triggers $db_name > /tmp/db_schema.sql
	sed -i.bak 's#MyISAM#innodb#g' /tmp/db_schema.sql
	time mysqldump --defaults-file=.my.cnf --no-create-info --no-autocommit --compact --complete-insert --no-create-db --skip-add-drop-table -R --triggers $db_name > /tmp/db_data.sql
        echo "copying  *.sql for $db_name to node1"
	docker cp /tmp/db_schema.sql node1:tmp
	time docker cp /tmp/db_data.sql node1:tmp
	# create the database
	docker exec -d node1 mysql -u root -pwhoh00! -e "DROP DATABASE IF EXISTS $db_name; CREATE DATABASE $db_name;"
	# create the schema
	echo "importing *.sql for $db_name into galera"
	time docker exec -it node1 mysql -u root -p$my_pwd -e "use $db_name;SET autocommit=0;source /tmp/db_schema.sql ; COMMIT;"
	# load in the data
	time docker exec -it node1 mysql -u root -p$my_pwd -e "use $db_name; source /tmp/db_data.sql ; COMMIT ;SET autocommit=1;"
    fi
done

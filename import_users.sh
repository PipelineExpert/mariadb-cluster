#!/bin/bash
# users on mysql.users do not populate over the cluster with inserts
# so add user permissions made 3/30/16 so using grant dll instead

if [ "$#" -lt 2 ]
then
	echo "need 2 args(galera root pwd & host name for donor of mysql users)"
	exit
fi
# get user table from CURRENT DB
sudo apt update && sudo apt install percona-toolkit -y
pt-show-grants -h$2 -uroot -p$1  > /tmp/users.sql
echo "FLUSH PRIVILEGES;" >> /tmp/users.sql

#set active docker-machine

i=$((1+$add_num))
echo "updating users on node$i"
docker-machine scp /tmp/users.sql node$i:./users.sql
docker-machine ssh node$i "docker cp users.sql galera_node:./users.sql \
    && docker exec -d galera_node mysql -uroot -p$1 -e 'source users.sql'"


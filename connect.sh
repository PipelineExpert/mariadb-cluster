#!/bin/bash
# used to connect to galera_node
if [ "$#" -lt 2 ]
then
	echo "need 2 args( root password, and machine_name)
	exit
fi
eval $(docker-machine env $2)
docker $(weave config) run -it --link galera_node:mysql --rm \
  -e TERM=xterm \
	vernonco/mariadb-cluster:stable \
	sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p$1'

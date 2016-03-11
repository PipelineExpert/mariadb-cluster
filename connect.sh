#!/bin/bash
# used to connect to node1
docker run -it --link node1:mysql --rm \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e TERM=xterm \
	vernonco/mariadb-cluster \
	sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p'
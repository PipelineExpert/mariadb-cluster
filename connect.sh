#!/bin/bash
# used to connect to node$1
docker run -it --link node$1:mysql --rm \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e TERM=xterm \
	stuartz/mariadb-cluster \
	sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p$2'
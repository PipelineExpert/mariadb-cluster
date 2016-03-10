#!/bin/bash
# used to connect to node1 with host port passwd
docker run -it --rm \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/certs:/var/lib/mysql/ssl \
  -e TERM=xterm \
	vernonco/mariadb-cluster \
	sh -c "exec mysql -h$1 -P$2 -uroot -p$3"
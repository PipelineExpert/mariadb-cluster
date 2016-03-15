#!/bin/bash
# used to connect to remote host with host port passwd
docker run -it --rm \
  -v /var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e TERM=xterm \
	vernonco/mariadb-cluster \
	sh -c "exec mysql -h$1 -P$2 -uroot -p$3"
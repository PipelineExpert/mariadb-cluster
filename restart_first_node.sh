#!/bin/bash
# used to restart/upgrade a previously initialized master node
# additional nodes are using -v /var/lib/mysql
# use restart_additional_node.sh
node=node1
tag="$1"

if [ "$#" -gt 1 ]
then
	# use docker-machine to run scripts remotely.
	eval $(docker-machine env $2)
fi

#first node
docker stop $node
docker rm $node
docker pull vernonco/mariadb-cluster:$tag
docker run \
  --name $node \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -v /home/ubuntu/my.cnf:/etc/mysql/my.cnf \
  -e TERM=xterm \
  -d \
  -p 3306:3306 \
  -p 4444:4444 \
  -p 4567:4567/udp \
  -p 4567-4568:4567-4568 \
  vernonco/mariadb-cluster:$tag \
  mysqld
  # can use --wsrep_[option] to change config if needed
  # otherwise the initial commands are in my.conf

sleep 20
docker stop myadmin
docker start myadmin
#!/bin/bash
# used to restart/upgrade a previously initialized node
node=node"$1"
if [ "$#" -lt 1 ]
then
	echo "need 1 args( node#)...  1 [tag docker-machine-name]"
	exit
fi

if [ "$#" -gt 2 ]
then
	# use docker-machine to run scripts remotely.
	eval $(docker-machine env $3)
fi

#first node
docker stop $node
docker rm $node
docker pull vernonco/mariadb-cluster:$2
docker run \
  --name $node \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e TERM=xterm \
  -d \
  -p 3306:3306 \
  -p 4444:4444 \
  -p 4567:4567/udp \
  -p 4567-4568:4567-4568 \
  vernonco/mariadb-cluster \
  mysqld
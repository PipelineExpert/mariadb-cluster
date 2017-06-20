#!/bin/bash
# used to start/restart a secondary node

# easier to use docker-machine, docker-compose and local my.cnf volume (see docker-compose.yml)
 # eval $(docker-machine env machine_name)
 # docker-compose up -d

# this links the volume of the previous db_volume
# to start a fresh node where one exists, use additional_node.sh
node=node"$1"
tag=$2
if [ "$#" -lt 1 ]
then
	echo "need 1 args( node# [tag docker-machine-name])"
	exit
fi

if [ "$#" -gt 2 ]
then
	# use docker-machine to run scripts remotely.
	eval $(docker-machine env $3)
fi
#restart another node
docker stop $node
docker rm -v $node
docker pull vernonco/mariadb-cluster:$tag
docker run \
  --name $node  \
  --volumes-from db_volume \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -v /home/ubuntu/my.cnf:/etc/mysql/my.cnf \
  -e TERM=xterm \
  -d \
  -p 3308:3306 \
  -p 4444:4444 \
  -p 4567-4568:4567-4568 \
  vernonco/mariadb-cluster:$tag \
  mysqld

#!/bin/bash
# can be used to start another node
# easier to use docker-machine, docker-compose and local my.cnf volume (see docker-compose.yml)
 # eval $(docker-machine env machine_name)
 # docker-compose up -d

this_node_IP="$1"
my_pwd="$2"
cluster_addresses=$3
node=galera_node
if [ "$#" -lt 3 ]
then
	echo "need 4 args( IP pwd node# cluster_addresses)... 10.0.0.3 password 1 "10.1.1.3,10.1.1.4,10.1.1.5" [':tag' docker-machine-name]"
	exit
fi

if [ "$#" -gt 3 ]
then
	tag=$4
else
	tag=:stable
fi

if [ "$#" -gt 4 ]
then
	# use docker-machine to run scripts remotely.
	docker_machine_name=$5
	eval $(docker-machine env $docker_machine_name)
fi

# issues with removed files still showing existing when db_init
# using volume on host instead
# create a fresh db_volume
#docker rm -v db_volume
#docker create -v /var/lib/mysql --name db_volume  debian:jessie

# create another fesh node. Remove node if already exists
docker stop $node
docker rm -v $node
docker pull vernonco/mariadb-cluster$tag
docker run \
  --name $node  \
  -v /var/lib/docker/data:/var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e MYSQL_INITDB_SKIP_TZINFO=yes \
  -e MYSQL_ROOT_PASSWORD=$my_pwd \
  -e TERM=xterm \
  -d \
  -p 3306:3306 \
  -p 4444:4444 \
  -p 4567-4568:4567-4568 \
  stuartz/mariadb-cluster$tag \
  --wsrep-node-address=$this_node_IP \
  --wsrep-node-name=$node \
  --wsrep-cluster-name=galera-cluster \
  --wsrep-cluster-address=gcomm://$cluster_addresses \
  --wsrep-sst-auth=root:$my_pwd \
  --wsrep-sst-donor=node1
#!/bin/bash
# can be used to start another node
this_node_IP="$1"
my_pwd="$2"
node=node"$3"
cluster_addresses=$4
tag=$5
if [ "$#" -lt 4 ]
then
	echo "need 4 args( IP pwd node# cluster_addresses)... 10.0.0.3 password 1 "10.1.1.3,10.1.1.4,10.1.1.5" [tag docker-machine-name]"
	exit
fi

if [ "$#" -gt 5 ]
then
	# use docker-machine to run scripts remotely.
	eval $(docker-machine env $6)
fi
#another node
docker rm -v db_volume
docker run -d -v /var/lib/mysql --name db_volume  debian:jessie
docker stop $node
docker rm -v $node
docker pull stuartz/mariadb-cluster$tag
docker run \
  --name $node  \
  --volumes-from db-volume \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e MYSQL_INITDB_SKIP_TZINFO=yes \
  -e MYSQL_ROOT_PASSWORD=$my_pwd \
  -e TERM=xterm \
  -d \
  -p 3306:3306 \
  -p 4444:4444 \
  -p 4567-4568:4567-4568 \
  stuartz/mariadb-cluster$tag \
  mysqld \
  --wsrep-node-address=$this_node_IP \
  --wsrep-node-name=$node \
  --wsrep-cluster-name=galera-cluster \
  --wsrep-cluster-address=gcomm://$cluster_addresses \
  --wsrep-sst-auth=root:$my_pwd \
  --wsrep-sst-donor=node1
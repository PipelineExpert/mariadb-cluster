#!/bin/bash
this_node_IP="$1"
my_pwd="$2"
node=node"$3"
cluster_addresses=10.1.3.28,10.1.1.133,10.1.1.134
if [ "$#" -ne 3 ]
then
	echo "need 3 args( IP pwd node#)... 10.0.0.3 password 1  [docker-machine-name]"
	exit
fi

if [ "$#" -ne 4 ]
then
	# use docker-machine to run scripts remotely.
	#  echo "sudo mkdir -p /data && sudo rm -rf /data/* && $(sudo chown 999:docker /data -R)" | $(docker-machine ssh $4)
	# eval $(docker-machine env $4)
else
	sudo rm -rf /data
	sudo mkdir -p /data
	sudo chown 999:docker /data
fi
#first node
docker stop $node
docker rm $node
docker pull vernonco/mariadb-cluster
docker run \
  --name $node \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/machines/galera/certs:/var/lib/mysql/ssl \
  -e MYSQL_INITDB_SKIP_TZINFO=yes \
  -e MYSQL_ROOT_PASSWORD=$my_pwd \
  -e TERM=xterm \
  -d \
  -p 3306:3306 \
  -p 4444:4444 \
  -p 4567:4567/udp \
  -p 4567-4568:4567-4568 \
  vernonco/mariadb-cluster:dev \
  mysqld --verbose --wsrep-new-cluster \
  --wsrep-node-address=$this_node_IP \
  --wsrep-sst-auth=root:$my_pwd \
  --wsrep-sst-donor=$node \
  --wsrep-node-name=$node --wsrep-cluster-name=galera-cluster \
  --wsrep-cluster-address=gcomm://$cluster_addresses \
  --wsrep-debug
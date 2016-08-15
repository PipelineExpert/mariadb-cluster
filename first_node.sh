#!/bin/bash
# this script for reference only -- not maitaining
# easier to use docker-machine, docker-compose and local my.cnf volume (see docker_compose_start.yml)
 # eval $(docker-machine env machine_name)
 # docker-compose -f docker_compose_start.yml up -d
 
# used to initiate first node with phpmyadmin

this_node_IP="$1"
my_pwd="$2"
node=node1
cluster_addresses=' '
tag=$3
if [ "$#" -lt 2 ]
then
	echo "need 2 args( IP pwd )... 10.0.0.3 password  [tag docker-machine-name]"
	exit
fi

if [ "$#" -gt 3 ]
then
	# use docker-machine to run scripts remotely.
	eval $(docker-machine env $4)
	docker stop $node
	docker-machine ssh $6 'sudo mkdir -p /data && sudo rm -rf /data/* && $(sudo chown 999:docker /data -R)'
else
	docker stop $node
	sudo rm -rf /data/*
	sudo mkdir -p /data
	sudo chown 999:docker /data
fi
#first node
docker rm $node
docker pull stuartz/mariadb-cluster$tag
docker run \
  --name $node \
  -v /data:/var/lib/mysql \
  -v /home/ubuntu/certs:/etc/mysql/ssl \
  -e MYSQL_INITDB_SKIP_TZINFO=yes \
  -e MYSQL_ROOT_PASSWORD=$my_pwd \
  -e MYSQL_DATABASE=Somedatabase \
  -e TERM=xterm \
  -d \
  -p 3306:3306 \
  -p 4444:4444 \
  -p 4567-4568:4567-4568 \
  stuartz/mariadb-cluster$tag \
  --wsrep-new-cluster \
  --wsrep-node-address=$this_node_IP \
  --wsrep-node-name=$node \
  --wsrep-cluster-name=galera-cluster \
  --wsrep-cluster-address=gcomm:// \
  --wsrep-sst-auth=root:$my_pwd \
  --wsrep-sst-donor=node1 \
  --log-error=/dev/stderr \
  --log_warnings=3

# phpmyadmin container
docker stop myadmin
docker rm myadmin
docker run --name myadmin \
	-d --link node1:db \
	-p 8080:80 \
	phpmyadmin/phpmyadmin

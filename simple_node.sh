#!/bin/bash
# runs the container and listens for mysqld instructions on 13306
# see https://github.com/diegomarangoni/docker-mariadb-galera

this_node_IP="$1"
my_pwd="$2"
node=node"$3"
if [ "$#" -ngt 2 ]
then
	echo "need 3 args( IP pwd node#)... 10.0.0.3 password 1 [docker-machine-name]"
	exit
fi

if [ "$#" -gt 3 ]
then
	# use docker-machine to run scripts remotely.
	echo "sudo mkdir -p /data && sudo rm -rf /data/* && $(sudo chown 999:docker /data -R)" | $(docker-machine ssh $4)
	eval $(docker-machine env $4)
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
  vernonco/mariadb-cluster:dev
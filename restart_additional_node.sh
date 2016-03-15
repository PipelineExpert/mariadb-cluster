#!/bin/bash
# used to start/restart a secondary node
# this copies over the volume of the previous node if it exists
# to start a fresh node where one exists, use additional_node.sh
if [ "$#" -gt 5 ]
then
	# use docker-machine to run scripts remotely.
	eval $(docker-machine env $6)
	docker stop $node
	#docker-machine ssh $6 'sudo mkdir -p /data && sudo rm -rf /data/* \
	#	&& sudo groupadd -r mysql && $(sudo chown msyql:mysql /data -R)'
else
	docker stop $node
	# unable to prevent permission issues with -v /data so using -v /var/lib/mysql
	#sudo rm -rf /data/* && sudo mkdir -p /data && 	sudo chown 999:docker /data
fi
CONTAINER=$(docker ps -a | grep $node | awk {"print \$1"})
RUNNING=$(docker inspect --format="{{ .State.Running }}" $CONTAINER 2> /dev/null)
if [ $? -neq 1 ]; then
	# volumenode is known...copy volume over to new container
	docker run --rm --volumes-from $node -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /var/lib/mysql
	docker rm -v $node
	docker pull vernonco/mariadb-cluster$tag
	docker run \
	  --name $node  \
	  -v /var/lib/mysql \
	  -e TERM=xterm \
	  -d \
	  -p 3306:3306 \
	  -p 4444:4444 \
	  -p 4567-4568:4567-4568 \
	  vernonco/mariadb-cluster$tag \
	  bash
	#copy volume data back into new container
	docker run --rm --volumes-from dbstore2 -v $(pwd):/backup ubuntu bash -c "cd /var/lib/mysql && tar xvf /backup/backup.tar --strip 1"
	# run mysqld on node
	docker exec -d $node mysqld

else
	#start another node
	docker rm -v $node
	docker pull vernonco/mariadb-cluster$tag
	docker run \
	  --name $node  \
	  -v /var/lib/mysql \
	  -v /home/ubuntu/certs:/etc/mysql/ssl \
	  -e MYSQL_INITDB_SKIP_TZINFO=yes \
	  -e MYSQL_ROOT_PASSWORD=$my_pwd \
	  -e TERM=xterm \
	  -d \
	  -p 3306:3306 \
	  -p 4444:4444 \
	  -p 4567-4568:4567-4568 \
	  vernonco/mariadb-cluster$tag \
	  mysqld \
	  --wsrep-node-address=$this_node_IP \
	  --wsrep-node-name=$node \
	  --wsrep-cluster-name=galera-cluster \
	  --wsrep-cluster-address=gcomm://$cluster_addresses \
	  --wsrep-sst-auth=root:$my_pwd \
	  --wsrep-sst-donor=node1
fi
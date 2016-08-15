#!/bin/sh
#!/bin/bash
# used to update all nodes
#**********************need to remove comments for node2 after migrating to production **********************
#stop nodes 2 & 3 to prevent getting ahead of node1
#contaier prefix
container=galera_
# set machine  **********************
eval $(docker-machine env galera-node2)
docker stop $(docker ps |grep $container|awk '{print $1}')

# set machine
eval $(docker-machine env galera-AWS)
docker stop $(docker ps |grep $container|awk '{print $1}')

#update machines and restart

# set machine
eval $(docker-machine env galera-node1)
docker pull vernonco/mariadb-cluster:stable
docker-machine ssh galera-node1 "docker-compose $(weave config) -p galera_ up --force-recreate -d"
sleep 3

# set machine ***************************
eval $(docker-machine env galera-node2)
docker pull vernonco/mariadb-cluster:stable
docker-machine ssh galera-node2 "docker-compose $(weave config) -p galera_ up --force-recreate -d"
#sleep 3

# set machine
eval $(docker-machine env galera-AWS)
docker pull vernonco/mariadb-cluster:stable
docker-machine ssh galera-aws "docker-compose $(weave config) -p galera_ up --force-recreate -d"

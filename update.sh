#!/bin/sh
#!/bin/bash
# used to update all nodes
#**********************need to remove comments for node2 after migrating to production **********************
#stop nodes 2 & 3 to prevent getting ahead of node1
#contaier prefix

if [ -z "$CLUSTER_NAME" ]; then
	echo >&2 'Error:  You need to specify CLUSTER_NAME'
	exit 1
fi

if [ -z "$NODES" ]; then
	echo >&2 'Error:  You need to specify NODES (number of)'
	exit 1
fi

for i in `seq 1 $NODES`;
do
    if [ $i -eq 1 ];then
        # leave it running -- it will be the bootstrap node
    else
        docker-machine ssh node$i "docker-compose down"
    fi
#update machines and restart
for i in `seq 1 $NODES`;
do
    if [ $i -eq 1 ];then
        CLUSTER_JOIN=
    else if [ $i -eq $NODES ]
        x=$((i-1))
        CLUSTER_JOIN=node1,node$x
    else
        x=$((i+1))
        CLUSTER_JOIN=node1,node$x
    fi
    # set machine
    # do not need to exort all the other variables as it check the persistent
    # volume for $DATADIR/grastate.dat to prevent doing a db init
    docker-machine ssh node$i "export CLUSTER_JOIN=$CLUSTER_JOIN \
        && docker-compose pull \
        && docker-compose $(weave config) up --force-recreate -d"
    sleep 3
done

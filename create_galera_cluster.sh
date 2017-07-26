#!/bin/bash
##### example run #####
##### Change as needed

#** Creates docker-machines on AWS and starts up a cluster on a secured weave network **
# PREREQUISITES: docker, docker-machine, AWS_ACCESS_KEY_ID, & AWS_SECRET_ACCESS_KEY
# see: https://docs.docker.com/machine/drivers/aws/#command-line-flags


# AWS security group requires ports for weave, docker-machine, and ssh:
# Cutom UDP Rule    UDP    6783-6784   0.0.0.0/0
# Custom TCP Rule   TCP    6783        0.0.0.0/0
# Custom TCP Rule   TCP    2376        yourip/32
# ssh               TCP    22          yourip/32

# can export ADD_NUM=n to set beginning node number
#    ie.add_num=3 will set begining node number to 4

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
	echo >&2 'Error:  You need to specify MYSQL_ROOT_PASSWORD'
	exit 1
fi
if [ -z "$XTRABACKUP_PASSWORD" ]; then
	echo >&2 'Error:  You need to specify XTRABACKUP_PASSWORD'
	exit 1
fi
if [ -z "$WEAVE_PASSWORD" ]; then
	echo >&2 'Error:  You need to specify WEAVE_PASSWORD'
	exit 1
fi
if [ -z "$CLUSTER_NAME" ]; then
	echo >&2 'Error:  You need to specify CLUSTER_NAME'
	exit 1
fi

# **********************************************
# example variables
AWS_VPC_ID='vpc-bd813dd8'
REGION='us-west-2'  #Oregon
INSTANCE_TYPE='m3.medium'
SPOT_PRICE='.1'  #if not desiring spot instance remove flag and price below
# **********************************************

#odd numbers. Minimum of 3 nodes for arbritration, 5 is better in case
# one goes down and ties up 4th node in IST or SST
# REQUIRED:
nodes=3
add_num=$ADD_NUM  # add_num=5 i=x+1 node$i will be node6
start_num=$((1+$add_num))

# ********************************************************
#OPTIONAL (for node status notifications) or modify galeranotification.py:
MAIL_FROM=$MAIL_FROM   #ie. "noreply@company.com" defaults to noreply@nodehost
MAIL_TO=$MAIL_TO    #ie. "user@company.com"
MONITOR_USER=$MONITOR_USER  #ie DATA_DOG
MONITOR_PASSWORD=$MONITOR_PASSWORD
DATA_DOG_API_KEY=$DATA_DOG_API_KEY
MYSQL_DATABASE=$MYSQL_DATABASE  # name of database you want to create
MYSQL_USER=$MYSQL_USER  #user to access database created
MYSQL_PASSWORD=$MYSQL_PASSWORD
WEAVE_VERSION=$WEAVE_VERSION  #set weave version or leave blank for latest

PREVIOUS_IP=$PREVIOUS_IP  # LEAVE BLANK to start on own network or ip to connect to network
# **********************************************************

for x in `seq 1 $nodes`;
do
    i=$((x+$add_num))
    echo '*************************************'
    echo
    echo "creating node$i"
    echo
    echo '*****************************************'
    docker-machine -D create \
        --driver amazonec2 \
        --amazonec2-vpc-id $AWS_VPC_ID \
        --amazonec2-region $REGION \
        --amazonec2-zone "b" \
        --amazonec2-tags "node$i,docker-machine" \
        --amazonec2-instance-type $INSTANCE_TYPE	\
        --amazonec2-security-group "docker" \
        --amazonec2-request-spot-instance \
        --amazonec2-spot-price $SPOT_PRICE \        
        --engine-storage-driver=overlay2 \
        --engine-install-url=https://releases.rancher.com/install-docker/17.05.sh \
        node$i

        #used rancher.com because of issues with latest docker-engine

    docker-machine ssh node$i 'sudo usermod -aG docker ubuntu'
    echo "Coping files and installing docker-compose & weave"
    docker-machine scp install_compose_weave.sh node$i:./
    docker-machine scp start_W_PHPMYADMIN.yml node$i:./
    docker-machine scp docker-compose.yml node$i:./
    docker-machine ssh node$i "export WEAVE_VERSION=$WEAVE_VERSION \
        && sh install_compose_weave.sh \
        && weave launch --ipalloc-init observer \
            --ipalloc-range 10.36.0.0/16 \
            --password=$WEAVE_PASSWORD $PREVIOUS_IP \
        && sudo apt-get update && sudo apt-get upgrade -y \
        && sudo reboot &"
    PREVIOUS_IP=$(docker-machine ip node$i)
done

# start cluster
echo "############################################"
echo
echo "Starting mariadb-cluster with node$start_num"
echo "#############################################"
docker-machine ssh node$start_num "export node=node$start_num \
    && export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
    && export XTRABACKUP_PASSWORD=$XTRABACKUP_PASSWORD \
    && export CLUSTER_NAME=$CLUSTER_NAME \
    && export MAIL_FROM=$MAIL_FROM \
    && export MAIL_TO=$MAIL_TO \
    && export MYSQL_DATABASE=$MYSQL_DATABASE \
    && export MYSQL_USER=$MYSQL_USER \
    && export MYSQL_PASSWORD=$MYSQL_PASSWORD \
    && export MONITOR_USER=$MONITOR_USER \
    && export MONITOR_PASSWORD=$MONITOR_PASSWORD \
    && export DATA_DOG_API_KEY=$DATA_DOG_API_KEY \
    && docker-compose -f start_W_PHPMYADMIN.yml pull \
    && docker-compose $(weave config) -f start_W_PHPMYADMIN.yml up -d"

COUNTER=2  # start after first node
CLUSTER_JOIN=node$start_num

while [ $COUNTER -lt $(($nodes+1)) ];
do
    i=$((COUNTER+$add_num))
    echo "############################################"
    echo
    echo "Adding mariadb-cluster node$i"
    echo "#############################################"
    docker-machine ssh node$i "export node=node$i \
        && export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        && export XTRABACKUP_PASSWORD=$XTRABACKUP_PASSWORD \
        && export CLUSTER_NAME=$CLUSTER_NAME \
        && export CLUSTER_JOIN=$CLUSTER_JOIN \
        && export MAIL_FROM=$MAIL_FROM \
        && export MAIL_TO=$MAIL_TO \
        && export MONITOR_USER=$MONITOR_USER \
        && export MONITOR_PASSWORD=$MONITOR_PASSWORD \
        && export DATA_DOG_API_KEY=$DATA_DOG_API_KEY \
        && docker-compose pull \
        && docker-compose $(weave config) up -d"
    COUNTER=$(expr $COUNTER + 1)
    CLUSTER_JOIN=$CLUSTER_JOIN+",node$i"
done

echo 'hosts(contaners) on weave network:'
docker-machine ssh node$start_num 'weave status dns'

echo "PHPMYADMIN is on node$start_num on port 8080 at: "
docker-machine ip node$start_num

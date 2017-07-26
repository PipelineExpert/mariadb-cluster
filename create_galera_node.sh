#!/bin/bash

#** Creates docker-machine on AWS and attaches node to a cluster on a secured weave network **
# PREREQUISITES: docker, docker-machine, AWS_ACCESS_KEY_ID, & AWS_SECRET_ACCESS_KEY, & running cluster
# see: https://docs.docker.com/machine/drivers/aws/#command-line-flags

# *** set CLUSTER_JOIN TO ADD NODE OR LEAVE EMPTY TO START ONE

# AWS security group requires ports for weave, docker-machine, and ssh:
# Cutom UDP Rule    UDP    6783-6784   0.0.0.0/0
# Custom TCP Rule   TCP    6783        0.0.0.0/0
# Custom TCP Rule   TCP    2376        yourip/32
# ssh               TCP    22          yourip/32

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
if [ -z "$NODE_NUM" ]; then
	echo >&2 'Error:  You need to specify NODE_NUM (The node number)'
	exit 1
fi
if [ -z "$PREVIOUS_IP" ]; then
	echo >&2 'Error:  You need to specify PREVIOUS_IP (ip to connect to weave network)'
	exit 1
fi

# example variables
AWS_VPC_ID='vpc-71f65118'
REGION='us-east-2'  #Ohio
INSTANCE_TYPE='m4.large'
SPOT_PRICE='.023'  #if not desiring spot instance remove flag and price below

#odd numbers. Minimum of 3 nodes for arbritration, 5 is better in case
# one goes down and ties up 4th node in IST or SST
# REQUIRED:

#OPTIONAL (for node status notifications) or modify galeranotification.py:
MAIL_FROM=$MAIL_FROM   #ie. "your-com.mail.protection.outlook.com"
MAIL_TO=$MAIL_TO    #ie. "user@company.com"
MONITOR_USER=$MONITOR_USER  #ie DATA_DOG
MONITOR_PASSWORD=$MONITOR_PASSWORD
DATA_DOG_API_KEY=$DATA_DOG_API_KEY
MYSQL_DATABASE=$MYSQL_DATABASE  # name of database you want to create
MYSQL_USER=$MYSQL_USER  #user to access database created
MYSQL_PASSWORD=$MYSQL_PASSWORD

docker-machine -D create \
    --driver amazonec2 \
    --amazonec2-vpc-id $AWS_VPC_ID \
    --amazonec2-region $REGION \
    --amazonec2-zone "b" \
    --amazonec2-tags "node$NODE_NUM,docker-machine" \
    --amazonec2-instance-type $INSTANCE_TYPE	\
    --amazonec2-security-group "docker" \
    --amazonec2-request-spot-instance \
    --amazonec2-spot-price $SPOT_PRICE \
    --engine-storage-driver=overlay2 \
    --engine-install-url=https://releases.rancher.com/install-docker/17.05.sh \
    node$NODE_NUM

docker-machine ssh node$NODE_NUM 'sudo usermod -aG docker ubuntu'
docker-machine scp install_compose_weave.sh node$NODE_NUM:./
docker-machine ssh node$NODE_NUM "export WEAVE_VERSION=$WEAVE_VERSION \
    && sh install_compose_weave.sh"
docker-machine scp docker-compose.yml node$NODE_NUM:./


# if joining a previous network add
# PREVIOUS_IP=ip1,anotherip,ip3,etc
# ip alloc-range needs to be the same for applications connecting to hit by hostname
# use private ips on vpc if not using weave
docker-machine ssh node$NODE_NUM \
    "weave launch --ipalloc-init observer --ipalloc-range 10.36.0.0/16 \
    --password=$WEAVE_PASSWORD $PREVIOUS_IP"

echo 'hosts(contaners) on weave network:'
docker-machine ssh node$NODE_NUM 'weave status dns'

# add node to cluster
docker-machine ssh node$NODE_NUM "export node=node$NODE_NUM \
    && export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
    && export XTRABACKUP_PASSWORD=$XTRABACKUP_PASSWORD \
    && export CLUSTER_NAME=$CLUSTER_NAME \
    && export CLUSTER_JOIN=$CLUSTER_JOIN \
    && export MAIL_FROM=$MAIL_FROM \
    && export MAIL_TO=$MAIL_TO \
    && export MONITOR_USER=$MONITOR_USER \
    && export MONITOR_PASSWORD=$MONITOR_PASSWORD \
    && export DATA_DOG_API_KEY=$DATA_DOG_API_KEY \
    && docker-compose $(weave config) up -d"

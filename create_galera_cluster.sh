#!/bin/bash

#** Creates docker-machines on AWS and starts up a cluster on a secured weave network **
# PREREQUISITES: docker, docker-machine, AWS_ACCESS_KEY_ID, & AWS_SECRET_ACCESS_KEY
# see: https://docs.docker.com/machine/drivers/aws/#command-line-flags

# *** check MYSQL_ROOT_PASSWORD and CLUSTER_NAME in start.yml
# and docker-compose.yml

# AWS security group requires ports for weave, docker-machine, and ssh:
# Cutom UDP Rule    UDP    6783-6784   0.0.0.0/0
# Custom TCP Rule   TCP    6783        0.0.0.0/0
# Custom TCP Rule   TCP    2376        yourip/32
# ssh               TCP    22          yourip/32

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
	echo >&2 'Error:  You need to specify MYSQL_ROOT_PASSWORD'
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
# example variables
AWS_VPC_ID='vpc-71f65118'
REGION='us-east-2'  #Ohio
INSTANCE_TYPE='m4.large'
SPOT_PRICE='.023'  #if not desiring spot instance remove flag and price below

#odd numbers. Minimum of 3 nodes for arbritration, 5 is better in case
# one goes down and ties up 4th node in IST or SST
# REQUIRED:
nodes=3

#OPTIONAL (for node status notifications) or modify galeranotification.py:
SMTP_SERVER=$SMTP_SERVER   #ie. "your-com.mail.protection.outlook.com"
SMTP_USERNAME=$SMTP_USERNAME    #ie. "user@company.com"
MYSQL_DATABASE=$MYSQL_DATABASE  # name of database you want to create
MYSQL_USER=$MYSQL_USER  #user to access database created
MYSQL_PASSWORD=$MYSQL_PASSWORD

for i in `seq 1 $nodes`;
do
    docker-machine -D create \
        --driver amazonec2 \
        --amazonec2-vpc-id $AWS_VPC_ID \
        --amazonec2-region $REGION \
        --amazonec2-zone "b" \
        --amazonec2-tags "$name,docker-machine" \
        --amazonec2-instance-type $INSTANCE_TYPE	\
        --amazonec2-security-group "docker" \
        --amazonec2-request-spot-instance \
        --amazonec2-spot-price $SPOT_PRICE \
    	node$i

    docker-machine ssh node$i 'sudo usermod -aG docker ubuntu'
    docker-machine scp install_compose_weave.sh node$i:./
    docker-machine ssh node$1 'sh install_compose_weave.sh'
    docker-machine scp start.yml node$i:./
    docker-machine scp docker-compose.yml node$i:./


    # if joining a previous network add
    # PREVIOUS_IP=ip1,anotherip,ip3,etc
    # ip alloc-range needs to be the same for applications connecting to hit by hostname
    # use private ips on vpc if not using weave
    docker-machine ssh node$i \
        "weave launch --ipalloc-init observer --ipalloc-range 10.36.0.0/16 \
        --password=$WEAVE_PASSWORD $PREVIOUS_IP"

    PREVIOUS_IP=$(docker-machine ip node$1)
    echo 'hosts(contaners) on weave network:'
    docker-machine ssh node$i 'weave status dns'
done

# start cluster
docker-machine ssh node1 "export node=node1 \
    && export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
    && export CLUSTER_NAME=$CLUSTER_NAME \
    && export SMTP_SERVER=$SMTP_SERVER \
    && export SMTP_USERNAME=$SMTP_USERNAME \
    && export MYSQL_DATABASE=$MYSQL_DATABASE \
    && export MYSQL_USER=$MYSQL_USER \
    && export MYSQL_PASSWORD=$MYSQL_PASSWORD \    
    && docker-compose -f start.yml up -d"

COUNTER=2
while [ $COUNTER -lte $nodes ];
do
    docker-machine ssh node$COUNTER \
        "export node=node$COUNTER \
        && export MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        && export CLUSTER_NAME=$CLUSTER_NAME \
        && export SMTP_SERVER=$SMTP_SERVER \
        && export SMTP_USERNAME=$SMTP_USERNAME \
        && docker-compose up -d"
    let COUNTER=COUNTER+1
done

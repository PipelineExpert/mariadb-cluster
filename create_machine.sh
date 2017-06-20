#!/bin/bash

# *** use to set up docker-machine access to an existing vm
# First create user on server
# `sudo adduser ubuntu`
# `passwd ubuntu_password`
# add user to sudoers without password
# `sudo su`
# `visudo`
# add following to visudo file
# ubuntu ALL=(ALL) NOPASSWD: ALL
# exit server
# next copy ssh id to server
# `ssh-copy-id ubuntu@$1`
# then run this script

# if machine of name already exists use it or docker-machine rm name

set -e
ip="$1"
name="$2"
if [ "$#" -ne 2 ]
then
	echo "READ file first.  Pass ip as first arg and machine name as second arg (ie. ~.sh 10.1.1.3 galera)"
	exit
fi
if [ -z ${ip} ]
then
	echo "pass ip as first arg"
	exit
fi

if [ -z ${name} ]
then
	echo "pass machine name as second arg"
	exit
fi

docker-machine -D create \
	--driver generic \
	--generic-ip-address=$ip \
	--generic-ssh-key=/home/ubuntu/.ssh/id_rsa \
	--generic-ssh-user=ubuntu \
	$name

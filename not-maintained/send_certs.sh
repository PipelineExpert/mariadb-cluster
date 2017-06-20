#!/bin/bash
# change galera-node# to our machine names

cd /path_to/certs
docker-machine scp -r ./ node1:./certs/
docker-machine scp -r ./ node2:./certs/
docker-machine scp -r ./ cp node3:./certs/

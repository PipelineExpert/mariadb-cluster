#!/bin/bash
# change galera-node# to our machine names

cd /path_to/certs
docker-machine scp -r ./ galera-node1:./certs/
docker-machine scp -r ./ galera-node2:./certs/
docker-machine scp -r ./ galera-node3:./certs/
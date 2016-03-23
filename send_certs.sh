#!/bin/bash
cd /home/ubuntu/certs
docker-machine scp -r ./ galera-node1:./certs/
docker-machine scp -r ./ galera-node2:./certs/
docker-machine scp -r ./ galera-node3:./certs/
**Currently using Mariadb 10.1.12.**
Modified the official Mariadb docker container to create a secure ssl cluster:
* installed openssl and xtrabackup
* adding my.cnf to /etc/mysql/my.cnf
* my.cnf  includes mandatory galera settings including bind-address   = 0.0.0.0 and ssl settings
* removed --skip-networking from entrypoint.sh
* exposed necessary ports for Galera

**SSL certificates**
You can generate self-signed certificate, and -v /path/to/certs/:/var/lib/mysql/ssl/:ro
Following naming convention in galera.cnf for certs:
`[mysqld]`
`ssl-ca=/var/lib/mysql/ssl/ca-cert.pem`
`ssl-cert=/var/lib/mysql/ssl/server-cert.pem`
`ssl-key=/var/lib/mysql/ssl/server-key.pem`
`[mysql]`
`ssl-ca = /var/lib/mysql/ssl/ca-cert.pem`
`ssl-key = /var/lib/mysql/ssl/client-key.pem`
`ssl-cert =/var/lib/mysql/ssl/client-cert.pem`
`[sst]`
`tca=/var/lib/mysql/ssl/ca-cert.pem`
`tcert=/var/lib/mysql/ssl/server-cert.pem`
`tkey=/var/lib/mysql/ssl/server-key.pem`
* see http://galeracluster.com/documentation-webpages/sslcert.html*

Mariadb10.1 automatically starts the master if datadir is empty on node1.

export my_pw="somepwd"
export this_node_IP="machineIP"
export cluster_addresses="10.1.1.3,10.1.1.4, etc."
export node_name = node-name

**Scripts**
_run_node1.sh_
`#!/bin/bash`
`#first node`
`sudo mkdir -p /data`
`docker run -d --name $node_name -e TERM=xterm \`
`  -v /data:/var/lib/mysql \`
`  -v /path_to/certs:/var/lib/mysql/ssl \`
`-e MYSQL_INITDB_SKIP_TZINFO=yes \`
`-e TERM=xterm \`
`-d \`
`-p 3306:3306 \`
`-p 4444:4444 \`
`-p 4567:4567/udp \`
`-p 4567-4568:4567-4568 \`
`-e MYSQL_ROOT_PASSWORD=$my_pw \`
`vernonco/mariadb-cluster \`
`--wsrep-new-cluster --wsrep-node-address=$this_node_IP \`
`  --wsrep-sst-auth=root:$my_pwd \`
`--wsrep-node-name=$node_name --wsrep-cluster-name=galera-cluster \`
` --wsrep-cluster-address=gcomm://$cluster_addresses `

export this_node_IP="machineIP"
export node_name=another_node_name

_bash run_a_node.sh_
`#!/bin/bash`
`docker run \
  --name $node_name \`
`  -v /data:/var/lib/mysql \`
`  -v /path_to/certs:/var/lib/mysql/ssl \`
`  -e MYSQL_INITDB_SKIP_TZINFO=yes \`
`  -e MYSQL_ROOT_PASSWORD=$my_pwd \`
` -e TERM=xterm \`
`  -d \`
`  -p 3306:3306 \`
`  -p 4444:4444 \`
`  -p 4567:4567/udp \`
`  -p 4567-4568:4567-4568 \`
`  vernonco/mariadb-cluster \`
`  mysqld \`
`  --wsrep-node-address=$this_node_IP \`
`  --wsrep-sst-auth=root:$my_pwd \`
`  --wsrep-node-name=$node_name --wsrep-cluster-name=galera-cluster \`
`  --wsrep-sst-donor=node1 \`
`  --wsrep-cluster-address=gcomm://$cluster_addresses `

**MySQL connect to node1**
docker run -it --link node1:mysql --rm mariadb sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'

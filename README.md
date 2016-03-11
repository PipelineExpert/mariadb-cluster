**Currently using Mariadb 10.1.12.**
Pull from vernonco/mariadb-cluster
Modified the official Mariadb docker container to create a secure ssl cluster:
* installed openssl and xtrabackup
* adding my.cnf to /etc/mysql/my.cnf
* my.cnf  includes mandatory galera settings including bind-address   = 0.0.0.0 and ssl settings
* removed --skip-networking from entrypoint.sh
* exposed necessary ports for Galera

**SSL certificates**
You can generate self-signed certificate, and -v /path/to/certs/:/etc/mysql/ssl/:ro
Following naming convention in galera.cnf for certs:
`[mysqld]`
`ssl-ca=/etc/mysql/ssl/ca-cert.pem`
`ssl-cert=/etc/mysql/ssl/server-cert.pem`
`ssl-key=/etc/mysql/ssl/server-key.pem`
`[mysql]`
`ssl-ca = /etc/mysql/ssl/ca-cert.pem`
`ssl-key = /etc/mysql/ssl/client-key.pem`
`ssl-cert =/etc/mysql/ssl/client-cert.pem`
`[sst]`
`tca=/etc/mysql/ssl/ca-cert.pem`
`tcert=/etc/mysql/ssl/server-cert.pem`
`tkey=/etc/mysql/ssl/server-key.pem`
* see http://galeracluster.com/documentation-webpages/sslcert.html*

COPY *.sh, *.sql, and *.sql.gz files to ./docker-entrypoint-initdb.d/ to be ran at init.

export my_pw="somepwd"
export cluster_addresses="10.1.1.3,10.1.1.4, etc."

**Scripts from https://github.com/stuartz/mariadb-cluster**

***first node***
`sh first_node.sh _host_IP_ $m_pwd _node#_ $cluster_addresses [docker-machine name]`

***other nodes (change this_node_IP for each)***
`sh node.sh _host_IP_  $m_pwd _node#_ $cluster_addresses [docker-machine name]`

***restart/upgrade a node***
`sh restart_node.sh _node#_ [docker-machine name]`

***connect to node1***
`sh connect.sh`


**MySQL connect to node1**
`docker run -it --link node1:mysql --rm -e TERM=xterm\`
`	-v /var/lib/mysql -v /path-to-certs/:/etc/mysql/ssl \`
`	vernonco/mariadb-cluster \`
`	sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p'`

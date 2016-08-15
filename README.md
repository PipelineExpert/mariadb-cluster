# mariadb-cluster
Create secure docker containers running a galera cluster accross networks.
* Use at your own risk and modify paths/my.cnf as desired for security and setings.
* You will need to open ports (3306, 4444, 4567-4568, 4567/udp) from the IPs in the host firewall
* if using weave, open ports (6783-6784/udp, 6783, 2376)
* if all nodes are on AWS, open all ports between security group on VPC for simplicity
* see iptables_sec.sh for securing host and docker container

Docker container can be pulled from stuartz/mariadb-cluster:latest or vernonco/mariadb-cluster:stable

**Currently using Mariadb 10.1.14.**
Modified the official Mariadb docker container to create a secure ssl cluster:
* installed openssl and xtrabackup
* adding my.cnf to /etc/mysql/my.cnf or add -v my.cnf:/etc/mysql/my.cnf
* my.cnf  includes mandatory galera settings including bind-address   = 0.0.0.0 and ssl settings
* removed --skip-networking from entrypoint.sh
* exposed necessary ports for Galera
* initial wsrep options passed are written to my.cnf for persistence with volume container

**SSL certificates**
You can generate self-signed certificate with `generate_certs.sh`, and -v /path/to/certs/:/etc/mysql/ssl/
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
* modify and use send_certs.sh to send to docker-machines the nodes will run on*

COPY *.sh, *.sql, and *.sql.gz files to ./docker-entrypoint-initdb.d/ to be ran at init.


**Scripts from https://github.com/stuartz/mariadb-cluster**

#docker-compose examples using weave for encrypted connection between nodes
# see install_compose_weave.sh  and weave_launch.sh
**start nodes**

`docker-compose $(weave config) -f docker-compose_start.yml -p galera_ up -d`

**restart or update nodes**

`docker-compose $(weave config) -p galera_ up -d`

**backup maintenance for nodes**

`cluster_status.sh, snap_create.sh and snap_delete.py on cron jobs`

#docker script examples are no longer maintained--left for reference
# using local my.cnf copy and compose and weave instead

`export my_pw="somepwd"`

`export cluster_addresses="10.1.1.3,10.1.1.4, etc."`

**first node**

** named node1**

`sh first_node.sh _host_IP_ $m_pwd  [ ":tag" docker-machine name ]`

**other nodes (change this_node_IP for each)**

** named node`#`**

`sh additional_node.sh _host_IP_  $m_pwd _node#_ $cluster_addresses [ ":tag" docker-machine_name ]`

**restart/upgrade a node**

`sh restart_first_node.sh [ ":tag" docker-machine name ]`

`sh restart_additional_node.sh  _node#_  [ ":tag" docker-machine_name ]`

**connect to local node$1**

`sh connect.sh _node#_ _root_passwd_`

**connect to remote node**

`sh rconnect.sh _host_IP_ _port_ _root_passwd_`


**MySQL connect to node1 (same as connect.sh)**

`docker run -it --link node1:mysql --rm -e TERM=xterm\`
`	-v /var/lib/mysql -v /path-to-certs/:/etc/mysql/ssl \`
`	stuartz/mariadb-cluster \`
`	sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p'`

# IST sync on AWS
# was able to use weave with encrypted pipes for IST
**or hosted service that has private ip and public ip**

`wating for Galera version 25.3.16 to add wsrep_provider_options="ist.bind=<privateIP>;..."`

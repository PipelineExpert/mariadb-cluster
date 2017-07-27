# mariadb-cluster
Used for containers running a Galera cluster across a secure Weave network.
* Use at your own risk and modify paths/my.cnf as desired for security and setings.
* To use weave, open ports (6783-6784/udp, 6783, 2376)
* if all nodes are on AWS, open all ports between security group on VPC for simplicity
* see iptables_sec.sh for securing host and docker container

Docker container can be pulled from stuartz/mariadb-cluster:#version# or vernonco/mariadb-cluster:stable

**Currently stable is Mariadb 10.1.22.**
Modified the official Mariadb docker container to create a secure cluster running
on a WAN secure Weave network.  These settings are not secure in themselves, but rely on a
secure network like Weave with ssl enabled for WAN or an AWS VPC:
* installed xtrabackup-v2
* adding my.cnf to /etc/mysql/my.cnf or add -v my.cnf:/etc/mysql/my.cnf
* my.cnf  includes mandatory galera settings including bind-address   = 0.0.0.0
* removed --skip-networking from entrypoint.sh
* exposed necessary ports for Galera
* added notification utility galeranotify.py
* sets innodb--buffer-pool-size to 80% of available memory
* to change maraidb version, edit Dockerfile ENV MARIADB_REPO & MARIADB_PACKAGE
* create_galera_cluster.sh uses docker 17.05 and spot pricing on AWS


COPY *.sh, *.sql, and *.sql.gz files to ./docker-entrypoint-initdb.d/ to be ran at init.

**Environment Variables**

Required:

* MYSQL_ROOT_PASSWORD='You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD
* CLUSTER_NAME='your_cluster_name'
* WEAVE_PASSWORD='longrandompassword to secure weave' -- required if using weave

Optional:
* PREVIOUS_IP=  LEAVE BLANK to start on own network or ip to connect to network
* XTRABACKUP_PASSWORD='secret password' or defaults to $MYSQL_ROOT_PASSWORD
* MAIL_FROM='noreply@somedomain.com' if desiring notification of node status changes
* MAIL_TO='user@company.com'
* MYSQL_DATABASE='name of database to create'
* MYSQL_USER='username to connect to above database'
* MYSQL_PASSWORD='password for MYSQL_USER'
* MONITOR_USER / MONITOR_PASSWORD -- creates user with REPLICATION CLIENT, SUPER, PROCESS for monitoring
* DATA_DOG_API_KEY -- to monitor with datadog. Requires datadog.sh in /docker-entrypoint-initdb.d/repeat/ 
* WEAVE_VERSION -- defaults to latest, can set version here (ie. 1.9.4)


**Scripts from https://github.com/stuartz/mariadb-cluster**

** see create_galera_cluster.sh  which creates AWS instances with a cluster running on weave

** start cluster first node **

`docker-compose $(weave config) -f start_W_PHPMYADMIN.yml up -d`

**restart or update nodes**

`docker-compose $(weave config) up -d`

**backup & maintenance for nodes**

`cluster_status.sh, snap_create.sh and snap_delete.py on cron jobs`

**Node Status Notification**
if desiring notification on node status changes add following environment variables:
* SMTP_SERVER = 'your smtp server url' # 'your_company.mail.protection.outlook.com'
* SMTP_USERNAME = 'your email' # --used for from and to
* if Tls needed for authentication, modify galeranotify.py

**MySQL connect to node1 (same as connect.sh)**

`docker $(weave config) run -it --link node1:mysql --rm -e TERM=xterm\`
`	stuartz/mariadb-cluster \`
`	sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p'`


**Without docker-compose on secured weave network**
First node:
`docker $(weave config) run -d -e MYSQL_ROOT_PASSWORD=somepass -e CLUSTER_JOIN='' \`
`   -e CLUSTER_NAME='your_cluster_name' --hostname=node1 stuartz/mariadb-cluster`
Additional nodes (change links and CLUSTER_JOIN):
`docker $(weave config) run -d --link=node1 --link=node2 \
-e MYSQL_ROOT_PASSWORD=somepass -e CLUSTER_JOIN='node1,node2' \
-e CLUSTER_NAME='your_cluster_name' --hostname=node# \ 
stuartz/mariadb-cluster`

# IST sync on AWS
** was able to use weave with encrypted pipes for IST**
**on hosted service that has private ip and public ip**

`To use without weave, bind IST listener on container running in EC2 (ie. wsrep_provider_options="ist.recv_addr=ec2 ip or host)`

# Clone and build
git clone https://github.com/stuartz/mariadb-cluster.git

docker build -t yourrepository/mariadb:tag .

docker push yourrepository/mariadb:tag

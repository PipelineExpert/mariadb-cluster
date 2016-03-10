#!/bin/bash
# change wsrep_sst_method xtrabackup-v2 to mysqldump
# add -v init.db:/docker-entrypoint-init.db

sed -i.bak s/xtrabackup-v2/mysqldump/g /etc/mysql/my.cnf
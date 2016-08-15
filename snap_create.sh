#!/bin/bash

# create a snapshot of volume on AWS
# much quicker than a mysql backup
# see snap_delete.py for maintenance of snapshots
# crontab -e
# 01 4 * * * bash /path/to/snap_create.sh

#parse json string
function jsonValue() {
	KEY=$1
	num=$2
	awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p
}

# find if monthyly, weekly, or daily backup for tag to rotate backups
function get_bkupValue (){
	if [ `date '+%d'` == 01 ];then
		echo "monthly"
	else
		if [ `date '+%u'` -gt 6 ];then
			echo "weekly"
		else
			echo "daily"
		fi
	fi
}

#sends alert if a failur or notice if success
send_alert() {
	if [ "$2" -eq 2 ];then
		echo $1  | mail -s "ATTENTION: Galera snapshot Error" stuartz@yourdomain.com
	else
		echo $1  | mail -s "ATTENTION: Galera snapshot Successful" stuartz@yourdomain.com
	fi
}

###### before snapshot
#prevent flow control issue
docker-machine ssh galera-aws2 "mysql --defaults-file=.bkup-my.cnf -e 'set global wsrep_desync=ON;'"
if [ $? -gt 0 ]; then 
  send_alert "snap_create.sh: Failed running mysql wsrep_desync=ON" 2
  exit 1 
fi
#temporarily lock and flush for a clean shapshot
docker-machine ssh galera-aws2 "mysql --defaults-file=.bkup-my.cnf -e 'FLUSH TABLES WITH READ LOCK AND DISABLE CHECKPOINT;'" 
if [ $? -gt 0 ]; then 
  docker-machine ssh galera-aws2 "mysql --defaults-file=.bkup-my.cnf -e 'set global wsrep_desync=OFF;'"
  send_alert "snap_create.sh: Failed running mysql freeze" 2
  exit 1 
else 
  echo "mysql freeze succeeded" 1>&2 
fi

###### create snapshot
bkupValue="$(get_bkupValue)"
#run aws-cli to create snapshot of EBS volume
snapshot="mariadb shapshot: $(date +'%F %H:%M:%S')"
ID=$(aws ec2 create-snapshot --volume-id vol-53d06fd3 --description "$snapshot")
snapID=$(echo "$ID" | jsonValue "SnapshotId" 1)
if [ -z "$snapID" ]; then
	send_alert "snap_create.sh: There was an issue creating the snapshot" 2
	exit 1
else
	# add tag to backup works with snap_delete.py for removing old weekly and dailys
	aws ec2 create-tags --resources $snapID --tags Key=backup,Value=$bkupValue
	echo "Snapshot created successfully: $snapID" 1>&2 
fi

##### after snapshot
docker-machine ssh galera-aws2 "date +'%F %H:%M:%S' > sql_backup_time; mysql --defaults-file=.bkup-my.cnf -e 'unlock tables;'" 
if [ $? -gt 0 ]; then 
  send_alert "snap_create.sh: Failed running mysql unfreeze" 2
  exit 1 
fi

# rejoin nodes as synced
docker-machine ssh galera-aws2 "mysql --defaults-file=.bkup-my.cnf -e 'set global wsrep_desync=OFF;'"
if [ $? -gt 0 ]; then 
  send_alert "snap_create.sh: Failed running mysql wsrep_desync=OFF" 2
  exit 1 
else 
  echo "mysql wsrep_desync=OFF succeeded" 1>&2 
fi

##### finish snapshot
docker-machine ssh galera-aws2 "bash snap_inner"
if [ $? -gt 0 ]; then 
  send_alert "snap_create.sh: Failed running mysql truncate logs" 2
  exit 1 
else 
  echo "mysql truncate logs succeeded" 1>&2 
fi
send_alert "snap_create.sh: snapshot created successfully"

#!/usr/bin/bash
# crontab -e
# 2 * * * * bash path/to/cluster_status.sh

send_alert() {
    echo "You will continue receiving notifications every 2 minutes from galera node at $2 until it re-syncs itself or the issue is fixed" \
         | mail -s "ATTENTION: Galera $1 is not available" webadmin@yourdomain.com
}

COUNTER=0
# check nodes at each ip
for i in "ip" "ip" "ip"; do
    let COUNTER=COUNTER+1
    echo "node$COUNTER"
    echo $i
    status=$(mysql -h$i --ssl -e "SHOW STATUS LIKE 'wsrep_local_state'\G"|grep Value:  |awk '{print $2}')
    if [ $status -ne "4" ]
    then
        # check if temporarily desynced for sst or backup
        desynced=$(mysql -h$i --ssl -e "SHOW VARIABLES LIKE 'wsrep_desync'\G"|grep Value:  |awk '{print $2}')
        if [ $desynced -ne 'ON']; then
            #send email
            send_alert Node$COUNTER $i
        fi
    fi
done

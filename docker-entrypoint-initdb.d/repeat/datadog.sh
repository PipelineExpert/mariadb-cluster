#!/bin/sh

# best to run on host instead of in container that way you have info if container goes down.

# run script to initialize datadog
#docker-entrypoint-initdb.d folder must be copied to the machine and volume on docker-compose.yaml

#get host name from /etc/mysql/my.cnf
hostname=$(cat /etc/mysql/my.cnf | grep wsrep-node-name | cut -d "=" -f 2 )

#install datadog
datadog_user=your_user
datadog_pwd=user_pwd
DD_API_KEY=datadog_key
bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"

#edit datadog.conf
sed -i.bak 's/#hostname: mymachine.mydomain/hostname: $hostname/g'/etc/dd-agent/datadog.conf
sed -i.bak 's/#tags: mytag/tags: $hostname/g'/etc/dd-agent/datadog.conf
sed -i.bak 's/# log_to_syslog: yes/log_to_syslog: no/g'/etc/dd-agent/datadog.conf

#enable /etc/dd-agent/conf.d/mysql.yaml.example
cp /etc/dd-agent/conf.d/mysql.yaml.example /etc/dd-agent/conf.d/mysql.yaml

# connectin info
sed -i.bak 's/# user: my_username/user: $datadob_user/g' /etc/dd-agent/conf.d/mysql.yaml
sed -i.bak 's/# pass: my_password/pass: $datadob_pwd/g' /etc/dd-agent/conf.d/mysql.yaml
#tag
sed -i.bak 's/#   - optional_tag1/  - $hostname/g' /etc/dd-agent/conf.d/mysql.yaml
#enable metrics
sed -i.bak 's/#   galera_cluster: false/  galera_cluster: true/g' /etc/dd-agent/conf.d/mysql.yaml
sed -i.bak 's/#   extra_/  extra_/g' /etc/dd-agent/conf.d/mysql.yaml

#finish datadog
/etc/init.d/datadog-agent restart

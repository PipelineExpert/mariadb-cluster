#!/bin/sh
# used to limit access to database to trusted IPs...cluster and applications
if [ "$#" -lt 1 ]
then
	echo "need 1 arg for permitted ips (ie."10.1.0.0/16,52.33.77.236,45.23.64.58")"
	exit
fi
# Docker opens up ports to the world. Tighten for security
# add Logging to iptables for trouble shooting and drop
# to view:
# cat /var/log/syslog | grep IPTables-Dropped:
iptables -N LOGGING
iptables -F LOGGING
iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4
iptables -A LOGGING -j DROP

# Clear FORWARD chain and rebuild
iptables -F FORWARD
iptables -A FORWARD -j DOCKER-ISOLATION

# if web server container
#iptables -I FORWARD 2 -m state --state NEW -p tcp --dport 80 -j DOCKER
#iptables -I FORWARD 2 -m state --state NEW -p tcp --dport 443 -j DOCKER

#allow docker com to outside world, amoung itself, and localhost
iptables -A FORWARD -i docker0  -j ACCEPT
iptables -A FORWARD -i lo -o docker0 -j ACCEPT

# accept established com
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j DOCKER

# accept range of trusted ips (ie. local-lan/16,external-ip,another-ip) to forward to DOCKER
iptables -A FORWARD -o docker0 -s $1 -j DOCKER
#send rest to logging and drop
iptables -A FORWARD -j LOGGING

iptables -L FORWARD --verbose


# install persistent iptables
apt-get install -y iptables-persistent
#if changes made after installation, run following again to renew saved state
iptables-save >/etc/iptables/rules.v4
iptables-save >/etc/iptables/rules.v6
#!/usr/bin/env bash
# start other applications first to get dns-lookup

acceptable_IPs="list of comma separated ips"

# Check if the PRE_DOCKER chain exists
iptables -C FORWARD -o docker0 -j PRE_DOCKER
if [ $? -neq 0 ]; then
    # Create the PRE_DOCKER
    iptables -N PRE_DOCKER
fi

#check if LOGGING CHAIN exits
iptables -C INPUT -j LOGGING
if [ $? -neq 0 ]; then
    # Create the LOGGING
    iptables -N LOGGING
fi

# reset iptables
iptables -F

# Default actions
iptables -I INPUT -j LOGGING
iptables -I FORWARD -j LOGGING
iptables -I LOGGING -j DROP
iptables -I LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

#weave
iptables -I INPUT -i docker0 -p tcp --destination-port=6784 -j ACCEPT
iptables -I INPUT -p tcp --dport 6784 -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT
iptables -I INPUT -p tcp --destination-port=6783 -j ACCEPT
iptables -I INPUT -p udp --destination-port=6783 -j ACCEPT
iptables -I INPUT -p udp --destination-port=6784 -j ACCEPT
iptables -I INPUT -p tcp --dport 6783 -i docker0 -s 172.17.0.1 -j LOGGING
iptables -I INPUT -p udp --dport 6783 -i docker0 -s 172.17.0.1 -j LOGGING
iptables -I INPUT -p udp --dport 6784 -i docker0 -s 172.17.0.1 -j LOGGING
#dns for docker
iptables -I INPUT -p udp --dport domain -i docker0 -j ACCEPT
iptables -I INPUT -p tcp --dport domain -i docker0 -j ACCEPT

#accept anything from safe IPs
iptables -I INPUT -s $acceptable_IPs -j ACCEPT


# all established connections
iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

#have docker insert its bridges etc in iptables
service docker restart
sleep 5

# weave
iptables -I FORWARD -i weave -j ACCEPT
iptables -I FORWARD -i docker0 -o weave -j LOGGING


# Default action
iptables -I PRE_DOCKER -j LOGGING

#allow from acceptable ips for db access
iptables -I PRE_DOCKER -i eth0  -s $acceptable_IPs -j ACCEPT

#allow weave
iptables -I PRE_DOCKER -i weave -s   -j ACCEPT

# Docker internal use
iptables -I PRE_DOCKER -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -I PRE_DOCKER -i docker0 ! -o docker0 -j ACCEPT
iptables -I PRE_DOCKER -m state --state RELATED -j ACCEPT
iptables -I PRE_DOCKER -i docker0 -o docker0 -j ACCEPT

iptables -I FORWARD -o docker0 -j PRE_DOCKER

iptables -L -v


# install persistent iptables
apt-get install -y iptables-persistent
#if changes made after installation, run following again to renew saved state
invoke-rc.d iptables-persistent save

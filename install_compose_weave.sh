#! /bin/sh
# use with create_machine.sh

# install compose   check for latest version and replace 1.6.2
sudo curl -L https://github.com/docker/compose/releases/download/1.14.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#install weave
sudo curl -L git.io/weave -o /usr/local/bin/weave
sudo chmod +x /usr/local/bin/weave

#set weave version or use latest
if [ ! -z $WEAVE_VERSION ];then
sed -i "s|SCRIPT_VERSION.*|SCRIPT_VERSION=$WEAVE_VERSION|g" /usr/local/bin/weave
fi

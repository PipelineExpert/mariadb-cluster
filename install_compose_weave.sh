#! /bin/sh
# use with create_machine.sh

# install compose   check for latest version and replace 1.6.2
sudo curl -L https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#install weave
sudo curl -L git.io/weave -o /usr/local/bin/weave
sudo chmod +x /usr/local/bin/weave

# see weave_launch.txt for examples of launching weave with encrypted pipes

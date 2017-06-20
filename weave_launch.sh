#!/bin/sh

# an example script
# if not installed on host
#sudo curl -L git.io/weave -o /usr/local/bin/weave && sudo chmod +x /usr/local/bin/weave

# pass number of nodes for consensus

# following can be left out on new machines, otherwise clears out weave for fresh launch
# eval $(weave env --restore) \
# && weave stop && weave reset --force\

docker-machine ssh node1 "eval $(weave env --restore) \
 && weave stop && weave reset --force\
&& weave launch --ipalloc-init consensus=$1 --ipalloc-range 10.36.0.0/16 --password=yourspecialpassword "

docker-machine ssh node2 "eval $(weave env --restore) \
 && weave stop && weave reset \
&& weave launch --ipalloc-init consensus=$1 --ipalloc-range 10.36.0.0/16 --password=yourspecialpassword "

docker-machine ssh node3 "eval $(weave env --restore) \
 && weave stop && weave reset --force\
&& weave launch --ipalloc-init consensus=$1 --ipalloc-range 10.36.0.0/16 --password=yourspecialpassword "

docker-machine ssh Cluster_Control "eval $(weave env --restore) \
 && weave stop && weave reset --force\
&& weave launch --ipalloc-init observer --ipalloc-range 10.36.0.0/16 --password=yourspecialpassword "

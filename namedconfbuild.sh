#!/bin/sh
#namedconfbuild.sh 
echo "zone \"$1\" {" >> forwardwlist.named
echo "        type forward;" >> forwardwlist.named
echo "        forwarders { 169.254.169.254; };" >> forwardwlist.named
echo "};" >> forwardwlist.json

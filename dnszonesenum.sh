#!/bin/sh
complist=$(oci iam compartment list --all --compartment-id $tenancy_comp --compartment-id-in-subtree true)
complistcur=$(echo $complist | jq .data | jq -r '.[] | ."id"')
rm -f zonelist.log
rm -f named.conf
rm -f forwardwlist.named
for compocid in $complistcur; do echo Listing DNS Zones in $compocid && oci dns zone list --compartment-id $compocid --all --scope PRIVATE --scope PRIVATE --query 'data[?("is-protected")]' | jq -r '.[] | ."name"' >> zonelist.log ; done
zones=$(cat zonelist.log)
for zone in $zones; do echo formating zone $zone && ./named.builder.sh $zone ; done
sed -i 's/169.254.169.254/'$listenerip'/g' forwardwlist.named
cat forwardwlist.named >> $filename
path=$(pwd)
echo $path/$filename

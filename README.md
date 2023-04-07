# oci_dns_zones_forwarder


Get all DNS zones accross all compartents and build a named.conf for a Customer's managed DNS server. 


```
#!/bin/sh
export listenerip="a.b.c.d"
complist=$(oci iam compartment list --all --compartment-id-in-subtree true) 
complistcur=$(echo $complist | jq .data | jq -r '.[] | ."id"')
rm -f zonelist.log
rm -f named.conf
rm -f forwardwlist.named

cat stdnamedconf.ref > named.conf
for compocid in $complistcur; do oci dns zone list --compartment-id $compocid --all --scope PRIVATE | jq .data | jq -r '.[] | ."name"' >> zonelist.log ; done
zones=$(cat zonelist.log) 
for zone in $zones; do ./namedconfbuild.sh $zone ; done 
sed -i 's/169.254.169.254/'$listenerip'/g' forwardwlist.named
cat forwardwlist.named >> named.conf

#\cp -f named.conf /etc/named.conf

```

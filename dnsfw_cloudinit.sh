#!/bin/bash
sudo su
yum install bind -y
systemctl restart named

systemctl mask iptables
systemctl stop iptables
firewall-offline-cmd --zone=public --add-port=53/udp 
firewall-offline-cmd --zone=public --add-port=53/tcp
systemctl restart firewalld

### DNS Vars###
export rootcomp_tenancy_01="ocid1.tenancy."
export listener_tenancy_01_region_01="a.b.c.d"

mkdir /home/opc/autodns

### Create Collector scripts

### Tenancy 01
## Region 01
cat <<EOF >> /home/opc/autodns/named.autoconf.tenant01-region01.sh
#!/bin/sh
#variables 
export listenerip=$listener_tenancy_01_region_01
export tenancy_comp=$rootcomp_tenancy_01
 

complist=\$(oci iam compartment list --all --auth instance_principal --compartment-id \$tenancy_comp --compartment-id-in-subtree true)
complistcur=\$(echo \$complist | jq .data | jq -r '.[] | ."id"')
rm -f /home/opc/autodns/zonelist.log
rm -f /home/opc/autodns/named.conf
rm -f f/home/opc/autodns/forwardwlist.named

cat /home/opc/autodns/stdnamedconf.ref > /home/opc/autodns/named.conf
for compocid in \$complistcur; do oci dns zone list --compartment-id \$compocid --all --auth instance_principal --scope PRIVATE | jq .data | jq -r '.[] | ."name"' >> /home/opc/autodns/zonelist.log ; done
zones=\$(cat /home/opc/autodns/zonelist.log)
for zone in \$zones; do . /home/opc/autodns/named.autoconf.builder.sh \$zone ; done
sed -i 's/169.254.169.254/'\$listenerip'/g' /home/opc/autodns/forwardwlist.named
cat /home/opc/autodns/forwardwlist.named >> /home/opc/autodns/named.conf
\cp -f /home/opc/autodns/named.conf /etc/named.conf
EOF

chmod +x /home/opc/autodns/named.autoconf.tenant01-region01.sh

cat <<EOF >> /home/opc/autodns/named.autoconf.builder.sh
#!/bin/sh
#named.autoconf.builder.sh 
echo "zone \"\$1\" {" >> /home/opc/autodns/forwardwlist.named
echo "        type forward;" >> /home/opc/autodns/forwardwlist.named
echo "        forwarders { 169.254.169.254; };" >> /home/opc/autodns/forwardwlist.named
echo "};" >> /home/opc/autodns/forwardwlist.json
EOF

chmod +x /home/opc/autodns/named.autoconf.builder.sh

cat <<EOF >> /home/opc/autodns/stdnamedconf.ref
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//
// See the BIND Administrator's Reference Manual (ARM) for details about the
// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

options {
        listen-on port 53 { 127.0.0.1; };
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        recursing-file  "/var/named/data/named.recursing";
        secroots-file   "/var/named/data/named.secroots";
        allow-query     { localhost; };

        /*
         - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
         - If you are building a RECURSIVE (caching) DNS server, you need to enable
           recursion.
         - If your recursive DNS server has a public IP address, you MUST enable access
           control to limit queries to your legitimate users. Failing to do so will
           cause your server to become part of large scale DNS amplification
           attacks. Implementing BCP38 within your network would greatly
           reduce such attack surface
        */
        recursion yes;

        dnssec-enable yes;
        dnssec-validation yes;

        /* Path to ISC DLV key */
        bindkeys-file "/etc/named.root.key";

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
        };

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

EOF

echo "*/10 * * * * /home/opc/autodns/named.autoconf.tenant01-region01.sh" |crontab -

. /home/opc/autodns/named.autoconf.tenant01-region01.sh
systemctl restart named

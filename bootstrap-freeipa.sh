#!/bin/sh

VM=`cat /etc/hostname`

printf "\n>>>\n>>> WORKING ON: $VM ...\n>>>\n\n>>>\n>>> (STEP 1/6) Configuring system ...\n>>>\n\n\n"
sleep 5
echo 'root:hortonworks' | chpasswd
timedatectl set-timezone Europe/Berlin
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && service sshd restart
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
echo 0 > /sys/fs/selinux/enforce
yum update
yum install -y ntp net-tools telnet
service ntpd start

printf "\n>>>\n>>> (STEP 2/6) Configuring SSH keys ...\n>>>\n\n"
sleep 5
mkdir /root/.ssh ; cat /sources/ambari/authorized_keys >> /root/.ssh/authorized_keys ; chmod 600 /root/.ssh/authorized_keys

printf "\n>>>\n>>> (STEP 3/6) Installing Ambari Agent ...\n>>>\n\n"
sleep 5
cp /sources/ambari/ambari.repo /etc/yum.repos.d/
yum install -y ambari-agent
sed -i "s/hostname=localhost/hostname=ambari.devops.local/" /etc/ambari-agent/conf/ambari-agent.ini

printf "\n>>>\n>>> (STEP 4/6) Installing FreeIPA Server ...\n>>>\n\n"
sleep 5
yum install -y rng-tools ipa-server ipa-server-dns bind-dyndb-ldap
systemctl start rngd
ipa-server-install --setup-dns<<EOF
freeipa.devops.local
devops.local
DEVOPS.LOCAL
hortonworks
hortonworks
hortonworks
hortonworks
no
no
yes
EOF

printf "\n>>>\n>>> (STEP 5/6) FreeIPA DNS Fix (source: https://pagure.io/freeipa/c/1e912f5b83166154806e0382f3f028d0eac81731) ...\n>>>\n\n"
# Applicable for Python 2.7.* and ipa-server-4.4.*
sleep 5
for LOCATION in client server; do cp -p /sources/freeipa/site-packages/ipa$LOCATION/plugins/dns.py /usr/lib/python2.7/site-packages/ipa$LOCATION/plugins/dns.py; done

printf "\n>>>\n>>> (STEP 6/6) Configuring FreeIPA Server ...\n>>>\n\n"
sleep 5
cp /sources/hosts /etc/hosts
kinit admin<<EOF
hortonworks
EOF
ipa group-add ambari-managed-principals
ipa dnsrecord-add devops.local ambari --a-rec 192.168.144.10
ipa dnsrecord-add devops.local namenode --a-rec 192.168.144.11
ipa dnsrecord-add devops.local datanode --a-rec 192.168.144.12

printf "\n>>>\n>>> Finished bootstrapping $VM\n>>>\n"

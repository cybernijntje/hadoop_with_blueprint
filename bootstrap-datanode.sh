#!/bin/sh

VM=`cat /etc/hostname`

printf "\n>>>\n>>> WORKING ON: $VM ...\n>>>\n\n>>>\n>>> (STEP 1/5) Configuring system ...\n>>>\n\n\n"
sleep 5
echo 'root:hortonworks' | chpasswd
timedatectl set-timezone Europe/Berlin
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
echo 0 > /sys/fs/selinux/enforce
cp /sources/hosts /etc/hosts
yum update
yum install -y ntp net-tools telnet
service ntpd start

printf "\n>>>\n>>> (STEP 2/5) Configuring SSH keys ...\n>>>\n\n"
sleep 5
mkdir /root/.ssh && cat /sources/ambari/authorized_keys >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys

printf "\n>>>\n>>> (STEP 3/5) Installing Ambari Agent ...\n>>>\n\n"
sleep 5
cp /sources/ambari/ambari.repo /etc/yum.repos.d/
yum install -y ambari-agent
sed -i "s/hostname=localhost/hostname=ambari.devops.local/" /etc/ambari-agent/conf/ambari-agent.ini
service ambari-agent start

printf "\n>>>\n>>> (STEP 4/5) Installing & configuring ipa-client ...\n>>>\n\n"
sleep 5
yum install -y ipa-client
ipa-client-install --force-ntpd --domain=devops.local --server=freeipa.devops.local --mkhomedir -p admin@DEVOPS.LOCAL -W --force-join<<EOF
yes
yes
hortonworks
EOF

printf "\n>>>\n>>> (STEP 5/5) Importing Ambari Blueprint  ...\n>>>\n\n"
sleep 5
curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://ambari.devops.local:8080/api/v1/blueprints/devops -d @/sources/ambari/cluster_configuration.json
# !!! URL BELOW HAS /clusters/ INSTEAD OF /blueprints/ !!!
curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://ambari.devops.local:8080/api/v1/clusters/devops -d @/sources/ambari/hostmapping.json

printf "\n>>>\n>>> Finished bootstrapping $VM\n>>>\n\n>>> Ambari is reachable via:\n>>> http://ambari.devops.local:8080\n\n>>> USERNAME: admin\n>>> PASSWORD: admin\n"

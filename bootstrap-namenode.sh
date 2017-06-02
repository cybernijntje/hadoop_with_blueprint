#!/bin/sh

VM=`cat /etc/hostname`

printf "\n>>>\n>>> WORKING ON: $VM ...\n>>>\n\n>>>\n>>> (STEP 1/4) Configuring system ...\n>>>\n\n\n"
sleep 5
echo 'root:hortonworks' | chpasswd
timedatectl set-timezone Europe/Berlin
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
echo 0 > /sys/fs/selinux/enforce
cp /sources/hosts /etc/hosts
yum update
yum install -y ntp net-tools telnet
service ntpd start

printf "\n>>>\n>>> (STEP 2/4) Configuring SSH keys ...\n>>>\n\n"
sleep 5
mkdir /root/.ssh && cat /sources/ambari/authorized_keys >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys

printf "\n>>>\n>>> (STEP 3/4) Installing Ambari Agent ...\n>>>\n\n"
sleep 5
cp /sources/ambari/ambari.repo /etc/yum.repos.d/
yum install -y ambari-agent
sed -i "s/hostname=localhost/hostname=ambari.devops.local/" /etc/ambari-agent/conf/ambari-agent.ini
service ambari-agent start

printf "\n>>>\n>>> (STEP 4/4) Installing & configuring ipa-client ...\n>>>\n\n"
sleep 5
yum install -y ipa-client
ipa-client-install --force-ntpd --domain=devops.local --server=freeipa.devops.local --mkhomedir -p admin@DEVOPS.LOCAL -W --force-join<<EOF
yes
yes
hortonworks
EOF

printf "\n>>>\n>>> Finished bootstrapping $VM\n>>>\n"

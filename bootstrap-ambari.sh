#!/bin/sh

VM=`cat /etc/hostname`

printf "\n>>>\n>>> WORKING ON: $VM ...\n>>>\n\n>>>\n>>> (STEP 1/7) Configuring system ...\n>>>\n\n\n"
sleep 5
echo 'root:hortonworks' | chpasswd
timedatectl set-timezone Europe/Berlin
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
echo 0 > /sys/fs/selinux/enforce
cp /sources/hosts /etc/hosts
yum update
yum install -y ntp net-tools telnet
service ntpd start

printf "\n>>>\n>>> (STEP 2/7) Configuring SSH keys ...\n>>>\n\n"
sleep 5
#ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N ""
#cat /root/.ssh/id_rsa.pub > /sources/$SOURCE/authorized_keys
mkdir /root/.ssh && cp -p /sources/ambari/id_rsa* /root/.ssh/

printf "\n>>>\n>>> (STEP 3/7) Installing Ambari Server 2.4.2.0 ...\n>>>\n\n"
sleep 5
cp /sources/ambari/ambari.repo /etc/yum.repos.d/
yum install -y ambari-server
ambari-server setup -s
service ambari-server start

printf "\n>>>\n>>> (STEP 4/7) Installing & configuring ipa-client ...\n>>>\n\n"
sleep 5
yum install -y ipa-client ipa-admintools
ipa-client-install --force-ntpd --domain=devops.local --server=freeipa.devops.local --mkhomedir -p admin@DEVOPS.LOCAL -W --force-join<<EOF
yes
yes
hortonworks
EOF

printf "\n>>>\n>>> (STEP 5/7) Enabling FreeIPA experimental plugin & Configuring krb5.conf Credential Cache ...\n>>>\n\n"
# If the experimental FreeIPA plugin is not wanted, just comment out the lines in the script (below) 
# and read https://community.hortonworks.com/articles/811/manual-keytab-principal-creation-for-ipa-to-suppor.html
sleep 5
sed -i 's/enableIpa: false/enableIpa: true/' /usr/lib/ambari-server/web/javascripts/app.js
# HDP does not support the in-memory keyring storage of the Kerberos credential cache
# See: https://community.hortonworks.com/questions/11288/kerberos-cache-in-ipa-redhat-idm-keyring-solved.html
sed -i 's/default_ccache_name = KEYRING:persistent:\%{uid}/default_ccache_name = FILE:\/tmp\/krb5cc_\%{uid}/' /etc/krb5.conf
# This can be tested by executing the following command, after authentication (ie. kinit admin):
# [root@ambari ~]# klist
#   klist: Credentials cache keyring 'persistent:0:0' not found
#
# [root@ambari ~]# vi /etc/krb5.conf (change from KEYRING to FILE)
#
# [root@ambari ~]# klist
#   Ticket cache: FILE:/tmp/krb5cc_0
#   Default principal: admin@DEVOPS.LOCAL
#   Valid starting       Expires              Service principal
#   05/31/2017 14:02:40  06/01/2017 14:02:38  krbtgt/DEVOPS.LOCAL@DEVOPS.LOCAL

printf "\n>>>\n>>> (STEP 6/7) Remotely starting Ambari Agent on freeipa.devops.local ...\n>>>\n\n"
sleep 5
ssh -o StrictHostKeychecking=no root@freeipa.devops.local "service ambari-agent start"

printf "\n>>>\n>>> (STEP 7/7) Installing & configuring MariaDB ...\n>>>\n\n"
# Lines below are the requirements to install Ranger
sleep 5
yum install -y mariadb-server mariadb mysql-connector-java
systemctl start mariadb && systemctl enable mariadb
mysql_secure_installation <<EOF

y
hortonworks
hortonworks
y
y
y
y
EOF
mysql -uroot -phortonworks -e 'grant all privileges on *.* to 'root'@'namenode.devops.local' identified by "hortonworks" with grant option;'
mysql -uroot -phortonworks -e 'select user,host from mysql.user;'
ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar

printf "\n>>>\n>>> Finished bootstrapping $VM\n>>>\n"

#!/bin/sh

# udhcp
cp default.script /usr/share/udhcpc/default.script
rm /usr/share/udhcpc/udhcp.txt
chmod 777 /usr/share/udhcpc/default.script

# init.d
cp S88lnode /etc/init.d/S88lnode
chmod 777 /etc/init.d/S88lnode

# bin
ln -s /usr/local/lnode/bin/lnode /usr/sbin/lnode
ln -s /usr/local/lnode/bin/lpm /usr/sbin/lpm
rm -rf /usr/local/bin/

# 
echo "lpm set did xxxxxx"
echo "lpm set password xxxxxx"
echo "echo 'xxxxxx' > /usr/local/lnode/conf/lnode.key"

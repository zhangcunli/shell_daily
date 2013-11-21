#!/bin/sh
#echo -n `/sbin/ifconfig eth0|grep HWaddr|awk '{ print $5}'`

if [ -z "$1" ]
then
    echo -n `/sbin/ifconfig eth0|grep HWaddr|awk '{ print $5 }'`
elif [[ readConf == "$1" && 1 == "$#" ]]
then
    MNGInterface=`cat eth.conf|grep "MNG"`
    ethname=`expr "$MNGInterface" : .*'\(eth.\)'`
    echo -n `/sbin/ifconfig $ethname|grep HWaddr|awk '{ print $5 }'`
else
    echo -n "argument error"
fi

echo

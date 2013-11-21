#!/bin/sh

str=`cat eth.conf |grep "MNG"`
echo $str

echo -n `expr "$str" : .*'\(eth.\)'`
echo

str2=`cat eth.conf |grep "NETWORK_INTERFACE"`
echo $str2
eth=`awk -F'<|>' '{if(NF>3) {print $3} }' eth.conf`
echo $eth
echo


#!/bin/sh

#
#	Script uses Linux Bridge to create an IPv6-only bridge on OpenWRT 15.05
#
#	(Inside LAN)----->eth0.1 (br0) eth1----->(Outside LAN)
#					 (   brouter    )
#
#	Adapted from http://ebtables.netfilter.org/examples/basic.html#ex_brouter
#
#	Sets up Brouter ports eth0 & eth1
#		forwards IPv4 traffic via NAT from interfaces eth0.1 to eth1
#		bridges IPv6 traffic between eth0.1 and eth1
#
#	Requires: ebtables
#
#	Adapted from v6brouter.sh (for generic linux IPv6 brouter)
#
#	TODO: Add status option
#		Add iptables rule to UCI config
#
#
#	Craig Miller 16 February 2016

# BRouter interfaces
# 	INSIDE: is the RFC 1918 Private address
# 	OUTSIDE: is the public IP address
#	BRIDGE: is name of the bridge to create

# change these to match your interfaces
INSIDE=eth0.1
OUTSIDE=eth1
BRIDGE=br-lan

# IPv6 Management address
BRIDGE_IP6=2001:470:1d:583::11

# not used for OpenWRT
# change IPv4 address to match your IPv4 networks
INSIDE_IP=192.168.11.1
OUTSIDE_IP=10.1.1.177

# script version
VERSION=0.97


usage () {
	# show help
	echo "help is here"
	echo "	$0 - sets up brouter to NAT IPv4, and bridge IPv6"
	#echo "	-D    delete brouter, v6bridge, IPv4 NAT config"
	echo "	-R    restore openwrt bridge config"
	echo "	-h    this help"
	echo "  "
	echo " By Craig Miller - Version: $VERSION"
	exit 1
}


# default options values
CLEANUP=0
RESTORE=0
numopts=0
# get args from CLI
while getopts "?hR" options; do
  case $options in
    R ) RESTORE=1
		numopts=$((numopts+1));;
    D ) CLEANUP=1
		numopts=$((numopts+1));;
    d ) DEBUG=1
		numopts=$((numopts+1));;
    h ) usage;;
    \? ) usage	# show usage with flag and no value
         exit 1;;
    * ) usage		# show usage with unknown flag
    	 exit 1;;
  esac
done

# remove the options as cli arguments
shift $(($numopts))

# check that there are no arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi


echo "--- checking for ebtables"
which ebtables
ERR=$?
if [ $ERR -eq 1 ]; then
	echo "ebtables not found, please install, quitting"
	exit 1
fi



# remove previous bridge
old_bridge=$(brctl show | grep $BRIDGE | cut -f 1)
if [ "$old_bridge" = "$BRIDGE" ] && [ $RESTORE -eq 0 ]; then
	echo "-- delete old bridge:$BRIDGE"
	brctl delif $BRIDGE $INSIDE 2> /dev/null
	brctl delif $BRIDGE $OUTSIDE 2> /dev/null
	ip link set $BRIDGE down 2> /dev/null
	brctl delbr $BRIDGE 2> /dev/null
	brctl show
	# remove config
	# remove IPv6 management address to bridge
	ip addr del  $BRIDGE_IP6/64 dev $BRIDGE	
fi

#restore openwrt default bridge, br-lan
if [ $RESTORE -eq 1 ]; then
	echo "-- Restore old bridge:$BRIDGE"
	#brctl delif $BRIDGE $INSIDE 2> /dev/null
	brctl delif $BRIDGE $OUTSIDE 2> /dev/null
	ip link set $BRIDGE down 2> /dev/null
	#brctl delbr $BRIDGE 2> /dev/null
	brctl show

	# remove IPv6 management address to bridge
	ip addr del  $BRIDGE_IP6/64 dev $BRIDGE	2> /dev/null
	# restore original inside management address
	ip addr del  $INSIDE_IP/24 dev $INSIDE
	ifconfig $BRIDGE 0.0.0.0
	ip addr add  $INSIDE_IP/24 dev $BRIDGE
	
	# remove BLOCK_SSH rule from ip6tables /* user rules */
	ip6tables -D  forwarding_rule -m mark --mark 16 -p tcp --dport 22  -j DROP

	# restore IPv4  forward from LAN to WAN
	iptables -D forwarding_rule --in-interface $INSIDE -j ACCEPT
fi


if [ $CLEANUP -eq 1 ] || [ $RESTORE -eq 1 ]; then
	# flush ebtables
	ebtables -F
	ebtables -t broute -F
	ebtables -P FORWARD ACCEPT
	echo "--- cleanup done"
	exit 0
fi

echo "--- configuring v6 bridge"
# add the bridge
brctl addbr $BRIDGE 2> /dev/null
brctl addif $BRIDGE $INSIDE 2> /dev/null
brctl addif $BRIDGE $OUTSIDE
ip link set $BRIDGE down
ip link set $BRIDGE up

brctl show

# configure ebtables to bridge IPv6-only
ebtables -F
# Mark $OUTSIDE packets to be dropped by ip6tables (later)
ebtables -A  FORWARD -p ipv6 -i $OUTSIDE -j mark --set-mark 16 --mark-target CONTINUE
# allow all IPv6 packets to be bridged
ebtables -A FORWARD -p IPV6 -j ACCEPT
ebtables -P FORWARD DROP
ebtables -L

#---- detect mac addresses
INSIDE_MAC=$(ip link show dev $INSIDE | grep link | cut -d " " -f 6)
OUTSIDE_MAC=$(ip link show dev $OUTSIDE | grep link | cut -d " " -f 6)

# add static IPv4 addresses to interfaces
#ip addr flush dev $BRIDGE
ifconfig $BRIDGE 0.0.0.0
#ip addr add $INSIDE_IP/24 dev $INSIDE
#ip addr add $OUTSIDE_IP/24 dev $OUTSIDE
ifconfig $INSIDE $INSIDE_IP netmask 255.255.255.0
ifconfig $OUTSIDE $OUTSIDE_IP netmask 255.255.255.0

echo "--- assigning IPv6 management address $BRIDGE_IP6 to $BRIDGE"
# add IPv6/IPv4 management address to bridge
ip addr add  $BRIDGE_IP6/64 dev $BRIDGE


echo "--- configuring brouter ipv4 interface tables"
# broute table DROP, means forward to higher level stack
ebtables -t broute -F

# send up ARP packets to stack rather than bridging them
ebtables -t broute -A BROUTING -p arp -i $INSIDE -d $INSIDE_MAC -j DROP
ebtables -t broute -A BROUTING -p arp -i $OUTSIDE -d $OUTSIDE_MAC -j DROP

# setup for router - accept all ipv4 packets with our MAC address
ebtables -t broute -A BROUTING -p ipv4 -i $INSIDE -d $INSIDE_MAC -j DROP
ebtables -t broute -A BROUTING -p ipv4 -i $OUTSIDE -d $OUTSIDE_MAC -j DROP

# allow DHCP request to go to stack
ebtables -t broute -A BROUTING -p ipv4 -i $INSIDE -d ff:ff:ff:ff:ff:ff  -j DROP


# show tables
ebtables -t broute -L

# NAT configuration (via iptables) remains unchanged
# IPv4 LAN port moved from $BRIDGE to $INPUT, need rule to forward from LAN to WAN
echo "--- Move NAT input port to $INSIDE with iptables"
iptables -A forwarding_rule --in-interface $INSIDE -j ACCEPT


# Drop inbound SSH from $OUTSIDE interface
echo "--- BLOCK_SSH from $OUTSIDE via ip6tables"
ip6tables -A forwarding_rule -m mark --mark 16 -p tcp --dport 22  -j DROP


# Enable ip6tables for the bridge
echo "--- enable ip6tables firewall for brouter"

sysctl -w net.bridge.bridge-nf-call-ip6tables=1

echo "--- pau"


#!/bin/sh

##################################################################################
#
#  Copyright (C) 2016 Craig Miller
#
#  See the file "LICENSE" for information on usage and redistribution
#  of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#  Distributed under GPLv2 License
#
##################################################################################

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
#	Reworked to simplify non-ipv6 routing, idea from - http://blog.iopsl.com/ipv6-behind-openwrt-router/
#		ebtables -t broute -A BROUTING -i eth1 -p ! ipv6 -j DROP && brctl addif br-lan eth1
#		echo 2 > /proc/sys/net/ipv6/conf/br-lan/accept_ra
#		echo 1 > /proc/sys/net/ipv6/conf/br-lan/forwarding
#
#
#	TODO: 
#		Add iptables rule to UCI config
#		Refine IPv6 Firewall ICMPv6 rules
#
#	Craig Miller 16 February 2016

source /etc/v6brouter.conf

# script version
VERSION=2.0.3

usage () {
	# show help
	echo "help is here"
	echo "	$0 - sets up brouter to NAT IPv4, and bridge IPv6"
	echo "	-E    Enable OpenWRT v6brouter"
	echo "	-R    Restore OpenWRT bridge config"
	echo "	-F    configure v6Bridge firewall (default DROP, except ports configured in /etc/v6brouter.conf)"
	echo "	-s    show status of $0"
	echo "	-h    this help"
	echo "  "
	echo "  Please edit vars in script to match your config:"
	echo "      BRIDGE, WAN_DEV, BRIDGE_IP6"
	echo "  "
	echo " By Craig Miller - Version: $VERSION"
	exit 1
}


# default options values
CLEANUP=0
RESTORE=0
ENABLE=0
FIREWALL=0
STATUS=0
numopts=0

# get args from CLI
while getopts "?hERFs" options; do
	case $options in
		E ) ENABLE=1
			numopts=$((numopts+1));;
		R ) RESTORE=1
			numopts=$((numopts+1));;
		D ) CLEANUP=1
			numopts=$((numopts+1));;
		F ) FIREWALL=1
			numopts=$((numopts+1));;
		s ) STATUS=1
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

# remove the options as CLI arguments
shift $(($numopts))

# check that there are no arguments left to process
if [ $# -ne 0 ]; then
	usage
	exit 1
fi

# check that BRIDGE and WAN_DEV interfaces are defined
# User should have all 5 parameters set, see help
if [ -z $BRIDGE ] || [ -z $WAN_DEV ] ; then
	echo "ERROR: Please set the variables listed below."
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


if [ $STATUS -eq 1 ]; then
	echo "--- checking status of v6Brouter"
	erule=$(ebtables -t broute -L | grep IPv6)
	if [ -z "$erule" ]; then
		echo "    v6brouter: disabled"
	else
		echo "    v6brouter: enabled"
	fi
	exit 0
fi


# restore openwrt default bridge, br-lan
if [ $RESTORE -eq 1 ]; then
	echo "-- Restore old bridge:$BRIDGE"
	brctl delif $BRIDGE $WAN_DEV 2> /dev/null
	ip link set $BRIDGE down 2> /dev/null
	#brctl delbr $BRIDGE 2> /dev/null
	brctl show

	# remove IPv6 management address to bridge
	ip addr del $BRIDGE_IP6/64 dev $BRIDGE 2> /dev/null

	# remove user rules for incoming connections on TCP ports
	if [ -n "${TCP_PORTS}" ]; then
		for port in $TCP_PORTS; do
			ip6tables -D forwarding_rule -m mark --mark 16 -p tcp --dport $port -j ACCEPT 2> /dev/null
		done
	fi

	# remove user rules for incoming connections on UDP ports
	if [ -n "${UDP_PORTS}" ]; then
		for port in $UDP_PORTS; do
			ip6tables -D forwarding_rule -m mark --mark 16 -p udp --dport $port -j ACCEPT 2> /dev/null
		done
	fi

	# remove allow ICMPv6 rule
	ip6tables -D forwarding_rule -m mark --mark 16 -p icmpv6 -j ACCEPT 2> /dev/null
	# remove drop all other packets
	ip6tables -D forwarding_rule -m mark --mark 16 -j DROP 2> /dev/null
	# remove conntrack forwarding rule
	ip6tables -D forwarding_rule -m mark --mark 16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

	echo "-- Disable ip6tables inspection of bridge traffic"
	# disable ip6tables inspection of bridge traffic
	sysctl -w net.bridge.bridge-nf-call-ip6tables=0	2>/dev/null

	# disable RA listen on bridge interface
	echo 1 > /proc/sys/net/ipv6/conf/$BRIDGE/accept_ra

	# restore DHCPv6 server and sending RAs on LAN
	uci set dhcp.lan.ra='server'
	uci set dhcp.lan.dhcpv6='server'
	uci commit

	# restore network
	/etc/init.d/network restart
fi


if [ $CLEANUP -eq 1 ] || [ $RESTORE -eq 1 ]; then

	# Flush ebtables
	ebtables -F
	ebtables -t broute -F
	ebtables -P FORWARD ACCEPT
	echo "--- cleanup done"
	exit 0
fi


# Enable v6brouter OpenWRT
if [ $ENABLE -eq 1 ]; then

	echo "--- configuring v6 bridge"
	# add the bridge
	brctl addbr $BRIDGE 2> /dev/null
	brctl addif $BRIDGE $WAN_DEV
	ip link set $BRIDGE down
	ip link set $BRIDGE up

	brctl show

	# configure ebtables to bridge IPv6-only
	ebtables -F
	result=$?

	# test that ebtables doesn't crash
	if [ $result -ne 0 ]; then
		echo "OOPS: Looks like ebtables crashed, and doesn't work on this router"
		echo "      without ebtables, v6brouter will not work, sorry."
		exit 1
	fi

	if [ $FIREWALL -eq 1 ];then
		# Mark $WAN_DEV packets to be dropped by ip6tables (later)
		ebtables -A FORWARD -p ipv6 -i $WAN_DEV -j mark --set-mark 16 --mark-target CONTINUE
	fi

	# allow all packets to be bridged
	ebtables -P FORWARD ACCEPT
	ebtables -L

	echo "--- Disable IPv6 RA and DHCPv6 Server on LAN"
	uci set dhcp.lan.ra='disabled'
	uci set dhcp.lan.dhcpv6='disabled'
	uci commit
	/etc/init.d/odhcpd restart

	echo "--- assigning IPv6 management address $BRIDGE_IP6 to $BRIDGE"
	# add IPv6/IPv4 management address to bridge
	ip addr add $BRIDGE_IP6/64 dev $BRIDGE
	# enable RA listen to BRIDGE
	echo 2 > /proc/sys/net/ipv6/conf/$BRIDGE/accept_ra

	echo "--- configuring brouter to route everything but IPv6"
	# broute table DROP, means forward to higher level stack
	ebtables -t broute -F
	ebtables -t broute -A BROUTING -i $WAN_DEV -p ! ipv6 -j DROP

	# show tables
	ebtables -t broute -L

	# NAT configuration (via iptables) remains unchanged

	if [ $FIREWALL -eq 1 ]; then
		echo "--- Allow ports from user rules (from $WAN_DEV) via ip6tables, block all others"

		# allow conntrack connections to return data
		ip6tables -I forwarding_rule -m mark --mark 16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

		# allow icmpv6 - for RAs and ND
		ip6tables -A forwarding_rule -m mark --mark 16 -p icmpv6 -j ACCEPT

		# allow incoming connections on TCP ports
		if [ -n "${TCP_PORTS}" ]; then
			for port in $TCP_PORTS; do
				ip6tables -A forwarding_rule -m mark --mark 16 -p tcp --dport $port -j ACCEPT
			done
		fi

		# allow incoming connections on UDP ports
		if [ -n "${UDP_PORTS}" ]; then
			for port in $UDP_PORTS; do
				ip6tables -A forwarding_rule -m mark --mark 16 -p udp --dport $port -j ACCEPT
			done
		fi

		# drop all other IPv6 packets
		ip6tables -A forwarding_rule -m mark --mark 16 -j DROP
		ip6tables -L forwarding_rule

		# Enable ip6tables for the bridge (not required for newer kernels
		echo "--- enable ip6tables firewall for v6Bridge"
		sysctl -w net.bridge.bridge-nf-call-ip6tables=1 2>/dev/null
	fi
	# end of ENABLE
else
	# show user help
	usage
fi

echo "--- pau"

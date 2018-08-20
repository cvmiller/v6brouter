## Synopsis


A shell script to quickly setup an IPv6 brouter on OpenWRT.  A brouter, is part bridge, part router, this script sets up a IPv6 bridge, and an IPv4 NAT router.

There is also a generic version of the script (tested on Ubuntu 14.04 LTS) which in addition to the brouter, also sets up basic IPv4 NAT.


## Motivation

IPv4 NAT is everywhere. From an IPv6 point of view NAT is a cancer which breaks end to end network connectivity. NAT is used from large-scale CGNs (Carrier Grade NAT), to little home routers, down to your cell phone, when you want to turn on a *hotspot*.

With 18,446,744,073,709,551,616 (2^64) potential IPv6 addresses on a LAN segment, there are more than enough addresses to extend the IPv6 network across many of the smaller NAT scenarios.

#### Bridging IPv6, while routing IPv4
By using bridging for IPv6, it just works. The *inside* network is connected transparently (for IPv6) to the *outside* network. Using a v6brouter, allows you to extend the IPv6 network with minimal effort and maximum compatibility, while maintaining current IPv4 NAT-based typologies.

For example, given the router with eth0.1 and eth1 interfaces:
* IPv6: Inside LAN and Outside LAN are one multicast domain or bridged
* IPv4: Inside LAN and Outside LAN are two broadcast domains and routed (via NAT)

![Figure 1](art/brouter.png?raw=true)


```
#	(Inside LAN)----->eth0.1 (br-lan) eth1----->(Outside LAN)
#						 (   brouter    )
```

#### Leveraging Netfilter
The v6brouter script leverages Netfilter heavily, by utilizing `ebtables` (for bridging) and `iptables` (for NAT). Netfilter does all the heavy lifting, and is well optimized code. More information for `ebtables` can be found at [ebtables.netfilter.org](http://ebtables.netfilter.org/examples/basic.html#ex_brouter) with specific brouter examples.

#### Why shell script?
Shell script is easy to read, understand, and execute. The v6brouter shell script is designed to be a working script, as well as a tutorial for those who wish to incorporate the concept of a brouter into their own networks. The OpenWRT included `/bin/sh` works just fine with v6brouter shell script.

#### Version 2
Version 2 has been reworked to address issues with wlan interfaces having different MAC addresses from the LAN (br-lan) interface. It uses a much simpler approach found in [IOPSL's Blog](http://blog.iopsl.com/ipv6-behind-openwrt-router/).

It differs from IOPSL's implementation in that it implements a IPv6 Firewall, which blocks all in-bound IPv6 traffic (except SSH & ICMPv6). To enable the firewall, use the `-F` parameter when starting up `v6brouter_openwrt.sh`.


## Examples

### OpenWRT Support

Because OpenWRT already has `iptables` support for IPv4 NAT, but is lacking --ip-dst extension to `ebtables`, a script has been created specifically for OpenWRT, called `v6brouter_openwrt.sh`. Use the `-R` option to remove v6brouter and *restore* the OpenWRT default bridge configuration.

The script does **not** make any changes to the OpenWRT UCI Configuration. Cycling power to the router will restore your previous configuration. 

If you want the v6brouter configuration to survive reboots:
* Copy script to /root on the router
* In LuCI, System -> Startup -> Local Startup, add: `/root/v6brouter_openwrt.sh -E`

Note: Due to the timing of when interfaces actually become available, you _may_ have to add a `sleep 5;` before the script if you find that v6brouter is _not_ working as expected on reboot.


#### Help
```
root@openwrt:# ./v6brouter_openwrt.sh -h
	./v6brouter_openwrt.sh - sets up brouter to NAT IPv4, and bridge IPv6
	-E    Enable openwrt v6brouter
	-R    Restore openwrt bridge config
	-F    configure v6Bridge FireWall (default DROP, except SSH)
	-s    show status of ./v6brouter_openwrt.sh
	-h    this help

```
#### Running v6brouter_openwrt.sh

```
root@openwrt:# ./v6brouter_openwrt.sh -E
--- checking for ebtables
/usr/sbin/ebtables
--- configuring v6 bridge
brctl: bridge br-lan: Device or resource busy
bridge name     bridge id               STP enabled     interfaces
br-lan          7fff.0024a5d73088       no              eth0.1
                                                        wlan0
                                                        eth1
Bridge table: filter

Bridge chain: INPUT, entries: 0, policy: ACCEPT

Bridge chain: FORWARD, entries: 0, policy: ACCEPT

Bridge chain: OUTPUT, entries: 0, policy: ACCEPT
--- Disable IPv6 RA on LAN
--- assigning IPv6 management address 2001:470:ebbd:0::11 to br-lan
--- configuring brouter to route everything but IPv6
Bridge table: broute

Bridge chain: BROUTING, entries: 1, policy: ACCEPT
-p ! IPv6 -i eth1 -j DROP 
--- pau
```

#### Running v6brouter_openwrt.sh with firewall

```
root@openwrt:# ./v6brouter_openwrt.sh -E -F
--- checking for ebtables
/usr/sbin/ebtables
--- configuring v6 bridge
bridge name     bridge id               STP enabled     interfaces
br-lan          7fff.0024a5d73088       no              eth0.1
                                                        wlan0
                                                        eth1
Bridge table: filter

Bridge chain: INPUT, entries: 0, policy: ACCEPT

Bridge chain: FORWARD, entries: 1, policy: ACCEPT
-p IPv6 -i eth1 -j mark --mark-set 0x10 --mark-target CONTINUE

Bridge chain: OUTPUT, entries: 0, policy: ACCEPT
--- Disable IPv6 RA on LAN
--- assigning IPv6 management address 2001:470:ebbd:0::11 to br-lan
--- configuring brouter to route everything but IPv6
Bridge table: broute

Bridge chain: BROUTING, entries: 1, policy: ACCEPT
-p ! IPv6 -i eth1 -j DROP 
--- ALLOW_SSH from eth1 via ip6tables, block all others
Chain forwarding_rule (1 references)
target     prot opt source               destination         
ACCEPT     tcp      anywhere             anywhere             mark match 0x10 tcp dpt:ssh
ACCEPT     ipv6-icmp    anywhere             anywhere             mark match 0x10
DROP       all      anywhere             anywhere             mark match 0x10
--- enable ip6tables firewall for v6Bridge
net.bridge.bridge-nf-call-ip6tables = 1
--- pau

```
#### Viewing Status of v6brouter

Forgot if the v6brouter is already enabled? No problem a **status** option has been added, which will report *enabled* or *DISABLED*.

```
root@openwrt:# ./v6brouter_openwrt.sh -s
--- checking for ebtables
/usr/sbin/ebtables
--- checking status of v6Brouter
    v6Brouter enabled
```

#### Restoring OpenWRT (by removing v6brouter)

Remove v6brouter config, thus restoring the *normal* OpenWRT operation.

```
root@openwrt:#  ./v6brouter_openwrt.sh -R
--- checking for ebtables
/usr/sbin/ebtables
-- Restore old bridge:br-lan
bridge name     bridge id               STP enabled     interfaces
br-lan          7fff.0024a5d73088       no              eth0.1
                                                        wlan0
-- Disable ip6tables inspection of bridge traffic
net.bridge.bridge-nf-call-ip6tables = 0
--- cleanup done

```

- - -

### Generic v6brouter.sh with IPv4 NAT

The `v6brouter.sh` script can be run multiple times, as it will cleanup before adding bridge elements and rules. Use the -D option when deleting the v6brouter. This script is more of a learning exercise, and active development is on the OpenWRT version.
#### Help

```
$ ./v6brouter.sh -h
	./v6brouter.sh - sets up brouter to NAT IPv4, and bridge IPv6
	-D    delete brouter, v6bridge, IPv4 NAT config
	-h    this help
  
```

#### Running v6brouter.sh

```
~$ sudo ./v6brouter.sh 
--- configuring v6 bridge
bridge name	bridge id		STP enabled	interfaces
br0		8000.9cd643ae1915	no		eth0
							eth1
Bridge table: filter

Bridge chain: INPUT, entries: 0, policy: ACCEPT

Bridge chain: FORWARD, entries: 1, policy: DROP
-p IPv6 -j ACCEPT 

Bridge chain: OUTPUT, entries: 0, policy: ACCEPT
--- configuring brouter ipv4 interface tables
Bridge table: broute

Bridge chain: BROUTING, entries: 8, policy: ACCEPT
-p IPv4 -i eth0 --ip-dst 192.168.11.77 -j DROP 
-p IPv4 -i eth1 --ip-dst 10.1.1.177 -j DROP 
-p ARP -d d4:9a:20:1:e0:a4 -i eth0 -j DROP 
-p ARP -d 9c:d6:43:ae:19:15 -i eth1 -j DROP 
-p ARP -i eth0 --arp-ip-dst 192.168.11.77 -j DROP 
-p ARP -i eth1 --arp-ip-dst 10.1.1.177 -j DROP 
-p IPv4 -d d4:9a:20:1:e0:a4 -i eth0 -j DROP 
-p IPv4 -d 9c:d6:43:ae:19:15 -i eth1 -j DROP 
--- configuring IPv4 NAT
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             anywhere            

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  all  --  anywhere             anywhere            
--- pau
```

#### Deleting v6brouter

```
$ sudo ./v6brouter.sh -D
-- removing old bridge:br0
--- cleanup done 
```



## Installation

Install `ebtables` and `ip` on your OpenWRT router using LuCI or via the command line:

```
# opkg install ebtables
# opkg install ip
```

Copy `v6brouter_openwrt.sh` to your router, edit values (for interfaces, and addresses) near the top of the script and run. 


The following values should be adjusted for your network, and brouter (as of version 2, this is simplified):

```
# change these to match your interfaces
WAN_DEV=eth1
BRIDGE=br-lan

# IPv6 Management address
BRIDGE_IP6=2001:470:1d:583::11
```

## Dependencies

One only needs to install `ebtables` and `ip` packages. It has been tested on Chaos Calmer (v15.05.1) of OpenWRT. (removed `bash` dependency as of v0.97). It may be required to also install `kmod-br-netfilter` if opkg doesn't install it as part of the `ebtables` install.

#### for Ubuntu or general Linux systems

Script requires `ebtables`, `iptables`, `brctl`, `ip` and must be run via `sudo` or as root, as it is making changes to bridging and iptables in kernel space. It has been tested with Ubuntu 14.04 LTS.

It also assumes that two (2) interfaces are available for brouting.


## Limitations



The openwrt version of the script uses the OpenWRT firewall and IPv4 NAT. The script does not change the iptables rules. When using the `-F` option to enable the v6Bridge Firewall, an entry is added to the the ip6tables user chain `forwrding_rule` to drop all *OUTSIDE* IPv6 traffic, except SSH & ICMPv6. ICMPv6 is required for RAs and Neighbour Discovery (ND) to get across the v6Brouter.

When in v6brouter mode, it *is* possible to log into the OpenWRT router via `ssh` from the **outside network**. You *may* wish to add an IPv6 firewall rule to prevent this. 


#### for Ubuntu or general Linux systems

The script assumes /24 IPv4 subnets.

The script does **NOT** configure any firewall. Do not recommend using this for a device directly connected to the internet without first adding firewall rules.

## More Details about ebtables, IPv6-only bridging, and IPv4 routing

`ebtables` is part of [netfilter](http://netfilter.org/), commonly known in Linux as `iptables` and `ip6tables`. `ebtables` however, operates on Layer 2 (think Ethernet layer) rather than Layer 3 (the network layer) of the OSI model.

### Bridging Basics

Bridging is where a device forwards a packet based on the destination MAC address of the packet. A bridge is only useful if it has 2 or more ports. In Linux the `brctl` command is used to assign ports (or interfaces) to the kernel-based bridge.

### EtherTypes

The Ethernet header has the destination MAC, source MAC, and [EtherType](http://www.iana.org/assignments/ieee-802-numbers/ieee-802-numbers.xhtml) fields.The EtherType field can be thought of a *what's next* field, as it signals to the protocol decoder what is the next header is going to be. This is a hexadecimal field, but some common values are:

* **0800** IPv4
* **0806** ARP
* **86DD** IPv6


### Creating an IPv6-only bridge

In order to create an IPv6-only bridge, the bridging device (Linux kernel) needs to filter the packets based on the EtherType field with the value of 0x86DD, and the do the normal destination MAC address lookup.

It is amazingly simple to create an IPv6-only bridge using `ebtables`. `ebtables` has three standard *chains*, INPUT, OUTPUT, and FORWARD. And additionally it has a built-in `broute` chain. In the broute chain, DROP means forward packet to the stack:

```
ebtables -t broute -F
ebtables -t broute -A BROUTING -i $WAN_DEV -p ! ipv6 -j DROP
```

That's it! The first rule says delete all rules in the broute chain. The second rule says, send all non-IPv6 traffic to the stack (to be routed).

### Creating a Brouter is more tricky

As you saw, it is decidedly easy to create an IPv6-only bridge. To create a Brouter, some packets must be bridged, and others must be sent up the stack to be evaluated and forwarded at the Network Layer (3).

`ebtables` has a special chain called *broute* which when packets are *dropped* in this chain, the packets are actually not *dropped* but are sent *up* the stack to be dealt with by the networking layer and above. 

Once the packets are at the network layer, `iptables` can do their magic (using the special *NAT* chain) to mangle the packets for NAT. All the while IPv6 packets have been quietly bridged without the network layer knowing. 



### Creating a bridge firewall

As stated earlier the advantage of a v6Brouter is that it just bridges IPv6 traffic, thus extending the existing IPv6 prefix address space. However, you may not want the upstream network to access your network. The answer is to use a firewall, and `ip6tables` is very capable.

The usual way of creating a firewall is to block traffic from one interface (say the OUTSIDE) and allow traffic from the INSIDE interface. 

However with a brouter, all packets appear to be coming from the BRIDGE interface from **both** directions! And because both sides of the v6Brouter share the same IPv6 prefix, you can't filter based on destination address, or source address. `ebtables` knows the correct ingress/egress interfaces, but can't filter at L3 or L4 (OpenWRT doesn't support filtering L3 with ebtables).

#### So what is a firewall to do?

Fortunately, the netfilter architects created a mechanism for ebtables and ip6tables to communicate, called *mark*. By *marking* a packet at L2 with `ebtables` , the *mark* can be read and acted upon (read: drop) with `ip6tables`. In order to block, say SSH traffic from the OUTSIDE, requires 3 steps:
* Mark all packets from the OUTSIDE interface with a value, say 16 (or 0x10) with `ebtables`
* Filter or DROP packets which have destination port 22 (for SSH) *and* the marked value of 16 with `ip6tables`
* Enable ip6tables to inspect bridged traffic with `sysctl`

At the command line, this looks like:

```
# Mark $OUTSIDE packets to be dropped by ip6tables (later)
ebtables -A  FORWARD -p ipv6 -i $WAN_DEV -j mark --set-mark 16 --mark-target CONTINUE

# allow SSH from the WAN
ip6tables -A forwarding_rule -m mark --mark 16 -p tcp --dport 22  -j ACCEPT
# allow icmpv6 - for RAs and ND
ip6tables -A forwarding_rule -m mark --mark 16 -p icmpv6  -j ACCEPT
# Drop all inbound traffic from $WAN_DEV interface
ip6tables -A forwarding_rule -m mark --mark 16  -j DROP

# Enable ip6tables for the bridge
sysctl -w net.bridge.bridge-nf-call-ip6tables=1
```
Version 0.98 of v6brouter_openwrt.sh now contains this firewall example, enable with **-F** option.

## Contributors

All code by Craig Miller cvmiller at gmail dot com. But ideas, and ports to other embedded platforms beyond OpenWRT are welcome. 


## License

This project is open source, under the GPLv2 license (see [LICENSE](LICENSE))

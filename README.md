## Synopsis

A shell script example to quickly setup an IPv6 brouter. A brouter, is part bridge, part router, this script sets up a IPv6 bridge, and an IPv4 NAT router. 


## Motivation

IPv4 NAT is everywhere. From an IPv6 point of view NAT is a cancer which breaks end to end network connectivity. NAT is used from large-scale CGNs (Carrier Grade NAT), to little home routers, to your cell phone, when you want to turn on a *hotspot*.

With 18,446,744,073,709,551,616 (2^64) potential IPv6 addresses on a LAN segment, there are more than enough addresses to extend the IPv6 network across many of the NAT scenarios.

#### Bridging IPv6, while routing IPv4
By using bridging for IPv6, it just works. The *inside* network is connected transparently (for IPv6) to the *outside* network. Using a v6brouter, allows you to extend the IPv6 network with minimal effort, while maintaining current IPv4 NAT-based typologies.

For example, given the router with eth0 and eth1 interfaces:
* IPv6: Inside LAN and Outside LAN are one multicast domain or bridged
* IPv4: Inside LAN and Outside LAN are two broadcast domains and routed (via NAT)

![](https://raw.githubusercontent.com/cvmiller/v6brouter/master/art/brouter.svg)
<img src="https://raw.githubusercontent.com/cvmiller/v6brouter/master/art/brouter.svg" alt="brouter">


```
#	(Inside LAN)----->eth0 (br0) eth1----->(Outside LAN)
#					 (   brouter    )
```

#### Leveraging Netfilter
The v6brouter script leverages Netfilter heavily, by utilizing `ebtables` (for bridging) and `iptables` (for NAT).Netfilter does all the heavy lifting, and is well optimized code. 

#### Why Bash?
Bash is easy to read, understand, and execute. The v6brouter shell script is designed to be a working script, as well as a tutorial for those who wish to incorporate the concept of a brouter into their own networks.

## Examples

The `v6brouter.sh` script can be run multiple times, as it will cleanup before adding bridge elements and rules. Use the -D option when deleting the v6brouter.

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

Copy `v6brouter.sh` into your directory, edit values (for interfaces, and addresses) near the top of the script and run. 

The following values should be adjusted for your network, and brouter:
```
# change these to match your interfaces
INSIDE=eth0
OUTSIDE=eth1
BRIDGE=br0

# change IPv4 address to match your IPv4 networks
INSIDE_IP=192.168.11.77
OUTSIDE_IP=10.1.1.177
```


## Dependencies

Script requires `ebtables`, `iptables`, `brctl`, `ip` and must be run via `sudo` or as root, as it is making changes to bridging and iptables in kernel space. It has been tested with Ubuntu 14.04 LTS.

It also assumes that two (2) interfaces are available for brouting.

## Limitations

The script assumes /24 IPv4 subnets.

The script does **NOT** configure any firewall. Do not recommend using this for a device directly connected to the internet without first adding firewall rules.

## Contributors

All code by Craig Miller cvmiller at gmail dot com. But ideas, and ports to other languages are welcome. 


## License

This project is open source, under the GPLv2 license (see [LICENSE](LICENSE))

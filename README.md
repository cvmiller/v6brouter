## Synopsis


A shell script to quickly setup an IPv6 brouter on OpenWRT.  A brouter, is part bridge, part router, this script sets up a IPv6 bridge, and an IPv4 NAT router.

There is also a generic version of the script (tested on Ubuntu 14.04 LTS) which in addition to the brouter, also sets up basic IPv4 NAT.


## Motivation

IPv4 NAT is everywhere. From an IPv6 point of view NAT is a cancer which breaks end to end network connectivity. NAT is used from large-scale CGNs (Carrier Grade NAT), to little home routers, to your cell phone, when you want to turn on a *hotspot*.

With 18,446,744,073,709,551,616 (2^64) potential IPv6 addresses on a LAN segment, there are more than enough addresses to extend the IPv6 network across many of the NAT scenarios.

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
The v6brouter script leverages Netfilter heavily, by utilizing `ebtables` (for bridging) and `iptables` (for NAT). Netfilter does all the heavy lifting, and is well optimized code. More information for `ebtables` can be found at [ebtabes.netfilter.org](http://ebtables.netfilter.org/examples/basic.html#ex_brouter) with specifc brouter examples.

#### Why Bash?
Bash is easy to read, understand, and execute. The v6brouter shell script is designed to be a working script, as well as a tutorial for those who wish to incorporate the concept of a brouter into their own networks.

## Examples

### OpenWRT Support

Because OpenWRT already has `iptables` support for IPv4 NAT, but is lacking --ip-dst extension to `ebtabes`, a script has been created specifically for OpenWRT, called `v6brouter_openwrt.sh`. Use the -R option to remove v6brouter and *restore* the OpenWRT default bridge configuration.

The script does **not** make any changes to the OpenWRT UCI Configuration. Cycling power to the router will restore your previous configuration. 

If you want the v6brouter configuration to survive reboots:
* Copy script to /root on the router
* In LuCI, System -> Startup -> Local Startup, add: `/root/v6brouter_openwrt.sh`


#### Help
```
root@openwrt:/tmp# ./v6brouter_openwrt.sh -h
	./v6brouter_openwrt.sh - sets up brouter to NAT IPv4, and bridge IPv6
	-D    delete brouter, v6bridge, IPv4 NAT config
	-R    restore openwrt default bridge config
	-h    this help 
```
#### Running v6brouter_openwrt.sh

```
root@openwrt:/tmp# ./v6brouter_openwrt.sh 
--- checking for ebtables
-- delete old bridge:br-lan
bridge name	bridge id		STP enabled	interfaces
Cannot find device "br-lan"
--- configuring v6 bridge
bridge name	bridge id		STP enabled	interfaces
br-lan		8000.0024a5d73088	no		eth0.1
					            		eth1
brctl: invalid argument 'br-lan' to 'brctl'
Bridge table: filter

Bridge chain: INPUT, entries: 0, policy: ACCEPT

Bridge chain: FORWARD, entries: 1, policy: DROP
-p IPv6 -j ACCEPT 

Bridge chain: OUTPUT, entries: 0, policy: ACCEPT
--- assigning IPv6 management address 2001:470:1d:583::11 to br-lan
--- configuring brouter ipv4 interface tables
Bridge table: broute

Bridge chain: BROUTING, entries: 4, policy: ACCEPT
-p ARP -d 0:24:a5:d7:30:88 -i eth0.1 -j DROP 
-p ARP -d 0:24:a5:d7:30:89 -i eth1 -j DROP 
-p IPv4 -d 0:24:a5:d7:30:88 -i eth0.1 -j DROP 
-p IPv4 -d 0:24:a5:d7:30:89 -i eth1 -j DROP 
--- pau
```

#### Restoring OpenWRT (by removing v6brouter)

```
root@openwrt:/tmp# ./v6brouter_openwrt.sh -R
--- checking for ebtables
-- Restore old bridge:br-lan
bridge name	bridge id		STP enabled	interfaces
br-lan		8000.0024a5d73088	no		eth0.1
--- cleanup done
```

- - -

### Generic v6brouter.sh with IPv4 NAT

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

Install `bash` and `ebtables` on your OpenWRT router.

Copy `v6brouter_openwrt.sh` to your router, edit values (for interfaces, and addresses) near the top of the script and run. 


The following values should be adjusted for your network, and brouter:
```
# change these to match your interfaces
INSIDE=eth0.1
OUTSIDE=eth1
BRIDGE=br-lan

# change IPv4 address to match your IPv4 networks
INSIDE_IP=192.168.11.77
OUTSIDE_IP=10.1.1.177

# IPv6 Management address
BRIDGE_IP6=2001:470:1d:583::11
```

## Dependencies

One only needs to install `bash`, and `ebtables`. It has been tested on Chaos Calmer (v15.05) of OpenWRT.

#### for Ubuntu or general Linux systems

Script requires `ebtables`, `iptables`, `brctl`, `ip` and must be run via `sudo` or as root, as it is making changes to bridging and iptables in kernel space. It has been tested with Ubuntu 14.04 LTS.

It also assumes that two (2) interfaces are available for brouting.


## Limitations

The network connection may be reset when running the script, as interfaces are deleted and added. If this happens, one should be able to re-login using the IPv4 **inside network** address or the IPv6 management address.

The openwrt version of the script uses the OpenWRT firewall and IPv4 NAT. The script does not change the iptables rules. 

That said, when in v6brouter mode, it *is* possible to log into the OpenWRT router via `ssh` from the **outside network**. You *may* wish to add an IPv6 firewall rule to prevent this. 


#### for Ubuntu or general Linux systems

The script assumes /24 IPv4 subnets.

The script does **NOT** configure any firewall. Do not recommend using this for a device directly connected to the internet without first adding firewall rules.


## Contributors

All code by Craig Miller cvmiller at gmail dot com. But ideas, and ports to other embedded platforms beyond OpenWRT are welcome. 


## License

This project is open source, under the GPLv2 license (see [LICENSE](LICENSE))
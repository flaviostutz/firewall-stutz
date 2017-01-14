#INSTRUCTIONS
#In order for this script to overwrite router settings successfully, perform the following steps:
#  1. Connect your computer to the master port of LAN (very important). For example, on RB750 and RB2011, port is ether2
#  2. Connect ssh terminal to admin@192.168.88.1 and execute /system reset-configuration (or reset configuration through reset button)
#  3. After boot, connect to ssh and paste this script contents
#  4. Verify if all steps were accepted
#  5. Reboot router (/system reboot)
#  6. Change your computer cable to ether4 (now it is the lan1-master)
#If boot fails and you lose access to the router, unplug power cable, press reset button, plug it again,
#when USR led starts blinking, release reset button. Connect to default address 192.168.88.1 and try again.
#
# When deploying a new router:
#  - Change WAN1 and WAN2 fixed IPs and gateways
#       - IP->Address set wan1/wan2 to ISP IP
#       - IP->Route change default-gateway for to_ISP1 or to_ISP2 to ISP gateway IP
#  - Change WAN1 NAT 1x1 Asterisk IP (IP->Firewall->NAT)
#  - Add DNS server address of your ISPs (IP->DNS)
#  - Check if [/ip firewall filter] and [/ip firewall mangle] are not duplicated
#       - on some routers there are builtin rules that cannot be deleted and that causes this script to be unable to clear rules before applying new ones. If needed, cleanup manually and execute the filter portion of this script on ssh terminal
#  - Set an admin password (System->users)
#  - Reboot router (sometimes the router doesn't routes packets from lan to wan before rebooting)

#VARIABLES

#WAN SECTION
#for RB750
#:global wan1Interface1 "ether1-wan1"
#for RB2011
:global wan1Interface1 "ether06-wan1"
:global wan1NatOutAddress "179.179.106.164"
:global wan1Address "179.179.106.163/29"
:global wan1Network "179.179.106.160"
:global wan1NetworkMask "179.179.106.160/24"
:global wan1Gateway "179.179.106.161"

#for RB750
#:global wan1Interface2 "ether2-wan1"
#for RB2011
:global wan1Interface2 "ether07-wan1"
:global wan1Interface3 "ether08-wan1"
:global wan1Interface4 "ether09-wan1"

#for RB750
#:global wan2Interface1 "ether3-wan2"
#for RB2011
:global wan2Interface1 "ether10-wan2"
:global wan2NatOutAddress "192.168.1.111"
:global wan2Address "192.168.1.111/24"
:global wan2Network "192.168.1.0"
:global wan2NetworkMask "192.168.1.0/24"
:global wan2Gateway "192.168.1.254"

#LAN SECTION
#for RB750
#:global lan1Interface1 "ether4-lan1"
#for RB2011
:global lan1Interface1 "ether01-lan1"
:global lan1Prefix "10.1.1"
:global lan1Gateway "$lan1Prefix.254"
:global lan1Address "$lan1Gateway/22"
:global lan1Network "$lan1Prefix.0"
#network: 10.1.1.0/22 broadcast: 10.1.3.255

#for RB750
#:global lan1Interface2 "ether5-lan1"
#for RB2011
:global lan1Interface2 "ether02-lan1"
:global lan1Interface3 "ether03-lan1"
:global lan1Interface4 "ether04-lan1"
:global lan1Interface5 "ether05-lan1"

#Asterisk server (nat 1:1 to wan1)
:global asteriskLanIp "10.1.2.5"
:global asteriskPublicIp "179.179.106.164"


#INTERFACE CONFIG
/interface ethernet
#for RB750
#set [ find default-name=ether1 ] name=$wan1Interface1 master-port=none
#set [ find default-name=ether2 ] name=$wan1Interface2 master-port=none
#set [ find default-name=ether3 ] name=$wan2Interface1 master-port=none
#set [ find default-name=ether4 ] name=$lan1Interface1 master-port=none
#set [ find default-name=ether5 ] name=$lan1Interface2 master-port=none
#for RB2011
set [ find default-name=ether1 ]  name=$lan1Interface1 master-port=none
set [ find default-name=ether2 ]  name=$lan1Interface2 master-port=none
set [ find default-name=ether3 ]  name=$lan1Interface3 master-port=none
set [ find default-name=ether4 ]  name=$lan1Interface4 master-port=none
set [ find default-name=ether5 ]  name=$lan1Interface5 master-port=none
set [ find default-name=ether6 ]  name=$wan1Interface1 master-port=none
set [ find default-name=ether7 ]  name=$wan1Interface2 master-port=none
set [ find default-name=ether8 ]  name=$wan1Interface3 master-port=none
set [ find default-name=ether9 ]  name=$wan1Interface4 master-port=none
set [ find default-name=ether10 ] name=$wan2Interface1 master-port=none

/interface bridge
remove [ /interface bridge find ]
add name="wan1"
add name="wan2"
add name="lan1"

/interface bridge port
remove [ /interface bridge port find ]
add bridge=wan1 interface=$wan1Interface1
add bridge=wan1 interface=$wan1Interface2
add bridge=wan1 interface=$wan1Interface3
add bridge=wan1 interface=$wan1Interface4
add bridge=wan2 interface=$wan2Interface1

add bridge=lan1 interface=$lan1Interface1
add bridge=lan1 interface=$lan1Interface2
add bridge=lan1 interface=$lan1Interface3
add bridge=lan1 interface=$lan1Interface4
add bridge=lan1 interface=$lan1Interface5

/ip neighbor discovery
set $wan1Interface1 discover=no
set $wan1Interface2 discover=no
set $wan1Interface3 discover=no
set $wan2Interface1 discover=no


#WAN CONFIG (DUAL GATEWAYS)
/ip address
remove [ /ip address find address=wan1 ]
remove [ /ip address find address=wan2 ]
add address=$wan1Address comment="wan1 - router address" interface=wan1 network=$wan1Network
add address=$asteriskPublicIp comment="wan1 - asterisk nat 1:1" interface=wan1 network=$wan1Network
add address=$wan2Address comment="wan2 - router address" interface=wan2 network=$wan2Network

/ip dhcp-client
remove [ /ip dhcp-client find interface=wan1 ]
remove [ /ip dhcp-client find interface=wan2 ]
#add interface=wan1 disabled=no
#add interface=wan2 disabled=no

/ip firewall mangle
remove [ /ip firewall mangle find ]

#dual wan marks
#add chain=prerouting in-interface=lan1 dst-address=$wan1NetworkMask action=accept
#add chain=prerouting in-interface=lan1 dst-address=$wan2NetworkMask action=accept
#add chain=prerouting in-interface=wan1 connection-mark=no-mark action=mark-connection new-connection-mark=ISP1_conn
#add chain=prerouting in-interface=wan2 connection-mark=no-mark action=mark-connection new-connection-mark=ISP2_conn
#add chain=prerouting in-interface=lan1 connection-mark=no-mark dst-address-type=!local per-connection-classifier=both-addresses:2/0 action=mark-connection new-connection-mark=ISP1_conn
#add chain=prerouting in-interface=lan1 connection-mark=no-mark dst-address-type=!local per-connection-classifier=both-addresses:2/1 action=mark-connection new-connection-mark=ISP2_conn
#add chain=prerouting in-interface=lan1 connection-mark=ISP1_conn action=mark-routing new-routing-mark=to_ISP1
#add chain=prerouting in-interface=lan1 connection-mark=ISP2_conn action=mark-routing new-routing-mark=to_ISP2
#add chain=output connection-mark=ISP1_conn action=mark-routing new-routing-mark=to_ISP1
#add chain=output connection-mark=ISP2_conn action=mark-routing new-routing-mark=to_ISP2

#qos marks
add comment="packets from unlimited network" src-address=10.1.2.0/24 chain=forward action=mark-packet new-packet-mark=qos-unlimited-packets
add comment="packets to unlimited network" dst-address=10.1.2.0/24 chain=forward action=mark-packet new-packet-mark=qos-unlimited-packets
add comment="limited packets for qos" packet-mark=!qos-unlimited-packets chain=forward action=mark-packet new-packet-mark=qos-limited-packets

#add comment="packets from santa maria network" src-address=179.184.85.160/29 chain=forward action=mark-packet new-packet-mark=qos-sm-packets
#add comment="packets to santa maria network" dst-address=179.184.85.160/29 chain=forward action=mark-packet new-packet-mark=qos-sm-packets

/ip route
remove [ /ip route find ]
#add dst-address=0.0.0.0/0 gateway=$wan1Gateway routing-mark=to_ISP1 distance=1 check-gateway=ping
#add dst-address=0.0.0.0/0 gateway=$wan2Gateway routing-mark=to_ISP2 distance=1 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=$wan1Gateway distance=1 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=$wan2Gateway distance=2 check-gateway=ping


#WAN FIREWALL CONFIG
/ip firewall filter
remove [ /ip firewall filter find ]
add chain=input comment="input - accept icmp (ping etc)" protocol=icmp
add chain=input comment="input - enable remote management" dst-port=80 protocol=tcp
add chain=input comment="input - accept ssh" dst-port=22 protocol=tcp
add chain=input comment="input - enable pptp vpn" dst-port=1723 protocol=tcp
add chain=input comment="input - enable pptp vpn" protocol=gre
add chain=input comment="input - accept all established/related packets" connection-state=established,related
add action=drop chain=input comment="input - drop all packets by default wan1" in-interface=wan1 log=yes log-prefix="default drop"
add action=drop chain=input comment="input - drop all packets by default wan2" in-interface=wan2 log=yes log-prefix="default drop"

add chain=forward comment="forward - accept all dst-nat new connections wan1" connection-nat-state=dstnat connection-state=new in-interface=wan1
add chain=forward comment="forward - accept all dst-nat new connections wan2" connection-nat-state=dstnat connection-state=new in-interface=wan2
add chain=forward comment="forward - accept all established/related packets" connection-state=established,related
add action=drop chain=forward comment="forward - drop all packets by default wan1" in-interface=wan1 log=yes log-prefix="default drop"
add action=drop chain=forward comment="forward - drop all packets by default wan2" in-interface=wan2 log=yes log-prefix="default drop"
add action=drop chain=forward comment="forward - drop all packets that are new connections not configured on DST-NAT wan1" connection-nat-state=!dstnat \
    connection-state=new disabled=yes in-interface=wan1
add action=drop chain=forward comment="forward - drop all packets that are new connections not configured on DST-NAT wan2" connection-nat-state=!dstnat \
    connection-state=new disabled=yes in-interface=wan2

#LAN CONFIG
/ip address
remove [ /ip address find address=$lan1Address ]
add address=$lan1Address comment="lan" interface=lan1 network=$lan1Network


#LAN BANDWIDTH LIMITING FOR NON-ASTERISK TRAFFIC (QoS)
/queue simple
remove [ /queue simple find ]
add comment="total allowed bandwidth" name=total-max-bandwidth max-limit=8M/8M target=""
add comment="allowed bandwidth for lan users" name=lan-users parent="total-max-bandwidth" packet-marks=qos-limited-packets max-limit=6M/6M queue=pcq-upload-default/pcq-download-default target=""
#add comment="allowed bandwidth for santa maria hosts" name=santamaria-hosts parent="total-max-bandwidth" packet-marks=qos-sm-packets max-limit=3M/3M queue=pcq-upload-default/pcq-download-default target=""


#LAN DHCP SERVER
/ip pool
remove [ /ip pool find ]
add name=default-dhcp ranges="$lan1Prefix.50-$lan1Prefix.250"

/ip dhcp-server
remove [ /ip dhcp-server find ]
add address-pool=default-dhcp disabled=no interface=lan1 name=default

/ip dhcp-server network
remove [ /ip dhcp-server network find ]
add address="$lan1Network/22" comment="lan" gateway=$lan1Gateway dns-server=$lan1Gateway


#LAN DNS SERVER
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,8.8.4.4

/ip dns static
remove [ /ip dns static find ]
add address=$lan1Gateway name=router


#NAT CONFIGURATIONS
/ip firewall nat
remove [ /ip firewall nat find ]

#NAT 1:1 Asterisk
add chain=srcnat comment="nat 1:1 asterisk" out-interface=wan1 src-address=$asteriskLanIp action=src-nat to-address=$asteriskPublicIp
add chain=dstnat comment="nat 1:1 asterisk" in-interface=wan1 dst-address=$asteriskPublicIp action=dst-nat to-address=$asteriskLanIp

#NAT OUTBOUND
/ip firewall nat
add chain=srcnat comment="outbound nat wan1" out-interface=wan1 action=src-nat to-addresses=$wan1NatOutAddress
add chain=srcnat comment="outbound nat wan2" out-interface=wan2 action=src-nat to-addresses=$wan2NatOutAddress


#SYSTEM TOOLS
/snmp set enabled=yes
/system ntp client set enabled=yes primary-ntp=200.160.0.8 secondary-ntp=200.189.40.8

#pptp vpn
/ppp profile
remove [ /ppp profile find name=pptp-profile ]
add name=pptp-profile local-address=default-dhcp remote-address=default-dhcp bridge=lan1

/ppp secret
remove [ /ppp secret find name=admin ]
add name=admin password="" profile=pptp-profile service=any

/interface pptp-server server
set enabled=yes


#graphing
/tool graphing queue remove [ /tool graphing queue find ]
/tool graphing queue add simple-queue=all
/tool graphing resource remove [ /tool graphing resource find ]
/tool graphing resource add
/tool graphing interface remove [ /tool graphing interface find ]
/tool graphing interface add interface=all

#/tool mac-server
#remove [ /tool mac-server find ]
#set [ find default=yes ] disabled=yes
#add interface=ether4-lan1
#add interface=ether5-lan2

#/tool mac-server mac-winbox
#remove [ /tool mac-server mac-winbox find ]
#set [ find default=yes ] disabled=yes
#add interface=ether4-lan1
#add interface=ether5-lan2

#/romon port
#remove [ /romon port find ]
#add disabled=no interface=ether4-lan1

/

#INSTRUCTIONS
#In order for this script to overwrite router settings successfully, perform the following steps:
#  1. Connect your computer to the master port of LAN (very important). For example, on RB750, default is ether2
#  2. Open terminal and execute /system reset-configuration (or reset configuration through reset button)
#  3. After boot, connect to ssh (admin@192.168.88.1) and paste this script contents
#  4. Verify if all steps were accepted
#  5. Reboot router (/system reboot)
#  6. Change your computer cable to ether4 (now it is the lan1-master)
#If boot fails and you lose access to the router, unplug power cable, press reset button, plug it again,
#when USR led starts blinking, release reset button. Connect to default address 192.168.88.1 and try again.


#VARIABLES
:global wan1Interface "ether1-wan1"
:global wan1Address "10.90.1.111/24"
:global wan1Network "10.90.1.0"
:global wan1NetworkMask "10.90.1.0/24"
:global wan1Gateway "10.90.1.254"

:global wan2Interface "ether2-wan2"
:global wan2Address "10.80.1.111/24"
:global wan2Network "10.80.1.0"
:global wan2NetworkMask "10.80.1.0/24"
:global wan2Gateway "10.80.1.254"

:global wan3Interface "ether3-wan3"
:global wan3Address "192.168.1.111/24"
:global wan3Network "192.168.1.0"
:global wan3Gateway "192.168.1.254"

:global lan1Interface "ether4-lan1"
:global lan1Prefix "10.1.1"
:global lan1Gateway "$lan1Prefix.254"
:global lan1Address "$lan1Gateway/22"
:global lan1Network "$lan1Prefix.0"

:global lan2Interface "ether5-lan2"


#INTERFACE CONFIG
/interface ethernet
set [ find default-name=ether1 ] master-port=none name=$wan1Interface
set [ find default-name=ether2 ] master-port=none name=$wan2Interface
set [ find default-name=ether3 ] master-port=none name=$wan3Interface
set [ find default-name=ether4 ] master-port=none name=$lan1Interface
set [ find default-name=ether5 ] master-port=$lan1Interface name=$lan2Interface

/ip neighbor discovery
set ether1-wan1 discover=no
set ether2-wan2 discover=no
set ether3-wan3 discover=no


#WAN CONFIG (DUAL GATEWAYS)
/ip address
remove [ /ip address find address=$wan1Address ]
remove [ /ip address find address=$wan2Address ]
add address=$wan1Address comment="wan1" interface=$wan1Interface network=$wan1Network
add address=$wan2Address comment="wan2" interface=$wan2Interface network=$wan2Network

/ip dhcp-client
remove [ /ip dhcp-client find interface=$wan1Interface ]
remove [ /ip dhcp-client find interface=$wan2Interface ]
add interface=$wan1Interface disabled=no
add interface=$wan2Interface disabled=no

/ip firewall nat
remove [ /ip firewall nat find ]
add action=masquerade chain=srcnat comment="wan1" out-interface=$wan1Interface
add action=masquerade chain=srcnat comment="wan2" out-interface=$wan2Interface

/ip route
remove [ /ip route find ]
add dst-address=0.0.0.0/0 gateway=$wan1Gateway routing-mark=to_ISP1 distance=1 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=$wan2Gateway routing-mark=to_ISP2 distance=1 check-gateway=ping
#add dst-address=0.0.0.0/0 gateway=$wan1Gateway distance=1 check-gateway=ping
#add dst-address=0.0.0.0/0 gateway=$wan2Gateway distance=1 check-gateway=ping

/ip firewall mangle
remove [ /ip firewall mangle find ]
add chain=prerouting in-interface=$lan1Interface dst-address=$wan1NetworkMask action=accept
add chain=prerouting in-interface=$lan1Interface dst-address=$wan2NetworkMask action=accept
add chain=prerouting in-interface=$wan1Interface connection-mark=no-mark action=mark-connection new-connection-mark=ISP1_conn
add chain=prerouting in-interface=$wan2Interface connection-mark=no-mark action=mark-connection new-connection-mark=ISP2_conn
add chain=prerouting in-interface=$lan1Interface connection-mark=no-mark dst-address-type=!local per-connection-classifier=both-addresses:2/0 action=mark-connection new-connection-mark=ISP1_conn
add chain=prerouting in-interface=$lan1Interface connection-mark=no-mark dst-address-type=!local per-connection-classifier=both-addresses:2/1 action=mark-connection new-connection-mark=ISP2_conn
add chain=prerouting in-interface=$lan1Interface connection-mark=ISP1_conn action=mark-routing new-routing-mark=to_ISP1
add chain=prerouting in-interface=$lan1Interface connection-mark=ISP2_conn action=mark-routing new-routing-mark=to_ISP2
add chain=output connection-mark=ISP1_conn action=mark-routing new-routing-mark=to_ISP1
add chain=output connection-mark=ISP2_conn action=mark-routing new-routing-mark=to_ISP2

add comment="packets from unlimited network" src-address=10.1.2.0/24 chain=forward action=mark-packet new-packet-mark=qos-unlimited-packets
add comment="packets to unlimited network" dst-address=10.1.2.0/24 chain=forward action=mark-packet new-packet-mark=qos-unlimited-packets
add comment="limited packets for qos" packet-mark=!qos-unlimited-packets chain=forward action=mark-packet new-packet-mark=qos-limited-packets

add comment="packets from santa maria network" src-address=179.184.85.160/29 chain=forward action=mark-packet new-packet-mark=qos-sm-packets
add comment="packets to santa maria network" dst-address=179.184.85.160/29 chain=forward action=mark-packet new-packet-mark=qos-sm-packets


#WAN FIREWALL CONFIG
/ip firewall filter
remove [ /ip firewall filter find ]
add chain=input comment="wan" protocol=icmp
add chain=input comment="wan" connection-state=established,related

add chain=forward comment="wan" connection-state=established,related
add action=drop chain=forward comment="wan" connection-state=invalid

add action=drop chain=input comment="wan" in-interface=ether1-wan1
add action=drop chain=input comment="wan" in-interface=ether2-wan2
add action=drop chain=input comment="wan" in-interface=ether3-wan3

add action=drop chain=forward comment="wan" connection-nat-state=!dstnat connection-state=new in-interface=ether1-wan1
add action=drop chain=forward comment="wan" connection-nat-state=!dstnat connection-state=new in-interface=ether2-wan2
add action=drop chain=forward comment="wan" connection-nat-state=!dstnat connection-state=new in-interface=ether3-wan3


#LAN CONFIG
/ip address
remove [ /ip address find address=$lan1Address ]
add address=$lan1Address comment="lan" interface=$lan1Interface network=$lan1Network


#LAN BANDWIDTH LIMITING FOR NON-ASTERISK TRAFFIC (QoS)
/queue simple
remove [ /queue simple find ]
add name=total-max-bandwidth max-limit=8M/8M target=""
add name=lan-users parent="max-bandwidth" packet-marks=qos-limited-packets max-limit=6M/6M queue=pcq-upload-default/pcq-download-default target=""
add name=santamaria-hosts parent="max-bandwidth" packet-marks=qos-sm-packets max-limit=3M/3M queue=pcq-upload-default/pcq-download-default target=""


#LAN DHCP SERVER
/ip pool
remove [ /ip pool find ]
add name=default-dhcp ranges="$lan1Prefix.50-$lan1Prefix.250"

/ip dhcp-server
remove [ /ip dhcp-server find ]
add address-pool=default-dhcp disabled=no interface=$lan1Interface name=default

/ip dhcp-server network
remove [ /ip dhcp-server network find ]
add address="$lan1Network/24" comment="lan" gateway=$lan1Gateway dns-server=$lan1Gateway ntp-server=200.160.0.8


#LAN DNS SERVER
/ip dns
set allow-remote-requests=yes

/ip dns static
remove [ /ip dns static find ]
add address=$lan1Gateway name=router


#SYSTEM TOOLS
/snmp set enabled=yes
/system ntp client set enabled=yes primary-ntp=200.160.0.8 secondary-ntp=200.189.40.8


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

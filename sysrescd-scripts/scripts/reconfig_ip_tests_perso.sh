#!/bin/bash

# Script pour reconfigurer rapidement le reseau pour des tests perso
# quand NetworkManager fiche le bazar
# Derniere modif: 12/10/2016

. /bin/crob_fonctions.sh

echo "
****************************
 Reconfig IP avec acces SSH 
     parametres perso
****************************
"

IP=192.168.1.100
MASK=255.255.255.0
GW=192.168.1.254

GET_INTERFACE_DEFAUT

iface=$(cat /tmp/iface.txt)

/etc/init.d/NetworkManager stop

ifconfig $iface $IP netmask $MASK

route add default gw $GW

echo "# OpenDNS: http://fr.wikipedia.org/wiki/OpenDNS
nameserver 208.67.222.222
nameserver 208.67.220.220
nameserver 208.67.222.220
nameserver 208.67.220.222

# Free
#nameserver 212.27.54.252
#nameserver 212.27.53.252

# Wanadoo:
#nameserver 193.252.19.3
#nameserver 193.252.19.4
" >> /etc/resolv.conf

mkdir -p -m700 /root/.ssh
cp /root/cles_pub_ssh/boireaus.pub /root/.ssh/authorized_keys
/etc/init.d/sshd_crob start

echo "Termine."


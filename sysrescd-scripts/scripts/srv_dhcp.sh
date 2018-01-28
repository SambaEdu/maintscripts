#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read
# Derniere modification: 26/06/2013

source /bin/crob_fonctions.sh

ladate=$(date +"%Y.%m.%d-%H.%M.%S");
tmp=/tmp/$ladate
mkdir $tmp


echo -e "$COLTITRE"
echo "*******************************************"
echo "* Script de mise en place du serveur DHCP *"
echo "*******************************************"

echo -e "$COLINFO"
echo "Ce script permet de mettre en place un serveur DHCP."

POURSUIVRE

echo -e "$COLPARTIE"
echo "==========================="
echo "Configuration IP du serveur"
echo "==========================="

CONFIG_RESEAU

test=$(ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1" | wc -l)
if [ "$test" = "0" ]; then
	echo -e "$COLERREUR"
	echo "La configuration IP semble avoir echoue."
	sleep 2
	exit
else
	OLDIFS=$IFS
	IFS='
'
	lignes_ip=($(ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1"))
	IFS=$OLDIFS
	#if [ "$test" = "1" ]; then
	#	IP=$(ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1" | cut -d":" -f2 | cut -d" " -f1)
	#	BCAST=$(ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1" | cut -d":" -f3 | cut -d" " -f1)
	#	MASK=$(ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1" | cut -d":" -f4 | cut -d" " -f1)
	#else
	#
	#fi

	#DEFIP=$(echo "${lignes_ip[0]}" | cut -d":" -f2 | cut -d" " -f1)
	#	root@sysresccd /root % ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1"
	#			inet 192.168.52.10  netmask 255.255.255.0  broadcast 192.168.52.255
	#	root@sysresccd /root % 
	DEFIP=$(echo "${lignes_ip[0]}" | sed -e "s|^ *||g" | cut -d" " -f2)
	#DEFBCAST=$(echo "${lignes_ip[0]}" | cut -d":" -f3 | cut -d" " -f1)
	#DEFMASK=$(echo "${lignes_ip[0]}" | cut -d":" -f4 | cut -d" " -f1)
	DEFMASK=$(echo "${lignes_ip[0]}" | sed -e "s| \{2,\}| |g" | sed -e "s|^ *||g" | cut -d" " -f4)

	#source /bin/bibliotheque_ip_masque.sh

	#NETWORK=$(calcule_reseau $IP $MASK)
fi


echo -e "$COLPARTIE"
echo "=========================="
echo "Parametres du serveur DHCP"
echo "=========================="

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo -e "Quelle est l'adresse IP du serveur? [${COLDEFAUT}${DEFIP}${COLTXT}] ${COLSAISIE}\c"
	read IP

	if [ -z "$IP" ]; then
		IP=$DEFIP
	fi

	echo -e "$COLTXT"
	echo -e "Quel est le masque? [${COLDEFAUT}${DEFMASK}${COLTXT}] ${COLSAISIE}\c"
	read MASK

	if [ -z "$MASK" ]; then
		MASK=$DEFMASK
	fi

	source /bin/bibliotheque_ip_masque.sh
	DEFNET=$(calcule_reseau $IP $MASK)
	DEFBCAST=$(calcule_broadcast $IP $MASK)

	# On ne propose pas de modifier...
	NETWORK=$DEFNET
	BROADCAST=$DEFBCAST

	tmpip1=$(echo $IP | cut -d"." -f1)
	tmpip2=$(echo $IP | cut -d"." -f2)
	tmpip3=$(echo $IP | cut -d"." -f3)
	tmpip4=$(echo $IP | cut -d"." -f4)

	if [ -e "/tmp/GW.txt" ]; then
		DEFGW=$(cat /tmp/GW.txt)
	else
		if [ "$MASK" = "255.255.0.0" ]; then
			DEFGW="$tmpip1.$tmpip2.164.1"
		else
			DEFGW="$tmpip1.$tmpip2.$tmpip3.1"
		fi
	fi

	echo -e "$COLTXT"
	echo -e "Quelle est l'adresse de la passerelle? [${COLDEFAUT}${DEFGW}${COLTXT}] ${COLSAISIE}\c"
	read GW

	if [ -z "$GW" ]; then
		GW=$DEFGW
	fi

	test=$(grep "^nameserver " /etc/resolv.conf | sed -e "s/^nameserver //" | wc -l)
	if [ "$test" != "0" ]; then
		LISTE_DNS=($(grep "^nameserver " /etc/resolv.conf | sed -e "s/^nameserver //"))
		DEFDNS=${LISTE_DNS[0]}
	else
		DEFDNS="${DNS_ACAD}"
	fi

	echo -e "$COLTXT"
	echo -e "Quelle est l'adresse du serveur DNS? [${COLDEFAUT}${DEFDNS}${COLTXT}] ${COLSAISIE}\c"
	read DNS

	if [ -z "$DNS" ]; then
		DNS=$DEFDNS
	fi

	echo ""
	echo -e "${COLINFO}Récapitulatif sur l'identité du serveur DHCP:${COLTXT}"
	echo -e "IP:         ${COLINFO}${IP}${COLTXT}"
	echo -e "Masque:     ${COLINFO}${MASK}${COLTXT}"
	echo -e "Passerelle: ${COLINFO}${GW}${COLTXT}"
	echo -e "DNS:        ${COLINFO}${DNS}${COLTXT}"

	POURSUIVRE_OU_CORRIGER "1"
done




tmpval=$(($tmpip4+1))
if [ $tmpval -lt 249 ]; then
	DEFDHCP1=$tmpip1.$tmpip2.$tmpip3.$tmpval
	DEFDHCP2=$tmpip1.$tmpip2.$tmpip3.249
else
	tmpval=$(($tmpip4-1))
	DEFDHCP1=$tmpip1.$tmpip2.$tmpip3.2
	DEFDHCP2=$tmpip1.$tmpip2.$tmpip3.$tmpval
fi

echo -e "$COLINFO"
echo "Definition de la plage IP proposee pour le DHCP."

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo -e "Quelle est la premiere adresse a proposer? [${COLDEFAUT}${DEFDHCP1}${COLTXT}] ${COLSAISIE}\c"
	read DHCP1

	if [ -z "$DHCP1" ]; then
		DHCP1=$DEFDHCP1
	fi

	echo -e "$COLTXT"
	echo -e "Quelle est la derniere adresse a proposer? [${COLDEFAUT}${DEFDHCP2}${COLTXT}] ${COLSAISIE}\c"
	read DHCP2

	if [ -z "$DHCP2" ]; then
		DHCP2=$DEFDHCP2
	fi

	echo ""
	echo -e "${COLINFO}Récapitulatif sur la plage DHCP:${COLTXT}"
	echo -e "Premiere IP de la plage DHCP: ${COLINFO}${DHCP1}${COLTXT}"
	echo -e "Derniere IP de la plage DHCP: ${COLINFO}${DHCP2}${COLTXT}"

	POURSUIVRE_OU_CORRIGER "1"
done

echo -e "$COLINFO"
echo "Generation du fichier de configuration DHCP..."
echo -e "$COLCMD\c"
if [ -e /etc/dhcp/dhcpd.conf ]; then
	cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.${ladate}
fi

echo "#
# DHCP Server Configuration file.
#   see /usr/share/doc/dhcp*/dhcpd.conf.sample
#

ddns-update-style interim;
ignore client-updates;

subnet $NETWORK netmask $MASK {

        option routers $GW;
        option subnet-mask $MASK;
        option domain-name-servers $DNS;

        range dynamic-bootp $DHCP1 $DHCP2;
        default-lease-time 21600;
        max-lease-time 43200;

        # if we want to define an IP address for a mac address
        #host pxeclient {
        #        hardware ethernet      00:1C:C4:43:10:86;
        #        fixed-address          192.168.1.86;
        #}
}

#allow booting;
#allow bootp;
#next-server $IP; # IP addr of the TFTP server
" > /etc/dhcp/dhcpd.conf
echo '
#class "pxeclients" {
#   match if substring(option vendor-class-identifier, 0, 9) = "PXEClient";
#   filename "/pxelinux.0";
#}
' >> /etc/dhcp/dhcpd.conf


echo -e "$COLPARTIE"
echo "===================="
echo "Demarrage du serveur"
echo "===================="

if ps aux | grep "/usr/sbin/dhcpd" > /dev/null; then
	echo -e "$COLINFO"
	echo "Re-demarrage..."
	echo -e "$COLCMD\c"
	/etc/init.d/dhcpd restart
	#/etc/init.d/dhcpd_crob restart
else
	echo -e "$COLINFO"
	echo "Demarrage..."
	echo -e "$COLCMD\c"
	/etc/init.d/dhcpd start
	#/etc/init.d/dhcpd_crob start
fi

echo -e "${COLTITRE}"
echo "***********"
echo "* Termine *"
echo "***********"
echo -e "${COLTXT}"
read PAUSE < /dev/tty


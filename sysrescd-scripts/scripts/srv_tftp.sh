#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read
# Derniere modification: 25/06/2013

source /bin/crob_fonctions.sh

ladate=$(date +"%Y.%m.%d-%H.%M.%S");
tmp=/tmp/$ladate
mkdir $tmp

pxebootsrv="pxebootsrv"
if [ -n "$1" ]; then
	if [ "$1" = "perso" ]; then
		pxebootsrv="pxebootsrv_perso"
	fi
fi

# On force:
pxebootsrv="pxebootsrv_perso"

echo -e "$COLTITRE"
echo "*******************************************"
echo "* Script de mise en place du serveur TFTP *"
echo "*******************************************"

echo -e "$COLINFO"
echo "Ce script permet de mettre en place un serveur DHCP/TFTP pour"
echo "permettre de booter sur SysRescCD en PXE sur des clients."
echo -e "Les clients doivent disposer d'au moins ${COLERREUR}300Mo de RAM${COLINFO} sans quoi"
echo "le téléchargement et la décompression du sysrcd.dat échouent."
echo ""
echo "Cela fonctionne bien si le SysRescCD peut être configuré comme le seul serveur"
echo "DHCP sur le réseau (ou alors il faudrait désigner le SysRescCD comme"
echo "next-server sur les autres serveurs DHCP)."

POURSUIVRE

echo -e "$COLPARTIE"
echo "==========================="
echo "Configuration IP du serveur"
echo "==========================="

# On recommande l'IP fixe... pour pouvoir faire serveur DHCP
echo "mode=ip_fixe" > /tmp/proposer_ip_statique.txt
CONFIG_RESEAU
rm /tmp/proposer_ip_statique.txt

test=$(ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1" | wc -l)
if [ "$test" = "0" ]; then
	echo -e "$COLERREUR"
	echo "La configuration IP semble avoir échoué."
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

	#	root@sysresccd /root % ifconfig | grep inet | grep -v "inet6" | grep -v "127.0.0.1"
	#			inet 192.168.52.10  netmask 255.255.255.0  broadcast 192.168.52.255
	#	root@sysresccd /root % 

	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		DEFIP=$(echo "${lignes_ip[0]}" | cut -d":" -f2 | cut -d" " -f1)
		#DEFBCAST=$(echo "${lignes_ip[0]}" | cut -d":" -f3 | cut -d" " -f1)
		DEFMASK=$(echo "${lignes_ip[0]}" | cut -d":" -f4 | cut -d" " -f1)
	else
		DEFIP=$(echo "${lignes_ip[0]}" | sed -e "s|^ *||" | cut -d" " -f2)
		DEFMASK=$(echo "${lignes_ip[0]}" | sed -e "s|.*netmask ||" | cut -d" " -f1)
	fi
	#source /bin/bibliotheque_ip_masque.sh

	#NETWORK=$(calcule_reseau $IP $MASK)
fi


echo -e "$COLPARTIE"
echo "=========================="
echo "Parametres du serveur TFTP"
echo "=========================="

echo -e "$COLINFO"
echo "Si vous disposez d'un autre serveur DHCP sur le réseau, il convient d'ajouter"
echo "à sa configuration une ligne"
echo "   next-server IP_SYSRESCCD;"

REPDHCPSRV=""
while [ "$REPDHCPSRV" != "1" -a "$REPDHCPSRV" != "2" ]
do
	echo -e "$COLTXT"
	echo -e "SysRescCD doit-il faire serveur DHCP (${COLCHOIX}1${COLTXT})"
	echo -e "ou disposez-vous d'un autre serveur DHCP sur le réseau (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
	read REPDHCPSRV

	if [ -z "$REPDHCPSRV" ]; then
		REPDHCPSRV=1
	fi
done

if [ "${REPDHCPSRV}" = "1" ]; then

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		VALIDE="n"
		while [ "$VALIDE" != "y" ]
		do
			echo -e "$COLTXT"
			echo -e "Quelle est l'adresse IP du serveur? [${COLDEFAUT}${DEFIP}${COLTXT}] ${COLSAISIE}\c"
			read IP

			if [ -z "$IP" ]; then
				IP=$DEFIP
			fi

			#echo -e "$COLTXT"
			#echo -e "Vous avez choisi ${COLINFO}${IP}"

			t=$(CHECK_IP $IP)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "IP non valide: '$IP'"
				VALIDE="n"
			else
				VALIDE="y"
			fi
		done

		VALIDE="n"
		while [ "$VALIDE" != "y" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel est le masque? [${COLDEFAUT}${DEFMASK}${COLTXT}] ${COLSAISIE}\c"
			read MASK

			if [ -z "$MASK" ]; then
				MASK=$DEFMASK
			fi

			MASK=$(CLEAN_IP $MASK)

			#echo -e "$COLTXT"
			#echo -e "Vous avez choisi ${COLINFO}${MASK}"

			t=$(CHECK_IP $MASK)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "Non valide: '$MASK'"
				VALIDE="n"
			else
				VALIDE="y"
			fi
		done

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

		VALIDE="n"
		while [ "$VALIDE" != "y" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel est l'adresse de la passerelle? [${COLDEFAUT}${DEFGW}${COLTXT}] ${COLSAISIE}\c"
			read GW

			if [ -z "$GW" ]; then
				GW=$DEFGW
			fi

			GW=$(CLEAN_IP $GW)

			#echo -e "$COLTXT"
			#echo -e "Vous avez choisi ${COLINFO}${GW}"

			t=$(CHECK_IP $GW)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "IP non valide: '$GW'"
				VALIDE="n"
			else
				VALIDE="y"
			fi
		done


		test=$(grep "^nameserver " /etc/resolv.conf | sed -e "s/^nameserver //" | wc -l)
		if [ "$test" != "0" ]; then
			LISTE_DNS=($(grep "^nameserver " /etc/resolv.conf | sed -e "s/^nameserver //"))
			DEFDNS=${LISTE_DNS[0]}
		else
			DEFDNS="${DNS_ACAD}"
		fi

		VALIDE="n"
		while [ "$VALIDE" != "y" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel est l'adresse du serveur DNS? [${COLDEFAUT}${DEFDNS}${COLTXT}] ${COLSAISIE}\c"
			read DNS

			if [ -z "$DNS" ]; then
				DNS=$DEFDNS
			fi

			DNS=$(CLEAN_IP $DNS)

			#echo -e "$COLTXT"
			#echo -e "Vous avez choisi ${COLINFO}${DNS}"

			t=$(CHECK_IP $DNS)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "IP non valide: '$DNS'"
				VALIDE="n"
			else
				VALIDE="y"
			fi
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
		echo "Definition de la plage IP proposée pour le DHCP."

		VALIDE="n"
		while [ "$VALIDE" != "y" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel est la premiere adresse à proposer? [${COLDEFAUT}${DEFDHCP1}${COLTXT}] ${COLSAISIE}\c"
			read DHCP1

			if [ -z "$DHCP1" ]; then
				DHCP1=$DEFDHCP1
			fi

			DHCP1=$(CLEAN_IP $DHCP1)

			#echo -e "$COLTXT"
			#echo -e "Vous avez choisi ${COLINFO}${DHCP1}"

			t=$(CHECK_IP $DHCP1)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "IP non valide: '$DHCP1'"
				VALIDE="n"
			else
				VALIDE="y"
			fi
		done

		VALIDE="n"
		while [ "$VALIDE" != "y" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel est la derniere adresse à proposer? [${COLDEFAUT}${DEFDHCP2}${COLTXT}] ${COLSAISIE}\c"
			read DHCP2

			if [ -z "$DHCP2" ]; then
				DHCP2=$DEFDHCP2
			fi

			DHCP2=$(CLEAN_IP $DHCP2)

			#echo -e "$COLTXT"
			#echo -e "Vous avez choisi ${COLINFO}${DHCP2}"


			t=$(CHECK_IP $DHCP2)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "IP non valide: '$DHCP2'"
				VALIDE="n"
			else
				VALIDE="y"
			fi
		done

		echo -e "${COLINFO}Recapitulatif:${COLTXT}"
		echo -e "IP:                           ${COLINFO}${IP}${COLTXT}"
		echo -e "Masque:                       ${COLINFO}${MASK}${COLTXT}"
		echo -e "Passerelle:                   ${COLINFO}${GW}${COLTXT}"
		echo -e "DNS:                          ${COLINFO}${DNS}${COLTXT}"
		echo -e "Premiere IP de la plage DHCP: ${COLINFO}${DHCP1}${COLTXT}"
		echo -e "Derniere IP de la plage DHCP: ${COLINFO}${DHCP2}${COLTXT}"

		POURSUIVRE_OU_CORRIGER "1"
	done

	echo -e "$COLINFO"
	echo "Génération du fichier de configuration TFTP..."
	echo -e "$COLCMD\c"
	cp /etc/conf.d/pxebootsrv /etc/conf.d/pxebootsrv.${ladate}
	echo '# ------------------------ CONFIGURATION -------------------------------
# By default the current systems acts as DHCP and TFTP and HTTP server
# If you want another machine of you network to act as one of those
# you will have to turn the appropriate option yo "no"

# Set to "yes" if you want this machine to act as a DHCP server
PXEBOOTSRV_DODHCPD="yes"
# Set to "yes" if you want this machine to act as a TFTP server
PXEBOOTSRV_DOTFTPD="yes"
# Set to "yes" if you want this machine to act as an HTTP server
PXEBOOTSRV_DOHTTPD="yes"
# Set to "yes" if you want this machine to act as an NFS server
PXEBOOTSRV_DONFSD="no"
# Set to "yes" if you want this machine to act as an NBD server
PXEBOOTSRV_DONBD="no"

# Here is a typical PXE-Boot configuration --> update with your settings
PXEBOOTSRV_SUBNET="'${NETWORK}'"                    # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_NETMASK="'${MASK}'"                 # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_DEFROUTE="'${GW}'"                # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_DNS="'${DNS}'"                     # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_DHCPRANGE="'${DHCP1}' '${DHCP2}'" # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_LOCALIP="'${IP}'"

# Keep these values to $PXEBOOTSRV_LOCALIP if the current computer
# acts as TFTP server and HTTP server as well as DHCP server
PXEBOOTSRV_TFTPSERVER="$PXEBOOTSRV_LOCALIP"        # IP address of the TFTP server if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_HTTPSERVER="http://$PXEBOOTSRV_LOCALIP/sysrcd.dat" # download URL

# Set a low value to boot faster. Default, wait 900 deciseconds (1min30sec)
PXEBOOTSRV_TIMEOUT="50"                           # Used only if PXEBOOTSRV_DOTFTPD="yes"
# You can append extra parameters such as "rootpass=xxx" or "ar_source=xxx"
PXEBOOTSRV_EXTRA=""                               # Used only if PXEBOOTSRV_DOTFTPD="yes"
' > /etc/conf.d/pxebootsrv
else

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
		echo -e "Vous avez choisi ${COLINFO}${IP}"

		t=$(CHECK_IP $IP)
		if [ -z "$t" ]; then
			echo -e "$COLERREUR"
			echo "IP non valide: '$IP'"
		else
			POURSUIVRE_OU_CORRIGER "1"
		fi
	done

	echo -e "$COLINFO"
	echo "Génération du fichier de configuration TFTP..."
	echo -e "$COLCMD\c"
	cp /etc/conf.d/pxebootsrv /etc/conf.d/pxebootsrv.${ladate}
	echo '# ------------------------ CONFIGURATION -------------------------------
# By default the current systems acts as DHCP and TFTP and HTTP server
# If you want another machine of you network to act as one of those
# you will have to turn the appropriate option yo "no"

# Set to "yes" if you want this machine to act as a DHCP server
PXEBOOTSRV_DODHCPD="no"
# Set to "yes" if you want this machine to act as a TFTP server
PXEBOOTSRV_DOTFTPD="yes"
# Set to "yes" if you want this machine to act as an HTTP server
PXEBOOTSRV_DOHTTPD="yes"
# Set to "yes" if you want this machine to act as an NFS server
PXEBOOTSRV_DONFSD="no"
# Set to "yes" if you want this machine to act as an NBD server
PXEBOOTSRV_DONBD="no"

# Here is a typical PXE-Boot configuration --> update with your settings
PXEBOOTSRV_SUBNET="192.168.1.0"                    # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_NETMASK="255.255.255.0"                 # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_DEFROUTE="192.168.1.254"                # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_DNS="192.168.1.254"                     # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_DHCPRANGE="192.168.1.100 192.168.1.150" # Used only if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_LOCALIP="'${IP}'"

# Keep these values to $PXEBOOTSRV_LOCALIP if the current computer
# acts as TFTP server and HTTP server as well as DHCP server
PXEBOOTSRV_TFTPSERVER="$PXEBOOTSRV_LOCALIP"        # IP address of the TFTP server if PXEBOOTSRV_DODHCPD="yes"
PXEBOOTSRV_HTTPSERVER="http://$PXEBOOTSRV_LOCALIP/sysrcd.dat" # download URL

# Set a low value to boot faster. Default, wait 900 deciseconds (1min30sec)
PXEBOOTSRV_TIMEOUT="50"                           # Used only if PXEBOOTSRV_DOTFTPD="yes"
# You can append extra parameters
PXEBOOTSRV_EXTRA=""                               # Used only if PXEBOOTSRV_DOTFTPD="yes"
' > /etc/conf.d/pxebootsrv
fi

# Le script ajout� /etc/init.d/pxebootsrv_perso fait semble-t-il appel aux variables de /etc/conf.d/pxebootsrv_perso bien que dans le fichier, il soit fait r�f�rence � /etc/conf.d/pxebootsrv
cd /etc/conf.d
if [ -e pxebootsrv_perso ]; then
	rm -f pxebootsrv_perso
fi
ln -s pxebootsrv pxebootsrv_perso
# Dans le /etc/init.d/pxebootsrv_perso, j'ai ajout�:
#			#=================================
#			# /tftpboot/pxelinux.cfg/default
#			echo "label cp
#	kernel rescuecd
#	append scandelay=5 netboot=$PXEBOOTSRV_HTTPSERVER initrd=initram.igz video=ofonly setkmap=fr work=cli_partimaged.sh ip_serveur_partimaged=$PXEBOOTSRV_LOCALIP
#	" >> /tftpboot/pxelinux.cfg/default
#			#=================================

if [ ! -e "/tftpboot/pxelinux.cfg/default" ]; then
	mkdir -p /tftpboot/pxelinux.cfg
	echo '

' > /tftpboot/pxelinux.cfg/default
fi

cd /root

# PROBLEME: Cela déborde
#cp -r ${mnt_cdrom}/isolinux/linux /tftpboot/
#cp -r ${mnt_cdrom}/isolinux/bootdos /tftpboot/
#cp -r ${mnt_cdrom}/isolinux/maps /tftpboot/
mkdir -p /tftpboot/maps
if [ -e ${mnt_cdrom}/isolinux/maps/fr.ktl ]; then
	cp -r ${mnt_cdrom}/isolinux/maps/fr.ktl /tftpboot/maps/
elif [ -e ${mnt_cdrom}/syslinux/maps/fr.ktl ]; then
	cp -r ${mnt_cdrom}/syslinux/maps/fr.ktl /tftpboot/maps/
fi

echo -e "$COLPARTIE"
echo "========================="
echo "Démarrage du serveur TFTP"
echo "========================="

echo -e "$COLCMD\c"
touch /tmp/pxebootsrv_old_way

if ps aux | grep "/usr/sbin/in.tftpd" > /dev/null; then
	echo -e "$COLINFO"
	echo "Re-démarrage..."
	echo -e "$COLCMD\c"
	/etc/init.d/$pxebootsrv restart
else
	echo -e "$COLINFO"
	echo "Démarrage..."
	echo -e "$COLCMD\c"
	/etc/init.d/$pxebootsrv start
fi

#if [ ! -e "/tftpboot/linux/udpcast/vmlu26" ]; then
#	mkdir -p /tftpboot/linux/udpcast
#	cp ${mnt_cdrom}/isolinux/linux/udpcast/* /tftpboot/linux/udpcast/
#fi
echo -e "$COLTXT"
echo "Copie des images de boot Linux et Bootdos"
echo -e "$COLCMD\c"
mkdir -p /tftpboot/
if [ -e ${mnt_cdrom}/isolinux/linux ]; then
	cp -r ${mnt_cdrom}/isolinux/linux /tftpboot/
elif [ -e ${mnt_cdrom}/syslinux/linux ]; then
	cp -r ${mnt_cdrom}/syslinux/linux /tftpboot/
fi
if [ -e ${mnt_cdrom}/isolinux/bootdos ]; then
	cp -r ${mnt_cdrom}/isolinux/bootdos /tftpboot/
elif [ -e ${mnt_cdrom}/syslinux/bootdos ]; then
	cp -r ${mnt_cdrom}/syslinux/bootdos /tftpboot/
fi

# Mettre en place des pages F1, F2,... allégées.



echo -e "${COLTITRE}"
echo "***********"
echo "* Terminé *"
echo "***********"
echo -e "${COLTXT}"
if [ "$1" != "perso" ]; then
	read PAUSE < /dev/tty
fi


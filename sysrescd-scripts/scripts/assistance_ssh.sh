#!/bin/bash

# Script de config pour assistance SSH
# Derniere modification: 14/04/2014

source /bin/crob_fonctions.sh
source /bin/bibliotheque_ip_masque.sh

echo -e "$COLTITRE"
echo "*******************************"
echo "* Script de configuration SSH *"
echo "*  pour assistance distante   *"
echo "*******************************"

echo -e "$COLTXT"
echo "Lecture de /proc/cmdline"

tmp=/tmp/root
mkdir -p -m 700 ${tmp}
fich_proc_cmdline=$tmp/fichier_cmdline.$(date +%Y%m%d%H%M%S).txt
#echo "root=/dev/sda5 ro ip=10.127.164.5 mask=255.255.0.0 truc cle_ssh=boireaus,mollef chose=a" > $fichtest

mkdir -p /root/.ssh

cat /proc/cmdline | sed -e "s/ /\n/g" > $fich_proc_cmdline

if [ -e "${mnt_cdrom}/sysresccd/liste_rne.csv" ]; then
	# Fichier au format:
	# RNE;IP;MASQUE;GW;DNS
	if grep -q -i "rne=" /proc/cmdline; then
		#sed -e "s| |\n|g" /proc/cmdline|while read A
		while read A
		do
			if [ "${A:0:4}" = "rne=" ]; then
				ligne=$(grep -i "^${A:4};" ${mnt_cdrom}/sysresccd/liste_rne.csv)
				if [ -n "$ligne" ]; then
					IP=$(echo "$ligne" | cut -d";" -f2)
					MASK=$(echo "$ligne" | cut -d";" -f3)
					GW=$(echo "$ligne" | cut -d";" -f4)
					DNS=$(echo "$ligne" | cut -d";" -f5)

					echo -e "${COLINFO}Parametres reseau:${COLTXT} IP/Masque:  ${COLINFO}$IP/$MASK"
					echo -e "                   ${COLTXT}Passerelle: ${COLINFO}$GW"
					echo -e "                   ${COLTXT}Dns:        ${COLINFO}$DNS"
					if [ -e /root/.ssh/authorized_keys ]; then
						cat /root/cles_pub_ssh/boireaus.pub >> /root/.ssh/authorized_keys
					else
						cat /root/cles_pub_ssh/boireaus.pub > /root/.ssh/authorized_keys
					fi
				fi
			fi
		done < $fich_proc_cmdline
	fi
fi

#OLDIFS=$IFS
#IFS=" "
while read ligne
do
    if [ "${ligne:0:3}" = "ip=" ]; then
        IP=${ligne:3}
        echo "   IP=$IP"
    fi

    if [ "${ligne:0:5}" = "mask=" ]; then
        MASK=${ligne:5}
        echo "   MASK=$MASK"
    fi

    if [ "${ligne:0:4}" = "dns=" ]; then
        DNS=${ligne:4}
        echo "   DNS=$DNS"
    fi

    if [ "${ligne:0:3}" = "gw=" ]; then
        GW=${ligne:3}
        echo "   GW=$GW"
    fi

    if [ "${ligne:0:8}" = "cle_ssh=" ]; then
		mkdir -p -m 700 /root/.ssh
        CLES_SSH=($(echo "${ligne:8}" | sed -e "s/,/\n/g"))

		echo ""
		cpt=0
		while [ $cpt -lt ${#CLES_SSH[*]} ]
		do
			if [ -e "/root/cles_pub_ssh/${CLES_SSH[$cpt]}.pub" ]; then
				echo "Insertion de la cle ${CLES_SSH[$cpt]}.pub"
				cat /root/cles_pub_ssh/${CLES_SSH[$cpt]}.pub >> /root/.ssh/authorized_keys
			else
				echo -e "${COLERREUR}La cle ${CLES_SSH[$cpt]}.pub est absente.${COLTXT}"
			fi
			cpt=$(($cpt+1))
		done
    fi
done < $fich_proc_cmdline
#IFS=$OLDIFS

#rm $fichtest
#rm _$fichtest

#exit

#===============================================================


#===============================================================

echo -e "$COLTXT"
echo "Voici la liste des interfaces détectées:"
echo -e "$COLCMD"

DEFAULT_INTERFACE=""
TEMOIN_CABLE_CONNECT=""

#local old_ifs="${IFS}"
old_ifs="${IFS}"
#local opts
IFS="
"
for ifname in $($ifconfig -a | grep "^[^ ]"); do
	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		ifname="${ifname%% *}"
	else
		ifname="${ifname%%: *}"
	fi
	[[ ${ifname} == "lo" ]] && continue
	#opts="${opts} ${ifname} '$(get_ifdesc ${ifname})'"

	# Pour ne pas tout modifier des scripts de la bibliothèque de fonctions de SysRescCD...
	iface=$ifname

	if_bus="$(readlink /sys/class/net/${iface}/device/bus)"
	# Il semble qu'il n'y ait plus de fichier 'bus' dans /sys/class/net/${iface}/device/
	#if [ -n "${if_bus}" ]; then
		bus=""
		if [ -n "${if_bus}" ]; then
			bus=$(basename ${if_bus})
		fi

		# Recherche des infos générales
		#if [[ ${bus} == "pci" ]]; then
			# Example: ../../../devices/pci0000:00/0000:00:0a.0 (wanted: 0000:00:0a.0)
			# Example: ../../../devices/pci0000:00/0000:00:09.0/0000:01:07.0 (wanted: 0000:01:07.0)
			if_pciaddr="$(readlink /sys/class/net/${iface}/device)"
			if [ -n "$if_pciaddr" ]; then
				if_pciaddr="$(basename ${if_pciaddr})"

				# Example: 00:0a.0 Bridge: nVidia Corporation CK804 Ethernet Controller (rev a3)
				#  (wanted: nVidia Corporation CK804 Ethernet Controller)
				if_devname="$(lspci -s ${if_pciaddr})"
				if_devname="${if_devname#*: }"
				if_devname="${if_devname%(rev *)}"
			fi
		#fi

		if [[ ${bus} == "usb" ]]; then
			if_usbpath="$(readlink /sys/class/net/${iface}/device)"
			if_usbpath="/sys/class/net/${iface}/$(dirname ${if_usbpath})"
			if_usbmanufacturer="$(< ${if_usbpath}/manufacturer)"
			if_usbproduct="$(< ${if_usbpath}/product)"

			[[ -n ${if_usbmanufacturer} ]] && if_devname="${if_usbmanufacturer} "
			[[ -n ${if_usbproduct} ]] && if_devname="${if_devname}${if_usbproduct}"
		fi

		if [[ ${bus} == "ieee1394" ]]; then
			if_devname="IEEE1394 (FireWire) Network Adapter";
		fi


		# Recherche du pilote:
		if_driver="$(readlink /sys/class/net/${iface}/device/driver)"
		#if_driver=$(basename ${if_driver})
		if [ ! -z "$if_driver" ]; then
			if_driver=$(basename ${if_driver})

			if [ -z "${DEFAULT_INTERFACE}" ]; then
				DEFAULT_INTERFACE=$ifname
			fi

			#t=$(ethtool $ifname 2>/dev/null | grep Link | cut -d":" -f2)
			t=$(ethtool $ifname 2>/dev/null | grep -i "Link detected: yes")
			if [ -n "$t" -a -z "$TEMOIN_CABLE_CONNECT" ]; then
				DEFAULT_INTERFACE=$ifname
				TEMOIN_CABLE_CONNECT="trouve"
			fi
		fi


		# Recherche de l'adresse MAC:
		if_mac=$(cat /sys/class/net/${iface}/address)

		if_vendor=""
		if_device=""
		if [ -e /sys/class/net/${iface}/device/vendor ]; then
			if_vendor=$(cat /sys/class/net/${iface}/device/vendor | cut -d"x" -f2)
		fi
		if [ -e /sys/class/net/${iface}/device/device ]; then
			if_device=$(cat /sys/class/net/${iface}/device/device | cut -d"x" -f2)
		fi

		echo -e "${COLTXT}Interface:   ${COLINFO}$ifname"
		echo -e "${COLTXT}Infos:       ${COLCMD}${if_devname}"
		echo -e "${COLTXT}Pilote:      ${COLCMD}${if_driver}"
		echo -e "${COLTXT}Adresse MAC: ${COLCMD}${if_mac}"
		echo ""

	#fi
done
IFS="${old_ifs}"

#echo -e "$COLINFO"
#echo "Voici la liste des interfaces détectées:"
#echo -e "$COLTXT\c"
#echo $opts

if [ -z "${DEFAULT_INTERFACE}" ]; then
	DEFAULT_INTERFACE="eth0"
fi

#echo "Pause..."
#PAUSE

#iface="eth0"

REPONSE=2
while [ "$REPONSE" = 2 ]
do
	iface=""
	echo -e "$COLTXT"
	echo -e "Quelle interface voulez-vous configurer? [${COLDEFAUT}${DEFAULT_INTERFACE}${COLTXT}] ${COLSAISIE}\c"
	# (30 secondes pour repondre)
	read -t 30 iface

	if [ -z "$iface" ]; then
		iface=${DEFAULT_INTERFACE}

		echo -e "$COLINFO"
		echo "Vous avez choisi (par defaut) l'interface '$iface'"
		REPONSE=1
	else
		echo -e "$COLINFO"
		echo "Vous avez choisi l'interface '$iface'"

		POURSUIVRE_OU_CORRIGER "1"
	fi
done

#===============================================================

if ! grep -q -i "rne=" /proc/cmdline; then
	if [ -e ${mnt_cdrom}/sysresccd/liste_rne.csv ]; then
		echo -e "$COLINFO"
		echo "Un fichier de parametres IP pour certains etablissements existe.
		Dans 20s, on poursuit sans prendre un de ces parametrages.

La liste concerne:"
		sleep 3
		echo -e "$COLTXT"
		cpt=1
		while read ligne
		do
			if [ -n "$ligne" ]; then
				rne[$cpt]=$(echo "$ligne"|cut -d";" -f1)
				ip[$cpt]=$(echo "$ligne"|cut -d";" -f2)
				mask[$cpt]=$(echo "$ligne"|cut -d";" -f3)
				gw[$cpt]=$(echo "$ligne"|cut -d";" -f4)
				dns[$cpt]=$(echo "$ligne"|cut -d";" -f5)
				#echo -e "${COLCHOIX}($cpt)${COLTXT} ${rne[$cpt]} (${ip[$cpt]}/${mask[$cpt]})"

				echo -e "   ${COLCHOIX}($cpt)${COLTXT} ${rne[$cpt]} (${ip[$cpt]})\c"

				if [ "$(($cpt-2*$(($cpt/2))))" = "0" ]; then
					echo ""
				fi

				cpt=$((cpt+1))
			fi
		done < /livemnt/boot/sysresccd/liste_rne.csv

		echo -e "$COLTXT"
		echo -e "Tapez le numero souhaite et ENTREE
ou laissez vide et pressez ENTREE pour poursuivre: $COLSAISIE\c"
		read -t 20 REP

		if [ -n "$REP" -a -n "${ip[$REP]}" ]; then
			IP=${ip[$REP]}
			MASK=${mask[$REP]}
			GW=${gw[$REP]}
			DNS=${dns[$REP]}

			echo -e "$COLTXT"
			echo "Les parametres suivants vont etre utilises:"
			echo -e "${COLTXT}Ip:          ${COLINFO}$IP"
			echo -e "${COLTXT}Masque:      ${COLINFO}$MASK"
			echo -e "${COLTXT}Passerelle:  ${COLINFO}$GW"
			echo -e "${COLTXT}Serveur DNS: ${COLINFO}$DNS"
			sleep 2
		else
			echo -e "$COLTXT"
			echo "Vous n avez pas souhaite un de ces parametrages."
			sleep 2
		fi
	fi
fi
#===============================================================

if [ -n "$IP" -a -n "$MASK" ]; then
	if [ -e /etc/init.d/NetworkManager ]; then
		echo -e "$COLTXT"
		echo "Arret de NetworkManager..."
		echo -e "$COLCMD"
		/etc/init.d/NetworkManager stop
	fi

	NETWORK=$(calcule_reseau $IP $MASK)
	BROADCAST=$(calcule_broadcast $IP $MASK)

	$ifconfig ${iface} ${IP} broadcast ${BROADCAST} netmask ${MASK}
	echo "iface_eth0=\"${IP} broadcast ${BROADCAST} netmask ${MASK}\"" >> /etc/conf.d/net

	if [ -n "$GW" ]; then
		if [ -e /sbin/route ]; then
			/sbin/route add default gw ${GW} dev ${iface} netmask 0.0.0.0 metric 1
		else
			/bin/route add default gw ${GW} dev ${iface} netmask 0.0.0.0 metric 1
		fi
	    echo "gateway=\"${iface}/${GW}\"" >> /etc/conf.d/net
	else
		# Reclamer la GW

		tmpip1=$(echo $IP | cut -d"." -f1)
		tmpip2=$(echo $IP | cut -d"." -f2)
		tmpip3=$(echo $IP | cut -d"." -f3)
		if [ "$MASK" = "255.255.0.0" ]; then
			TMPGW="$tmpip1.$tmpip2.164.1"
		else
			if [ "$MASK" = "255.255.255.192" ]; then
				tmpip4=$(echo $NETWORK | cut -d"." -f4)
				tmpip4=$(($tmpip4+1))
				TMPGW="$tmpip1.$tmpip2.$tmpip3.$tmpip4"
			else
				TMPGW="$tmpip1.$tmpip2.$tmpip3.1"
			fi
		fi

		GW=""
		while [ -z "$GW" ]
		do
			echo -e "$COLTXT"
			echo -e "Passerelle: [${COLDEFAUT}${TMPGW}${COLTXT}] $COLSAISIE\c"
			read GW

			if [ -z "$GW" ]; then
				GW="${TMPGW}"
			fi
		done
	fi
fi


if [ -n "$DNS" ]; then
	echo "nameserver $DNS" > /etc/resolv.conf
	echo "# Free
#nameserver 212.27.54.252
#nameserver 212.27.53.252

# Wanadoo:
#nameserver 193.252.19.3
#nameserver 193.252.19.4
" >> /etc/resolv.conf
else
	# Reclamer le DNS

	if [ "$MASK" = "255.255.0.0" -o "$MASK" = "255.255.255.192" -a -n "$GW" ]; then
		#tmpip1=$(echo $IP | cut -d"." -f1)
		#tmpip2=$(echo $IP | cut -d"." -f2)
		#TMPDNS="$tmpip1.$tmpip2.164.1"
		TMPDNS=$GW
	else
		#TMPDNS="195.221.20.10"
		TMPDNS="${DNS_ACAD}"
	fi

	DNS=""
	while [ -z "$DNS" ]
	do
		echo -e "$COLTXT"
		echo -e "Serveur DNS: [${COLDEFAUT}${TMPDNS}${COLTXT}] $COLSAISIE\c"
		read DNS

		if [ -z "$DNS" ]; then
			DNS="${TMPDNS}"
		fi
	done
fi
#===============================================================

# Pour config DHCP

#echo -e "$COLTXT"
#echo -e "Renseignement des fichiers de configuration réseau,"
#echo -e "et mise en place de la configuration..."
#echo -e "$COLCMD\c"
#/sbin/dhcpcd -n -t 10 -h $(hostname) ${iface} &
#echo "iface_${iface}=\"dhcp\"" >> /etc/conf.d/net

#===============================================================


# Demarrer SSHD
echo -e "${COLTXT}"
echo "Demarrage de SSH"
echo -e "${COLCMD}\c"
#/etc/init.d/sshd start
/etc/init.d/sshd_crob start

sleep 1
t=$(ps aux|grep /usr/sbin/sshd|grep -v grep)
if [ -n "$t" ]; then
	echo -e "${COLTXT}"
	echo "Il est maintenant possible de prendre la machine en SSH."
else
	echo -e "${COLERREUR}"
	echo "Il semble que le serveur SSH n'ait pas demarre."
	echo "Il faudrait retenter:"
	echo "   /etc/init.d/sshd start"
	echo "ou pour eviter des problemes avec NetworkManager"
	echo "   /etc/init.d/sshd_crob start"
	echo -e "${COLTXT}"
	exit 1
fi

echo -e "${COLTXT}"
echo "Test de configuration reseau:"
if [ "$(TEST_PING)" = "0" ]; then
	echo -e "${COLTXT}  - Ping vers l'exterieur reussi."
else
	echo -e "${COLERREUR}  - Echec lors d'un ping vers l'exterieur."
fi
if [ "$(TEST_DNS)" = "0" ]; then
	echo -e "${COLTXT}  - Test de resolution DNS reussi."
else
	echo -e "${COLERREUR}  - Echec lors d'un test de resolution DNS."
fi
if [ "$(TEST_WGET)" = "0" ]; then
	echo -e "${COLTXT}  - Test de telechargement de page web reussi."
	echo "    S'il y a un proxy, il est correctement configure."
else
	echo -e "${COLERREUR}  - Echec d'un telechargement de page web."
	echo "    Cela peut signifier que la configuration proxy est incorrecte."
fi

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour revenir au menu."
read PAUSE

#!/bin/bash

# Script de telechargement puis execution d'un script via WGET
# Derniere modification: 10/04/2013

source /bin/crob_fonctions.sh
source /bin/bibliotheque_ip_masque.sh

echo -e "$COLTITRE"
echo "******************************"
echo "*  Script de telechargement  *"
echo "* puis execution d'un script *"
echo "******************************"

echo -e "$COLTXT"
echo "Lecture de /proc/cmdline"

tmp=/tmp/root
mkdir -p -m 700 ${tmp}
fich_proc_cmdline=$tmp/fichier_cmdline.$(date +%Y%m%d%H%M%S).txt

cat /proc/cmdline | sed -e "s/ /\n/g" > $fich_proc_cmdline

while read ligne
do
    if [ "${ligne:0:12}" = "wget_script=" ]; then
        WGET_SCRIPT=${ligne:12}
        echo "   WGET_SCRIPT=$WGET_SCRIPT"
    fi

    if [ "${ligne:0:6}" = "proxy=" ]; then
        PROXY=${ligne:6}
        echo "   PROXY=$PROXY"
    fi
done < $fich_proc_cmdline


if [ -z "$WGET_SCRIPT" ]; then
	echo -e "$COLERREUR"
	echo "Abandon: Aucun script a telecharger n'a ete specifie."
	echo -e "$COLTXT"
	exit
fi


echo -e "$COLTXT"
echo "Voici la liste des interfaces detectees:"
echo -e "$COLCMD"

DEFAULT_INTERFACE=""

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

	# Pour ne pas tout modifier des scripts de la biblioth�que de fonctions de SysRescCD...
	iface=$ifname

	if_bus="$(readlink /sys/class/net/${iface}/device/bus)"
	# Il semble qu'il n'y ait plus de fichier 'bus' dans /sys/class/net/${iface}/device/
	#if [ -n "${if_bus}" ]; then
		bus=""
		if [ -n "${if_bus}" ]; then
			bus=$(basename ${if_bus})
		fi

		# Recherche des infos g�n�rales
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
#echo "Voici la liste des interfaces d�tect�es:"
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

#===============================================================
# Pour d�sactiver la config IP manuelle.
# On opte dans ce script pour une config DHCP
if [ "$BIDON" = "bidon" ]; then
	if [ -n "$IP" -a -n "$MASK" ]; then
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
fi
#===============================================================

# Pour config DHCP

echo -e "$COLTXT"
echo -e "Renseignement des fichiers de configuration reseau,"
echo -e "et mise en place de la configuration..."
echo -e "$COLCMD\c"
/sbin/dhcpcd -n -t 10 -h $(hostname) ${iface} &
echo "iface_${iface}=\"dhcp\"" >> /etc/conf.d/net

if [ -n "$PROXY" ]; then
	export http_proxy="$PROXY"
	export ftp_proxy="$PROXY"
fi

#===============================================================

# T�l�chargement du script
echo -e "${COLTXT}"
echo "Telechargement de $WGET_SCRIPT"
echo -e "${COLCMD}\c"
tmp=/tmp/root_wget_script_$(date +%Y%m%d%H%M%S)
mkdir -p -m 700 $tmp
cd $tmp
wget --no-check-certificate ${WGET_SCRIPT}

WG_SCRIPT=$(basename ${WGET_SCRIPT})

echo -e "${COLTXT}"
echo "Execution du script..."
sh ${WG_SCRIPT}

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour revenir au menu."
read PAUSE

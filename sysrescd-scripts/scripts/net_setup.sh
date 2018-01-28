#!/bin/sh

# Script de configuration réseau
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 10/04/2013

#Couleurs
COLTITRE="\033[1;35m"	# Rose
COLPARTIE="\033[1;34m"	# Bleu

COLTXT="\033[0;37m"	# Gris
COLCHOIX="\033[1;33m"	# Jaune
COLDEFAUT="\033[0;33m"	# Brun-jaune
COLSAISIE="\033[1;32m"	# Vert

COLCMD="\033[1;37m"	# Blanc

COLERREUR="\033[1;31m"	# Rouge
COLINFO="\033[0;36m"	# Cyan

# Bibliothèque de calcul du réseau et du broadcast:
source /bin/bibliotheque_ip_masque.sh
# Pour recuperer aussi la variable DNS_ACAD
source /bin/crob_fonctions.sh

ERREUR()
{
	echo -e "$COLERREUR"
	echo "ERREUR!"
	echo -e "$1"
	echo -e "$COLTXT"
	read PAUSE
	exit 0
}

POURSUIVRE_OU_CORRIGER()
{
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		if [ ! -z "$1" ]; then
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT}) ? [${COLDEFAUT}${1}${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="$1"
			fi
		else
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT}) ? $COLSAISIE\c"
			read REPONSE
		fi
	done
}

# ===============================================

/etc/init.d/NetworkManager stop

if [ -z "$1" ]; then

	# Bibliothèque de fonctions du LiveCD:
	#source /sbin/livecd-functions.sh

	echo -e "$COLTXT\c"
	echo "Voici la liste des interfaces détectées:"
	echo -e "$COLCMD"

	DEFAULT_INTERFACE=""

	# Compteur pour le tableau des interfaces
	cpt_if=0

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
#		if [ -n "${if_bus}" ]; then
			bus=""
			if [ -n "${if_bus}" ]; then
				bus=$(basename ${if_bus})
			fi

			# Recherche des infos générales
# Comme on ne trouve plus le bus, on suppose que c'est pci... pas top.
#			if [[ ${bus} == "pci" ]]; then
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
#			fi

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

				# On met par defaut la premiere interface trouvee comme interface par defaut
				# On testera mieux plus loin
				if [ -z "${DEFAULT_INTERFACE}" ]; then
					DEFAULT_INTERFACE=$ifname
				fi

				# On stocke la liste des interfaces
				tab_if[$cpt_if]=$ifname
				cpt_if=$(($cpt_if+1))
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
			if [ ! -z "$if_device" -a ! -z "$if_vendor" ]; then
				#echo -e "${COLTXT}Précisions:  ${COLCMD}${if_vendor}${COLTXT}:${COLCMD}${if_device}"

				if [ -e "/root/liste_rom-o-matic.txt" ]; then
					liste_pilotes=($(grep "0x${if_vendor},0x${if_device}" /root/liste_rom-o-matic.txt))
				fi

				echo -e "${COLTXT}Précisions:  ${COLCMD}${if_vendor}${COLTXT}:${COLCMD}${if_device}   ${COLTXT}(pour rom-o-matic)"
				#echo -e "${COLTXT}             (pour rom-o-matic)"
				if [ -e "/root/liste_rom-o-matic.txt" ]; then
					cpt_pilote=0
					while [ ${cpt_pilote} -le ${#liste_pilotes[*]} ]
					do
						echo -e "${COLCMD}             ${liste_pilotes[$cpt_pilote]}"
						cpt_pilote=$(($cpt_pilote+1))
					done
				fi
			fi
			echo ""
#		fi
	done
	IFS="${old_ifs}"

	#echo -e "$COLINFO"
	#echo "Voici la liste des interfaces détectées:"
	#echo -e "$COLTXT\c"
	#echo $opts

	# Recherche de l'interface par defaut
	cpt_if=0
	while [ $cpt_if -lt ${#tab_if[*]} ]
	do
		t=$(ethtool ${tab_if[$cpt_if]} 2>/dev/null | grep -i "Link detected: yes")
		if [ -n "$t" ]; then
			DEFAULT_INTERFACE=${tab_if[$cpt_if]}
			break
		fi
		cpt_if=$(($cpt_if+1))
	done

	if [ -z "${DEFAULT_INTERFACE}" ]; then
		DEFAULT_INTERFACE="eth0"
	fi

	#echo "Pause..."
	#PAUSE

	#iface="eth0"

	REPONSE=2
	while [ "$REPONSE" = 2 ]
	do
		echo -e "$COLTXT"
		echo -e "Quelle interface voulez-vous configurer? [${COLDEFAUT}${DEFAULT_INTERFACE}${COLTXT}] ${COLSAISIE}\c"
		read iface

		if [ -z "$iface" ]; then
			iface=${DEFAULT_INTERFACE}
		fi

		echo -e "$COLINFO"
		echo "Vous avez choisi l'interface '$iface'"

		POURSUIVRE_OU_CORRIGER "1"
	done


	#ERREUR "Passer en paramètre le nom de l'interface à configurer (eth0 en général)."
	#exit
else
	iface=$1

	echo -e "$COLINFO"
	echo "Vous allez configurer l'interface $iface"
fi

DEF_REP_DHCP=2
if [ -e "/tmp/proposer_ip_statique.txt" ]; then
	DEF_REP_DHCP=1
fi

REPONSE=""
while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous effectuer une configuration réseau statique (${COLCHOIX}1${COLTXT})"
	echo -e "ou préférez-vous le configurer en client DHCP (${COLCHOIX}2${COLTXT})?"
	echo -e "Votre choix: [${COLDEFAUT}${DEF_REP_DHCP}${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE=${DEF_REP_DHCP}
	fi
done

if [ $REPONSE = "1" ]; then
	REPONSE=2
	while [ "$REPONSE" = "2" ]
	do

		IP=""
		while [ -z "$IP" ]
		do
			echo -e "$COLTXT"
			echo -e "Adresse IP: [${COLDEFAUT}10.127.164.200${COLTXT}] $COLSAISIE\c"
			read IP

			if [ -z "$IP" ]; then
				IP="10.127.164.200"
			fi

			test=$(echo "$IP" | tr "." "0" | sed -e "s/[0-9]//g" | wc -m)
			if [ "$test" != "1" ]; then
				echo -e "$COLTXT"
				echo -e "CaractÃšres invalides: ---${COLINFO}${test}${COLTXT}---"
				IP=""
			else
				tmpip1=$(echo $IP | cut -d"." -f1)
				tmpip2=$(echo $IP | cut -d"." -f2)
				tmpip3=$(echo $IP | cut -d"." -f3)
				tmpip4=$(echo $IP | cut -d"." -f4)
				#echo -e "tmpip1=$tmpip1"
				#echo -e "tmpip2=$tmpip2"
				#echo -e "tmpip3=$tmpip3"
				#echo -e "tmpip4=$tmpip4"

				if [ -z "$tmpip1" ]; then
					IP=""
				else
					if [ "$tmpip1" != "0" ]; then
						if [ $tmpip1 -lt 1 -o $tmpip1 -gt 255  ]; then
							IP=""
						fi
					fi

					if [ -z "$tmpip2" ]; then
						IP=""
					else
						if [ "$tmpip2" != "0" ]; then
							if [ $tmpip2 -lt 1 -o $tmpip2 -gt 255  ]; then
								IP=""
							fi
						fi

						if [ -z "$tmpip3" ]; then
							IP=""
						else
							if [ "$tmpip3" != "0" ]; then
								if [ $tmpip3 -lt 1 -o $tmpip3 -gt 255  ]; then
									IP=""
								fi
							fi

							if [ -z "$tmpip4" ]; then
								IP=""
							else
								if [ "$tmpip4" != "0" ]; then
									if [ $tmpip4 -lt 1 -o $tmpip4 -gt 255  ]; then
										IP=""
									fi
								fi
							fi
						fi
					fi
				fi
			fi

			if [ -z "$IP" ]; then
				echo -e "$COLTXT"
				echo "Des caractÃšres ou des valeurs invalides ont Ã©tÃ© saisis."
			fi
		done

		if [ "${IP:0:6}" = "10.127" -o "${IP:0:6}" = "10.176" ]; then
			DEFAULTMASK="255.255.0.0"
		else
			if [ "${IP:0:7}" = "172.21." -o "${IP:0:7}" = "172.20." ]; then
				DEFAULTMASK="255.255.255.192"
			else
				DEFAULTMASK="255.255.255.0"
			fi
		fi

		MASK=""
		while [ -z "$MASK" ]
		do
			echo -e "$COLTXT"
			#echo -e "Masque: [${COLDEFAUT}255.255.0.0${COLTXT}] $COLSAISIE\c"
			echo -e "Masque: [${COLDEFAUT}${DEFAULTMASK}${COLTXT}] $COLSAISIE\c"
			read MASK

			if [ -z "$MASK" ]; then
				#MASK="255.255.0.0"
				MASK=${DEFAULTMASK}
			fi

			test=$(echo "$MASK" | tr "." "0" | sed -e "s/[0-9]//g" | wc -m)
			if [ "$test" != "1" ]; then
				MASK=""
			else
				tmpmask1=$(echo $MASK | cut -d"." -f1)
				tmpmask2=$(echo $MASK | cut -d"." -f2)
				tmpmask3=$(echo $MASK | cut -d"." -f3)
				tmpmask4=$(echo $MASK | cut -d"." -f4)

				if [ -z "$tmpmask1" ]; then
					MASK=""
				else
					if [ "$tmpmask1" != "0" ]; then
						if [ $tmpmask1 -lt 1 -o $tmpmask1 -gt 255  ]; then
							MASK=""
						fi
					fi

					if [ -z "$tmpmask2" ]; then
						MASK=""
					else
						if [ "$tmpmask2" != "0" ]; then
							if [ $tmpmask2 -lt 1 -o $tmpmask2 -gt 255  ]; then
								MASK=""
							fi
						fi

						if [ -z "$tmpmask3" ]; then
							MASK=""
						else
							if [ "$tmpmask3" != "0" ]; then
								if [ $tmpmask3 -lt 1 -o $tmpmask3 -gt 255  ]; then
									MASK=""
								fi
							fi

							if [ -z "$tmpmask4" ]; then
								MASK=""
							else
								if [ "$tmpmask4" != "0" ]; then
									if [ $tmpmask4 -lt 1 -o $tmpmask4 -gt 255  ]; then
										MASK=""
									fi
								fi
							fi
						fi
					fi
				fi
			fi

			if [ -z "$MASK" ]; then
				echo -e "$COLTXT"
				echo "Des caractÃšres invalides ont Ã©tÃ© saisis."
			fi
		done

		TMPNETWORK=$(calcule_reseau $IP $MASK)
		TMPBROADCAST=$(calcule_broadcast $IP $MASK)

		echo -e "$COLTXT"
		echo -e "Reseau: [${COLDEFAUT}${TMPNETWORK}${COLTXT}] $COLSAISIE\c"
		read NETWORK

		if [ -z "$NETWORK" ]; then
			NETWORK="$TMPNETWORK"
		fi

		echo -e "$COLTXT"
		echo -e "Broadcast: [${COLDEFAUT}${TMPBROADCAST}${COLTXT}] $COLSAISIE\c"
		read BROADCAST

		if [ -z "$BROADCAST" ]; then
			BROADCAST="${TMPBROADCAST}"
		fi

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

		echo -e "$COLTXT"
		echo -e "Passerelle: [${COLDEFAUT}${TMPGW}${COLTXT}] $COLSAISIE\c"
		read GW

		if [ -z "$GW" ]; then
			GW="${TMPGW}"
		fi

		if [ "$MASK" = "255.255.0.0" -o "$MASK" = "255.255.255.192" ]; then
			#tmpip1=$(echo $IP | cut -d"." -f1)
			#tmpip2=$(echo $IP | cut -d"." -f2)
			#TMPDNS="$tmpip1.$tmpip2.164.1"
			TMPDNS=$GW
		else
			TMPDNS="${DNS_ACAD}"
		fi

		echo -e "$COLTXT"
		echo -e "Serveur DNS: [${COLDEFAUT}${TMPDNS}${COLTXT}] $COLSAISIE\c"
		read DNS

		if [ -z "$DNS" ]; then
			DNS="${TMPDNS}"
		fi


		echo -e "$COLINFO"
		echo "Rappel de la configuration choisie:"
		echo -e " ${COLTXT}IP:        ${COLINFO}${IP}"
		echo -e " ${COLTXT}MASK:      ${COLINFO}${MASK}"
		echo -e " ${COLTXT}NETWORK:   ${COLINFO}${NETWORK}"
		echo -e " ${COLTXT}BROADCAST: ${COLINFO}${BROADCAST}"
		echo -e " ${COLTXT}GW:        ${COLINFO}${GW}"
		echo -e " ${COLTXT}DNS:       ${COLINFO}${DNS}"

		POURSUIVRE_OU_CORRIGER "1"
	done

	echo "$GW" > /tmp/GW.txt

	echo -e "$COLTXT"
	echo -e "Renseignement des fichiers de configuration réseau,"
	echo -e "et mise en place de la configuration..."
	echo -e "$COLCMD\c"

	echo "nameserver $DNS" > /etc/resolv.conf
	echo "
# OpenDNS: http://fr.wikipedia.org/wiki/OpenDNS
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

	$ifconfig ${iface} ${IP} broadcast ${BROADCAST} netmask ${MASK}
	if [ -e /sbin/route ]; then
		/sbin/route add default gw ${GW} dev ${iface} netmask 0.0.0.0 metric 1
	else
		/bin/route add default gw ${GW} dev ${iface} netmask 0.0.0.0 metric 1
	fi

	echo "iface_eth0=\"${IP} broadcast ${BROADCAST} netmask ${MASK}\"" >> /etc/conf.d/net
	if [ -n "${GW}" ]; then
		echo "gateway=\"${iface}/${GW}\"" >> /etc/conf.d/net
	fi

else
	echo -e "$COLTXT"
	echo -e "Renseignement des fichiers de configuration réseau,"
	echo -e "et mise en place de la configuration..."
	echo -e "$COLCMD\c"
	/sbin/dhcpcd -n -t 10 -h $(hostname) ${iface} &
	echo "iface_${iface}=\"dhcp\"" >> /etc/conf.d/net
fi

REPPROXY=""
while [ "$REPPROXY" != "o" -a "$REPPROXY" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous paramétrer un proxy pour votre installation? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPPROXY

	if [ -z "$REPPROXY" ]; then
		REPPROXY="n"
	fi
done

if [ "$REPPROXY" = "o" ]; then
	REPONSE=2
	while [ $REPONSE = 2 ]
	do
		if [ ! -z "$GW" ]; then
			echo -e "$COLTXT"
			echo -e "Quel est l'IP ou le nom DNS du proxy? [${COLDEFAUT}${GW}${COLTXT}] $COLSAISIE\c"
			read PROXY

			if [ -z "$PROXY" ]; then
				PROXY=$GW
			fi
		else
			echo -e "$COLTXT"
			echo -e "Quel est l'IP ou le nom DNS du proxy? $COLSAISIE\c"
			read PROXY
		fi

		echo -e "$COLTXT"
		echo -e "Quel est le port du proxy? [${COLDEFAUT}3128${COLTXT}] $COLSAISIE\c"
		read PORT

		if [ -z "$PORT" ]; then
			PORT="3128"
		fi

		echo -e "$COLTXT"
		echo -e "Vous avez choisi le proxy ${COLINFO}${PROXY}${COLTXT}:${COLINFO}${PORT}${COLTXT}"

		POURSUIVRE_OU_CORRIGER "1"
	done

	echo -e "$COLTXT"
	echo -e "Renseignement du proxy dans ${COLINFO}/etc/profile"
	echo -e "$COLCMD\c"
	echo "export http_proxy=\"http://$PROXY:$PORT\"" >> /etc/profile
	echo "export ftp_proxy=\"http://$PROXY:$PORT\"" >> /etc/profile

	echo -e "$COLTXT"
	echo -e "Mise en place du proxy."
	echo -e "$COLCMD\c"
	export http_proxy="http://$PROXY:$PORT"
	export ftp_proxy="http://$PROXY:$PORT"
fi

echo -e "$COLTITRE"
echo "Configuration de l'interface réseau $iface terminée."
echo -e "$COLTXT\c"

echo $iface > /tmp/iface.txt

sleep 1

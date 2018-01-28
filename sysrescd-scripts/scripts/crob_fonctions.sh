# Un ensemble de fonctions humblement realisees par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 11/05/2015

web_browser=midori
web_browser_avec_chemin=$(which $web_browser)

# Volume de SysRescCD quand on copie pour CDRESTAURE
volume_sysresccd="310"

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

# Chemin ntfsclone:
chemin_ntfs=/usr/sbin
# Chemin dar:
chemin_dar=/usr/bin

# Point de montage du cdrom
#mnt_cdrom=/mnt/cdrom
mnt_cdrom=/livemnt/boot

if [ -e "/tmp/chemin_mnt_cdrom" ]; then
	mnt_cdrom=$(cat /tmp/chemin_mnt_cdrom)
fi

# Option pour sauvegarder/restaurer avec dd: A TESTER
#opt_dd=" conv=sync,noerror bs=64K"

# Option Locale pour ntfs-3g
#OPT_LOCALE_NTFS3G="locale=fr_FR.UTF8"
OPT_LOCALE_NTFS3G="locale=en_US.utf8"

# En 3.4.1, on est passe de /sbin/ifconfig a /bin/ifconfig
ifconfig="/bin/ifconfig"

#DNS_ACAD=195.221.20.10
#DNS_ACAD=194.167.110.1
#DNS_ACAD=194.167.110.33

# OpenDNS: http://fr.wikipedia.org/wiki/OpenDNS
# nameserver 208.67.222.222
# nameserver 208.67.220.220
# nameserver 208.67.222.220
# nameserver 208.67.220.222
DNS_ACAD=208.67.222.222

ERREUR()
{
	echo -e "$COLERREUR"
	echo "ERREUR!"
	echo -e "$1"
	echo -e "$COLTXT"
	read PAUSE
	exit 0
}

AFFICHHD()
{
	echo -e "$COLTXT"
	echo "Voici la liste des disques trouves sur votre machine:"
	echo -e "$COLCMD"
	TEMOIN=""

	sfdisk -g > /tmp/sfdisk_g.txt 2>&1
	# WARNING: GPT (GUID Partition Table) detected on '/dev/sda'! The util sfdisk doesn't support GPT. Use GNU Parted.
	disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on " /tmp/sfdisk_g.txt|cut -d"'" -f2)

	liste_sfdisk_g=$(sfdisk -g 2>/dev/null)
	if [ -n "${liste_sfdisk_g}" ]; then
		TEMOIN="OK"
		sfdisk -g|while read A
		do
			echo "$A"
			curdev=$(echo "$A"|sed -e "s|^/dev/||"|cut -d":" -f1)
			if [ -n "$curdev" ]; then
				GET_INFO_HD $curdev
			fi
		done
	fi

	if [ "$TEMOIN" != "OK" ]; then
		if dmesg | grep hd | grep drive | grep -v driver | grep -v ROM; then
			TEMOIN="OK"
		fi

		#dmesg | grep sd | grep drive | grep -v driver | grep -v ROM
		if dmesg | grep sd | grep SCSI | grep -v ROM; then
			TEMOIN="OK"
		fi
	fi

	if [ "$TEMOIN" != "OK" ]; then
		echo -e "${COLINFO}Les methodes precedentes de detection n'ont pas fonctionne."
		echo "Deux autres methodes vont etre tentees."
		echo "Si elles echouent, il vous faudra connaitre"
		echo -e "l'identifiant (hda, hdb,...) du disque pour poursuivre.${COLCMD}"
		#Sur les IBM Thinkpad, les commandes precedentes ne donnent rien alors que /dev/hda est bien present.
		#dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"
		#if dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"; then
		if dmesg | grep dev | grep host | grep bus | grep target | grep lun > /dev/null; then
			dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"
			TEMOIN="OK"
		fi
		#Une alternative sera: ls /dev/hd*
	fi

	if [ "$TEMOIN" != "OK" ]; then
		echo ""
		ls /dev/ | egrep "(hd|sd)" | grep -v "[0-9]" 2>/dev/null |while read A
		do
			#if fdisk -l /dev/$A | grep Blocks > /dev/null 2>/dev/null; then
			if fdisk -l /dev/$A 2>/dev/null| grep Blocks > /dev/null; then
				echo $A
				echo "OK" > /tmp/TEMOIN
			fi
		done
		if [ -e "/tmp/TEMOIN" ]; then
			TEMOIN=$(cat /tmp/TEMOIN)
			rm -f /tmp/TEMOIN
			echo -e "$COLINFO"
			echo "Un message eventuel indiquant:"
			echo -e "${COLERREUR}Disk /dev/XdY doesn't contain a valid partition table"
			echo -e "${COLINFO}signifie seulement que le peripherique /dev/XdY ne doit pas etre un disque dur."
		fi
	fi

	if [ "$TEMOIN" != "OK" ]; then
		echo -e "$COLCMD"
		if ls /dev/hd* | grep "[0-9]" > /dev/null; then
			#ls /dev/hd* | grep "[0-9]" | sed -e "s|/dev/||g" | sed -e "s/[0-9]*//g"
			ls /dev/hd* | grep "[0-9]" | sed -e "s|/dev/||g" | sed -e "s/[0-9]*//g" | sort | uniq
		else
			echo -e "${COLINFO}Le(s) disque(s) dur(s) n'a/ont pas ete identifie(s) par mon script.\nCela ne vous empeche pas de poursuivre,\nmais il faut alors connaitre le peripherique...${COLTXT}"
		fi
	fi
}

POURSUIVRE()
{
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		if [ -z "$1" ]; then
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		else
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${1}${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="$1"
			fi
		fi
	done

	if [ "$REPONSE" != "o" ]; then
		ERREUR "Abandon!"
	fi
}

POURSUIVRE2()
{
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE < /dev/tty
	done

	if [ "$REPONSE" != "o" ]; then
		ERREUR "Abandon!"
	fi
}

POURSUIVRE_OU_CORRIGER()
{
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		if [ ! -z "$1" ]; then
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT}) ? [${COLDEFAUT}${1}${COLTXT}] $COLSAISIE\c"
			if [ -n "$2" ]; then
				read -t $2 REPONSE
			else
				read REPONSE
			fi

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

GET_DEFAULT_DISK(){
	# A cause du HP Proliant ML350
	# Il faut proposer cciss/c0d0
	liste_tmp=($(sfdisk -g 2>/dev/null| grep "^/dev/" | cut -d":" -f1 | cut -d"/" -f3))
	if [ "${liste_tmp[0]:0:11}" = "/dev/cciss/" ]; then
		DEFAULTDISK=${liste_tmp[0]:5}
	else
		liste_tmp=($(sfdisk -g 2>/dev/null| grep "^/dev/" | cut -d":" -f1 | cut -d"/" -f3))
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTDISK=${liste_tmp[0]}
		else
			DEFAULTDISK="sda"
		fi
	fi
	echo $DEFAULTDISK
}

TYPE_PART(){
	if [ "${1:0:5}" = "/dev/" ]; then
		TMP_PART=$(echo "$1" | cut -d"/" -f3)
	else
		TMP_PART=$1
	fi

	TMP_TYPE=""

	#parted /dev/$TMP_HD print |grep -E '^ [0-9]+' | awk '{print $1 " " $6}'
	TMP_TYPE=$(parted /dev/$TMP_PART print 2>/dev/null|grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
	if [ "$TMP_TYPE" = "fat32" ]; then
		TMP_TYPE="vfat"
	elif [ "$TMP_TYPE" = "fat16" ]; then
		TMP_TYPE="vfat"
	elif [ "$TMP_TYPE" = "linux-swap" ]; then
			TMP_TYPE="linux-swap"
	elif [ "$TMP_TYPE" = "ntfs" ]; then
			TMP_TYPE="ntfs"
	elif [ -z "$TMP_TYPE" ]; then
		TMP_DD=$(echo $TMP_PART | sed -e "s/[0-9]//g")

		type_parttable=$(parted /dev/${TMP_DD} print|grep -i "^Partition Table: "|cut -d":" -f2|sed -e "s|^[ ]||g")
		if [ "$type_parttable" = "msdos" ]; then
			TMP_TYPE=$(fdisk -l /dev/$TMP_DD | grep "^/dev/" | tr "\t" " " | grep "$TMP_PART " | tr "*" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)

			if [ "$TMP_TYPE" = "HPFS/NTFS" ]; then
				TMP_TYPE="ntfs"
			fi

			if [ "$TMP_TYPE" = "W95" ]; then
				TMP_TYPE="vfat"
			fi

			if [ "$TMP_TYPE" = "Linux" ]; then
				# Quand la partition n'est pas formatee, on peut en arriver la...
				TMP_TYPE=""
			fi
		fi
	fi

	echo "$TMP_TYPE"
}

CONFXORG()
{
	# Avec le passage a SysRescCD 0.3.5, Xorg est passe a la version Xorg-7.2
	# Il n'est plus necessaire avec cette version que le /etc/X11/xorg.conf existe
	# dans le mode standard (vga=0) soit 'nofb'.
	# Par contre, avec les modes 'fb...', ce fichier reste necessaire.
	if ! egrep "( vga=0 | vga=4 | vga=5 | vga=6 )" /proc/cmdline > /dev/null; then
		if [ ! -e /etc/X11/xorg.conf ]; then
			echo "Generation du fichier /etc/X11/xorg.conf"
			/usr/sbin/mkxf86config.sh
		fi
	fi
}

LISTE_INTERFACES_RESEAU()
{
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
		[[ "${ifname}" == "lo" ]] && continue
		#opts="${opts} ${ifname} '$(get_ifdesc ${ifname})'"

		# Pour ne pas tout modifier des scripts de la bibliotheque de fonctions de SysRescCD...
		iface=$ifname

		if_bus="$(readlink /sys/class/net/${iface}/device/bus)"
		if [ -n "${if_bus}" ]; then
			bus=$(basename ${if_bus})

			# Recherche des infos generales
			if [[ "${bus}" == "pci" ]]; then
				# Example: ../../../devices/pci0000:00/0000:00:0a.0 (wanted: 0000:00:0a.0)
				# Example: ../../../devices/pci0000:00/0000:00:09.0/0000:01:07.0 (wanted: 0000:01:07.0)
				if_pciaddr="$(readlink /sys/class/net/${iface}/device)"
				if_pciaddr="$(basename ${if_pciaddr})"

				# Example: 00:0a.0 Bridge: nVidia Corporation CK804 Ethernet Controller (rev a3)
				#  (wanted: nVidia Corporation CK804 Ethernet Controller)
				if_devname="$(lspci -s ${if_pciaddr})"
				if_devname="${if_devname#*: }"
				if_devname="${if_devname%(rev *)}"
			fi

			if [[ "${bus}" == "usb" ]]; then
				if_usbpath="$(readlink /sys/class/net/${iface}/device)"
				if_usbpath="/sys/class/net/${iface}/$(dirname ${if_usbpath})"
				if_usbmanufacturer="$(< ${if_usbpath}/manufacturer)"
				if_usbproduct="$(< ${if_usbpath}/product)"

				[[ -n "${if_usbmanufacturer}" ]] && if_devname="${if_usbmanufacturer} "
				[[ -n "${if_usbproduct}" ]] && if_devname="${if_devname}${if_usbproduct}"
			fi

			if [[ "${bus}" == "ieee1394" ]]; then
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

			if [ -z "$1" ]; then
				echo -e "${COLTXT}Interface:   ${COLINFO}$ifname"
				echo -e "${COLTXT}Infos:       ${COLCMD}${if_devname}"
				echo -e "${COLTXT}Pilote:      ${COLCMD}${if_driver}"
				echo -e "${COLTXT}Adresse MAC: ${COLCMD}${if_mac}"
				if [ ! -z "$if_device" -a ! -z "$if_vendor" ]; then
					#echo -e "${COLTXT}Precisions:  ${COLCMD}${if_vendor}${COLTXT}:${COLCMD}${if_device}"
					echo -e "${COLTXT}Precisions:  ${COLCMD}${if_vendor}${COLTXT}:${COLCMD}${if_device}   ${COLTXT}(pour rom-o-matic)"
					#echo -e "${COLTXT}             (pour rom-o-matic)"
				fi
			else
				echo -e "Interface:   $ifname"
				echo -e "Infos:       ${if_devname}"
				echo -e "Pilote:      ${if_driver}"
				echo -e "Adresse MAC: ${if_mac}"
				if [ ! -z "$if_device" -a ! -z "$if_vendor" ]; then
					#echo -e "Precisions:  ${if_vendor}:${if_device}"
					echo -e "Precisions:  ${if_vendor}:${if_device}   (pour rom-o-matic)"
					#echo -e "${COLTXT}             (pour rom-o-matic)"
				fi
			fi
			echo ""
		fi
	done
	IFS="${old_ifs}"
}

CONFIG_RESEAU(){
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
	do
		echo -e "$COLTXT"
		echo "Il est donc necessaire d'effectuer la configuration reseau."
		CHOIX=2

		AFFICHE_LIGNES_INTERFACES_CONFIGUREES

		echo -e "${COLTXT}\c"
		echo -e "Si le reseau est OK, tapez       ${COLCHOIX}1${COLTXT}"
		echo -e "Pour configurer le reseau, tapez ${COLCHOIX}2${COLTXT}"
		echo -e "Pour abandonner, tapez           ${COLCHOIX}3${COLTXT}"
		echo -e "Votre choix: [${COLDEFAUT}${CHOIX}${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=${CHOIX}
		fi
	done

	if [ "$REPONSE" = "3" ]; then
		echo -e "$COLERREUR"
		echo "ABANDON!"
		echo -e "$COLTXT"
		read PAUSE
		exit
	fi

	if [ "$REPONSE" = "2" ]; then
		echo -e "$COLINFO"
		echo "Le script net-setup de SystemRescueCD (depuis la version 0.3.1) pose des"
		echo "problemes lorsqu'il est lance sans etre passe par une console avant le lancement"
		echo "(cas du lancement via l'autorun)."
		echo "Un script alternatif est propose, mais il ne permet pas, contrairement au script"
		echo "net-setup officiel, de configurer une interface wifi."
		REPNET=""
		while [ "$REPNET" != "1" -a "$REPNET" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel script souhaitez-vous utiliser? (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
			read REPNET

			if [ -z "$REPNET" ]; then
				REPNET=2
			fi
		done

		REP="o"
		while [ "$REP" = "o" ]
		do
			echo -e "$COLCMD"
			#SysRescCD:
			if [ "$REPNET" = "1" ]; then
				net-setup eth0
				iface=eth0
			else
				if [ -e "/bin/net_setup.sh" ]; then
					/bin/net_setup.sh
					iface=$(cat /tmp/iface.txt)
				else
					if [ -e "${mnt_cdrom}/sysresccd/scripts/net_setup.sh" ]; then
						sh ${mnt_cdrom}/sysresccd/scripts/net_setup.sh
						iface=$(cat /tmp/iface.txt)
					else
						echo -e "$COLERREUR"
						echo "Le script net_setup.sh n'a pas ete trouve."
						echo -e "$COLTXT"
						echo "Tentative d'utiliser le script officiel net-setup"
						echo -e "$COLCMD\c"
						sleep 3
						net-setup eth0
						iface=eth0
					fi
				fi
			fi
			#Puppy:
			#net-setup.sh

			echo -e "$COLTXT"
			echo "Patientez..."
			sleep 2

			echo -e "$COLTXT"
			echo "Voici la config IP:"
			echo -e "$COLCMD\c"

			RENSEIGNE_ligne_CONFIG_IP_IFACE $iface

			if [ -z "${ligne}" ]; then
				DEFAULT_REP="o"
			else
				echo "${ligne}"
				DEFAULT_REP="n"
			fi

			echo -e "$COLTXT"
			echo -e "Voulez-vous corriger/modifier cette configuration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${DEFAULT_REP}${COLTXT}] $COLSAISIE\c"
			read REP

			if [ -z "$REP" ]; then
				REP="${DEFAULT_REP}"
			fi
		done
	fi
}


GET_INTERFACE_DEFAUT() {
	echo -e "$COLTXT"
	echo "Voici la liste des interfaces detectees:"
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
	
		# Pour ne pas tout modifier des scripts de la bibliotheque de fonctions de SysRescCD...
		iface=$ifname
	
		if_bus="$(readlink /sys/class/net/${iface}/device/bus)"
		# Il semble qu'il n'y ait plus de fichier 'bus' dans /sys/class/net/${iface}/device/
		#if [ -n "${if_bus}" ]; then
			bus=""
			if [ -n "${if_bus}" ]; then
				bus=$(basename ${if_bus})
			fi
	
			# Recherche des infos generales
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
	#echo "Voici la liste des interfaces detectees:"
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
	echo $iface > /tmp/iface.txt
}


DEST_SVG(){
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" -a "$REPONSE" != "4" ]
	#while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
	do
		echo -e "$COLTXT"
		echo "Souhaitez-vous effectuer?"
		echo -e "     (${COLCHOIX}1${COLTXT}) une sauvegarde vers une partition locale,"
		echo -e "     (${COLCHOIX}2${COLTXT}) une sauvegarde vers un partage Samba/win."
		#Le module lufs a l'air absent...
		echo -e "     (${COLCHOIX}3${COLTXT}) une sauvegarde vers un serveur SSH."
		echo -e "     (${COLCHOIX}4${COLTXT}) une sauvegarde vers un dossier FTP."
		echo -e "Mode choisi: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=1
		fi
	done

	case "$REPONSE" in
		1)
			TYPE_DEST_SVG='partition'
			echo -e "$COLPARTIE"
			echo "**********************************************************"
			echo "Vous avez choisi une sauvegarde vers une partition locale."
			echo "**********************************************************"

			echo -e "$COLPARTIE"
			echo "==================================="
			echo " Choix de la partition de stockage "
			echo "         de la sauvegarde          "
			echo "==================================="

			VERIF=""
			while [ "${VERIF}" != "OK" ]
			do
				VERIF=""
				SAVEHD=""
				CHOIX_DEST=""

				AFFICHHD

				if [ -z "${HD}" ]; then
					DEFAULTDISK=$(GET_DEFAULT_DISK)
				else
					DEFAULTDISK=${HD}
				fi

				echo -e "$COLTXT"
				echo -e "Sur quel disque se trouve la partition\nde stockage de la sauvegarde?"
				echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
				#echo -e "Disque: [${COLDEFAUT}hda${COLTXT}] $COLSAISIE\c"
				echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
				read SAVEHD

				if [ -z "${SAVEHD}" ]; then
					#SAVEHD="hda"
					SAVEHD=${DEFAULTDISK}
				fi

				if sfdisk -s /dev/$SAVEHD > /dev/null 2>&1; then
					if [ -e "/sys/block/$SAVEHD" ]; then
						echo -e "$COLTXT"
						echo "Le disque /dev/$SAVEHD existe."
					else
						echo -e "$COLERREUR"
						echo "ERREUR: La disque propose ne semble pas exister."

						POURSUIVRE_OU_CORRIGER "2"

						if [ "$REPONSE" = "2" ]; then
							VERIF="ERREUR"
						fi
					fi
				else
					echo -e "$COLERREUR"
					echo "ERREUR: La disque propose ne semble pas exister."

					POURSUIVRE_OU_CORRIGER "2"

					if [ "$REPONSE" = "2" ]; then
						VERIF="ERREUR"
					fi
				fi

				if [ "$VERIF" != "ERREUR" ]; then
					echo -e "$COLTXT"
					#echo "La partition de destination ne doit pas etre de type NTFS (ni Linux SWAP)."
					echo "La partition de destination ne doit pas etre de type Linux SWAP."
					echo "(NTFS est maintenant supporte en ecriture avec ntfs-3g)"
					echo "Voici la/les partition(s) susceptibles de convenir:"
					echo -e "$COLCMD"
					#fdisk -l /dev/${SAVEHD} | grep "/dev/${SAVEHD}[0-9]" | grep -v NTFS | grep -v "Linux swap"
					#fdisk -l /dev/${SAVEHD} | grep "/dev/${SAVEHD}[0-9]" | grep -v "^/dev/${CHOIX_SOURCE} " | grep -v NTFS | grep -v "Linux swap"

					SAVEHD_CLEAN=$(echo ${SAVEHD}|sed -e "s|[^0-9A-Za-z]|_|g")

					#fdisk -l /dev/$SAVEHD > /tmp/fdisk_l_${SAVEHD_CLEAN}.txt 2>&1
					#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${SAVEHD}'" /tmp/fdisk_l_${SAVEHD_CLEAN}.txt|cut -d"'" -f2)

					#t=$(parted /dev/${SAVEHD} print|grep -i "Partition Table: gpt")
					#if [ -n "$t" ]; then
					if [ "$(IS_GPT_PARTTABLE ${SAVEHD})" = "y" ]; then
						disque_en_GPT=/dev/${SAVEHD}
					else
						disque_en_GPT=""
					fi

					if [ -z "$disque_en_GPT" ]; then
						fdisk -l /dev/${SAVEHD} 2>/dev/null| grep "/dev/${SAVEHD}[0-9]" | grep -v "^/dev/${CHOIX_SOURCE} " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility"

						#liste_tmp=($(fdisk -l /dev/${SAVEHD} | grep "^/dev/${SAVEHD}" | tr "\t" " " | grep -v "^/dev/${CHOIX_SOURCE} " | grep -v "NTFS" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd"))
						liste_tmp=($(fdisk -l /dev/${SAVEHD} | grep "^/dev/${SAVEHD}" | tr "\t" " " | grep -v "^/dev/${CHOIX_SOURCE} " | grep -v "NTFS" | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility" | cut -d" " -f1))

						#liste_tmp=($(fdisk -l /dev/${SAVEHD} | grep "^/dev/${SAVEHD}" | tr "\t" " " | grep -v "^/dev/${CHOIX_SOURCE} " | grep -v "NTFS" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden"))
						if [ ! -z "${liste_tmp[0]}" ]; then
							# Avec ${liste_tmp[0]} on ne recupere que le '/dev/sda1' sans la suite des infos donnees par le fdisk
							# L'espace est dans les separateurs pris en compte dans $IFS
							#DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")

							# Plus propre quand meme:
							DEFAULTPART=$(echo ${liste_tmp[0]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
						else
							# On recherche une partition (eventuellement) NTFS en second choix:
							liste_tmp=($(fdisk -l /dev/${SAVEHD} | grep "^/dev/${SAVEHD}" | tr "\t" " " | grep -v "^/dev/${CHOIX_SOURCE} " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility" | cut -d" " -f1))
							if [ ! -z "${liste_tmp[0]}" ]; then
								#DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
								DEFAULTPART=$(echo ${liste_tmp[0]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
							else
								DEFAULTPART="hda5"
							fi
						fi
					else
						#parted /dev/${SAVEHD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]"|cut -d" " -f1 > /tmp/num_partitions_${SAVEHD_CLEAN}.txt
						parted /dev/${SAVEHD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${SAVEHD_CLEAN}.txt
						NUM_PART_CHOIX_SOURCE=$(echo "${CHOIX_SOURCE}"|sed -e "s|^${SAVEHD}||")
						# Tester si parted renvoie ces chaines:
						grep -v "^${NUM_PART_CHOIX_SOURCE} " /tmp/partitions_${SAVEHD_CLEAN}.txt | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility" > /tmp/partitions_dest_${SAVEHD_CLEAN}.txt

						temoin_dest_part_non_ntfs=""
						temoin_dest_part_ntfs="n"
						parted /dev/${SAVEHD} print|grep "^Number "
						while read A
						do
							#echo ${SAVEHD}${A}
							#B=$(echo "$A"|sed -e "s| \{2,\}| |"|tr " " "\t")
							#echo "${SAVEHD}${B}"
							echo "${SAVEHD}${A}"

							B=$(echo "$A"|cut -d" " -f1)
							if [ -z "$DEFAULTPART" ]; then
								DEFAULTPART=${SAVEHD}${B}
								if echo "$A"|grep -q "ntfs"; then
									temoin_dest_part_ntfs="y"
								else
									temoin_dest_part_non_ntfs="y"
								fi
							else
								if [ "$temoin_dest_part_non_ntfs" != "y" ]; then
									if echo "$A"|grep -q "ntfs"; then
										# On ne change pas de partition destination (une ntfs pour une autre)
										plop=""
									else
										DEFAULTPART=${SAVEHD}${B}
										temoin_dest_part_non_ntfs="y"
									fi
								fi
							fi
						done < /tmp/partitions_dest_${SAVEHD_CLEAN}.txt
					fi

					CHOIX_DEST=""
					while [ -z "$CHOIX_DEST" ]
					do
						echo -e "$COLTXT"
						#echo -e "Quelle est la partition destination? [${COLDEFAUT}hda5${COLTXT}] $COLSAISIE\c"
						echo -e "Quelle est la partition destination? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
						read CHOIX_DEST

						if [ -z "${CHOIX_DEST}" ]; then
							#CHOIX_DEST=hda5
							CHOIX_DEST=${DEFAULTPART}
						fi
					done

					#PART_CIBLE="/dev/${CHOIX_DEST}"
					PARTSTOCK="/dev/${CHOIX_DEST}"
					PTMNTSTOCK="/mnt/${CHOIX_DEST}"
					mkdir -p ${PTMNTSTOCK}

					if [ -z "$disque_en_GPT" ]; then
						if ! fdisk -l /dev/${SAVEHD} 2>/dev/null | grep "${PARTSTOCK} " > /dev/null; then
							part_dest_ok="n"
						else
							part_dest_ok="y"
						fi
					else
						if [ -e "/sys/block/$SAVEHD/$CHOIX_DEST/size" ]; then
							part_dest_ok="y"
						else
							part_dest_ok="n"
						fi
					fi

					#if ! fdisk -s $PART_CIBLE > /dev/null; then
					#if ! fdisk -l /dev/${SAVEHD} | grep "${PART_CIBLE} " > /dev/null; then
					#if ! fdisk -l /dev/${SAVEHD} | grep "${PARTSTOCK} " > /dev/null; then
					if [ "$part_dest_ok" = "n" ]; then
						echo -e "$COLERREUR"
						echo "ERREUR: La partition proposee n'existe pas!"

						VERIF="ERREUR"

						echo -e "$COLTXT"
						echo "Appuyez sur ENTREE pour corriger votre choix."
						read PAUSE
					else
						if [ -z "${PART_SOURCE}" ]; then
							VERIF="OK"
						else
							#if [ "${PART_CIBLE}" = "${PART_SOURCE}" ]; then
							if [ "${PARTSTOCK}" = "${PART_SOURCE}" ]; then
								echo -e "$COLERREUR"
								echo "ERREUR: La partition a sauvegarder ne peut l'etre que sur une autre"
								echo "        partition."

								VERIF="ERREUR"

								echo -e "$COLTXT"
								echo "Appuyez sur ENTREE pour corriger votre choix."
								read PAUSE
							else
								VERIF="OK"
							fi
						fi
					fi
				fi
			done
			VERIF=""

			echo -e "$COLTXT"
			#echo "Quel est le type de la partition $PART_CIBLE?"
			echo "Quel est le type de la partition $PARTSTOCK?"
			echo "(vfat (pour FAT32), ext2, ext3,...)"
			#if fdisk -l /dev/${SAVEHD} | grep $PART_CIBLE | grep "W95 FAT32" > /dev/null; then
			#if fdisk -l /dev/${SAVEHD} | tr "\t" " " | grep "$PART_CIBLE " | egrep "(W95 FAT32|Win95 FAT32)" > /dev/null; then
			#DETECTED_TYPE=$(TYPE_PART $PART_CIBLE)
			DETECTED_TYPE=$(TYPE_PART $PARTSTOCK)
			if [ ! -z "${DETECTED_TYPE}" ]; then
				echo -e "Type: [${COLDEFAUT}${DETECTED_TYPE}${COLTXT}] $COLSAISIE\c"
				read TYPE

				if [ -z "$TYPE" ]; then
					TYPE=${DETECTED_TYPE}
				fi
			else
				echo -e "Type: $COLSAISIE\c"
				read TYPE
			fi

			echo -e "$COLCMD\c"
			if mount | grep "$PARTSTOCK " > /dev/null; then
				umount $PARTSTOCK
				sleep 1
			fi

			if mount | grep "${PTMNTSTOCK}" > /dev/null; then
				umount "${PTMNTSTOCK}"
				sleep 1
			fi

			echo -e "$COLTXT"
			echo "Montage de la partition ${PARTSTOCK} en ${PTMNTSTOCK}:"
			if [ -z "$TYPE" ]; then
				echo -e "${COLCMD}mount ${PARTSTOCK} ${PTMNTSTOCK}"
				mount ${PARTSTOCK} "${PTMNTSTOCK}"||ERREUR "Le montage de ${PARTSTOCK} a echoue!"
			else
				if [ "$TYPE" = "ntfs" ]; then
					echo -e "${COLCMD}ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G}"
					ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a echoue!"
					sleep 1
				else
					echo -e "${COLCMD}mount -t $TYPE ${PARTSTOCK} ${PTMNTSTOCK}"
					mount -t $TYPE ${PARTSTOCK} "${PTMNTSTOCK}" || ERREUR "Le montage de ${PARTSTOCK} a echoue!"
				fi
			fi

			echo -e "$COLTXT"
			echo "L'espace disponible sur cette partition:"
			echo -e "$COLCMD\c"
			df -h | egrep "(Filesystem|${PARTSTOCK})"
		;;

		2)
			TYPE_DEST_SVG='smb'
			echo -e "$COLPARTIE"
			echo "**********************************************************"
			echo "Vous avez choisi une sauvegarde vers un partage samba/win."
			echo "**********************************************************"


			CONFIG_RESEAU

			VERIF=""
			while [ "${VERIF}" != "OK" ]
			do
				VERIF=""

				PTMNTSTOCK="/mnt/smb"
				if mount | grep ${PTMNTSTOCK} > /dev/null; then
					umount ${PTMNTSTOCK} || ERREUR "Le point de montage ${PTMNTSTOCK} est deja support d'un montage\net n'a pas pu etre demonte."
				fi

				REPONSE=""
				while [ "$REPONSE" != "1" ]
				do
					if [ -e "/tmp/ip_smb_srv.txt" ]; then
						DEFAULT_IP_SRV=$(cat /tmp/ip_smb_srv.txt)

						echo -e "$COLTXT"
						echo -e "Quelle est l'adresse IP du serveur? [${COLDEFAUT}${DEFAULT_IP_SRV}${COLTXT}] $COLSAISIE\c"
						read IP

						if [ -z "$IP" ]; then
							IP=${DEFAULT_IP_SRV}
						fi
					else
						IP=""
						while [ -z "$IP" ]
						do
							echo -e "$COLTXT"
							echo -e "Quelle est l'adresse IP du serveur? $COLSAISIE\c"
							read IP
						done
					fi

					echo "$IP" > /tmp/ip_smb_srv.txt

					if grep "^$IP " /etc/hosts > /dev/null; then
						DEFNOMNETBIOS=$(grep "^$IP " /etc/hosts | cut -d" " -f2)

						echo -e "$COLTXT"
						echo -e "Quel est le nom NETBIOS du serveur? [${COLDEFAUT}${DEFNOMNETBIOS}${COLTXT}] $COLSAISIE\c"
						read NOMNETBIOS

						if [ -z "$NOMNETBIOS" ]; then
							NOMNETBIOS=$DEFNOMNETBIOS
						fi
					else
						echo -e "$COLTXT"
						echo -e "Quel est le nom NETBIOS du serveur? $COLSAISIE\c"
						read NOMNETBIOS
					fi

					if cat /etc/hosts | grep "^$IP " > /dev/null; then
						if ! cat /etc/hosts | grep "^$IP " | egrep "( $NOMNETBIOS$| $NOMNETBIOS )" > /dev/null; then
							chaine1=$(cat /etc/hosts | grep "^$IP ")
							chaine2="${chaine1} ${NOMNETBIOS}"
							sed -e "s/^$chaine1$/$chaine2/" /etc/hosts > /tmp/hosts
							cp -f /tmp/hosts /etc/hosts
						fi
					else
						if cat /etc/hosts | egrep "( $NOMNETBIOS$| $NOMNETBIOS )" > /dev/null; then
							egrep -v "( $NOMNETBIOS$| $NOMNETBIOS )" /etc/hosts > /tmp/hosts
							cp -f /tmp/hosts /etc/hosts
						fi
						echo "$IP $NOMNETBIOS" >> /etc/hosts
					fi

					echo -e "$COLTXT"
					if ping -c 1 $NOMNETBIOS > /dev/null; then
						echo -e "La machine ${COLINFO}${NOMNETBIOS}${COLTXT} a repondu au ping."
						REPONSE=1
					else
						echo -e "La machine ${COLINFO}${NOMNETBIOS}${COLTXT} n'a pas repondu au ping."
						echo "Si la machine filtre les ping, c'est normal."
						echo "Sinon, vous devriez annuler."

						POURSUIVRE_OU_CORRIGER "2"

						#echo -e "Voulez-vous tout de meme poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
						#read REPONSE

						#if [ "$REPONSE" != "o" ]; then
						#	ERREUR "Vous n'avez pas souhaite poursuivre."
						#fi
					fi
				done

				if [ -e /usr/bin/smbclient -o -e /usr/sbin/smbclient ]; then
					REPONSE=""
					while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
					do
						echo -e "$COLTXT"
						echo -e "Voulez-vous rechercher les partages proposes par cette machine? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
						read REPONSE
					done
	
					if [ "$REPONSE" = "o" ]; then
						REPONSE=""
						while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
						do
							echo -e "$COLTXT"
							echo -e "Voulez-vous effectuer la recherche:"
							echo -e "   (${COLCHOIX}1${COLTXT}) en vous identifiant"
							echo -e "   (${COLCHOIX}2${COLTXT}) ou en anonyme (partages publics seulement)"
							echo -e "Votre choix: (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
							read REPONSE
	
							if [ -z "$REPONSE" ]; then
								REPONSE="2"
							fi
						done
	
						if [ "$REPONSE" = "2" ]; then
							echo -e "$COLTXT"
							echo "Voici la liste des partages publics trouves:"
							echo -e "$COLCMD"
							#smbclient -L $IP -N > /tmp/liste_partages.txt 2> /dev/null
							smbclient -L $IP -N > /tmp/liste_partages.txt
						else
							echo -e "$COLTXT"
							echo -e "Veuillez saisir le nom du login: $COLSAISIE\c"
							read NOMLOGIN
	
							echo -e "$COLTXT"
							echo "Pour afficher la liste des partages visibles par $NOMLOGIN,"
							echo "vous allez devoir fournir un mot de passe:"
							echo -e "$COLCMD\c"
							#smbclient -L $IP -N > /tmp/liste_partages.txt 2> /dev/null
							smbclient -L $IP -U $NOMLOGIN > /tmp/liste_partages.txt
						fi
						FINPARTAGES=""
						cat /tmp/liste_partages.txt | tr "\t" " " | while read A
						do
							if echo "$A" | grep "Workgroup            Master" > /dev/null; then
								FINPARTAGES="o"
							fi
							if echo "$A" | grep "Server               Comment" > /dev/null; then
								FINPARTAGES="o"
							fi
							if [ "$FINPARTAGES" != "o" ]; then
								if ! echo "$A" | grep " Printer " > /dev/null; then
									echo "$A"
								fi
							fi
						done
					fi
				fi

				echo -e "$COLTXT"
				echo -e "Quel est le nom du partage sur le serveur? $COLSAISIE\c"
				read PARTAGE

				echo -e "$COLTXT"
				echo -e "Le partage necessite-t-il un login particulier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
				read LOGIN

				if [ -z "$LOGIN" ]; then
					LOGIN="n"
				fi

				NOMPRECEDENT="$NOMLOGIN"
				NOMLOGIN=""
				DEFAULT_LOGIN="admin"
				if [ "$LOGIN" = "o" ]; then
					echo -e "$COLTXT"
					if [ -z "$NOMPRECEDENT" ]; then
						#echo -e "Veuillez saisir le nom du login: $COLSAISIE\c"
						echo -e "Veuillez saisir le nom du login: [${COLDEFAUT}${DEFAULT_LOGIN}${COLTXT}] $COLSAISIE\c"
						read NOMLOGIN

						if [ -z "$NOMLOGIN" ]; then
							NOMLOGIN="${DEFAULT_LOGIN}"
						fi
					else
						echo -e "Veuillez saisir le nom du login: [${COLDEFAUT}${NOMPRECEDENT}${COLTXT}] $COLSAISIE\c"
						read NOMLOGIN

						if [ -z "$NOMLOGIN" ]; then
							NOMLOGIN="$NOMPRECEDENT"
						fi
					fi
				fi

				if [ "$LOGIN" = "o" ]; then
					CHOIX="o"
				else
					CHOIX="n"
				fi
				echo -e "$COLTXT"
				echo -e "Le partage necessite-t-il un mot de passe? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${CHOIX}${COLTXT}] $COLSAISIE\c"
				read MDP

				if [ -z "$MDP" ]; then
					MDP="$CHOIX"
				fi

				MOTDEPASSE=""
				if [ "$MDP" = "o" ]; then
					echo -e "$COLTXT"
					echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
					read MOTDEPASSE
					echo -e "\033[0;39m                                                                                "
				fi

				echo -e "$COLTXT"
				echo "Creation du point de montage:"
				echo -e "$COLCMD\c"
				echo "mkdir -p ${PTMNTSTOCK}"
				mkdir -p ${PTMNTSTOCK}
				echo -e "$COLTXT"
				echo "Montage du partage:"
				echo -e "$COLCMD\c"

				OPTIONS=""
				if [ ! -z "$NOMLOGIN" ]; then
					OPTIONS="username=$NOMLOGIN"
					#if [ ! -z "MOTDEPASSE" ]; then
					if [ "$MDP" = "o" ]; then
						OPTIONS="$OPTIONS,password=$MOTDEPASSE"
					fi
				else
					#if [ ! -z "MOTDEPASSE" ]; then
					if [ "$MDP" = "o" ]; then
						OPTIONS="password=$MOTDEPASSE"
					else
						OPTIONS="guest"
					fi
				fi

				#if [ ! -z "MOTDEPASSE" ]; then
				#	if [ -z "$OPTIONS" ]; then
				#		OPTIONS="password=$MOTDEPASSE"
				#	else
				#		OPTIONS="$OPTIONS,password=$MOTDEPASSE"
				#	fi
				#fi

				#if [ -z "$OPTIONS" ]; then
				#	OPTIONS="guest"
				#fi

				if mount | grep "//$NOMNETBIOS/$PARTAGE" > /dev/null; then
					umount "//$NOMNETBIOS/$PARTAGE" || ERREUR "//$NOMNETBIOS/$PARTAGE est deja monte\net n'a pas pu etre demonte."
				fi

				if mount | grep "${PTMNTSTOCK}" > /dev/null; then
					#smbumount ${PTMNTSTOCK} || ERREUR "Le point de montage ${PTMNTSTOCK} est deja support d'un montage\net n'a pas pu etre demonte."
					umount "${PTMNTSTOCK}" || ERREUR "Le point de montage ${PTMNTSTOCK} est deja support d'un montage\net n'a pas pu etre demonte."
				fi

				NOPWOPT=$(echo "$OPTIONS" | sed -e "s/password=$MOTDEPASSE/password=XXXXXX/")

				# BIZARRE: Avec la 0.4.2, j'ai des problemes pour monter //se3/Progs avec CIFS
				#if [ "${BOOT_IMAGE}" = "rescuecd" ]; then
				# smbmount a a nouveau disparu en 1.6.2
				if [ ! -e /usr/bin/smbmount -a ! -e /usr/sbin/smbmount ]; then
					echo "mount -t cifs //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $NOPWOPT"
					mount -t cifs //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS
					# || ERREUR "Le montage a echoue!"
					# Traitement d'erreur supprime a ce niveau parce qu'il a tendance a se produire une erreur sans grande consequence du type:
					# CIFS VFS: Send error in SETFSUnixInfo = -5
					# Par contre, le $? contient quand meme zero.
				else
					echo "smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $NOPWOPT"
					#smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS||ERREUR "Le montage a echoue!"
					smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS
				fi
				if [ "$?" != "0" ]; then
					#ERREUR "//$NOMNETBIOS/$PARTAGE est deja monte\net n'a pas pu etre demonte."
					echo -e "$COLERREUR"
					echo "ERREUR: Le montage a echoue!"
					VERIF="PB"
				fi
				echo ""

				if [ "$VERIF" != "PB" ]; then
					#CHEMINSOURCE="//$IP/$PARTAGE"
					#PART_CIBLE="//$NOMNETBIOS/$PARTAGE"
					PARTSTOCK="//$NOMNETBIOS/$PARTAGE"

					if mount | grep ${PTMNTSTOCK} > /dev/null; then
						echo -e "${COLTXT}Voici ce qui est monte en ${PTMNTSTOCK}"
						echo -e "${COLCMD}\c"
						mount | grep ${PTMNTSTOCK}

						#Test:
						echo -e "${COLTXT}"
						echo "Test d'ecriture..."
						echo -e "${COLCMD}\c"
						la_date_de_test=$(date +"%Y.%m.%d-%H.%M.%S");
						#if ! echo "Test" > "${PTMNTSTOCK}/$la_date_de_test.txt"; then
						echo "Test" > "${PTMNTSTOCK}/$la_date_de_test.txt" 2> /dev/null
						if [ "$?" != "0" ]; then
							echo -e "$COLERREUR"
							echo "Il semble qu'il ne soit pas possible d'ecrire dans ${PTMNTSTOCK}"
							echo "Le partage est peut-etre en lecture seule."
							echo "Ou alors vous n'avez pas le droit d'ecrire a la racine du partage,"
							echo "mais peut-etre avez-vous le droit dans un sous-dossier."

							REPONSE=""
							while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
							do
								echo -e "$COLTXT"
								echo -e "Voulez-vous poursuivre neanmoins? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
								read REPONSE

								if [ -z "$REPONSE" ]; then
									REPONSE="n"
									VERIF="PB"
								else
									if [ "$REPONSE" = "o" ]; then
										VERIF="OK"
									fi
								fi
							done

							#if [ "$REPONSE" != "o" ]; then
							#	ERREUR "Vous n'avez pas souhaite poursuivre."
							#fi
						else
							echo "OK."
							VERIF="OK"
							rm -f "${PTMNTSTOCK}/$la_date_de_test.txt"
						fi
					else
						echo -e "${COLERREUR}Il semble que rien ne soit monte en ${PTMNTSTOCK}"

						REPONSE=""
						while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
						do
							echo -e "$COLTXT"
							echo -e "Voulez-vous poursuivre neanmoins? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
							read REPONSE
						done

						if [ "$REPONSE" != "o" ]; then
							#ERREUR "Vous n'avez pas souhaite poursuivre."
							VERIF="PB"
						else
							VERIF="OK"
						fi
					fi
				fi
			done
			VERIF=""

			echo -e "${COLTXT}"
			echo "Appuyez sur ENTREE pour poursuivre..."
			read PAUSE
		;;
		3)
			TYPE_DEST_SVG='ssh'
			echo -e "$COLPARTIE"
			echo "****************************************************"
			echo "Vous avez choisi une sauvegarde vers un serveur SSH."
			echo "****************************************************"

			CONFIG_RESEAU

			VERIF=""
			while [ "${VERIF}" != "OK" ]
			do
				VERIF=""

				PTMNTSTOCK="/mnt/ssh"
				if mount | grep ${PTMNTSTOCK} > /dev/null; then
					umount ${PTMNTSTOCK} || ERREUR "Le point de montage ${PTMNTSTOCK} est deja support d'un montage\net n'a pas pu etre demonte."
				fi

				echo -e "$COLTXT"
				echo "Nom DNS ou Adresse du serveur SSH"
				echo -e "Dans la plupart des cas, saisir l'IP vous evitera\ndes problemes de resolution des noms de machines."
				REPONSE=""
				while [ "$REPONSE" != "1" ]
				do
					if [ -e /tmp/sshfs_srv.txt ]; then
						DEFAULT_IP_SRV=$(cat /tmp/sshfs_srv.txt)

						echo -e "$COLTXT"
						echo -e "Quel est le nom DNS ou l'IP du serveur? [${COLDEFAUT}${DEFAULT_IP_SRV}${COLTXT}] $COLSAISIE\c"
						read SERVEUR

						if [ -z "$SERVEUR" ]; then
							SERVEUR=${DEFAULT_IP_SRV}
						fi
					else
						SERVEUR=""
						while [ -z "$SERVEUR" ]
						do
							echo -e "$COLTXT"
							echo -e "Quel est le nom DNS ou l'IP du serveur? $COLSAISIE\c"
							read SERVEUR
						done
					fi

					echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$SERVEUR"

					POURSUIVRE_OU_CORRIGER 1
				done

				echo "$SERVEUR" > /tmp/sshfs_srv.txt

				REPONSE=""
				while [ "$REPONSE" != "1" ]
				do
					echo -e "$COLTXT"
					echo -e "Veuillez saisir le nom de login: [${COLDEFAUT}root${COLTXT}] $COLSAISIE\c"
					read NOMLOGIN

					if [ -z "$NOMLOGIN" ]; then
						NOMLOGIN="root"
					fi

					echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$NOMLOGIN"

					POURSUIVRE_OU_CORRIGER 1
				done

				#echo -e "$COLTXT"
				#echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
				#read MOTDEPASSE
				#echo -e "\033[0;39m                                                                                "

				echo -e "$COLTXT"
				echo -e "On accede generalement a la racine en sshfs."
				echo -e "Vous pourrez choisir le sous-dossier de sauvegarde plus loin."
				REPONSE=""
				while [ "$REPONSE" != "1" ]
				do
					echo -e "$COLTXT"
					echo -e "Veuillez choisir le dossier racine distante a monter: [${COLDEFAUT}/${COLTXT}] $COLSAISIE\c"
					read DOSSIERDISTANT

					if [ -z "$DOSSIERDISTANT" ]; then
						DOSSIERDISTANT="/"
					fi

					echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$DOSSIERDISTANT"

					POURSUIVRE_OU_CORRIGER 1
				done

				echo -e "$COLTXT"
				echo -e "Le port sur lequel tourne SSH est generalement le port 22."
				echo -e "Modifiez la valeur si le serveur a une configuration differente."
				REPONSE=""
				while [ "$REPONSE" != "1" ]
				do
					echo -e "$COLTXT"
					echo -e "Veuillez choisir le port du serveur SSH: [${COLDEFAUT}22${COLTXT}] $COLSAISIE\c"
					read PORTSSH

					if [ -z "$PORTSSH" ]; then
						PORTSSH="22"
					fi

					echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$PORTSSH"

					POURSUIVRE_OU_CORRIGER 1
				done

				echo -e "$COLTXT"
				echo "Creation du point de montage:"
				echo -e "$COLCMD"
				echo "mkdir -p ${PTMNTSTOCK}"
				mkdir -p ${PTMNTSTOCK}

				# Le module fuse est devenu inutile avec la version 0.3.8
				# La fonctionnalite est directement dans le noyau
				#echo -e "$COLTXT"
				#echo "Chargement du module fuse:"
				#echo -e "$COLCMD\c"
				#modprobe fuse

				echo -e "$COLTXT"
				echo "Montage du partage:"
				echo -e "$COLCMD\c"

				echo "sshfs -p $PORTSSH ${NOMLOGIN}@${SERVEUR}:${DOSSIERDISTANT} ${PTMNTSTOCK}"
				sshfs -p $PORTSSH ${NOMLOGIN}@${SERVEUR}:${DOSSIERDISTANT} ${PTMNTSTOCK}
				if [ "$?" != "0" ]; then
					echo -e "$COLERREUR"
					echo "ERREUR: Le montage a echoue!"
					VERIF="PB"
				fi
				# || ERREUR "Le montage a echoue!"
				echo ""

				if [ "$VERIF" != "PB" ]; then
					PART_CIBLE="sshfs://${SERVEUR}"

					if mount | grep ${PTMNTSTOCK} > /dev/null; then
						echo -e "${COLTXT}Voici ce qui est monte en ${PTMNTSTOCK}"
						echo -e "${COLCMD}\c"
						mount | grep ${PTMNTSTOCK}
						VERIF="OK"
					else
						echo -e "${COLERREUR}Il semble que rien ne soit monte en ${PTMNTSTOCK}"

						REPONSE=""
						while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
						do
							echo -e "$COLTXT"
							echo -e "Voulez-vous poursuivre neanmoins? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
							read REPONSE
						done

						if [ "$REPONSE" != "o" ]; then
							#ERREUR "Vous n'avez pas souhaite poursuivre."
							VERIF="PB"
						else
							VERIF="OK"
						fi
					fi
				fi
			done
			VERIF=""

			echo -e "${COLTXT}"
			echo "Appuyez sur ENTREE pour poursuivre..."
			read PAUSE

			PARTSTOCK="sshfs://${SERVEUR}"

			;;
		4)
			TYPE_DEST_SVG='ftp'
			echo -e "$COLPARTIE"
			echo "****************************************************"
			echo "Vous avez choisi une sauvegarde vers un serveur FTP."
			echo "****************************************************"

			PTMNTSTOCK="/mnt/ftp"
			if mount | grep ${PTMNTSTOCK} > /dev/null; then
				umount ${PTMNTSTOCK} || ERREUR "Le point de montage ${PTMNTSTOCK} est deja support d'un montage\net n'a pas pu etre demonte."
			fi


			CONFIG_RESEAU


			echo -e "$COLTXT"
			echo "Nom ou Adresse du serveur FTP:"
			echo -e "Dans la plupart des cas, saisir l'IP vous evitera\ndes problemes de resolution des noms de machines."
			echo -e "Quel est le nom ou IP du serveur? $COLSAISIE\c"
			read SERVEUR

			REPONSE=""
			while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
			do
				echo -e "$COLTXT"
				echo -e "S'agit-t-il d'un FTP anonyme (${COLCHOIX}1${COLTXT}) ou faut-il un compte/mot de passe (${COLCHOIX}2${COLTXT})? $COLSAISIE\c"
				read REPONSE
			done

			if [ "$REPONSE" = "2" ]; then
				echo -e "$COLTXT"
				echo -e "Veuillez saisir le nom du login: $COLSAISIE\c"
				read NOMLOGIN

				echo -e "$COLTXT"
				echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
				read MOTDEPASSE
				echo -e "\033[0;39m                                                                                "

				echo -e "$COLTXT"
				echo "Creation du point de montage:"
				echo -e "$COLCMD"
				echo "mkdir -p ${PTMNTSTOCK}"
				mkdir -p ${PTMNTSTOCK}
				echo -e "$COLTXT"
				echo "Montage du partage:"
				echo -e "$COLCMD\c"

				#echo "lufsmount ftpfs://${NOMLOGIN}:XXXXXX@${SERVEUR} ${PTMNTSTOCK}"
				#lufsmount ftpfs://${NOMLOGIN}:${MOTDEPASSE}@${SERVEUR} ${PTMNTSTOCK}||ERREUR "Le montage a echoue!"
				echo "lufis fs=ftpfs,host=${SERVEUR},username=${NOMLOGIN},password=XXXXXX ${PTMNTSTOCK} -s"
				lufis fs=ftpfs,host=${SERVEUR},username=${NOMLOGIN},password=${MOTDEPASSE} ${PTMNTSTOCK} -s||ERREUR "Le montage a echoue!"
				echo ""
			else

				echo -e "$COLTXT"
				echo "Creation du point de montage:"
				echo -e "$COLCMD"
				echo "mkdir -p ${PTMNTSTOCK}"
				mkdir -p ${PTMNTSTOCK}
				echo -e "$COLTXT"
				echo "Montage du partage:"
				echo -e "$COLCMD\c"

				#echo "lufsmount ftpfs://${SERVEUR} ${PTMNTSTOCK}"
				#lufsmount ftpfs://${SERVEUR} ${PTMNTSTOCK}||ERREUR "Le montage a echoue!"
				echo "lufis fs=ftpfs,host=${SERVEUR} ${PTMNTSTOCK} -s"
				lufis fs=ftpfs,host=${SERVEUR} ${PTMNTSTOCK} -s||ERREUR "Le montage a echoue!"
				echo ""
			fi

			PART_CIBLE="ftpfs://${SERVEUR}"

			if mount | grep ${PTMNTSTOCK} > /dev/null; then
				echo -e "${COLTXT}Voici ce qui est monte en ${PTMNTSTOCK}"
				echo -e "${COLCMD}\c"
				mount | grep ${PTMNTSTOCK}
			else
				echo -e "${COLERREUR}Il semble que rien ne soit monte en ${PTMNTSTOCK}"

				REPONSE=""
				while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				do
					echo -e "$COLTXT"
					echo -e "Voulez-vous poursuivre neanmoins? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
					read REPONSE
				done

				if [ "$REPONSE" != "o" ]; then
					ERREUR "Vous n'avez pas souhaite poursuivre."
				fi
			fi

			echo -e "${COLTXT}"
			echo "Appuyez sur ENTREE pour poursuivre..."
			read PAUSE
			;;
		*)
			ERREUR "Le mode de sauvegarde semble incorrect."
		;;
	esac

	# CHOIX DE SOUS-DOSSIER
	VERIF=""
	while [ "$VERIF" != "OK" ]
	do
		VERIF=""

		DEFAULT_SOUS_DOSSIER="n"
		if [ -e "${PTMNTSTOCK}/sauvegarde" -o -e "${PTMNTSTOCK}/sauvegardes" -o -e "${PTMNTSTOCK}/save" -o -e "${PTMNTSTOCK}/oscar" ]; then
			DEFAULT_SOUS_DOSSIER="o"
		fi

		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Voulez-vous effectuer la sauvegarde\ndans un sous-dossier de ${PTMNTSTOCK}? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${DEFAULT_SOUS_DOSSIER}${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="${DEFAULT_SOUS_DOSSIER}"
			fi
		done

		TEMOIN_NOUVEAU_DOSSIER="non"

		REP_DEF_CHOIX_DOSSIER="o"
		if [ "$REPONSE" = "o" ]; then
			#...
			echo -e "$COLTXT"

			echo -e "$COLTXT"
			echo "Voici les dossiers contenus dans ${PTMNTSTOCK}:"
			echo -e "$COLCMD"
			ls -l ${PTMNTSTOCK} | grep ^d > /tmp/ls.txt
			more /tmp/ls.txt

			echo -e "$COLTXT"
			echo "Dans quel dossier voulez-vous effectuer la sauvegarde?"
			echo "Completez le chemin (le dossier sera cree si necessaire)."
			echo -e "Chemin: ${COLCMD}${PTMNTSTOCK}/${COLSAISIE}\c"
			cd "${PTMNTSTOCK}"
			read -e DOSSTEMP
			cd /root

			DOSSIER=$(echo "$DOSSTEMP" | sed -e "s|/$||g")

			DESTINATION="${PTMNTSTOCK}/${DOSSIER}"
			if [ ! -e "${DESTINATION}" ]; then
				TEMOIN_NOUVEAU_DOSSIER="oui"

				echo -e "$COLCMD\c"
				mkdir -p "$DESTINATION"
				if [ "$?" != "0" ]; then
					# Cela peut arriver s'il n'y a plus de place sur la partition
					echo -e "$COLERREUR"
					echo "Echec de la creation de dossier."
					REP_DEF_CHOIX_DOSSIER="n"
				fi
			else
				mkdir -p "$DESTINATION"
			fi
		else
			DESTINATION="${PTMNTSTOCK}"

			echo -e "$COLTXT"
			echo "Test d'ecriture... "
			echo -e "$COLCMD\c"
			tmp_timestamp=$(date +%s)
			echo "Test ecriture" > ${DESTINATION}/test_ecriture_DEST_SVG_${tmp_timestamp}.txt
			if [ "$?" != "0" ]; then
				REP_DEF_CHOIX_DOSSIER="n"
				echo -e "$COLERREUR\c"
				echo "Echec"
			else
				echo -e "$COLINFO\c"
				echo "Succes"
			fi
			rm -f ${DESTINATION}/test_ecriture_DEST_SVG_${tmp_timestamp}.txt
		fi

		echo -e "$COLTXT"
		echo -e "Vous souhaitez effectuer la sauvegarde vers ${COLINFO}${DESTINATION}${COLTXT}"

		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour poursuivre..."
		read PAUSE

		if [ "${TEMOIN_NOUVEAU_DOSSIER}" != "oui" ]; then
			echo -e "$COLTXT"
			echo "Voici les fichiers contenus dans ce dossier:"
			echo -e "$COLCMD"
			sleep 1
			ls -lh ${DESTINATION} | grep -v "^d" > /tmp/ls2.txt
			more /tmp/ls2.txt
		fi

		echo -e "${COLTXT}Peut-on poursuivre avec ce choix de dossier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${REP_DEF_CHOIX_DOSSIER}${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=$REP_DEF_CHOIX_DOSSIER
		fi

		if [ "$REPONSE" != "o" ]; then
			#echo -e "$COLERREUR"
			#echo "ABANDON!"
			#echo -e "$COLTXT"
			#exit
			VERIF="PB"
		else
			VERIF="OK"
		fi
	done
	VERIF=""
}

COMPTE_A_REBOURS(){
	MSG_AV=$1
	cpt_decompte=$2
	MSG_AP=$3
	while [ ${cpt_decompte} -ge 0 ]
	do
		# Il faudrait un nombre d'espaces en fin de chaine egal a la longueur de $cpt_decompte -1
		#echo -en "\r${COLTXT}${MSG_AV} ${COLINFO}${cpt_decompte}${COLTXT} ${MSG_AP}"
		echo -en "\r${COLTXT}${MSG_AV} ${COLINFO}${cpt_decompte}${COLTXT} ${MSG_AP}    "
		cpt_decompte=$((${cpt_decompte}-1))
		sleep 1
	done
	echo ""
}

LECTEUR_CD_DVD_PAR_DEFAUT(){
	echo -e "${COLTXT}"
	echo "Voici la liste des lecteurs reperes:"
	echo -e "${COLCMD}"
	#dmesg | grep hd | grep drive | grep -v driver | grep ROM | grep Cache
	#dmesg | grep sd | grep drive | grep -v driver | grep ROM | grep Cache
	#dmesg | grep sd | grep SCSI | grep ROM
	TEMOIN=""
	if dmesg | grep hd | grep drive | grep -v driver | grep ROM | grep Cache; then
		TEMOIN="OK"
	fi

	#dmesg | grep sd | grep drive | grep -v driver | grep -v ROM
	if dmesg | grep sd | grep SCSI | grep ROM; then
		TEMOIN="OK"
	fi

	if [ "$TEMOIN" != "OK" ]; then
		#Sur les IBM Thinkpad, les commandes precedentes ne donnent rien alors que /dev/hda est bien present.
		#dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"
		if dmesg | grep dev | grep host | grep bus | grep target | grep lun >/dev/null; then
			dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"
			TEMOIN="OK"
		fi
		#Une alternative sera: ls /dev/hd*
	fi

	if [ "$TEMOIN" != "OK" ]; then
		if ls /dev/hd* | grep -v "[0-9]" > /dev/null 2> /dev/null; then
			ls /dev/hd* | grep -v "[0-9]" | sed -e "s|/dev/||g"

			LECTDEFAUT=""
		fi

		if dmesg | grep sr0 > /dev/null; then
			dmesg | grep sr0
			LECTDEFAUT="sr0"
		fi
	else
		LISTE=($(dmesg | grep hd | grep drive | grep -v driver | grep ROM | grep Cache))
		LECTDEFAUT=$(echo ${LISTE[0]} | cut -d":" -f1)
	fi
	echo ""
}

TEST_PING() {
	ping -c1 -w3 195.221.20.10 > /dev/null 2>&1
	echo $?
}

TEST_WGET() {
	wget -t 1 --connect-timeout=3 -o /tmp/test_wget_google_$(date +%Y%m%d%H%M%S).html http://www.google.fr 2> /dev/null
	echo $?
}

TEST_DNS() {
	host www.google.fr > /dev/null 2>&1
	echo $?
}

ENVOI_MAIL() {
	if [ -z "$ladate" ]; then
		ladate=$(date +%Y%m%d%H%M%S)
	fi

	tmp=/tmp/envoi_mail_${ladate}
	mkdir -p $tmp

	if [ -e "/tmp/smtp.txt" ]; then
		default_smtp=$(cat /tmp/smtp.txt)

		REPONSE=""
		while [ "${REPONSE}" != "1" ]
		do
			smtp=""
			echo -e "$COLTXT"
			echo -e "Quel smtp utiliser? [${COLDEFAUT}${default_smtp}${COLTXT}] ${COLSAISIE}\c"
			read smtp

			if [ -z "$smtp" ]; then
				smtp=${default_smtp}
			fi

			echo -e "${COLINFO}Vous avez choisi ${COLCHOIX}$smtp"

			POURSUIVRE_OU_CORRIGER "1"
		done
	else
		REPONSE=""
		if [ -e "/root/liste_smtp.txt" ]; then
			echo -e "$COLTXT"
			echo "Liste des SMTP references:"
			echo -e "$COLCMD\c"
			more /root/liste_smtp.txt

			while [ "${REPONSE}" != "o" -a "${REPONSE}" != "n" ]
			do	
				echo -e "$COLTXT"
				echo -e "Voulez-vous utiliser un smtp de la liste ci-dessus? [${COLDEFAUT}o${COLTXT}] (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="o"
				fi
			done
		fi

		if [ "${REPONSE}" = "o" ]; then
			cpt=1
			while read A
			do
				if [ -n "$A" -a "${A:0:1}" != "#" ]; then
					TAB_SMTP[$cpt]=$A
					cpt=$(($cpt+1))
				fi
			done < /root/liste_smtp.txt

			REPONSE=""
			while [ "$REPONSE" != "1" ]
			do
				echo -e "$COLTXT"
				echo "Quel smtp voulez-vous utiliser?"
				cpt=1
				while [ $cpt -le ${#TAB_SMTP[*]} ]
				do
					echo -e "   ${COLCHOIX}${cpt}${COLTXT} ${TAB_SMTP[$cpt]}"
					cpt=$(($cpt+1))
				done

				echo -e "$COLTXT"
				echo -e "Votre choix: $COLSAISIE\c"
				read REP_SMTP

				t=$(echo "$REP_SMTP" | sed -e "s|[0-9]||g")
				if [ -z "$t" -a -n "${TAB_SMTP[$REP_SMTP]}" ]; then
					echo -e "${COLINFO}"
					echo -e "Vous avez choisi ${COLCHOIX}${TAB_SMTP[$REP_SMTP]}"
	
					POURSUIVRE_OU_CORRIGER "1"
				fi
			done

			smtp=${TAB_SMTP[$REP_SMTP]}
		else
			REPONSE=""
			while [ "${REPONSE}" != "1" ]
			do
				smtp=""
				echo -e "$COLTXT"
				echo -e "Quel smtp utiliser? ${COLSAISIE}\c"
				read smtp
	
				echo -e "${COLINFO}Vous avez choisi ${COLCHOIX}$smtp"
	
				POURSUIVRE_OU_CORRIGER "1"
			done
		fi

		echo "$smtp" > /tmp/smtp.txt
	fi

	#============================================
	if [ -e "/tmp/mail_from.txt" ]; then
		default_mail_from=$(cat /tmp/mail_from.txt)

		REPONSE=""
		while [ "${REPONSE}" != "1" ]
		do
			mail_from=""
			echo -e "$COLTXT"
			echo -e "Quel est l'expediteur? [${COLDEFAUT}${default_mail_from}${COLTXT}] ${COLSAISIE}\c"
			read mail_from

			if [ -z "$mail_from" ]; then
				mail_from=${default_mail_from}
			fi

			echo -e "${COLINFO}"
			echo -e "Vous avez choisi ${COLCHOIX}$mail_from"

			if echo "$mail_from"| grep -q ".@."; then
				DEF_REP=1
			else
				DEF_REP=2
			fi

			POURSUIVRE_OU_CORRIGER "${DEF_REP}"
		done
	else
		REPONSE=""
		while [ "${REPONSE}" != "1" ]
		do
			mail_from=""
			echo -e "$COLTXT"
			echo -e "Quel est l'expediteur? ${COLSAISIE}\c"
			read mail_from

			echo -e "${COLINFO}"
			echo -e "Vous avez choisi ${COLCHOIX}$mail_from"

			if echo "$mail_from"| grep -q ".@."; then
				DEF_REP=1
			else
				DEF_REP=2
			fi

			POURSUIVRE_OU_CORRIGER "${DEF_REP}"
		done

		echo "$mail_from" > /tmp/mail_from.txt
	fi

	#============================================
	if [ -e "/tmp/mail_to.txt" ]; then
		default_mail_to=$(cat /tmp/mail_to.txt)

		REPONSE=""
		while [ "${REPONSE}" != "1" ]
		do
			mail_to=""
			echo -e "$COLTXT"
			echo -e "Quel est le destinataire? [${COLDEFAUT}${default_mail_to}${COLTXT}] ${COLSAISIE}\c"
			read mail_to

			if [ -z "$mail_to" ]; then
				mail_to=${default_mail_to}
			fi

			echo -e "${COLINFO}"
			echo -e "Vous avez choisi ${COLCHOIX}$mail_to"

			if echo "$mail_to"| grep -q ".@."; then
				DEF_REP=1
			else
				DEF_REP=2
			fi

			POURSUIVRE_OU_CORRIGER "${DEF_REP}"
		done
	else
		REPONSE=""
		while [ "${REPONSE}" != "1" ]
		do
			mail_to=""
			echo -e "$COLTXT"
			echo -e "Quel est le destinataire? ${COLSAISIE}\c"
			read mail_to

			echo -e "${COLINFO}"
			echo -e "Vous avez choisi ${COLCHOIX}$mail_to"

			if echo "$mail_to"| grep -q ".@."; then
				DEF_REP=1
			else
				DEF_REP=2
			fi

			POURSUIVRE_OU_CORRIGER "${DEF_REP}"
		done

		echo "$mail_to" > /tmp/mail_to.txt
	fi
	#============================================

	default_mail_subject="[SysRescCD]: ${ladate}"
	REPONSE=""
	while [ "${REPONSE}" != "1" ]
	do
		mail_subject=""
		echo -e "$COLTXT"
		echo -e "Quel est le sujet du mail? [${COLDEFAUT}${default_mail_subject}${COLTXT}] ${COLSAISIE}\c"
		read mail_subject

		if [ -z "$mail_subject" ]; then
			mail_subject=${default_mail_subject}
		fi

		echo -e "${COLINFO}"
		echo -e "Vous avez choisi ${COLCHOIX}$mail_subject"

		POURSUIVRE_OU_CORRIGER "1"
	done
	#============================================

	if [ -e "${1}" ]; then
		fichier_mail=${1}
		echo -e "$COLINFO"
		echo -e "Le fichier ${COLCHOIX}${fichier_mail}${COLINFO} va etre expedie..."
	else
		dossier_initial=$PWD
		cd /

		# Choisir le fichier a envoyer
		echo -e "$COLTXT"
		echo -e "Quel fichier faut-il envoyer?\c"
		REPONSE=""
		while [ "${REPONSE}" != "1" ]
		do
			fichier_mail=""
			echo -e "$COLTXT"
			echo "Chemin absolu: ${COLSAISIE}\c"
			read -e fichier_mail

			if [ ! -e "$fichier_mail" ]; then
				echo -e "${COLERREUR}"
				echo -e "Le fichier ${COLCHOIX}$fichier_mail${COLERREUR} n'existe pas."
			else
				echo -e "${COLINFO}"
				echo -e "Vous avez choisi ${COLCHOIX}$fichier_mail"
	
				POURSUIVRE_OU_CORRIGER "1"
			fi
		done
		cd ${dossier_initial}
	fi
	#============================================

	# Entete... du mail
	echo -e "$COLCMD"
	echo "HELO
MAIL FROM: ${mail_from}
RCPT TO: ${mail_to}
DATA
SUBJECT: ${mail_subject}
" > $tmp/mail_${ladate}.txt

	# Corps du mail
	cat ${1} >> $tmp/mail_${ladate}.txt

	# Fin du mail
	echo ".

QUIT
" >> $tmp/mail_${ladate}.txt

	# Envoi du mail
	telnet ${smtp} 25 < $tmp/mail_${ladate}.txt
	if [ "$?" = "0" ]; then
		echo -e "$COLINFO"
		echo "Succes de l'envoi..."
	else
	echo -e "$COLERREUR"
		echo "Echec de l'envoi..."
	fi
	echo -e "$COLTXT"
}

CALCULE_TAILLE() {
	if [ -z "$1" ]; then
		echo "Erreur: Il n'est pas possible de convertir une chaine vide."
	else
		t=$(echo "$1" | sed -e 's/[0-9]//g')
		if [ -n "$t" ]; then
			echo "Erreur: La chaine n'est pas numerique."
		else
			chaine=""
			t=$1
			if [ $t -gt 1048576 ]; then
				g=$(($t/1048576))
				m=$((($t-$g*1048576)/1024))
				echo "${g} Go ${m} Mo"
			else
				if [ $t -gt 1024 ]; then
					m=$(($t/1024))
					echo "${m} Mo"
				else
					echo "${t} o"
				fi
			fi
		fi
	fi
}

CLEAN_IP() {
	# Pour nettoyer les caracteres non affichables que l'on obtient si on a le malheur d'utiliser les fleches de direction pendant une saisie,...
	TMP_IP=$1

	tmp_check_ip1=$(echo "$TMP_IP" | cut -d"." -f1|sed -e "s|[^0-9]||g")
	tmp_check_ip2=$(echo "$TMP_IP" | cut -d"." -f2|sed -e "s|[^0-9]||g")
	tmp_check_ip3=$(echo "$TMP_IP" | cut -d"." -f3|sed -e "s|[^0-9]||g")
	tmp_check_ip4=$(echo "$TMP_IP" | cut -d"." -f4|sed -e "s|[^0-9]||g")

	TMP_IP=$tmp_check_ip1.$tmp_check_ip2.$tmp_check_ip3.$tmp_check_ip4

	echo $TMP_IP
}

CHECK_IP() {
	TMP_IP=$1

	tmp_check_ip1=$(echo "$TMP_IP" | cut -d"." -f1)
	tmp_check_ip2=$(echo "$TMP_IP" | cut -d"." -f2)
	tmp_check_ip3=$(echo "$TMP_IP" | cut -d"." -f3)
	tmp_check_ip4=$(echo "$TMP_IP" | cut -d"." -f4)
	#echo -e "tmp_check_ip1=$tmp_check_ip1"
	#echo -e "tmp_check_ip2=$tmp_check_ip2"
	#echo -e "tmp_check_ip3=$tmp_check_ip3"
	#echo -e "tmp_check_ip4=$tmp_check_ip4"

	t=$(echo "$tmp_check_ip1"|sed -e "s|[0-9]||g")
	if [ -n "$t" ]; then
		tmp_check_ip1=""
	fi
	t=$(echo "$tmp_check_ip2"|sed -e "s|[0-9]||g")
	if [ -n "$t" ]; then
		tmp_check_ip2=""
	fi
	t=$(echo "$tmp_check_ip3"|sed -e "s|[0-9]||g")
	if [ -n "$t" ]; then
		tmp_check_ip3=""
	fi
	t=$(echo "$tmp_check_ip4"|sed -e "s|[0-9]||g")
	if [ -n "$t" ]; then
		tmp_check_ip4=""
	fi


	if [ -z "$tmp_check_ip1" ]; then
		TMP_IP=""
	else
		if [ "$tmp_check_ip1" != "0" ]; then
			if [ $tmp_check_ip1 -lt 1 -o $tmp_check_ip1 -gt 255  ]; then
				TMP_IP=""
			fi
		fi

		if [ -z "$tmp_check_ip2" ]; then
			TMP_IP=""
		else
			if [ "$tmp_check_ip2" != "0" ]; then
				if [ $tmp_check_ip2 -lt 1 -o $tmp_check_ip2 -gt 255  ]; then
					TMP_IP=""
				fi
			fi

			if [ -z "$tmp_check_ip3" ]; then
				TMP_IP=""
			else
				if [ "$tmp_check_ip3" != "0" ]; then
					if [ $tmp_check_ip3 -lt 1 -o $tmp_check_ip3 -gt 255  ]; then
						TMP_IP=""
					fi
				fi

				if [ -z "$tmp_check_ip4" ]; then
					TMP_IP=""
				else
					if [ "$tmp_check_ip4" != "0" ]; then
						if [ $tmp_check_ip4 -lt 1 -o $tmp_check_ip4 -gt 255  ]; then
							TMP_IP=""
						fi
					fi
				fi
			fi
		fi
	fi

	echo $TMP_IP
}

CHECK_PART_ACTIVE() {
	TMP_HD=$1

	if [ -z "$TMP_HD" ]; then
		TMP_HD=$(GET_DEFAULT_DISK)
	fi

	if [ -z "$TMP_HD" ]; then
		#echo -e "$COLERREUR"
		#echo "ERREUR: Aucun disque trouve."
		exit
	fi

	NUM_PART=$(parted -s /dev/$TMP_HD print | grep 'boot$' | sed -e "s|^ ||g"|cut -d" " -f1)
	echo $NUM_PART
}

GET_GW() {
	route|grep "^default"|tr "\t" " "|sed -e "s| \{2,\}| |g"|cut -d" " -f2
}

CHERCHE_DNS() {
	test_verbeux=$(echo "$*"|grep "verbeux")

	if [ -e "/tmp/GW.txt" ]; then
		GW=$(cat /tmp/GW.txt)
	else
		GW=$(GET_GW)
	fi

	for i in $GW 195.221.20.10 194.167.110.1 212.27.40.240 212.27.40.241 212.27.54.252 212.27.53.252 193.252.19.3 193.252.19.4
	do
		if [ -n "$test_verbeux" ]; then
			echo -e "${COLTXT}Test DNS de ${COLCHOIX}$i${COLTXT}: \c"
		fi
		echo "nameserver $i" > /etc/resolv.conf
		host www.google.fr 2>&1 > /dev/null
		if [ "$?" = "0" ]; then
			if [ -n "$test_verbeux" ]; then
				echo -e "${COLINFO}Succes de la resolution DNS"
			fi
			break
		else
			if [ -n "$test_verbeux" ]; then
				echo -e "${COLERREUR}Echec de la resolution DNS"
			fi
		fi
	done
}

# check that device $1 is an USB-stick
is_dev_usb_stick()
{
	curdev="$1"
	
	remfile="/sys/block/${curdev}/removable"
	if [ -f "${remfile}" ] && cat ${remfile} 2>/dev/null | grep -qF '1' \
		&& cat /sys/block/${curdev}/device/uevent 2>/dev/null | grep -qF 'DRIVER=sd'
	then
		#vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
		#model="$(cat /sys/block/${curdev}/device/model 2>/dev/null)"
		#return 0
		echo 0
	else
		#return 1
		echo 1
	fi
}

# check that device $1 is an USB-HD
is_dev_usb_hd()
{
	curdev="$1"

	#remfile="/sys/block/${curdev}/removable"

	t=$(readlink /sys/block/${curdev}|grep "/usb")
	#t2=$(find /sys/block/${TEST_DRIVE}/ -name partition)

	if [ -n "$t" -a -n "$(cat /sys/block/${curdev}/device/uevent 2>/dev/null | grep -F 'DRIVER=sd')" ]
	then
		#vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
		#model="$(cat /sys/block/${curdev}/device/model 2>/dev/null)"
		#return 0
		echo 0
	else
		#return 1
		echo 1
	fi
}

get_infos_dev() {
	curdev="$1"

	vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
	model="$(cat /sys/block/${curdev}/device/model 2>/dev/null | tr "\t" " " | sed -e 's/ $//g')"

	chaine_tmp=$(echo "${vendor} ${model}" | sed -e "s|^ ||g" | sed -e "s| \{2,\}| |g")
	echo -e "${COLTXT}Le peripherique [${COLINFO}/dev/${curdev}${COLTXT}] detecte comme [${COLINFO}${chaine_tmp}${COLTXT}]\c"

	if [ -n "$(which blockdev)" ]
	then
		secsizeofdev="$(blockdev --getsz /dev/${curdev})"
		mbsizeofdev="$((secsizeofdev/2048))"
		echo -e " et taille=${COLINFO}${mbsizeofdev}MB${COLTXT}"
	fi
	echo ""
}

FICHIERS_RAPPORT_CONFIG_MATERIELLE() {
	dest=$1
	if [ -z "$dest" ]; then
		dest="."
	fi

	if [ -n "$2" ]; then
		prefixe="$2."
	fi

	t=$(whereis lshw)
	if [ -n "$t" ]; then
		lshw > $dest/${prefixe}lshw.txt
	fi

	t=$(whereis lspci)
	if [ -n "$t" ]; then
		lspci > $dest/${prefixe}lspci.txt
		lspci -n > $dest/${prefixe}lspci-n.txt
	fi

	t=$(whereis lsmod)
	if [ -n "$t" ]; then
		lsmod > $dest/${prefixe}lsmod.txt
	fi

	t=$(whereis dmidecode)
	if [ -n "$t" ]; then
		dmidecode > $dest/${prefixe}dmidecode.txt
	fi

	t=$(whereis lsusb)
	if [ -n "$t" ]; then
		lsusb > $dest/${prefixe}lsusb.txt
	fi
}

CALCULE_DUREE() {
	t1=$1
	t2=$2
	duree=""
	if [ -n "$t1" -a -n "$t2" ]; then
		if [ $t2 -ge $t1 ]; then
			d=$(($t2-$t1))
			h=$(($d/3600))
			m=$((($d-$h*3600)/60))
			s=$(($d-$h*3600-$m*60))

			if [ $m -lt 10 ]; then
				m="0$m"
			fi

			if [ $s -lt 10 ]; then
				s="0$s"
			fi

			duree="${h}H${m}M${s}S"
		fi
	fi
	echo $duree
}

LISTE_PART() {
	if [ "${1:0:5}" = "/dev/" ]; then
		TMP_HD=$(echo "$1"|sed -e "s|^/dev/||")
	else
		TMP_HD=$1
	fi

	type_part_cherche=$(echo "$*"|tr " " "\n"|grep "^type_part_cherche="|cut -d"=" -f2)
	afficher_liste=$(echo "$*"|tr " " "\n"|grep "^afficher_liste="|cut -d"=" -f2)
	avec_tableau_liste=$(echo "$*"|tr " " "\n"|grep "^avec_tableau_liste="|cut -d"=" -f2)
	avec_part_exclue_du_tableau=$(echo "$*"|tr " " "\n"|grep "^avec_part_exclue_du_tableau="|cut -d"=" -f2)
	#echo "avec_part_exclue_du_tableau=$avec_part_exclue_du_tableau">/tmp/debug_avec_part_exclue_du_tableau.txt

	tmp_fich_dest=/tmp/liste_part_extraite_par_LISTE_PART.txt
	if [ -e $tmp_fich_dest ]; then
		rm -f $tmp_fich_dest
	fi
	touch $tmp_fich_dest

	TMP_HD_CLEAN=$(echo ${TMP_HD}|sed -e "s|[^0-9A-Za-z]|_|g")
	# 20130624
	#fdisk -l /dev/$TMP_HD > /tmp/fdisk_l_${TMP_HD_CLEAN}.txt 2>&1
	#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${TMP_HD}'" /tmp/fdisk_l_${TMP_HD_CLEAN}.txt|cut -d"'" -f2)

	#t=$(parted /dev/${TMP_HD} print|grep -i "Partition Table: gpt")
	#if [ -n "$t" ]; then

	if [ "$(IS_GPT_PARTTABLE ${TMP_HD})" = "y" ]; then
		TMP_disque_en_GPT=/dev/${TMP_HD}
	else
		TMP_disque_en_GPT=""
	fi

	if [ -z "$TMP_disque_en_GPT" ]; then
		# Disque avec une table de partition classique : msdos
		if [ -z "$type_part_cherche" ]; then
			if [ "$afficher_liste" = "y" ]; then
				fdisk -l /dev/${TMP_HD}
			fi
			fdisk -l /dev/${TMP_HD} | grep "^/dev/${TMP_HD}" | tr "\t" " " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -vi "Dell Utility" | cut -d" " -f1 > $tmp_fich_dest
		elif [ "$type_part_cherche" = "linux" ]; then
			if [ "$afficher_liste" = "y" ]; then
				fdisk -l /dev/${TMP_HD}|grep -Ei "(Linux|^ |Device)" | grep -v "Linux swap" | grep -v -i "linux-swap"
			fi
			fdisk -l /dev/${TMP_HD} | grep "^/dev/${TMP_HD}" | tr "\t" " " | grep -i "Linux" | grep -v "Linux swap" | grep -v -i "linux-swap" | cut -d" " -f1 > $tmp_fich_dest
		elif [ "$type_part_cherche" = "ntfs" ]; then
			if [ "$afficher_liste" = "y" ]; then
				fdisk -l /dev/${TMP_HD}|grep -Ei "(ntfs|^ |Device)" | grep -vi "xtended" | grep -vi "Hidden"
			fi
			fdisk -l /dev/${TMP_HD} | grep "^/dev/${TMP_HD}" | tr "\t" " " | grep -i "ntfs" | grep -vi "xtended" | grep -vi "Hidden" | cut -d" " -f1 > $tmp_fich_dest
		elif [ "$type_part_cherche" = "fat" ]; then
			if [ "$afficher_liste" = "y" ]; then
				fdisk -l /dev/${TMP_HD}|grep -Ei "(fat32|fat16|vfat|w95|win95|msdos|^ |Device)" | grep -vi "xtended" | grep -vi "Hidden"
			fi
			fdisk -l /dev/${TMP_HD} | grep "^/dev/${TMP_HD}" | tr "\t" " " | grep -Ei "(fat32|fat16|vfat|w95|win95|msdos)" | cut -d" " -f1 > $tmp_fich_dest
		elif [ "$type_part_cherche" = "windows" ]; then
			if [ "$afficher_liste" = "y" ]; then
				fdisk -l /dev/${TMP_HD}|grep -Ei "(ntfs|fat32|fat16|vfat|w95|win95|msdos|^ |Device)" | grep -vi "xtended" | grep -vi "Hidden"
			fi
			fdisk -l /dev/${TMP_HD} | grep "^/dev/${TMP_HD}" | tr "\t" " " | grep -Ei "(ntfs|fat32|fat16|vfat|w95|win95|msdos)" | cut -d" " -f1 > $tmp_fich_dest
		elif [ "$type_part_cherche" = "non_ntfs" ]; then
			if [ "$afficher_liste" = "y" ]; then
				fdisk -l /dev/${TMP_HD}|grep -vi "ntfs"| grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility"
			fi
			fdisk -l /dev/${TMP_HD} | grep "^/dev/${TMP_HD}" | tr "\t" " " |grep -vi "ntfs"| grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -vi "Dell Utility" | cut -d" " -f1 > $tmp_fich_dest
		fi
	else

#echo 1

		# Disque avec une table de partition classique : GPT
		TMP_HD_CLEAN=$(echo ${TMP_HD}|sed -e "s|[^0-9A-Za-z]|_|g")
		# A REVOIR: Il ne faudrait peut-etre pas eliminer les partitions Hidden et Dell Utility a ce stade
		#parted /dev/${TMP_HD_CLEAN} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" | grep -vi "Linux swap" | grep -vi "xtended" | grep -vi "W95 Ext'd" | grep -vi "Hidden" | grep -v "Dell Utility" > /tmp/partitions_${TMP_HD_CLEAN}.txt
		parted /dev/${TMP_HD_CLEAN} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" | grep -vi "Linux swap" | grep -vi "linux-swap" | grep -vi "xtended" | grep -vi "W95 Ext'd" > /tmp/partitions_${TMP_HD_CLEAN}.txt

#echo 2

		if [ "$afficher_liste" = "y" ]; then
			parted /dev/${TMP_HD} print|grep "^Number "
		fi

#echo 3

		if [ -z "$type_part_cherche" ]; then
			while read A
			do
				if [ "$afficher_liste" = "y" ]; then
					echo "${TMP_HD}${A}"
				fi
				NUM_PART=$(echo "$A"|cut -d" " -f1)

				t=$(echo "$A"|grep -vi "Hidden"|grep -vi "Dell Utility")
				if [ -n "$t" ]; then
					echo "${TMP_HD}${NUM_PART}" >> $tmp_fich_dest
				fi
			done < /tmp/partitions_${TMP_HD_CLEAN}.txt
		elif [ "$type_part_cherche" = "linux" ]; then
			while read A
			do
				NUM_PART=$(echo "$A"|cut -d" " -f1)
				TMP_TYPE=$(parted /dev/${TMP_HD}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
				if [ "$TMP_TYPE" = "ext2" -o "$TMP_TYPE" = "ext3" -o "$TMP_TYPE" = "ext4" -o "$TMP_TYPE" = "reiserfs" -o "$TMP_TYPE" = "xfs" -o "$TMP_TYPE" = "jfs" ]; then
					if [ "$afficher_liste" = "y" ]; then
						echo "${TMP_HD}${A}"
					fi
					NUM_PART=$(echo "$A"|cut -d" " -f1)
					echo "${TMP_HD}${NUM_PART}" >> $tmp_fich_dest
				fi
			done < /tmp/partitions_${TMP_HD_CLEAN}.txt
		elif [ "$type_part_cherche" = "ntfs" ]; then
			while read A
			do
				NUM_PART=$(echo "$A"|cut -d" " -f1)
				TMP_TYPE=$(parted /dev/${TMP_HD}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
				if [ "$TMP_TYPE" = "ntfs" ]; then
					if [ "$afficher_liste" = "y" ]; then
						echo "${TMP_HD}${A}"
					fi
					NUM_PART=$(echo "$A"|cut -d" " -f1)
					echo "${TMP_HD}${NUM_PART}" >> $tmp_fich_dest
				fi
			done < /tmp/partitions_${TMP_HD_CLEAN}.txt
		elif [ "$type_part_cherche" = "fat" ]; then
			while read A
			do
				NUM_PART=$(echo "$A"|cut -d" " -f1)
				TMP_TYPE=$(parted /dev/${TMP_HD}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
				if [ "$TMP_TYPE" = "fat16" -o "$TMP_TYPE" = "fat32" -o "$TMP_TYPE" = "vfat" -o "$TMP_TYPE" = "msdos" -o "$TMP_TYPE" = "w95" -o "$TMP_TYPE" = "win95" ]; then
					if [ "$afficher_liste" = "y" ]; then
						echo "${TMP_HD}${A}"
					fi
					NUM_PART=$(echo "$A"|cut -d" " -f1)
					echo "${TMP_HD}${NUM_PART}" >> $tmp_fich_dest
				fi
			done < /tmp/partitions_${TMP_HD_CLEAN}.txt
		elif [ "$type_part_cherche" = "windows" ]; then
#echo 4
			while read A
			do
				NUM_PART=$(echo "$A"|cut -d" " -f1)
				TMP_TYPE=$(parted /dev/${TMP_HD}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
				if [ "$TMP_TYPE" = "ntfs" -o "$TMP_TYPE" = "fat16" -o "$TMP_TYPE" = "fat32" -o "$TMP_TYPE" = "vfat" -o "$TMP_TYPE" = "msdos" -o "$TMP_TYPE" = "w95" -o "$TMP_TYPE" = "win95" ]; then
					if [ "$afficher_liste" = "y" ]; then
						echo "${TMP_HD}${A}"
					fi
					NUM_PART=$(echo "$A"|cut -d" " -f1)
					echo "${TMP_HD}${NUM_PART}" >> $tmp_fich_dest
#echo 5
				fi
			done < /tmp/partitions_${TMP_HD_CLEAN}.txt
		elif [ "$type_part_cherche" = "non_ntfs" ]; then
			while read A
			do
				NUM_PART=$(echo "$A"|cut -d" " -f1)
				t=$(echo "$A"| grep -vi "Linux swap" | grep -v -i "linux-swap" | grep -vi "xtended" | grep -vi "W95 Ext'd" | grep -vi "Hidden" | grep -vi "Dell Utility")
				if [ -n "$t" ]; then
					TMP_TYPE=$(parted /dev/${TMP_HD}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
					if [ "$TMP_TYPE" != "ntfs" ]; then
						if [ "$afficher_liste" = "y" ]; then
							echo "${TMP_HD}${A}"
						fi
						NUM_PART=$(echo "$A"|cut -d" " -f1)
						echo "${TMP_HD}${NUM_PART}" >> $tmp_fich_dest
					fi
				fi
			done < /tmp/partitions_${TMP_HD_CLEAN}.txt
		fi
	fi

#echo 6
	if [ -n "$avec_part_exclue_du_tableau" ]; then
		#cat $tmp_fich_dest>>/tmp/debug_avec_part_exclue_du_tableau.txt
		#echo "\${avec_part_exclue_du_tableau:0:4}=${avec_part_exclue_du_tableau:0:4}">>/tmp/debug_avec_part_exclue_du_tableau.txt

		#if [ "${avec_part_exclue_du_tableau:0:4}" = "/dev" ]; then
		#	sed -i "/^${avec_part_exclue_du_tableau}$/d" $tmp_fich_dest
		#else
		#	sed -i "#^/dev/${avec_part_exclue_du_tableau}$#d" $tmp_fich_dest
		#	#sed -i "|^/dev/${avec_part_exclue_du_tableau}$|d" $tmp_fich_dest
		#fi

		rm -f $tmp_fich_dest.tmp
		mv $tmp_fich_dest $tmp_fich_dest.tmp
		while read A
		do
			if [ -n "$A" ]; then
				if [ "$A" != "${avec_part_exclue_du_tableau}" -a "$A" != "/dev/${avec_part_exclue_du_tableau}" ]; then
					echo "$A">$tmp_fich_dest
				fi
			fi
		done < $tmp_fich_dest.tmp

		#cat $tmp_fich_dest>>/tmp/debug_avec_part_exclue_du_tableau.txt
	fi
#echo 7

	if [ "$avec_tableau_liste" = "y" ]; then
		tmp_cpt=0
		# 20130903
		chaine_liste_tmp_part=""
		while read A
		do
			if [ $tmp_cpt -ge 1 ]; then
				chaine_liste_tmp_part="${chaine_liste_tmp_part}_"
			fi
				chaine_liste_tmp_part="${chaine_liste_tmp_part}${A}"
			liste_tmp[$tmp_cpt]=$A
			tmp_cpt=$((tmp_cpt+1))
#echo 8
		done < $tmp_fich_dest
	fi
}

AFFICHE_LIGNES_INTERFACES_CONFIGUREES() {
	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:" > /dev/null; then
			echo -e "${COLTXT}Une interface autre que 'lo' est configuree, voici sa config:${COLCMD}"
			ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:"
			CHOIX=1
		fi
	else
		if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 " > /dev/null; then
			echo -e "${COLTXT}Une interface autre que 'lo' est configuree, voici sa config:${COLCMD}"
			ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 "
			CHOIX=1
		fi
	fi
}

TEST_SI_AU_MOINS_UNE_INTERFACE_EST_CONFIGUREE() {
	RETOUR=0
	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:" > /dev/null; then
			RETOUR=1
		fi
	else
		if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 " > /dev/null; then
			RETOUR=1
		fi
	fi
	echo $RETOUR
}

AFFICHE_CONFIG_IP_IFACE() {
	tmp_iface=$1

	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		echo "ifconfig $tmp_iface | grep inet | grep -v \"inet6 addr:\""
		ifconfig $tmp_iface | grep inet | grep -v "inet6 addr:"
	else
		echo "ifconfig $tmp_iface | grep inet | grep -v \"inet6 \""
		ifconfig $tmp_iface | grep inet | grep -v "inet6 "
	fi
}

RENSEIGNE_ligne_CONFIG_IP_IFACE() {
	tmp_iface=$1

	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		echo "ifconfig $tmp_iface | grep inet | grep -v \"inet6 addr:\""
		ligne=$(ifconfig $tmp_iface | grep inet | grep -v "inet6 addr:")
	else
		echo "ifconfig $tmp_iface | grep inet | grep -v \"inet6 \""
		ligne=$(ifconfig $tmp_iface | grep inet | grep -v "inet6 ")
	fi
}

TYPE_TABLE_PART() {
	TMP_HD=$1
	type=$(parted /dev/${TMP_HD} print|grep -i "^Partition Table:"|cut -d":" -f2|sed -e "s|^[ ]||g")
	echo $type
}

IS_GPT_PARTTABLE() {
	TMP_HD=$1
	type=$(TYPE_TABLE_PART $TMP_HD | tr "[A-Z]" "[a-z]")
	if [ "$type" = "gpt" ]; then
		echo "y"
	else
		echo "n"
	fi
}

PING_PATIENTER() {
	IP=$1

	if [ -z "$2" ]; then
		nb=300
	else
		nb=$2
	fi

	cpt=0
	while [ $cpt -lt $nb ]
	do
		ping -c1 -W1 $IP >/dev/null 2>&1
		if [ "$?" = "0" ]; then
			echo "$IP repond au ping"
			cpt=$((nb+1))
		else
			echo -e "$cpt \c"
		fi

		cpt=$((cpt+1))
	done
}

GET_INFO_HD() {
	curdev=$1
	if [ -e "/sys/block/$curdev/device" ]; then
		if [ -n "$(which blockdev)" ]
		then
			secsizeofdev="$(blockdev --getsz /dev/${curdev})"
			mbsizeofdev="$((secsizeofdev/2048))"
			sizemsg=" et taille=${mbsizeofdev}MB"
		fi
		vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
		model="$(cat /sys/block/${curdev}/device/model 2>/dev/null | tr "\t" " " | sed -e 's/ $//g')"

		chaine_tmp=$(echo "${vendor} ${model}" | sed -e "s|^ ||g" | sed -e "s| \{2,\}| |g")
		echo "Le peripherique [${curdev}] detecte comme [${chaine_tmp}] est amovible${sizemsg}"
	fi
}


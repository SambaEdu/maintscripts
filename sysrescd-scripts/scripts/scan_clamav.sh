#!/bin/sh

# Script de scan antivirus avec clamav sur DiglooRescueCD
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 26/02/2013

# **********************************
# Version adaptée à Digloo Rescue CD
# **********************************

source /bin/crob_fonctions.sh

PTMNT="/mnt/disk"
mkdir -p "$PTMNT"


echo -e "$COLTITRE"
echo "****************************************"
echo "* Script de scan antiviral avec clamav *"
echo "****************************************"

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n"  ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous effectuer la mise à jour des signatures de virus? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLINFO"
	echo "Pour récupérer les signatures, le réseau doit être configuré."
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
	do
		CHOIX=2
		if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
			if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:" > /dev/null; then
				echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
				ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:"
				CHOIX=1
			fi
		else
			if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 " > /dev/null; then
				echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
				ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 "
				CHOIX=1
			fi
		fi

		echo -e "${COLTXT}\n"
		echo -e "Si le réseau est OK, tapez       ${COLCHOIX}1${COLTXT}"
		echo -e "Pour configurer le réseau, tapez ${COLCHOIX}2${COLTXT}"
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
		echo "problèmes lorsqu'il est lancé sans être passé par une console avant le lancement"
		echo "(cas du lancement via l'autorun)."
		echo "Un script alternatif est proposé, mais il ne permet pas, contrairement au script"
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
				/bin/net_setup.sh
				iface=$(cat /tmp/iface.txt)
			fi
			#DiglooRescueCD
			#net_setup eth0
			#Puppy:
			#net-setup.sh

			echo -e "$COLTXT"
			echo "Voici la config IP:"
			echo -e "$COLCMD\c"
			if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
				echo "ifconfig $iface | grep inet | grep -v \"inet6 addr:\""
				ifconfig $iface | grep inet | grep -v "inet6 addr:"
			else
				echo "ifconfig $iface | grep inet | grep -v \"inet6 \""
				ifconfig $iface | grep inet | grep -v "inet6 "
			fi

			echo -e "$COLTXT"
			echo -e "Voulez-vous corriger/modifier cette configuration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REP

			if [ -z "$REP" ]; then
				REP="n"
			fi
		done
	fi

	#Récupérer IP et MASK
	echo -e "$COLCMD\c"
	if [ -z "$iface" ]; then
		iface="eth0"
	fi

	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		IP=$(ifconfig ${iface} | grep "inet " | cut -d":" -f2 | cut -d" " -f1)
		MASK=$(ifconfig ${iface} | grep "inet " | cut -d":" -f4 | cut -d" " -f1)
	else
		IP=$(ifconfig ${iface} | grep "inet "|sed -e "s|^ *||g"| cut -d" " -f2)
		MASK=$(ifconfig ${iface} | grep "inet "|sed -e "s|.*netmask ||g"|cut -d" " -f1)
	fi

	if ! ping -c1 -W1 www.google.fr > /dev/null; then
		echo -e "$COLTXT"
		echo "Il semble que la passerelle soit inaccessible ou non définie,"
		echo "ou alors le serveur DNS est inaccessible ou non défini."

		echo -e "$COLTXT"
		echo "Voici les routes définies:"
		echo -e "$COLCMD"
		route

		echo -e "$COLTXT"
		echo "Voici le(s) serveur(s) DNS défini(s):"
		echo -e "$COLCMD"
		cat /etc/resolv.conf

		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n"  ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous (re)définir la passerelle? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		done

		if [ "$REPONSE" = "o" ]; then
			if [ "$MASK" = "255.255.0.0" ]; then
				tmpip1=$(echo "$IP" | cut -d"." -f1)
				tmpip2=$(echo "$IP" | cut -d"." -f2)
				TMPGW="$tmpip1.$tmpip2.164.1"
			else
				tmpip1=$(echo "$IP" | cut -d"." -f1)
				tmpip2=$(echo "$IP" | cut -d"." -f2)
				tmpip3=$(echo "$IP" | cut -d"." -f3)
				TMPGW="$tmpip1.$tmpip2.$tmpip3.1"
			fi

			echo -e "$COLTXT"
			echo -e "Passerelle: [${COLDEFAUT}${TMPGW}${COLTXT}] $COLSAISIE\c"
			read GW


			if [ -z "$GW" ]; then
				GW="${TMPGW}"
			fi
		fi

		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n"  ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous (re)définir un serveur DNS? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		done

		if [ "$REPONSE" = "o" ]; then
			if [ "$MASK" = "255.255.0.0" ]; then
				tmpip1=$(echo "$IP" | cut -d"." -f1)
				tmpip2=$(echo "$IP" | cut -d"." -f2)
				TMPDNS="$tmpip1.$tmpip2.164.1"
			else
				TMPDNS="${DNS_ACAD}"
			fi

			echo -e "$COLTXT"
			echo -e "Serveur DNS: [${COLDEFAUT}${TMPDNS}${COLTXT}] $COLSAISIE\c"
			read DNS

			if [ -z "$DNS" ]; then
				DNS="${TMPDNS}"
			fi


			echo -e "$COLTXT"
			echo -e "Renseignement du DNS..."
			echo -e "$COLCMD\c"

			#echo "nameserver $DNS" > /tmp/mnt/$SYSRESCDPART/etc/resolv.conf
			echo "nameserver $DNS" > /etc/resolv.conf
		fi
	fi

	REPPROXY=""
	while [ "$REPPROXY" != "o" -a "$REPPROXY" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Devez-vous passer par un proxy pour aller sur internet? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPPROXY
	done

	if [ "$REPPROXY" = "o" ]; then
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
		echo -e "Renseignement du proxy"
		echo -e "$COLCMD\c"
		export http_proxy="http://$PROXY:$PORT"
		export ftp_proxy="http://$PROXY:$PORT"

		#mv /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.initial
		#cat /etc/clamav/freshclam.conf.initial | grep -v "HTTPProxyServer" | grep -v "HTTPProxyPort" > /etc/clamav/freshclam.conf
		#echo "HTTPProxyServer $PROXY" >> /etc/clamav/freshclam.conf
		#echo "HTTPProxyPort $PORT" >> /etc/clamav/freshclam.conf
		mv /etc/freshclam.conf /etc/freshclam.conf.initial
		cat /etc/freshclam.conf.initial | grep -v "HTTPProxyServer" | grep -v "HTTPProxyPort" > /etc/freshclam.conf
		echo "HTTPProxyServer $PROXY" >> /etc/freshclam.conf
		echo "HTTPProxyPort $PORT" >> /etc/freshclam.conf
	else
		echo -e "$COLTXT"
		echo -e "Suppression d'un éventuel proxy..."
		echo -e "$COLCMD\c"
		export http_proxy=""
		export ftp_proxy=""
		mv /etc/freshclam.conf /etc/freshclam.conf.initial
		cat /etc/freshclam.conf.initial | grep -v "HTTPProxyServer" | grep -v "HTTPProxyPort" > /etc/freshclam.conf
	fi

	echo -e "$COLTXT"
	echo "Lancement de la mise à jour..."
	echo -e "$COLCMD"
	freshclam
fi

echo -e "$COLPARTIE"
echo "==============================="
echo "Choix de la partition à scanner"
echo "==============================="

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	DISK=""
	while [ -z "$DISK" ]
	do
		AFFICHHD
	
		DEFAULTDISK=$(GET_DEFAULT_DISK)
	
		echo -e "$COLTXT"
		echo "Sur quel disque se trouve la partition à scanner?"
		echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
		echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
		read DISK
	
		if [ -z "$DISK" ]; then
			DISK=${DEFAULTDISK}
		fi

		tst=$(sfdisk -s /dev/$DISK 2>/dev/null)
		if [ -z "$tst" -o ! -e "/sys/block/$DISK" ]; then
			echo -e "$COLERREUR"
			echo "Le disque $DISK n'existe pas."
			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour corriger."
			read PAUSE
			DISK=""
		fi
	done


	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo "Voici les partitions sur le disque /dev/$DISK:"
		#echo ""
		echo -e "$COLCMD\c"
		fdisk -l /dev/$DISK
		LISTE_PART ${DISK} afficher_liste=y
		#echo ""

		#liste_tmp=($(fdisk -l /dev/$DISK | grep "^/dev/$DISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | cut -d" " -f1))
		LISTE_PART ${DISK} avec_tableau_liste=y
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			DEFAULTPART="${DISK}1"
		fi

		echo -e "$COLTXT"
		echo "Quelle est la partition à scanner?"
		echo " (probablement $DEFAULTPART,...)"
		echo -e "Partition: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
		read PARTITION
		echo ""
	
		if [ -z "$PARTITION" ]; then
			PARTITION="$DEFAULTPART"
		fi
	
		#Vérification:
		#if ! fdisk -s /dev/$PARTITION > /dev/null; then
		t=$(fdisk -s /dev/$PARTITION)
		if [ -z "$t" -o ! -e "/sys/block/$DISK/$PARTITION" ]; then
			echo -e "$COLERREUR"
			echo "ERREUR: La partition proposée n'existe pas!"
			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour corriger."
			read PAUSE
			#exit 1
			REPONSE="2"
		else
			REPONSE=""
		fi
	
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
			read REPONSE
	
			if [ -z "$REPONSE" ]; then
				REPONSE="1"
			fi
		done
	done


	echo -e "$COLTXT"
	echo "Quel est le type de la partition $PARTITION?"
	echo "(vfat (pour FAT32), ext2, ext3,...)"
	DETECTED_TYPE=$(TYPE_PART $PARTITION)
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

	# BIZARRE... IL A L'AIR DE FAIRE LE DEMONTAGE SYSTEMATIQUEMENT
	# Effectivement: Lorsque la partition a déjà été montée, le nettoyage n'est pas fait après un umount.
	# On obtient toujours une figne dans 'mount' comme si la partition était encore montée.
	# RECTIFICATION: Il semble qu'elle finisse par disparaitre???
	# A creuser...
	echo -e "$COLCMD\c"
	if mount | grep "$PARTITION " > /dev/null; then
		umount /dev/$PARTITION
		sleep 1
	fi

	# BIZARRE... IL A L'AIR DE FAIRE LE DEMONTAGE SYSTEMATIQUEMENT
	if mount | grep $PTMNT > /dev/null; then
		umount $PTMNT
		sleep 1
	fi

	echo -e "$COLTXT"
	echo "Montage de la partition $PARTITION en $PTMNT:"
	if [ -z "$TYPE" ]; then
		echo -e "${COLCMD}mount /dev/$PARTITION $PTMNT"
		mount /dev/$PARTITION "$PTMNT"||ERREUR "Le montage de $PARTITION a échoué!"
	else
		echo -e "${COLCMD}mount -t $TYPE /dev/$PARTITION $PTMNT"
		mount -t $TYPE /dev/$PARTITION "$PTMNT"||ERREUR "Le montage de $PARTITION a échoué!"
	fi

	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done
done

echo -e "$COLPARTIE"
echo "=========================="
echo "Choix du dossier à scanner"
echo "=========================="

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Voulez-vous limiter le scan à un sous-dossier de ${PTMNT}? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	#...
	echo -e "$COLTXT"

	echo -e "$COLTXT"
	echo "Voici les dossiers contenus dans ${PTMNT}:"
	echo -e "$COLCMD"
	ls -l ${PTMNT} | grep ^d > /tmp/ls.txt
	more /tmp/ls.txt

	echo -e "$COLTXT"
	echo "Quel dossier souhaitez-vous scanner?"
	echo -e "Chemin: ${COLCMD}${PTMNT}/${COLSAISIE}\c"
	cd "${PTMNT}"
	read -e DOSSTEMP
	cd /root

	DOSSIER=$(echo "$DOSSTEMP" | sed -e "s|/$||g")

	DOSSIERSCAN="${PTMNT}/${DOSSIER}"
else
	DOSSIERSCAN="${PTMNT}"
fi

echo -e "$COLTXT"
echo -e "Vous souhaitez scanner ${COLINFO}${DOSSIERSCAN}${COLTXT}"

echo -e "${COLTXT}Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
read REPONSE

if [ -z "$REPONSE" ]; then
	REPONSE="o"
fi

if [ "$REPONSE" != "o" ]; then
	echo -e "$COLERREUR"
	echo "ABANDON!"
	echo -e "$COLTXT"
	exit
fi

# Il faudra proposer différents types de scans... ou de saisir des options...

echo -e "$COLTXT"
echo "Lancement du scan..."
echo -e "$COLCMD"
ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
#clamscan -ri "$DOSSIERSCAN" | tee -a "/tmp/scan_clamav.${ladate}.log"
# PROBLEME pour renvoyer la sortie d'erreur en tee
#clamscan -ri "$DOSSIERSCAN" 2> "/tmp/scan_clamav.${ladate}.log"
clamscan -ri "$DOSSIERSCAN" 2>&1 | tee "/tmp/scan_clamav.${ladate}.log"

echo -e "$COLTXT"
echo "Le rappel des logs est disponible dans le fichier suivant:"
echo -e "$COLINFO\c"
echo "   /tmp/scan_clamav.${ladate}.log"

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous consulter le contenu fichier? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo "Voici le contenu du fichier:"
	echo -e "$COLCMD"
	more /tmp/scan_clamav.${ladate}.log
fi

echo -e "$COLINFO"
echo "Si des fichiers sont infectés, il est possible de les mettre en quarantaine."
echo "Déplacer des fichiers peut cependant perturber le fonctionnement du système."
echo "Réfléchissez-y à deux fois..."

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous mettre des fichiers en quarantaine? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	#if fdisk -l /dev/$DISK | tr "\t" " " | grep "^/dev/$PARTITION " | grep "HPFS/NTFS" > /dev/null ; then
	type_fs=$(TYPE_PART $PARTITION)
	if [ "$type_fs" = "ntfs" ]; then
		echo -e "$COLINFO"
		echo "La partition /dev/$PARTITION est une partition NTFS."
		echo "Pour y déplacer des fichiers, il est nécessaire de remonter la partition en lecture écriture."

		echo -e "$COLTXT"
		echo "Démontage de la partition..."
		echo -e "$COLCMD\c"
		umount /mnt/disk

		#	echo -e "$COLTXT"
		#	echo "Préparation du montage avec captive-ntfs..."
		#	echo -e "$COLCMD\c"
		#	#cp /sysresccd/ntfs2/* /var/lib/captive/
		#	# PROBLEME: Si on a boote avec cdcache...
		#	cp ${mnt_cdrom}/sysresccd/ntfs2/* /var/lib/captive/
		#	#if ! lsmod | grep "^fuse " > /dev/null; then
		#	#	insmod /lib/modules/2.6.15.6/kernel/fs/fuse/fuse.ko
		#	#fi
		#	#if ! lsmod | grep "^lufs " > /dev/null; then
		#	#	insmod /lib/modules/2.6.15.6/kernel/fs/lufs.ko
		#	#fi
		#	#cd /
		#	#tar -xzf /digloo/dev_fuse.tar.gz
		#	echo -e "$COLTXT"
		#	echo -e "Montage de ${COLINFO}/dev/${PARTITION}${COLTXT} avec captive-ntfs..."
		#	echo -e "$COLCMD\c"
		#	#mount -t captive-ntfs /dev/$PARTITION /mnt/disk
		#	mount.captive-ntfs /dev/$PARTITION /mnt/disk

		echo -e "Montage de ${COLINFO}/dev/${PARTITION}${COLTXT} avec ntfs-g3..."
		echo -e "$COLCMD\c"
		ntfs-g3 /dev/$PARTITION /mnt/disk
	fi

	mkdir -p /mnt/disk/quarantaine_${ladate}
	grep "^/mnt/disk/" /tmp/scan_clamav.${ladate}.log | grep FOUND | while read A
	do
		fichier=$(echo "$A" | cut -d":" -f1)
		virus=$(echo "$A" | cut -d":" -f2 | sed -e "s/^ //" | sed -e "s/ FOUND$//")

		# Effectuer le traitement...
		echo -e "$COLTXT"
		echo -e "Voulez-vous mettre le fichier suivant infecté par ${COLINFO}$virus"
		echo -e "${COLTXT}en quarantaine:"
		echo -e "${COLINFO}   $fichier"
		echo -e "${COLTXT}Réponse: [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE < /dev/tty

		if [ "$REPONSE" = "o" ]; then
			echo -e "$COLCMD"
			chemin_tmp=$(dirname "$fichier" | sed -e "s|/mnt/disk/||")
			mkdir -p "/mnt/disk/quarantaine_${ladate}/$chemin_tmp"
			#mv "$fichier" "/mnt/disk/quarantaine_${ladate}"
			mv "$fichier" "/mnt/disk/quarantaine_${ladate}/$chemin_tmp/"
		fi
	done
fi

echo -e "$COLTXT"
echo "Démontage de la partition..."
echo -e "$COLCMD"
umount /mnt/disk

echo -e "$COLTITRE"
echo "***********"
echo "* Terminé *"
echo "***********"
echo -e "$COLTXT"

echo "Appuyez sur ENTREE pour terminer."
read PAUSE

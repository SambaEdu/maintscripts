#!/bin/sh

# Auteur: Stephane Boireau
# Derniere modification: 18/11/2013

source /bin/crob_fonctions.sh

echo -e "$COLTITRE"
echo "************************"
echo "* Clonage avec Udpcast *"
echo "************************"

echo -e "$COLCMD\c"
if mount | grep ${mnt_cdrom} > /dev/null; then
	grep docache /proc/cmdline > /dev/null
	if [ $? -eq 1 ]; then
		# Il n'est pas possible d'éjecter le CD.
		ejection_cd="n"
	else
		echo -e "$COLTXT"
		echo "Démontage et éjection du CD."
		echo -e "$COLCMD\c"
		umount ${mnt_cdrom}
		eject
	fi
fi

CONFIG_RESEAU

# On fait une pause parce que sinon, ça quitte... mais je ne saisis pas pourquoi.
sleep 1

if [ -z "$1" ]; then
	#echo -e "$COLERREUR"
	#echo "USAGE: Passer en paramètres:"
	#echo "       - 'emetteur' ou 'recepteur' en paramètre '\$1'"
	#echo "       - 'hda', 'hda1',... 'sda', 'sda1',... en paramètre '\$2'"
	#echo "         pour le périphérique à cloner."
	#echo -e "$COLTXT"
	#exit

	MODE=""
	while [ "$MODE" != "1" -a "$MODE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Le poste est-il le modèle (émetteur) (${COLCHOIX}1${COLTXT})"
		echo -e "ou un clone (récepteur) (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
		read MODE

		if [ -z "$MODE" ]; then
			MODE="2"
		fi
	done

	echo -e "$COLTXT"
	echo "Vous allez devoir indiquer ce qui doit être copié:"
	echo " 'hda', 'hda1',... 'sda', 'sda1',..."

	AFFICHHD

	DEFAULTDISK=$(GET_DEFAULT_DISK)

	DISK=""
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel disque souhaitez-vous cloner,"
		echo -e "ou sur quel disque se trouve la partition à cloner? [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
		read DISK

		if [ -z "$DISK" ]; then
			DISK=${DEFAULTDISK}
		fi

		#if ! fdisk -s /dev/$DISK > /dev/null 2>&1; then
		t=$(fdisk -s /dev/$DISK 2>/dev/null)
		if [ -z "$t" -o ! -e "/sys/block/$DISK" ]; then
			#root@sysresccd /root % cat /sys/block/sda/removable 
			#0
			# Avec 0 ce n'est pas un DD USB
			#root@sysresccd /root % cat /sys/block/sda/size     
			#41943040
			#root@sysresccd /root %
			echo -e "$COLERREUR\c"
			echo "ERREUR: Le disque proposé n'existe pas!"
			REPONSE="2"
		else
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="1"
			fi
		fi
	done

	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous cloner:"
		echo -e "   (${COLCHOIX}1${COLTXT}) tout le disque"
		echo -e "   (${COLCHOIX}2${COLTXT}) seulement une partition?"
		echo -e "Votre choix: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done

	if [ "$REPONSE" = "1" ]; then
		#FICHIER=$DISK
		FICHIER="/dev/$DISK"
	else
		echo -e "$COLTXT"
		echo "Voici les partitions présentes sur le disque /dev/$DISK"
		echo -e "$COLCMD\c"
		#fdisk -l /dev/$DISK
		LISTE_PART ${DISK} afficher_liste=y

		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do

			#liste_tmp=($(fdisk -l /dev/$DISK | grep "^/dev/$DISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))
			LISTE_PART ${DISK} avec_tableau_liste=y
			if [ ! -z "${liste_tmp[0]}" ]; then
				DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
			else
				DEFAULTPART="${DISK}1"
			fi

			PART=""
			echo -e "$COLTXT"
			echo -e "Quelle partition souhaitez-vous cloner? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
			read PART

			if [ -z "$PART" ]; then
				PART=$DEFAULTPART
			fi

			echo -e "${COLTXT}"
			echo -e "Vous avez choisi /dev/${COLINFO}${PART}"

			#if ! fdisk -s /dev/$PART > /dev/null 2>&1; then
			t=$(fdisk -s /dev/$PART 2>/dev/null)
			if [ -z "$t" -o ! -e "/sys/block/$DISK/$PART/partition" ]; then
				echo -e "$COLERREUR\c"
				echo "ERREUR: La partition proposée n'existe pas!"
				REPONSE="2"
			else
				echo -e "$COLTXT"
				echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="1"
				fi
			fi
		done

		#FICHIER=$PART
		FICHIER="/dev/$PART"
	fi

	PORT=""
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel port souhaitez-vous utiliser? [${COLDEFAUT}9002${COLTXT}] $COLSAISIE\c"
		read PORT

		if [ -z "$PORT" ]; then
			PORT=9002
		fi

		echo -e "${COLTXT}"
		echo -e "Vous avez choisi le port ${COLINFO}${PORT}"

		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done

	GET_INTERFACE_DEFAUT
	if [ -e /tmp/iface.txt ]; then
		DEFAULT_INTERFACE=$(cat /tmp/iface.txt)
	else
		DEFAULT_INTERFACE=eth0
	fi

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		INTERFACE=""
		echo -e "$COLTXT"
		echo -e "Quelle interface souhaitez-vous utiliser? [${COLDEFAUT}${DEFAULT_INTERFACE}${COLTXT}] $COLSAISIE\c"
		read INTERFACE

		if [ -z "$INTERFACE" ]; then
			INTERFACE=${DEFAULT_INTERFACE}
		fi

		echo -e "${COLTXT}"
		echo -e "Vous avez choisi l'interface ${COLINFO}${INTERFACE}"

		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		COMPR=""
		echo -e "$COLTXT"
		echo -e "Voulez-vous compresser avant d'émettre et"
		echo -e "décompresser sur le récepteur pour réduire le trafic réseau? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
		read COMPR

		if [ -z "$COMPR" ]; then
			COMPR="o"
		fi

		if [ "$COMPR" = "o" ]; then
			echo -e "${COLTXT}"
			echo -e "Vous souhaitez utiliser la compression."
			COMPRESSION="lzop"
		else
			echo -e "${COLTXT}"
			echo -e "Vous ne souhaitez pas utiliser la compression."
			COMPRESSION=""
		fi

		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done

else
	PORT=9002

	GET_INTERFACE_DEFAUT
	if [ -e /tmp/iface.txt ]; then
		INTERFACE=$(cat /tmp/iface.txt)
	else
		INTERFACE=eth0
	fi

	COMPRESSION="lzop"

	if [ "$1" = "emetteur" ]; then
		MODE=1
	else
		if [ "$1" = "recepteur" ]; then
			MODE=2
		fi
	fi

	if [ -z "$2" ]; then
		FICHIER="/dev/sda"
	else
		FICHIER="/dev/$2"
	fi

	if ! fdisk -s $FICHIER > /dev/null 2>&1; then
		echo -e "$COLERREUR"
		echo "ATTENTION: Le disque présélectionné $FICHIER n'existe pas!"

		AFFICHHD

		DEFAULTDISK=$(GET_DEFAULT_DISK)

		DISK=""
		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel disque souhaitez-vous cloner,"
			echo -e "ou sur quel disque se trouve la partition à cloner? [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
			read DISK

			if [ -z "$DISK" ]; then
				DISK=${DEFAULTDISK}
			fi

			if ! fdisk -s /dev/$DISK > /dev/null 2>&1; then
				echo -e "$COLERREUR\c"
				echo "ERREUR: Le disque proposé n'existe pas!"
				REPONSE="2"
			else
				echo -e "$COLTXT"
				echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="1"
				fi
			fi
		done

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous cloner:"
			echo -e "   (${COLCHOIX}1${COLTXT}) tout le disque"
			echo -e "   (${COLCHOIX}2${COLTXT}) seulement une partition?"
			echo -e "Votre choix: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="1"
			fi
		done

		if [ "$REPONSE" = "1" ]; then
			#FICHIER=$DISK
			FICHIER="/dev/$DISK"
		else
			echo -e "$COLTXT"
			echo "Voici les partitions présentes sur le disque /dev/$DISK"
			echo -e "$COLCMD\c"
			#fdisk -l /dev/$DISK
			LISTE_PART ${DISK} afficher_liste=y

			REPONSE=""
			while [ "$REPONSE" != "1" ]
			do

				#liste_tmp=($(fdisk -l /dev/$DISK | grep "^/dev/$DISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))
				LISTE_PART ${DISK} avec_tableau_liste=y
				if [ ! -z "${liste_tmp[0]}" ]; then
					DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
				else
					DEFAULTPART="${DISK}1"
				fi

				PART=""
				echo -e "$COLTXT"
				echo -e "Quelle partition souhaitez-vous cloner? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
				read PART

				if [ -z "$PART" ]; then
					PART=$DEFAULTPART
				fi

				echo -e "${COLTXT}"
				echo -e "Vous avez choisi /dev/${COLINFO}${PART}"

				if ! fdisk -s /dev/$PART > /dev/null 2>&1; then
					echo -e "$COLERREUR\c"
					echo "ERREUR: La partition proposée n'existe pas!"
					REPONSE="2"
				else
					echo -e "$COLTXT"
					echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
					read REPONSE

					if [ -z "$REPONSE" ]; then
						REPONSE="1"
					fi
				fi
			done

			#FICHIER=$PART
			FICHIER="/dev/$PART"
		fi
	fi

	#if [ ! -z "$3" ]; then
	#	#COMPRESSION="$3"
	#	COMPRESSION="lzop"
	#else
	#	COMPRESSION=""
	#fi
fi

datedebut=`date "+%Y-%m-%d %H:%M:%S"`
echo "Debut: $datedebut" > /tmp/dates.txt

if [ "$MODE" = "1" ]; then
	echo -e "$COLINFO"
	echo "Emetteur:"
	if [ "$COMPRESSION" = "lzop" ]; then
		echo -e "$COLTXT"
		echo "udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE --pipe 'lzop -c -f -'"
		echo -e "$COLCMD\c"
		udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE --pipe 'lzop -c -f -'
	else
		echo -e "$COLTXT"
		echo "udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE"
		echo -e "$COLCMD\c"
		udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE
	fi
else
	if [ "$MODE" = "2" ]; then
		echo -e "$COLINFO"
		echo "Récepteur:"
		if [ "$COMPRESSION" = "lzop" ]; then
			echo -e "$COLTXT"
			echo "udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd --pipe 'lzop -d -c -f -'"
			echo -e "$COLCMD\c"
			udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd --pipe 'lzop -d -c -f -'
		else
			echo -e "$COLTXT"
			echo "udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd"
			echo -e "$COLCMD\c"
			udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd
		fi

		if [ "$?" != "0" ]; then
			echo -e "$COLERREUR"
			echo "Il semble qu'un problème se soit produit."
			echo "Le clonage pourrait bien avoir échoué."
			echo -e "$COLTXT"
			read PAUSE
			#exit
		fi
	else
		echo -e "$COLERREUR"
		echo "Le mode choisi n'existe pas."
		read PAUSE
	fi
fi

echo -e "$COLTITRE"
echo "*****************"
echo "* Durée écoulée *"
echo "*****************"

echo -e "$COLTXT"
echo "Voici les dates relevées..."
echo -e "$COLCMD"
datefin=`date "+%Y-%m-%d %H:%M:%S"`
echo "Fin:   $datefin" >> /tmp/dates.txt
cat /tmp/dates.txt
echo -e "$COLINFO"
echo "Ces dates peuvent être incorrectes si les machines n'étaient pas à l'heure."
echo "Mais la différence entre les heures de début et de fin donne le temps de"
echo "clonage."

echo -e "$COLTITRE"
echo "***********"
echo "* Terminé *"
echo "***********"
echo -e "$COLTXT"
read PAUSE


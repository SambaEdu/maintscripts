#!/bin/sh

# Script de mise en place des pilotes NTFS XP
# CE N'EST PLUS LE CAS: LE SCRIPT N'UTILISE PLUS captive-ntfs mais ntfs-3g
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 02/02/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "*******************************"
echo "*  Ce script doit vous aider  *"
#echo "*      à mettre en place      *"
#echo "*    le pilote NTFS de XP     *"
#echo "*  pour permettre un montage  *"
echo "* à monter une partition NTFS *"
echo "*     en lecture/écriture     *"
echo "*******************************"

echo -e "$COLERREUR"
echo "Ce script utilisait captive-ntfs... et il existe maintenant sur SysRescCd"
echo "la solution ntfs-3g (plus performante) pour obtenir un accès en lecture-"
echo "écriture."

# Et captive-ntfs n'est plus présent.

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous monter une partition NTFS en lecture/écriture? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLPARTIE"
	echo "=============================="
	echo "Choix de la partition à monter"
	echo "=============================="

	echo -e "$COLTXT"
	echo "Voici la liste des disques détectés sur votre machine:"
	echo -e "$COLCMD"

	HD=""
	while [ -z "$HD" ]
	do
		AFFICHHD
	
		DEFAULTDISK=$(GET_DEFAULT_DISK)
	
		echo -e "$COLTXT"
		echo "Sur quel disque se trouve la partition à monter?"
		echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
		echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
		read HD
	
		if [ -z "$HD" ]; then
			HD=${DEFAULTDISK}
		fi

		tst=$(sfdisk -s /dev/$HD 2>/dev/null)
		if [ -z "$tst" -o ! -e "/sys/block/$HD" ]; then
			echo -e "$COLERREUR"
			echo "Le disque $HD n'existe pas."
			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour corriger."
			read PAUSE
			HD=""
		fi
	done

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo "Voici les partitions sur le disque /dev/$HD:"
		echo -e "$COLCMD"
		#echo "fdisk -l /dev/$HD"
		#fdisk -l /dev/$HD
		LISTE_PART ${HD} afficher_liste=y

		#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep "HPFS/NTFS" | cut -d" " -f1))
		LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=ntfs
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			DEFAULTPART="hda1"
		fi
	
		echo -e "$COLTXT"
		echo -e "Quelle est la partition à monter? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
		read PARTNT
	
		if [ -z "$PARTNT" ]; then
			PARTNT=${DEFAULTPART}
		fi

		#if ! fdisk -s /dev/$PARTNT > /dev/null; then
		t=$(fdisk -s /dev/$PARTNT)
		if [ -z "$t" -o ! -e "/sys/block/$HD/$PARTNT" ]; then
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


	PARTNTFS="/dev/$PARTNT"

	echo -e "$COLINFO"
	echo "RECAPITULATIF:"
	echo -e "$COLTXT"
	echo "Vous vous apprêtez à monter la partition $PARTNTFS en lecture/écriture."
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done

	if [ "$REPONSE" = "n" ]; then
		echo -e "$COLERREUR"
		echo "ABANDON!"
		echo -e "$COLTXT"
		read PAUSE
		exit 0
	fi

	echo -e "$COLPARTIE"
	echo "======================="
	echo "Montage de la partition"
	echo "======================="

	echo -e "$COLCMD"
	if mount | grep "$PARTNTFS " > /dev/null; then
		umount $PARTNTFS
	fi

	if mount | grep "/mnt/ntfs" > /dev/null; then
		umount /mnt/ntfs
	fi

	echo "mkdir -p /mnt/ntfs"
	mkdir -p /mnt/ntfs
	#echo "mount.captive-ntfs $PARTNTFS /mnt/ntfs"
	#mount.captive-ntfs $PARTNTFS /mnt/ntfs||ERREUR "Le montage a échoué!"
	echo "ntfs-3g $PARTNTFS /mnt/ntfs"
	ntfs-3g $PARTNTFS /mnt/ntfs -o ${OPT_LOCALE_NTFS3G} ||ERREUR "Le montage a échoué!"

	echo -e "$COLTXT"
	echo "La partition est maintenant $PARTNTFS montée en lecture/écriture sur /mnt/ntfs"
fi

echo -e "$COLTITRE"
echo "Bye!"
echo -e "$COLTXT"
echo "Appuyez sur une touche pour quitter."
read PAUSE


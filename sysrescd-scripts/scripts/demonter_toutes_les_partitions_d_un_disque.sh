#!/bin/sh

# Script de demontage de toutes les partitions d'un disque dur
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 04/02/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "************************************************"
echo "* Script de demontage de toutes les partitions *"
echo "*              d'un disque dur                 *"
echo "************************************************"

echo -e "$COLPARTIE"
echo "==================="
echo "Choix du disque dur"
echo "==================="

#echo -e "$COLTXT"
#echo "Voici la liste des disques détectés sur votre machine:"
#echo -e "$COLCMD"

HD=""
REP_NTFS=""

if echo "$*" | grep -q "HD="; then
	HD=$(echo "$*" | sed -e "s/ /\n/g" | grep "HD=" | cut -d"=" -f2 | sed -e "s|^/dev/||")
else
	t=$(echo "$1"|sed -e "s|[a-z]||g")
	if [ -n "$1" -a -z "$t" ]; then
		HD=$1
	fi
fi

if [ -n "$HD" ]; then
	tst=$(sfdisk -s /dev/$HD 2>/dev/null)
	if [ -z "$tst" ]; then
		echo -e "$COLERREUR"
		echo "Le disque $HD n'existe pas."
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour corriger."
		read PAUSE
		HD=""
	else
		AUTO=y
		REP_NTFS=1
	fi
fi

while [ -z "$HD" ]
do
	AFFICHHD
	
	#liste_tmp=($(sfdisk -g | grep "^/dev/" | cut -d":" -f1 | cut -d"/" -f3))
	#if [ ! -z "${liste_tmp[0]}" ]; then
	#	DEFAULTDISK=${liste_tmp[0]}
	#else
	#	DEFAULTDISK="hda"
	#fi
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque se trouvent les partitions à demonter?"
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

echo -e "$COLTXT"
echo "Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
LISTE_PART ${HD} afficher_liste=y

echo -e "$COLTXT"
echo "Parmi elles, celles qui sont montees sont:"
echo -e "$COLCMD"
mount|grep "/dev/$HD"

if [ "$AUTO" != "y" ]; then
	POURSUIVRE "o"
fi

mount|grep "/dev/$HD"|cut -d" " -f1|while read A
do
	echo -e "$COLTXT"
	echo "Demontage de $A"
	echo -e "$COLCMD\c"
	umount $A
	if [ "$?" != "0" ]; then
		echo -e "$COLERREUR"
		echo "Echec du demontage de $A"
	fi
done

echo -e "$COLTITRE"
echo "Terminé!"
echo -e "$COLTXT"
if [ "$AUTO" != "y" ]; then
	echo "Appuyez sur une touche pour quitter."
	read PAUSE
fi


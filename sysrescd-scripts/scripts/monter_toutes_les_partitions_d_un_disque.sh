#!/bin/sh

# Script de montage de toutes les partitions d'un disque dur
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 05/03/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "**********************************************"
echo "* Script de montage de toutes les partitions *"
echo "*             d'un disque dur                *"
echo "**********************************************"

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
	echo "Sur quel disque se trouvent les partitions à monter?"
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

if [ "$AUTO" != "y" ]; then
	POURSUIVRE "o"
fi

COMMANDE_MONTAGE_NTFS="mount -t ntfs"
#if fdisk -l /dev/$HD | grep -i "HPFS/NTFS" > /dev/null; then
LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=ntfs
if [ -n "${liste_tmp[0]}" ]; then
	while [ "${REP_NTFS}" != "1" -a "${REP_NTFS}" != "2" ]
	do
		echo -e "$COLTXT"
		echo "Une ou des partition(s) NTFS a(ont) été trouvé(es)."
		echo -e "Faut-il la(es) monter en lecture seule (${COLCHOIX}1${COLTXT}) ou en lecture/écriture (${COLCHOIX}2${COLTXT}) ?"
		echo -e "Votre choix: ${COLSAISIE}\c"
		read REP_NTFS
	done

	if [ "${REP_NTFS}" = "1" ]; then
		COMMANDE_MONTAGE_NTFS="mount -t ntfs"
	else
		COMMANDE_MONTAGE_NTFS="ntfs-3g"
	fi
fi

#fdisk -l /dev/$HD | grep "^/dev/" | grep -v "xtended" | grep -v "W95 Ext" | grep -v "Hidden" | grep -v "Dell Utility" | grep -v "Linux swap" | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||" | while read PART
LISTE_PART ${HD} avec_tableau_liste=y
cat /tmp/liste_part_extraite_par_LISTE_PART.txt | while read TMP_PART
do
	PART=$(echo $TMP_PART|sed -e "s|^/dev/||")

	echo -e "$COLTXT"
	echo "Montage de /dev/$PART"
	echo -e "$COLCMD\c"
	if mount | tr "\t" " " | grep -q "/dev/$PART "; then
		echo "La partition est deja montee."
	else
		mkdir -p /mnt/$PART
	
		TYPE_PART=$(TYPE_PART $PART)
	
		if [ "$TYPE_PART" = "ntfs" ]; then
			if [ "${REP_NTFS}" = "1" ]; then
				echo "${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART"
				${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART || echo -e "${COLERREUR}ERREUR${COLTXT}"
			else
				echo "${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART -o ${OPT_LOCALE_NTFS3G}"
				${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART -o ${OPT_LOCALE_NTFS3G} || echo -e "${COLERREUR}ERREUR${COLTXT}"
			fi
		else
			if [ -z "${TYPE_PART}" ]; then
				echo "mount /dev/$PART /mnt/$PART"
				mount /dev/$PART /mnt/$PART || echo -e "${COLERREUR}ERREUR${COLTXT}"
			else
				echo "mount -t ${TYPE_PART} /dev/$PART /mnt/$PART"
				mount -t ${TYPE_PART} /dev/$PART /mnt/$PART || echo -e "${COLERREUR}ERREUR${COLTXT}"
			fi
		fi
	fi

#		echo -e "$COLTXT"
#		echo "Démontage de /dev/$PART"
#		echo -e "$COLCMD\c"
#		umount /mnt/$PART

#	else
#		echo -e "$COLERREUR"
#		echo "Echec du montage de /dev/$PART ???"
#	fi
done

echo -e "$COLTITRE"
echo "Terminé!"
echo -e "$COLTXT"
if [ "$AUTO" != "y" ]; then
	echo "Appuyez sur une touche pour quitter."
	read PAUSE
fi


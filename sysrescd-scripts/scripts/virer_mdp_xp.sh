#!/bin/sh

# Script de suppression de mot de passe XP
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 01/04/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "*******************************"
echo "*  Ce script doit vous aider  *"
echo "*         à supprimer         *"
echo "*      les mots de passe      *"
echo "*        de comptes XP        *"
echo "*******************************"

echo -e "${COLERREUR}ATTENTION:${COLINFO} Ce script est expérimental.\nSi la partition XP modifiée est de type NTFS, le montage\nen lecture/écriture peut mal se passer et endommager le système.\nDans le doute, commencez par effectuer une sauvegarde du système."

POURSUIVRE

echo -e "$COLPARTIE"
echo "========================================"
echo "Choix du disque dur puis de la partition"
echo "========================================"

echo -e "$COLTXT"
echo "Voici la liste des disques détectés sur votre machine:"
echo -e "$COLCMD"

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

echo -e "$COLTXT"
echo "Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
LISTE_PART ${HD} afficher_liste=y

#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | egrep "(FAT|NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v Hidden | cut -d" " -f1))
LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows
if [ ! -z "${liste_tmp[0]}" ]; then
	DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
else
	DEFAULTPART="${HD}1"
fi

PARTNT=""
while [ -z "$PARTNT" ]
do
	echo -e "$COLTXT"
	echo -e "Quelle est la partition à monter? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read PARTNT

	if [ -z "$PARTNT" ]; then
		PARTNT=${DEFAULTPART}
	fi

	t=$(fdisk -s /dev/$PARTNT)
	if [ -z "$t" -o ! -e "/sys/block/$HD/$PARTNT" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposée n'existe pas!"
	fi
done

#if fdisk -l /dev/$HD | grep "/dev/$PARTNT " | grep NTFS > /dev/null; then
type_fs=$(TYPE_PART $PARTNT)
if [ "$type_fs" = "ntfs" ]; then
	echo -e "$COLTXT"
	echo "Montage de la partition NTFS en lecture/écriture à l'aide de ntfs-3g"
	echo -e "$COLCMD\c"
	mkdir -p /mnt/$PARTNT
	ntfs-3g /dev/$PARTNT /mnt/$PARTNT -o ${OPT_LOCALE_NTFS3G}
else
	#if fdisk -l /dev/$HD | grep "/dev/$PARTNT " | grep FAT > /dev/null; then
	if [ "$type_fs" = "fat16" -o "$type_fs" = "fat32" -o "$type_fs" = "vfat" ]; then
		echo -e "$COLTXT"
		echo "Montage de la partition /dev/$PARTNT en /mnt/$PARTNT"
		echo -e "$COLCMD\c"
		mkdir -p /mnt/$PARTNT
		mount -t vfat /dev/$PARTNT /mnt/$PARTNT
	else
		ERREUR "La partition ne semble être ni de type NTFS ni de type FAT..."
	fi
fi


echo -e "$COLPARTIE"
echo "=========================================="
echo "Copie des fichiers SAM, SECURITY et system"
echo "=========================================="

echo -e "$COLTXT"
echo "Copie des fichiers:"
echo -e "$COLCMD\n"
ladate=$(date '+%Y%m%d-%H%M%S')
# Sauvegarde
mkdir -p /tmp/svg_${ladate}

if [ -e "/mnt/$PARTNT/WINDOWS" ]; then
	WINDOWS="/mnt/$PARTNT/WINDOWS"
else
	if [ -e "/mnt/$PARTNT/WINNT" ]; then
		WINDOWS="/mnt/$PARTNT/WINNT"
	else
		ERREUR "Les dossiers WINDOWS ou WINNT n'ont pas été trouvés sur la partition $PARTNT"
	fi
fi

cp $WINDOWS/system32/config/system /tmp/svg_${ladate}/
cp $WINDOWS/system32/config/SAM /tmp/svg_${ladate}/
cp $WINDOWS/system32/config/SECURITY /tmp/svg_${ladate}/
# Copie des fichiers à traiter
cp -v $WINDOWS/system32/config/system /tmp/
cp -v $WINDOWS/system32/config/SAM /tmp/
cp -v $WINDOWS/system32/config/SECURITY /tmp/


echo -e "$COLPARTIE"
echo "==================="
echo "Lancement de chntpw"
echo "==================="

echo -e "$COLTXT"
echo "Lancement de chntpw..."
echo "(la suite est en anglais)"
echo -e "$COLCMD\c"
cd /tmp
sleep 1
chntpw -i SAM system SECURITY
sleep 1


echo -e "$COLPARTIE"
echo "==================================="
echo "Mise en place des fichiers modifiés"
echo "==================================="

echo -e "$COLINFO"
echo "Jusque la, tout a ete effectue sur une copie des fichiers de Window$,
pas sur les fichiers originaux.
S'il ne s'est pas produit d'erreur,
vous pouvez mettre en place les fichiers que vous venez de modifier.
Dans ce cas, repondre 'o' ci-dessous."

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous mettre en place les fichiers SAM system SECURITY modifiés? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLCMD"
	cp -v /tmp/system $WINDOWS/system32/config/
	cp -v /tmp/SAM $WINDOWS/system32/config/
	cp -v /tmp/SECURITY $WINDOWS/system32/config/
	sync
	sleep 1
else
	echo -e "$COLTXT"
	echo "Démontage de la partition $PARTNT..."
	echo -e "$COLCMD\c"
	umount /mnt/$PARTNT || echo -e "${COLERREUR}Erreur lors du démontage de /dev/$PARTNT"

	echo -e "$COLTXT"
	echo -e "${COLERREUR}ABANDON"
	exit
fi

echo -e "$COLTXT"
echo "Démontage de la partition $PARTNT..."
echo -e "$COLCMD\c"
umount /mnt/$PARTNT || echo -e "${COLERREUR}Erreur lors du démontage de /dev/$PARTNT"

echo -e "$COLTITRE"
echo "Terminé!"
echo -e "$COLTXT"
echo "Appuyez sur une touche pour quitter."
read PAUSE


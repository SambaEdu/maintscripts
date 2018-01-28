#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Script de remplissage des espaces vides par des zéros
# Dernière modification: 02/02/2013

# **********************************
# Version adaptée à System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

echo -e "$COLTITRE"
echo "**************************"
echo "* Remplir l'espace libre *"
echo "*    d'une partition     *"
echo "*     par des zéros      *"
echo "**************************"

echo -e "$COLINFO"
echo "Ce script permet de remplir l'espace libre des partitions"
echo "(non-NTFS ni SWAP) par des zéros."
echo ""
echo "Les données présentes ne sont pas altérées."
echo "Seul l'espace libre fait l'objet d'un traitement."
echo ""
echo "Cela a pour intérêt de réduire la taille des sauvegardes"
echo "de partitions qui peuvent être effectuées ensuite."

POURSUIVRE

echo -e "$COLPARTIE"
echo "==================="
echo "Choix du disque dur"
echo "==================="

AFFICHHD

DEFAULTDISK=$(GET_DEFAULT_DISK)

echo -e "$COLTXT"
echo -e "Sur quel disque se trouve la partition à 'remplir' de zéros?"
echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
read SAVEHD

if [ -z "$SAVEHD" ]; then
	SAVEHD=${DEFAULTDISK}
fi

SUITE=""
while [ "$SUITE" != "o" ]
do
	echo -e "$COLTXT"
	echo "La partition à 'remplir' de zéros ne doit pas être de type NTFS (ni Linux SWAP)."
	echo "Voici la/les partition(s) susceptibles de convenir:"
	echo -e "$COLCMD"
	#fdisk -l /dev/$SAVEHD | grep "/dev/${SAVEHD}[0-9]" | grep -v NTFS | grep -v "Linux swap"
	#liste_tmp=($(fdisk -l /dev/$SAVEHD | grep "^/dev/$SAVEHD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
	LISTE_PART ${SAVEHD} afficher_liste=y avec_tableau_liste=y type_part_cherche=non_ntfs
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART=${SAVEHD}1
	fi

	echo -e "$COLTXT"
	echo -e "Quelle est la partition à traiter? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read CHOIX_DEST

	if [ -z "$CHOIX_DEST" ]; then
		CHOIX_DEST=${DEFAULTPART}
	fi

	PARTSTOCK="/dev/$CHOIX_DEST"
	PTMNTSTOCK="/mnt/$CHOIX_DEST"
	mkdir -p $PTMNTSTOCK

	SUITE="o"
	#if ! fdisk -l /dev/$SAVEHD | grep $PARTSTOCK > /dev/null; then
	t=$(fdisk -s /dev/$PARTSTOCK)
	if [ -z "$t" -o ! -e "/sys/block/$SAVEHD/$PARTSTOCK" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposée n'existe pas!"
		echo -e "$COLTXT"
		read PAUSE
		#exit 1
		SUITE="n"
	fi

	#if fdisk -l /dev/$SAVEHD | grep $PARTSTOCK | egrep -i "(NTFS|SWAP)" > /dev/null; then
	type_fs=$(TYPE_PART $PARTSTOCK)
	if [ "$type_fs" = "ntfs" -o "$type_fs" = "linux-swap" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition ne doit pas être de type NTFS ni SWAP!"
		echo -e "$COLTXT"
		read PAUSE
		#exit 1
		SUITE="n"
	fi

done

echo -e "$COLTXT"
echo "Quel est le type de la partition $PARTSTOCK?"
echo "(vfat (pour FAT32), ext2, ext3,...)"
#DETECTED_TYPE=$(TYPE_PART $CHOIX_DEST)
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

if mount | grep "$PARTSTOCK " > /dev/null; then
	umount $PARTSTOCK
	sleep 1
fi

if mount | grep $PTMNTSTOCK > /dev/null; then
	umount $PTMNTSTOCK
	sleep 1
fi

echo -e "$COLTXT"
echo "Montage de la partition $PARTSTOCK en $PTMNTSTOCK:"
if [ -z "$TYPE" ]; then
	echo -e "${COLCMD}mount $PARTSTOCK $PTMNTSTOCK"
	mount $PARTSTOCK "$PTMNTSTOCK"||ERREUR "Le montage de $PARTSTOCK a échoué!"
else
	echo -e "${COLCMD}mount -t $TYPE $PARTSTOCK $PTMNTSTOCK"
	mount -t $TYPE $PARTSTOCK "$PTMNTSTOCK"||ERREUR "Le montage de $PARTSTOCK a échoué!"
fi


if mount | grep ${PTMNTSTOCK} > /dev/null; then
	echo -e "${COLTXT}Voici ce qui est monté en ${PTMNTSTOCK}"
	echo -e "${COLCMD}\c"
	mount | grep ${PTMNTSTOCK}
else
	echo -e "${COLERREUR}Il semble que rien ne soit monté en ${PTMNTSTOCK}"

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous poursuivre néanmoins? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done

	if [ "$REPONSE" != "o" ]; then
		ERREUR "Vous n'avez pas souhaité poursuivre."
	fi
fi

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour poursuivre..."
read PAUSE


echo -e "$COLINFO"
echo "L'espace libre de la partition va être rempli de zéros."
echo "Cela consiste à écrire des zéros dans un fichier jusqu'à remplir la partition."
echo "Lorsque la partition va être pleine, une erreur va s'afficher."
echo "Le gros fichier va ensuite être supprimé."

POURSUIVRE

echo -e "$COLINFO"
echo "Espace initialement disponible:"
echo -e "$COLCMD\c"
#espace=$(df | grep $PTMNTSTOCK | sed -e "s/ \{1,\} / /g" | cut -d" " -f4)
espace=$(df 2> /dev/null | grep $PTMNTSTOCK | sed -e "s/ \{1,\} / /g" | cut -d" " -f4)
echo $espace

echo -e "$COLTXT"
echo "Remplissage en cours..."

#espace=1
#while [ $espace -gt 0 ]
while [ $espace -gt 100 ]
do
	ladate=$(date +"%Y.%m.%d-%H.%M.%S");
	echo -e "$COLINFO"
	echo "Création et remplissage de gros_fichier_bidon_${ladate}"
	echo -e "$COLCMD\c"
	#dd if=/dev/zero of="${PTMNTSTOCK}/gros_fichier_bidon.${ladate} bs=1M count=1999"
	#dd if=/dev/zero of="${PTMNTSTOCK}/gros_fichier_bidon.${ladate} bs=1k count=1999000"
	dd if=/dev/zero of="${PTMNTSTOCK}/gros_fichier_bidon.${ladate}"

	#Il se produit une erreur lorsque le fichier atteint 2Go ou quand le disque dur est plein.
	echo -e "$COLINFO"
	echo "Il a dû s'afficher un message contenant:"
	echo -e "${COLERREUR}No space left on device"
	echo -e "$COLINFO\c"
	echo "ou"
	echo -e "${COLERREUR}File size limit exceeded"
	echo -e "$COLINFO\c"
	echo "Il se produit en effet une erreur lorsque le fichier atteint 2Go"
	echo "(sur FAT32) ou quand la partition est pleine."

	echo -e "$COLINFO"
	echo "Espace encore disponible:"
	echo -e "$COLCMD\c"
	#espace=$(df | grep $PTMNTSTOCK | sed -e "s/ \{1,\} / /g" | cut -d" " -f4)
	espace=$(df 2> /dev/null | grep $PTMNTSTOCK | sed -e "s/ \{1,\} / /g" | cut -d" " -f4)
	echo $espace
done

#echo -e "$COLINFO"
#echo "Il a du s'afficher un/des message(s) contenant:"
#echo -e "${COLERREUR}No space left on device"

echo -e "$COLTXT"
echo "Pour information, voici la taille du/des gros fichier(s) généré(s):"
echo -e "$COLCMD\c"
du -h ${PTMNTSTOCK}/gros_fichier_bidon.*

#read PAUSE

echo -e "${COLTXT}"
echo "Suppression de ${PTMNTSTOCK}/gros_fichier_bidon.*"
echo -e "$COLCMD"
rm -f ${PTMNTSTOCK}/gros_fichier_bidon.*

echo -e "${COLTXT}"
echo "Démontage de la partition $PARTSTOCK"
echo -e "${COLCMD}"
umount ${PTMNTSTOCK}
echo -e "${COLTITRE}Fin de l'opération!${COLTXT}"
read PAUSE

#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Script de redimensionnement de partition NTFS de SystemRescueCD
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 24/06/2013

# **********************************
# Version adaptée à System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

datetemp=$(date '+%Y%m%d-%H%M%S')
tmp=/tmp/${datetemp}
mkdir -p $tmp

echo -e "$COLTITRE"
echo "*************************************************"
echo "* Script de redimensionnement de partition NTFS *"
echo "*************************************************"

echo -e "$COLINFO"
echo "Ce script permet de réduire une partition NTFS en ligne de commande."
echo -e "$COLTXT"
echo "Le script est encore expérimental... prenez soin de faire une sauvegarde."

POURSUIVRE


PTMNTSTOCK="/mnt/save"
mkdir -p $PTMNTSTOCK

echo -e "$COLPARTIE"
echo "======================================"
echo "Choix de la partition à redimensionner"
echo "======================================"

HD=""
while [ -z "$HD" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque se trouve la partition à redimensionner?"
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
	else
		TMP_HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
		fdisk -l /dev/$HD > /tmp/fdisk_l_${TMP_HD_CLEAN}.txt 2>&1
		#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${TMP_HD_CLEAN}.txt|cut -d"'" -f2)

		if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
			TMP_disque_en_GPT=/dev/${HD}
		else
			TMP_disque_en_GPT=""
		fi

		if [ -n "$TMP_disque_en_GPT" ]; then
			echo -e "$COLERREUR"
			echo "La table de partition du disque $HD est de type GPT."
			echo "Le present script ne gere pas ce type de partitionnement."
			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour quitter."
			read PAUSE
			exit
		fi
	fi
done

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$HD:"
	echo -e "$COLCMD\c"
	#echo "fdisk -l /dev/$HD"
	#fdisk -l /dev/$HD
	LISTE_PART ${HD} afficher_liste=y

	#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -i "HPFS/NTFS" | grep -v "Hidden" | cut -d" " -f1))
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=ntfs
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		echo -e "$COLERREUR"
		echo -e "Aucune partition NTFS n'a été trouvée sur le disque ${COLINFO}/dev/$HD"
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour terminer."
		read PAUSE
		exit
	fi
	
	echo -e "$COLTXT"
	echo -e "Quelle est la partition à redimensionner ? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read CHOIX_SOURCE
	
	if [ -z "$CHOIX_SOURCE" ]; then
		CHOIX_SOURCE="${DEFAULTPART}"
	fi

	#if ! fdisk -s /dev/$CHOIX_SOURCE > /dev/null; then
	t=$(fdisk -s /dev/$CHOIX_SOURCE)
	if [ -z "$t" -o ! -e "/sys/block/$HD/$CHOIX_SOURCE" ]; then
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

PART_SOURCE="/dev/$CHOIX_SOURCE"

if mount | grep "/dev/$CHOIX_SOURCE " > /dev/null; then
	umount /dev/$CHOIX_SOURCE
	if [ "$?" != "0" ]; then
		echo -e "$COLERREUR"
		echo "Il semble que la partition /dev/$CHOIX_SOURCE soit montée"
		echo "et qu'elle ne puisse pas être démontée."
		echo "Il n'est pas possible de redimensionner la partition dans ces conditions..."
		echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de régler"
		echo "le problème (démonter la partition /dev/$CHOIX_SOURCE)"
		echo "avant de poursuivre."

		echo -e "$COLTXT"
		echo "Appuyez ensuite sur ENTREE pour poursuivre..."
		read PAUSE
	fi
fi




# Sauvegarde de la table de partition:
echo -e "$COLTXT"
echo "Sauvegarde de la table de partition et du secteur de démarrage de ${PART_SOURCE}"
echo -e "$COLCMD\c"
TMP_HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
fdisk -l /dev/$HD > /tmp/fdisk_l_${TMP_HD_CLEAN}.txt 2>&1
#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${TMP_HD_CLEAN}.txt|cut -d"'" -f2)

if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
	TMP_disque_en_GPT=/dev/${HD}
else
	TMP_disque_en_GPT=""
fi

if [ -z "$TMP_disque_en_GPT" ]; then
	sfdisk -d /dev/$HD > $tmp/$HD.out
else
	sfdisk -b $tmp/gpt_$HD.out /dev/$HD
fi
dd if=/dev/$HD of=$tmp/parttable.bin bs=512 count=1
dd if=${PART_SOURCE} of=$tmp/bootsector.bin bs=512 count=1

echo -e "$COLTXT"
echo "Recherche des dimensions min et max possibles"
echo -e "pour la partition ${COLINFO}${PART_SOURCE}"
echo -e "$COLCMD\c"
echo "ntfsresize -P -i -f -v ${PART_SOURCE}"
ntfsresize -P -i -f -v ${PART_SOURCE} > $tmp/ntfs_resize_step1.txt 2>&1
cat $tmp/ntfs_resize_step1.txt

vmax=$(grep "Current volume size" $tmp/ntfs_resize_step1.txt | cut -d"(" -f2 | cut -d" " -f1)
vmin=$(grep "You might resize at " $tmp/ntfs_resize_step1.txt | cut -d" " -f8)

echo -e "$COLTXT"
echo -e "La partition doit être redimensionnée entre ${COLINFO}${vmin}${COLTXT} et ${COLINFO}${vmax}${COLTXT} Mo."

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	REPONSE=2

	echo -e "$COLTXT"
	echo -e "Quelle est la nouvelle taille souhaitée (en Mo)? $COLSAISIE\c"
	read TAILLE

	longueur_test=$(echo "${TAILLE}" | sed -e "s/[0-9]//g" | wc -m)
	if [ "$longueur_test" != "1" ]; then
		echo -e "${COLERREUR}"
		echo -e "Des caractères non valides ont été saisis: ${COLCHOIX}$(echo "${TAILLE}" | tr "-" "_" | sed -e "s/[0-9]//g")"
		REPONSE=2
	else

		if [ ${TAILLE} -gt ${vmax} -o ${TAILLE} -lt ${vmin} ]; then
			echo -e "${COLERREUR}"
			echo -e "La valeur doit être comprise entre ${COLCHOIX}${vmin}${COLERREUR} et ${COLCHOIX}${vmax}"
			REPONSE=2
		else
			echo -e "${COLINFO}"
			echo -e "Vous avez choisi ${COLCHOIX}${TAILLE}${COLINFO} Mo."

			POURSUIVRE_OU_CORRIGER
		fi
	fi
done

# Détecter et annoncer la taille minimale pour la partition redimensionnée
# Demander une valeur en Mo
# La convertir en octets
TAILLE_OCT=$((${TAILLE}*1024*1024))

# Tester
echo -e "$COLTXT"
echo "Test de l'opération de redimensionnement du système de fichiers."
echo -e "$COLCMD\c"
echo "ntfsresize -P --force --force ${PART_SOURCE} -s ${TAILLE_OCT} --no-action"
ntfsresize -P --force --force ${PART_SOURCE} -s ${TAILLE_OCT} --no-action > $tmp/ntfs_resize_step2.txt 2>&1
cat $tmp/ntfs_resize_step2.txt
if ! grep "The read-only test run ended successfully." $tmp/ntfs_resize_step2.txt > /dev/null; then
	echo -e "$COLERREUR"
	echo "Le test a échoué. Il ne serait pas prudent de poursuivre."

	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour terminer."
	read PAUSE
	exit
else
	echo -e "$COLTXT"
	echo "Le test a réussi."
fi

POURSUIVRE

# En cas de succès forcer:
# ntfsresize -P --force --force /dev/hda1 -s 2147483648
echo -e "$COLTXT"
echo "Redimensionnement du système de fichiers."
echo -e "$COLCMD\c"
echo "ntfsresize -P --force --force ${PART_SOURCE} -s ${TAILLE_OCT}"
ntfsresize -P --force --force ${PART_SOURCE} -s ${TAILLE_OCT} > $tmp/ntfs_resize_step3.txt 2>&1
cat $tmp/ntfs_resize_step3.txt
if ! grep "Successfully resized NTFS on device " $tmp/ntfs_resize_step3.txt > /dev/null; then
	echo -e "$COLERREUR"
	echo "L'opération a échoué."
	echo "C'est la cata..."
	echo "Je ne sais pas comment automatiser la remise à l'état initial."

	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour terminer."
	read PAUSE
	exit
else
	echo -e "$COLTXT"
	echo "L'opération a réussi."
fi

POURSUIVRE

# Nouvelle taille telle que proposée par le retour de ntfs-resize
TAILLE_CORRIGEE=$(grep "New volume size    :" $tmp/ntfs_resize_step3.txt | cut -d"(" -f2 | cut -d" " -f1)

# Supprimer/recréer la partition avec une nouvelle taille
NUM_PART=$(echo ${PART_SOURCE} | sed -e "s|[a-z/]||g")

# Nombre de partitions:
#NB_PART=$(fdisk -l /dev/$HD | grep "^/dev/" |wc -l)
LISTE_PART ${HD} avec_tableau_liste=y
NB_PART=$(wc -l /tmp/liste_part_extraite_par_LISTE_PART.txt)

# Si la partition n'est pas primaire, faire la destruction/création à la main.
echo -e "$COLTXT"
echo "Suppression de la partition,"
echo -e "puis re-création de la partition à sa nouvelle taille: ${COLINFO}${TAILLE_CORRIGEE}${COLTXT}Mo"
echo -e "$COLCMD\c"
echo "d" > $tmp/ntfs_resize_step4.txt

if [ ${NB_PART} != "1" ]; then
	echo "${NUM_PART}" >> $tmp/ntfs_resize_step4.txt
fi

# Pour montrer l'etat intermediaire des partitions
echo "
p
" >> $tmp/ntfs_resize_step4.txt

if [ ${NUM_PART} -le 4 ]; then
	temoin_partitions_primaires=0
	for i in 1 2 3 4
	do
		t=$(fdisk -l /dev/${HD} | grep "^/dev/${HD}${i} ")
		if [ -n "$t" ]; then
			temoin_partitions_primaires=$(($temoin_partitions_primaires+1))
		fi
	done

	if [ "$temoin_partitions_primaires" = "4" ]; then
		echo "n
p

+${TAILLE_CORRIGEE}M" >> $tmp/ntfs_resize_step4.txt
	else
		echo "n
p
${NUM_PART}

+${TAILLE_CORRIGEE}M" >> $tmp/ntfs_resize_step4.txt
	fi
else
	echo "n
l

+${TAILLE_CORRIGEE}M" >> $tmp/ntfs_resize_step4.txt
fi

# Pour montrer l'etat intermediaire des partitions
echo "
p
" >> $tmp/ntfs_resize_step4.txt

# Type de la partition:
echo "t" >> $tmp/ntfs_resize_step4.txt
if [ ${NB_PART} != "1" ]; then
	#echo "${NUM_BOOT_PART}" >> $tmp/ntfs_resize_step4.txt
	echo "${NUM_PART}" >> $tmp/ntfs_resize_step4.txt
fi
echo "7" >> $tmp/ntfs_resize_step4.txt

# Pour montrer l'etat intermediaire des partitions
echo "
p
" >> $tmp/ntfs_resize_step4.txt

# On rétablit si nécessaire le flag bootable sur la partition:
#if fdisk -l /dev/$HD | tr "\t" " " | grep "^${PART_SOURCE} " | grep "\*" > /dev/null; then
#	echo "a
#${NUM_PART}" >> $tmp/ntfs_resize_step4.txt
#fi
if fdisk -l /dev/$HD | tr "\t" " " | grep "^/dev/$HD" | grep "\*" > /dev/null; then
	NUM_BOOT_PART=$(fdisk -l /dev/$HD | tr "\t" " " | grep "^/dev/$HD" | grep "\*" | cut -d" " -f1 | sed -e "s|[a-z/]||g")
	echo "a" >> $tmp/ntfs_resize_step4.txt
	# Pour le flag bootable, le numéro de partition est demandé même s'il n'y a qu'une partition.
	#if [ ${NB_PART} != "1" ]; then
		echo "${NUM_BOOT_PART}" >> $tmp/ntfs_resize_step4.txt
	#fi
fi

# Pour montrer l'etat des partitions avant ecriture
echo "
p
" >> $tmp/ntfs_resize_step4.txt

# Ecriture des modifs:
echo "w
" >> $tmp/ntfs_resize_step4.txt
fdisk /dev/$HD < $tmp/ntfs_resize_step4.txt

POURSUIVRE

# ntfsresize -P -i -f -v /dev/hda1
echo -e "$COLTXT"
echo "Vérification..."
echo -e "$COLCMD\c"
echo "ntfsresize -P -i -f -v $PART_SOURCE"
ntfsresize -P -i -f -v $PART_SOURCE > $tmp/ntfs_resize_step5.txt
cat $tmp/ntfs_resize_step5.txt

POURSUIVRE

# ntfsresize -P --force --force /dev/hda1 --no-action
echo -e "$COLTXT"
echo "Test..."
echo -e "$COLCMD\c"
echo "ntfsresize -P --force --force $PART_SOURCE --no-action"
ntfsresize -P --force --force $PART_SOURCE --no-action > $tmp/ntfs_resize_step6.txt
cat $tmp/ntfs_resize_step6.txt

if ! grep "The read-only test run ended successfully." $tmp/ntfs_resize_step6.txt > /dev/null; then
	echo -e "$COLERREUR"
	echo "Le test a échoué."
	echo "Il va falloir corriger à la mano..."

	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour terminer."
	read PAUSE
	exit
else
	echo -e "$COLTXT"
	echo "Le test a réussi."
fi

POURSUIVRE

# ntfsresize -P --force --force /dev/hda1
echo -e "$COLTXT"
echo "Application du redimensionnement."
echo -e "$COLCMD\c"
echo "ntfsresize -P --force --force $PART_SOURCE"
ntfsresize -P --force --force $PART_SOURCE > $tmp/ntfs_resize_step7.txt
cat $tmp/ntfs_resize_step7.txt

if ! grep "Successfully resized NTFS on device " $tmp/ntfs_resize_step7.txt > /dev/null; then
	echo -e "$COLERREUR"
	echo "Le redimensionnement a échoué."
	echo "Il va falloir corriger à la mano..."

	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour terminer."
	read PAUSE
	exit
else
	echo -e "$COLTXT"
	echo "Le redimensionnement a réussi."
fi

echo -e "${COLERREUR}"
echo -e "ATTENTION: ${COLTXT}Windows supporte mal les redimensionnements."
echo "Après une telle opération, il ne faut rien faire de plus,"
echo "rebooter le système et laisser Windows faire un scandisk"
echo "pour prendre en compte le changement de taille de la partition."
echo "Dans le cas contraire, Windows risque de ne pas retrouver ses billes."

echo -e "${COLTITRE}"
echo "Terminé."

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour quitter..."
read PAUSE

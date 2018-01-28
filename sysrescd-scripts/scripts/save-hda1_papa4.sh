#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Script de sauvegarde d'une partition
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# D'apres un script de Franck Molle (12/2003),
# lui-meme inspire par les scripts du CD StoneHenge,...
# Derniere modification: 25/05/2016

# **********************************
# Version adaptee a System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

# Chemin vers les programmes dar et ntfsclone
chemin_dar="/usr/bin"
chemin_ntfs="/usr/sbin"

option_fsarchiver="-v"

clear
echo -e "$COLTITRE"
echo "***************************************************"
echo "*     Ce script doit vous aider a sauvegarder     *"
echo "*     une partition (window$) vers une autre      *"
echo "*                                                 *"
echo "* ATTENTION: vous devez avoir une partition libre *"
echo "*    (pas en NTFS) pour y stocker l'image !!!     *"
echo "*      si tel n'est pas le cas, creez en une      *"
echo "*                                                 *"
echo "*    Les donnees proposees entre crochets sont    *"
echo "*    celles prises par defaut par le script en    *"
echo "*       appuyant simplement sur ENTREE            *"
echo "***************************************************"

PTMNTSTOCK="/mnt/save"
mkdir -p $PTMNTSTOCK

echo -e "$COLPARTIE"
echo "==================================="
echo "Choix de la partition a sauvegarder"
echo "==================================="

HD=""
while [ -z "$HD" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque se trouve la partition a sauvegarder?"
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
	echo -e "$COLCMD\c"
	HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
	fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
	#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt|cut -d"'" -f2)

	if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
		disque_en_GPT=/dev/${HD}
	else
		disque_en_GPT=""
	fi

	if [ -z "$disque_en_GPT" ]; then
		echo "fdisk -l /dev/$HD"
		fdisk -l /dev/$HD

		liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
	else
		HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
		parted /dev/${HD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" | grep -vi "Linux swap" | grep -v -i "linux-swap" | grep -vi "xtended" | grep -vi "W95 Ext'd" | grep -vi "Hidden" > /tmp/partitions_${HD_CLEAN}.txt

		cpt_tmp=0
		while read A
		do
			echo "${HD}${A}"

			NUM_PART=$(echo "$A"|cut -d" " -f1)
			#TMP_TYPE=$(parted /dev/${HD}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
			#if [ "$TMP_TYPE" = "ext2" -o "$TMP_TYPE" = "ext3" -o "$TMP_TYPE" = "ext4" -o "$TMP_TYPE" = "reiserfs" -o "$TMP_TYPE" = "xfs" -o "$TMP_TYPE" = "jfs" ]; then
				liste_tmp[${cpt_tmp}]=$(echo "${HD}${NUM_PART}")
				cpt_tmp=$((cpt_tmp+1))
			#fi
		done < /tmp/partitions_${HD_CLEAN}.txt
	fi

	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART="${HD}1"
	fi



	echo -e "$COLTXT"
	echo -e "Quelle est la partition a sauvegarder ? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read CHOIX_SOURCE
	
	if [ -z "$CHOIX_SOURCE" ]; then
		CHOIX_SOURCE="${DEFAULTPART}"
	fi

	if ! fdisk -s /dev/$CHOIX_SOURCE > /dev/null; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposee n'existe pas!"
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
		echo "Il semble que la partition /dev/$CHOIX_SOURCE soit montee"
		echo "et qu'elle ne puisse pas etre demontee."
		echo "Il n'est pas possible de sauvegarder la partition avec partimage ou ntfsclone"
		echo "dans ces conditions..."
		echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de regler"
		echo "le probleme (demonter la partition /dev/$CHOIX_SOURCE)"
		echo "avant de poursuivre."

		echo -e "$COLTXT"
		echo "Appuyez ensuite sur ENTREE pour poursuivre..."
		read PAUSE
	fi
fi

#if fdisk -l /dev/$HD | grep "$PART_SOURCE " | grep Linux > /dev/null; then
num_part=$(echo $PART_SOURCE | sed -e "s|^$HD||")
type_fs=$(parted /dev/$HD print | sed -e "s/ \{2,\}/ /g" | grep "^ ${num_part} " | cut -d" " -f7)
if [ "$type_fs" = "ext2" -o "$type_fs" = "ext3" -o "$type_fs" = "ext4" -o "$type_fs" = "reiserfs" -o "$type_fs" = "xfs" -o "$type_fs" = "jfs" ]; then

	#parted /dev/sda print | grep "^ 1" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f7
	num_part=$(echo $PART_SOURCE | sed -e "s|^$HD||")
	#type_fs=$(parted /dev/$HD print | grep "^ 1" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f7)
	#type_fs=$(parted /dev/$HD print | sed -e "s/ \{2,\}/ /g" | grep "^ ${num_part} " | cut -d" " -f7)
	# PB: $type_fs est vide alors que la commande tapee dans une console ne donne pas cela...
	# Correction:
	#type_fs=$(TYPE_PART ${PART_SOURCE})

	#if [ "$type_fs" = "ext2" -o "$type_fs" = "ext3" -o "$type_fs" = "ext4" ]; then

		fsck="fsck.$type_fs"

		echo -e "$COLTXT"
		echo "Il peut arriver sur des partitions Linux qu'un scan soit necessaire pour que"
		echo "la sauvegarde s'effectue correctement."

		REP_FSCK=""
		while [ "$REP_FSCK" != "o" -a "$REP_FSCK" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous controler la partition avec $fsck? [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
			read REP_FSCK

			if [ -z "$REP_FSCK" ]; then
				REP_FSCK="o"
			fi
		done

		if [ "$REP_FSCK" = "o" ]; then

			#if mount | grep "/dev/$PART_SOURCE " > /dev/null; then
			if mount | grep "$PART_SOURCE " > /dev/null; then
				#umount /dev/$PART_SOURCE
				umount $PART_SOURCE
				if [ "$?" = "0" ]; then
					echo -e "$COLTXT"
					echo "Lancement du 'scan'..."
					echo -e "$COLCMD\c"
					#$fsck /dev/$PART_SOURCE
					$fsck $PART_SOURCE
				else
					echo -e "$COLERREUR"
					#echo "Il semble que la partition /dev/$PART_SOURCE soit montee"
					echo "Il semble que la partition $PART_SOURCE soit montee"
					echo "et qu'elle ne puisse pas etre demontee."
					echo "Il n'est pas possible de scanner la partition dans ces conditions..."
					echo "... et probablement pas possible non plus de sauvegarder la partition"
					echo "tant qu'elle sera montee."
					echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de regler"
					#echo "le probleme (demonter et scanner ($fsck /dev/$PART_SOURCE))"
					echo "le probleme (demonter et scanner ($fsck $PART_SOURCE))"
					echo "avant de poursuivre."

					echo -e "$COLTXT"
					echo "Appuyez ensuite sur ENTREE pour poursuivre..."
					read PAUSE
				fi
			else
				echo -e "$COLTXT"
				echo "Lancement du 'scan'..."
				echo -e "$COLCMD\c"
				#$fsck /dev/$PART_SOURCE
				$fsck $PART_SOURCE
			fi

			POURSUIVRE
		fi
	#fi
fi



echo -e "$COLPARTIE"
echo "==========================="
echo "DESTINATION DES SAUVEGARDES"
echo "==========================="

DEST_SVG


#============================================================================


echo -e "$COLPARTIE"
echo "======================="
echo " Type de la sauvegarde "
echo "======================="

echo -e "$COLINFO"
echo "Les sauvegardes peuvent etre effectuees a divers formats:"
echo -e "$COLTXT\c"
#echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions, mais encore instable"
#echo -e "                si le noyau Linux utilise est en version 2.6.x"
echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions (NTFS compris)."
echo -e "                  (en revanche sauvegarde ext4 non supporte)"
echo -e " (${COLCHOIX}2${COLTXT}) dar: pour les partitions non-NTFS."
echo -e " (${COLCHOIX}3${COLTXT}) ntfsclone: pour les partitions NTFS."
echo -e " (${COLCHOIX}4${COLTXT}) FsArchiver: pour toutes les partitions"
echo -e "                  (support NTFS:"
echo -e "                   http://www.fsarchiver.org/Cloning-ntfs"
echo -e "                   fsarchiver permet de restaurer vers"
echo -e "                   une partition plus petite que l'originale)."

echo -e "$COLTXT"
echo "Voici le noyau actuellement utilise:"
echo -e "$COLCMD\c"
cat /proc/version

DEFAULT_FORMAT_SVG=1
DETECTED_TYPE=$(TYPE_PART $PART_SOURCE)
if [ "$DETECTED_TYPE" = "ntfs" ]; then
	DEFAULT_FORMAT_SVG=3
elif [ "$DETECTED_TYPE" = "ext4" ]; then
	DEFAULT_FORMAT_SVG=4
fi

#type_fs=$(TYPE_PART ${PART_SOURCE})
type_fs=$DETECTED_TYPE

FORMAT_SVG=""
while [ "$FORMAT_SVG" != "1" -a "$FORMAT_SVG" != "2" -a "$FORMAT_SVG" != "3" -a "$FORMAT_SVG" != "4" ]
do
	echo -e "$COLTXT"
	echo -e "Quel est le format de sauvegarde souhaite? [${COLDEFAUT}${DEFAULT_FORMAT_SVG}${COLTXT}] $COLSAISIE\c"
	read FORMAT_SVG

	if [ -z "$FORMAT_SVG" ]; then
		FORMAT_SVG=${DEFAULT_FORMAT_SVG}
	fi
done

if [ "$FORMAT_SVG" = "2" ]; then
	echo -e "$COLINFO"
	echo "La sauvegarde avec 'dar' necessite de monter la partition /dev/$CHOIX_SOURCE"
	echo "Le type du systeme de fichier doit donc etre precise."
	echo "Cela peut-etre: vfat, ext2 ou ext3"

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel est le type de la partition?"
		#if fdisk -l /dev/$HD | tr "\t" " " | grep "/dev/$CHOIX_SOURCE " | egrep "(W95 FAT32|Win95 FAT32)" > /dev/null; then
		DETECTED_TYPE=$(TYPE_PART $CHOIX_SOURCE)
		if [ ! -z "${DETECTED_TYPE}" ]; then
			echo -e "Type: [${COLDEFAUT}${DETECTED_TYPE}${COLTXT}] $COLSAISIE\c"
			read TYPE_FS

			if [ -z "$TYPE_FS" ]; then
				TYPE_FS=${DETECTED_TYPE}
			fi
		else
			echo -e "Type: $COLSAISIE\c"
			read TYPE_FS
		fi

		echo -e "$COLTXT"
		echo "Tentative de montage..."
		echo -e "$COLCMD"
		mkdir -p /mnt/$CHOIX_SOURCE
		if [ ! -z "$TYPE_FS" ]; then
			mount -t $TYPE_FS /dev/$CHOIX_SOURCE /mnt/$CHOIX_SOURCE
		else
			mount /dev/$CHOIX_SOURCE /mnt/$CHOIX_SOURCE
		fi
		umount /mnt/$CHOIX_SOURCE

		echo -e "$COLTXT"
		echo "Si aucune erreur n'est affichee, le type doit convenir..."

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? $COLSAISIE\c"
			read REPONSE
		done
	done

fi

case $FORMAT_SVG in
	1)
		NOM_IMAGE_DEFAUT="image.partimage"
		SUFFIXE_SVG="000"
	;;
	2)
		NOM_IMAGE_DEFAUT="image_dar"
		#SUFFIXE_SVG="dar"
		SUFFIXE_SVG="1.dar"
	;;
	3)
		NOM_IMAGE_DEFAUT="image"
		SUFFIXE_SVG="ntfs"
	;;
	4)
		NOM_IMAGE_DEFAUT="image.FsArchiver"
		SUFFIXE_SVG="fsa"
	;;
esac


#============================================================================



echo -e "$COLPARTIE"
echo "============================="
echo " Nom de l'image et lancement "
echo "      de la sauvegarde       "
echo "============================="

echo -e "$COLCMD\c"
chemin_courant="$PWD"
cd "$DESTINATION"

IMAGE=""
while [ -z "$IMAGE" ]
do
	echo -e "$COLTXT"
	echo -e "Quel est le nom de l'image a creer? [${COLDEFAUT}${NOM_IMAGE_DEFAUT}${COLTXT}] $COLSAISIE\c"
	read -e IMAGE

	if [ -z "$IMAGE" ]; then
		IMAGE="${NOM_IMAGE_DEFAUT}"
	fi

	tmp_test=$(echo "$IMAGE" | tr "-" "_" | sed -e "s/[A-Za-z0-9_.]//g" | wc -m)
	if [ "$tmp_test" != 1 ]; then
		echo -e "${COLERREUR}La chaine ${COLINFO}${IMAGE}${COLERREUR} contient des caracteres non valides."
		echo -e "Limitez-vous aux caracteres alphanumeriques sans accents plus le point"
		echo -e "et le tiret bas."
		IMAGE=""
	fi

	#if [ ! -e "$(dirname /home/sauvegarde/$IMAGE)" ]; then
	#	echo -e "${COLERREUR}Le chemin ${COLINFO}$(dirname /home/sauvegarde/${IMAGE})${COLERREUR} n existe pas."
	#	NOMIMAGE=""
	#fi

	if [ -e "${DESTINATION}/${IMAGE}.${SUFFIXE_SVG}" ]; then
		echo -e "$COLTXT"
		echo "Une sauvegarde de meme nom existe deja."
		echo "Si vous poursuivez, le fichier sera ecrase."

		POURSUIVRE_OU_CORRIGER

		if [ "$REPONSE" = "2" ]; then
			IMAGE=""
		fi
	fi
done

echo -e "$COLCMD\c"
cd "$chemin_courant"

echo -e "$COLTXT"
echo -e "Faut-il scinder l'image pour tenir sur des CD ou ZIP? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
read REPONSE

if [ -z "$REPONSE" ]; then
	REPONSE="n"
fi

VOLUME=0
if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo -e "Tapez un volume en Mega-Octets: $COLSAISIE\c"
	read VOLUME
fi

if [ "$FORMAT_SVG" = "1" ]; then
	# Dans SysRescCD 0.2.16, partimage est en version 0.6.4
	# Les volumes pour scinder les images sont en Mo.
	# Le test ci-dessous devrait donc toujours etre faux:
	if partimage -v | grep 0.6.1 > /dev/null; then
		VOLUME=$(echo ${VOLUME}*1024 | bc)
	fi
fi

if [ "$FORMAT_SVG" != "4" ]; then
	NIVEAU="Non defini"
	while [ "$NIVEAU" != "0" -a "$NIVEAU" != "1" -a "$NIVEAU" != "2" ]
	do
		echo -e "$COLTXT"
		echo "Quel est le niveau de compression souhaite?"
		echo -e " - ${COLCHOIX}0${COLTXT} Aucune compression (grosse image, mais sauvegarde rapide)"
		echo -e " - ${COLCHOIX}1${COLTXT} Compression avec gzip (image reduite, mais sauvegarde moins rapide)"
		echo -e " - ${COLCHOIX}2${COLTXT} Compression avec bzip2 (image tres reduite, mais sauvegarde lente)"
		echo -e "ATTENTION: Il n'est pas possible de restaurer le secteur de boot \net la table de partition depuis une image compressee avec bzip2."
		echo -e "Niveau: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read NIVEAU
	
		if [ "$NIVEAU" = "" ]; then
			NIVEAU=1
		fi
	done
else
	NIVEAU=""
	while [ -z "$NIVEAU" ]
	do
		echo -e "$COLTXT"
		echo "Quel est le niveau de compression souhaite?"
		echo "Du moins efficace au plus efficace (mais plus gourmand en ressources cpu)"
		echo -e " - ${COLCHOIX}1${COLTXT} Compression avec lzo (rapide mais gain faible)"
		echo -e " - ${COLCHOIX}2${COLTXT} Compression avec gzip niveau 3"
		echo -e " - ${COLCHOIX}3${COLTXT} Compression avec gzip niveau 6"
		echo -e " - ${COLCHOIX}4${COLTXT} Compression avec gzip niveau 9"
		echo -e " - ${COLCHOIX}5${COLTXT} Compression avec bzip2 niveau 2"
		echo -e " - ${COLCHOIX}6${COLTXT} Compression avec bzip2 niveau 5"
		echo -e " - ${COLCHOIX}7${COLTXT} Compression avec lzma niveau 1"
		echo -e " - ${COLCHOIX}8${COLTXT} Compression avec lzma niveau 6"
		echo -e " - ${COLCHOIX}9${COLTXT} Compression avec lzma niveau 9"
		echo -e "Niveau: [${COLDEFAUT}3${COLTXT}] $COLSAISIE\c"
		read NIVEAU

		if [ "$NIVEAU" = "" ]; then
			NIVEAU=3
		fi

		t=$(echo "$NIVEAU"|wc -m)
		if [ "$t" != "2" ]; then
			echo -e "${COLERREUR}Niveau incorrect."
			NIVEAU=""
		else
			t=$(echo "$NIVEAU"|sed -e "s|[1-9]||g")
			if [ -n "$t" ]; then
				echo -e "${COLERREUR}Niveau incorrect."
				NIVEAU=""
			fi
		fi
	done
fi

echo ""
echo -e "${COLINFO}RECAPITULATIF:"
echo -e "${COLTXT}Partition source :                   ${COLINFO}${PART_SOURCE}"
echo -e "${COLTXT}Destination :                        ${COLINFO}${DESTINATION}"
#echo -e "${COLTXT}Destination situee sur :             ${COLINFO}${PART_CIBLE}"
echo -e "${COLTXT}Destination situee sur :             ${COLINFO}${PARTSTOCK}"
if [ ! -z "$TYPE" ]; then
	echo -e "${COLTXT}Type de la partition destination :   ${COLINFO}${TYPE}"
fi
#echo -e "${COLTXT}Point de montage pour la sauvegarde: ${COLINFO}${PTMNTSTOCK}"
echo -e "${COLTXT}Nom de l'image :                     ${COLINFO}${IMAGE}"

#if [ "$VOLUME" != "0" ]; then
#	echo -e "${COLTXT}Volume max. de chaque image :        ${COLINFO}${VOLUME} Mo"
#fi
if [ "$VOLUME" != "0" ]; then
	if [ "$FORMAT_SVG" = "1" ]; then
		if partimage -v | grep 0.6.1 > /dev/null; then
			UNITE="ko"
		else
			UNITE="Mo"
		fi
	else
		UNITE="Mo"
	fi
	echo -e "${COLTXT}Volume max. de chaque image :        ${COLINFO}${VOLUME} $UNITE"
fi

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Peut-on continuer ? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="o"
	fi
done


echo -e "$COLTXT"
if [ "$REPONSE" = "o" ]; then

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous creer un fichier de commentaires? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="o"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		echo -e "$COLTXT"
		echo "Tapez vos commentaires, eventuellement sur plusieurs lignes"
		echo "et pour finir, tapez une ligne ne contenant que le mot 'FIN'."
		if [ -e "$DESTINATION/${IMAGE}.txt" ]; then
			rm -f $DESTINATION/${IMAGE}.txt
		fi
		touch $DESTINATION/${IMAGE}.txt
		LIGNE=""
		echo -e "$COLSAISIE"
		while [ "$LIGNE" != "FIN" ]
		do
			read LIGNE
			echo "$LIGNE" >> $DESTINATION/${IMAGE}.txt
		done

		cat $DESTINATION/${IMAGE}.txt | sed -e "s/^FIN$//g" > $DESTINATION/${IMAGE}.txt.tmp
		cp -f $DESTINATION/${IMAGE}.txt.tmp $DESTINATION/${IMAGE}.txt
		rm -f $DESTINATION/${IMAGE}.txt.tmp

		echo -e "$COLTXT"
		echo "Vous avez saisi:"
		echo -e "$COLCMD"
		cat $DESTINATION/${IMAGE}.txt

		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour poursuivre."
		read PAUSE
	fi

	#if mount | grep $PART_CIBLE > /dev/null; then
	#	umount $PART_CIBLE
	#	sleep 1
	#fi

	#if [ -z "$TYPE" ]; then
	#	#mount $PART_CIBLE $PTMNTSTOCK||echo -e "${COLERREUR}ERREUR!${COLTXT}"&&exit 1
	#	echo -e "${COLCMD}mount $PART_CIBLE $PTMNTSTOCK"
	#	mount $PART_CIBLE $PTMNTSTOCK||ERREUR "Le montage de $PART_CIBLE a echoue!"
	#else
	#	#mount -t $TYPE $PART_CIBLE $PTMNTSTOCK||echo -e "${COLERREUR}ERREUR!${COLTXT}"&&exit 1
	#	echo -e "${COLCMD}mount -t $TYPE $PART_CIBLE $PTMNTSTOCK"
	#	mount -t $TYPE $PART_CIBLE $PTMNTSTOCK||ERREUR "Le montage de $PART_CIBLE a echoue!"
	#fi
	#sleep 5
	#partimage -f3 -z1 -c -d -V700 save $PART_SOURCE $PTMNTSTOCK/sauve

	#echo -e "$COLTXT"
	#echo "Si aucune erreur ne s'est affichee au montage, vous pouvez continuer."
	#echo -e "Peut-on continuer? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	#read REPONSE

	#while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	#do
	#	echo -e "$COLTXT"
	#	echo -e "Peut-on continuer? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	#	read REPONSE
	#done

	echo -e "$COLTXT"
	echo "Extraction d'infos materielles avec lshw, dmidecode, lspci, lsmod, lsusb..."
	echo -e "$COLCMD\c"
	FICHIERS_RAPPORT_CONFIG_MATERIELLE ${DESTINATION}

	type_fs=$(TYPE_PART ${PART_SOURCE})
	if [ "$type_fs" = "ntfs" ]; then
		echo -e "$COLINFO"
		echo "Depuis l'arrivee de seven ou de l'UEFI, il semble que des donnees cachees"
		echo "soient inscrites entre le MBR et la premiere partition"
		echo ""
		echo "Ces donnees ne sont pas sauvegardees par ntfsclone, partimage,..."

		echo -e "$COLTXT"
		echo "Sauvegarde des 5 premiers Mo de $HD avec dd..."
		echo -e "$COLCMD\c"
		dd if="/dev/${HD}" of="${DESTINATION}/${HD}_premiers_MO.bin" bs=1M count=5

		echo -e "$COLTXT"
		echo "Sauvegarde des 5 premiers Mo de $PART_SOURCE avec dd..."
		echo -e "$COLCMD\c"
		dd if=$PART_SOURCE of="${DESTINATION}/${IMAGE}_premiers_MO.bin" bs=1M count=5

		COMPTE_A_REBOURS "Suite dans " 5 " secondes."
	fi


	#if [ "$REPONSE" != "n" ]; then
		#if [ "$VOLUME" != "0" ]; then
		#	partimage -f0 -z$NIVEAU -c -d -o -b -V${VOLUME} save $PART_SOURCE $DESTINATION/$IMAGE
		#else
		#	partimage -f0 -z$NIVEAU -c -d -o -b save $PART_SOURCE $DESTINATION/$IMAGE
		#fi
		echo -e "$COLINFO"
		echo "Lancement de la sauvegarde..."
		t1=$(date +%s)
		t2=""
		sleep 1
		echo -e "$COLCMD"
		case $FORMAT_SVG in
			1)
				type_svg='partimage'
				if [ "$VOLUME" != "0" ]; then
					partimage -f0 -z$NIVEAU -c -d -o -b -V${VOLUME} save $PART_SOURCE $DESTINATION/$IMAGE
				else
					partimage -f0 -z$NIVEAU -c -d -o -b save $PART_SOURCE $DESTINATION/$IMAGE
				fi
			;;
			2)
				type_svg='dar'
				mkdir -p /mnt/$CHOIX_SOURCE
				if [ ! -z "$TYPE_FS" ]; then
					mount -t $TYPE_FS /dev/$CHOIX_SOURCE /mnt/$CHOIX_SOURCE
				else
					mount /dev/$CHOIX_SOURCE /mnt/$CHOIX_SOURCE
				fi
				case $NIVEAU in
					0)
						# Le format de compression n'est mis qu'a titre informatif.
						# Ce fichier n'est pas necessaire pour la restauration de l'image.
						# Par contre, il peut servir a determiner le chemin de stokage du bootsector.bin
						# dans le cas oÃ¹ l'image comporte plusieurs morceaux.
						echo "" > $DESTINATION/$IMAGE.type_compression.txt
						OPT_COMPRESS=""
					;;
					1)
						echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
						OPT_COMPRESS="-z2"
					;;
					2)
						echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
						OPT_COMPRESS="-y2"
					;;
				esac
				if [ "$VOLUME" != "0" ]; then
					$chemin_dar/dar -c $DESTINATION/$IMAGE -s ${VOLUME}M $OPT_COMPRESS -v -R /mnt/$CHOIX_SOURCE
				else
					$chemin_dar/dar -c $DESTINATION/$IMAGE $OPT_COMPRESS -v -R /mnt/$CHOIX_SOURCE
				fi
			;;
			3)
				type_svg='ntfsclone'

				# Il faudrait tester si la partition est OK.
				# ERROR: Volume '/dev/sda4' is sheduled for a check or it was shutdown uncleanly. Please boot Windows or use the --force option to progress.
				echo -e "$COLTXT"
				echo "Controle de la partition..."
				echo -e "$COLCMD\c"
				$chemin_ntfs/ntfsfix -d /dev/$CHOIX_SOURCE

				if [ "$VOLUME" != "0" ]; then
					case $NIVEAU in
						0)
							echo "" > $DESTINATION/$IMAGE.type_compression.txt
							$chemin_ntfs/ntfsclone --save-image -o - /dev/$CHOIX_SOURCE | split -b ${VOLUME}m - $DESTINATION/$IMAGE.ntfs
						;;
						1)
							echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
							$chemin_ntfs/ntfsclone --save-image -o - /dev/$CHOIX_SOURCE | gzip -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.ntfs
						;;
						2)
							echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
							$chemin_ntfs/ntfsclone --save-image -o - /dev/$CHOIX_SOURCE | bzip2 -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.ntfs
						;;
					esac
				else
					case $NIVEAU in
						0)
							echo "" > $DESTINATION/$IMAGE.type_compression.txt
							$chemin_ntfs/ntfsclone --save-image -o $DESTINATION/$IMAGE.ntfs /dev/$CHOIX_SOURCE
						;;
						1)
							echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
							$chemin_ntfs/ntfsclone --save-image -o - /dev/$CHOIX_SOURCE | gzip -c > $DESTINATION/$IMAGE.ntfs
						;;
						2)
							echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
							$chemin_ntfs/ntfsclone --save-image -o - /dev/$CHOIX_SOURCE | bzip2 -c > $DESTINATION/$IMAGE.ntfs
						;;
					esac
				fi
			;;
			4)
				#echo -e "$COLINFO"
				#echo "La sauvegarde n'est pas verbeuse."
				#echo "En apparence, rien ne se passe, soyez patient."
				#echo -e "$COLCMD\c"

				type_svg='fsarchiver'
				if [ "$VOLUME" != "0" ]; then
					echo "fsarchiver -o -z$NIVEAU -s ${VOLUME} ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PART_SOURCE"
					fsarchiver -o -z$NIVEAU -s ${VOLUME} ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PART_SOURCE
				else
					echo "fsarchiver -o -z$NIVEAU ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PART_SOURCE"
					fsarchiver -o -z$NIVEAU ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PART_SOURCE
				fi
			;;
		esac

		if [ "$?" != "0" ]; then
			echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
			ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
			date >> $DESTINATION/$IMAGE.ECHEC.txt
			df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

			ERREUR "La sauvegarde a echoue.\nControlez si la partition n est pas pleine.\nIl arrive aussi sur des partitions ext2 qu un ext2fs -p -y /dev/hdaX soit necessaire."
		else
			t2=$(date +%s)
			if [ "$FORMAT_SVG" = "2" ]; then
				umount /mnt/$CHOIX_SOURCE
			fi
			echo -e "$COLTXT"
			echo -e "La sauvegarde a reussi."
			echo -e "$COLCMD\c"

			echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
			ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
			date >> $DESTINATION/$IMAGE.SUCCES.txt
			df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt

			#=============================================================
			# Ajout pour le script restaure_svg_hdusb.sh
			# echo ${PART_SOURCE} | sed -e "s|.*/||g"
			# Cas du HP Proliant ML350 avec disque raid: /dev/cciss/c0d0p1

			#num_part=$(echo ${CHOIX_SOURCE} | sed -e "s|[A-Za-z]||g")

			#/sys/block/sda/sda1/partition

			num_part=$(cat /sys/block/${HD}/${CHOIX_SOURCE}/partition)

			taille_part=$(fdisk -s /dev/${CHOIX_SOURCE})
			if [ -e "$DESTINATION/liste_svg.csv" ]; then
				if ! grep -q "^${num_part};" $DESTINATION/liste_svg.csv; then
					echo "${num_part};${type_svg};${IMAGE};${taille_part};" >> $DESTINATION/liste_svg.csv
				else
					echo -e "${COLERREUR}ATTENTION:${COLTXT} Il existe deja une sauvegarde de partition n°${num_part}"
					echo "           Le fichier liste_svg.csv genere n'est pas directement utilisable pour"
					echo "           le script restaure_svg_hdusb.sh"
					read -t 5 PAUSE
				fi
			else
				duree_svg=""
				if [ -n "$t2" ]; then
					duree_svg=$(CALCULE_DUREE $t1 $t2)
					echo -e "${COLTXT}"
					echo -e "Duree de sauvegarde: ${COLINFO}${duree_svg}${COLTXT}"
				fi
				echo "${num_part};${type_svg};${IMAGE};${taille_part};${duree_svg};" > $DESTINATION/liste_svg.csv
			fi
			#=============================================================

			dossier_initial=$PWD
			cd ${DESTINATION}
			ls -lh $IMAGE*
			cd ${dossier_initial}
			echo -e "$COLTXT"
			COMPTE_A_REBOURS "Le script va poursuivre dans" 5 "secondes."
		fi


		HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
		fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
		#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt|cut -d"'" -f2)

		if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
			disque_en_GPT=/dev/${HD}
		else
			disque_en_GPT=""
		fi

		if [ -z "$disque_en_GPT" ]; then
			if fdisk -l /dev/$HD | grep /dev/${HD}1 > /dev/null; then
				echo -e "$COLINFO"
				echo "Sauvegarde de la table de partitions et du secteur de boot:"
				echo -e "$COLTXT"
				echo "Table de partition:"
				echo -e "$COLCMD"
				echo "dd if=/dev/$HD of=$DESTINATION/parttable.bin bs=512 count=1"
				dd if=/dev/$HD of=$DESTINATION/parttable.bin bs=512 count=1
				echo -e "$COLTXT"
				echo "Secteur de boot:"
				echo -e "$COLCMD"
				echo "dd if=/dev/${HD}1 of=$DESTINATION/bootsector.bin bs=512 count=1"
				dd if=/dev/${HD}1 of=$DESTINATION/bootsector.bin bs=512 count=1
			fi


			if [ ! -e "$DESTINATION/${HD}.out" ]; then
				echo -e "$COLTXT"
				echo "Sauvegarde de la table de partition avec sfdisk:"
				echo -e "$COLCMD"
				echo "sfdisk -d /dev/${HD} > $DESTINATION/${HD}.out"
				sfdisk -d /dev/${HD} > $DESTINATION/${HD}.out
			else
				echo -e "$COLTXT"
				echo "Sauvegarde de la table de partition avec sfdisk:"
				echo -e "$COLCMD"
				ladate=$(date +%Y%m%d_%H%M%S)
				echo "sfdisk -d /dev/${HD} > $DESTINATION/${HD}_${ladate}.out"
				sfdisk -d /dev/${HD} > $DESTINATION/${HD}_${ladate}.out
			fi
		else
			if [ ! -e "$DESTINATION/gpt_${HD}.out" ]; then
				echo -e "$COLTXT"
				echo "Sauvegarde de la table de partition avec sgdisk:"
				echo -e "$COLCMD"
				echo "sgdisk -b $DESTINATION/gpt_$HD.out /dev/$HD"
				sgdisk -b $DESTINATION/gpt_$HD.out /dev/$HD
			else
				echo -e "$COLTXT"
				echo "Sauvegarde de la table de partition avec sgdisk:"
				echo -e "$COLCMD"
				ladate=$(date +%Y%m%d_%H%M%S)
				echo "sgdisk -b $DESTINATION/gpt_${HD}_${ladate}.out /dev/$HD"
				sgdisk -b $DESTINATION/gpt_${HD}_${ladate}.out /dev/$HD
			fi
		fi

		#umount $PTMNTSTOCK&&rmdir $PTMNTSTOCK
		#echo ""
	#else
	#	echo -e "$COLERREUR"
	#	echo "ERREUR et ABANDON!"
	#	echo -e "$COLTXT"
	#	exit 1
	#fi
fi
echo -e "$COLTXT"
echo "Demontage de $PTMNTSTOCK"
echo -e "${COLCMD}umount $PTMNTSTOCK"
umount $PTMNTSTOCK

echo -e "${COLTITRE}"
echo "********"
echo "Termine!"
echo "********"

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour finir."
read PAUSE
exit 0


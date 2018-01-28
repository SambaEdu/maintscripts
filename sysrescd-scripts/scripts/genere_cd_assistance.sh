#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Script de generation d un CD assistance
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# D'après un script de Franck Molle (12/2003),
# lui-meme inspiré par les scripts du CD StoneHenge,...
# Dernière modification: 02/02/2013

# **********************************
# Version adaptée à System Rescue CD
# **********************************

source /bin/crob_fonctions.sh
source /bin/bibliotheque_ip_masque.sh

clear
echo -e "$COLTITRE"
echo "***************************************************"
echo "*    Ce script doit vous aider à générer un CD    *"
echo "*     d'assistance pour un établissement en       *"
echo "*                particulier                      *"
echo "***************************************************"

tmp=/tmp/root_$(date +%Y%m%d%H%M%S)
mkdir -p $tmp

PTMNTSTOCK="/mnt/gencd_$(date +%Y%m%d%H%M%S)"
mkdir -p $PTMNTSTOCK

echo -e "$COLPARTIE"
echo "================================================================="
echo "Choix de la partition à copier le contenu du CD et générer l'ISO"
echo "================================================================="

echo -e "$COLINFO"
echo "Il faut disposer ici de 2 fois le volume du CD."

AFFICHHD

DEFAULTDISK=$(GET_DEFAULT_DISK)

echo -e "$COLTXT"
echo "Sur quel disque faut-il copier l'arborescence du CD?"
echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
read HD

if [ -z "$HD" ]; then
	HD=${DEFAULTDISK}
fi

echo -e "$COLTXT"
echo "Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD\c"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
LISTE_PART ${HD} afficher_liste=y

#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
LISTE_PART ${HD} avec_tableau_liste=y
if [ ! -z "${liste_tmp[0]}" ]; then
	DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
else
	DEFAULTPART="hda1"
fi



echo -e "$COLTXT"
echo -e "Quelle est la partition où effectuer la copie? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
read CHOIX_PART_CD

if [ -z "$CHOIX_PART_CD" ]; then
	CHOIX_PART_CD="${DEFAULTPART}"
fi

PART_CD="/dev/$CHOIX_PART_CD"

if ! mount | grep "/dev/$CHOIX_PART_CD " > /dev/null; then
	#if fdisk -l /dev/$HD | grep "$PART_CD " | grep Linux > /dev/null; then

		#parted /dev/sda print | grep "^ 1" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f7

		num_part=$(echo $PART_CD | sed -e "s|^$HD||")

		#type_fs=$(parted /dev/$HD print | grep "^ 1" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f7)
		#type_fs=$(parted /dev/$HD print | sed -e "s/ \{2,\}/ /g" | grep "^ ${num_part} " | cut -d" " -f7)
		# PB: $type_fs est vide alors que la commande tapée dans une console ne donne pas cela...

		# Correction:
		#type_fs=$(TYPE_PART ${PART_CD})
		#if [ "$type_fs" = "ext2" -o "$type_fs" = "ext3" ]; then

		TMP_TYPE=$(parted /dev/${HD}${num_part} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
		if [ "$TMP_TYPE" = "ext2" -o "$TMP_TYPE" = "ext3" -o "$TMP_TYPE" = "ext4" -o "$TMP_TYPE" = "reiserfs" -o "$TMP_TYPE" = "xfs" -o "$TMP_TYPE" = "jfs" ]; then

			fsck="fsck.$type_fs"

			echo -e "$COLTXT"
			echo "Il peut arriver sur des partitions Linux qu'un scan soit nécessaire"
			echo "avant montage."

			REP_FSCK=""
			while [ "$REP_FSCK" != "o" -a "$REP_FSCK" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous contrôler la partition avec $fsck? [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
				read REP_FSCK

				if [ -z "$REP_FSCK" ]; then
					REP_FSCK="o"
				fi
			done

			if [ "$REP_FSCK" = "o" ]; then

				#if mount | grep "/dev/$PART_CD " > /dev/null; then
				if mount | grep "$PART_CD " > /dev/null; then
					#umount /dev/$PART_CD
					umount $PART_CD
					if [ "$?" = "0" ]; then
						echo -e "$COLTXT"
						echo "Lancement du 'scan'..."
						echo -e "$COLCMD\c"
						#$fsck /dev/$PART_CD
						$fsck $PART_CD
					else
						echo -e "$COLERREUR"
						#echo "Il semble que la partition /dev/$PART_CD soit montée"
						echo "Il semble que la partition $PART_CD soit montée"
						echo "et qu'elle ne puisse pas Ãªtre démontée."
						echo "Il n'est pas possible de scanner la partition dans ces conditions..."
						echo "... et probablement pas possible non plus de sauvegarder la partition"
						echo "tant qu'elle sera montée."
						echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de régler"
						#echo "le problème (démonter et scanner ($fsck /dev/$PART_CD))"
						echo "le problème (démonter et scanner ($fsck $PART_CD))"
						echo "avant de poursuivre."

						echo -e "$COLTXT"
						echo "Appuyez ensuite sur ENTREE pour poursuivre..."
						read PAUSE
					fi
				else
					echo -e "$COLTXT"
					echo "Lancement du 'scan'..."
					echo -e "$COLCMD\c"
					#$fsck /dev/$PART_CD
					$fsck $PART_CD
				fi

				POURSUIVRE
			fi
		fi
	#fi

	echo -e "$COLTXT"
	#echo "Quel est le type de la partition $PART_CIBLE?"
	echo "Quel est le type de la partition $PART_CD?"
	echo "(vfat (pour FAT32), ext2, ext3,...)"
	DETECTED_TYPE=$(TYPE_PART $PART_CD)
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
	if mount | grep "$PART_CD " > /dev/null; then
		umount $PART_CD
		sleep 1
	fi

	if mount | grep "${PTMNTSTOCK}" > /dev/null; then
		umount "${PTMNTSTOCK}"
		sleep 1
	fi

	echo -e "$COLTXT"
	echo "Montage de la partition ${PART_CD} en ${PTMNTSTOCK}:"
	if [ -z "$TYPE" ]; then
		echo -e "${COLCMD}mount ${PART_CD} ${PTMNTSTOCK}"
		mount ${PART_CD} "${PTMNTSTOCK}"||ERREUR "Le montage de ${PART_CD} a échoué!"
	else
		if [ "$TYPE" = "ntfs" ]; then
			echo -e "${COLCMD}ntfs-3g ${PART_CD} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G}"
			ntfs-3g ${PART_CD} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a échoué!"
		else
			echo -e "${COLCMD}mount -t $TYPE ${PART_CD} ${PTMNTSTOCK}"
			mount -t $TYPE ${PART_CD} "${PTMNTSTOCK}" || ERREUR "Le montage de ${PART_CD} a échoué!"
		fi
	fi

	echo -e "$COLTXT"
	echo "L'espace disponible sur cette partition:"
	echo -e "$COLCMD\c"
	df -h | egrep "(Filesystem|${PART_CD})"

fi



# CHOIX DE SOUS-DOSSIER
VERIF=""
while [ "$VERIF" != "OK" ]
do
	VERIF=""

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous effectuer la copie\ndans un sous-dossier de ${PTMNTSTOCK}? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	TEMOIN_NOUVEAU_DOSSIER="non"

	if [ "$REPONSE" = "o" ]; then
		#...
		echo -e "$COLTXT"

		echo -e "$COLTXT"
		echo "Voici les dossiers contenus dans ${PTMNTSTOCK}:"
		echo -e "$COLCMD"
		ls -l ${PTMNTSTOCK} | grep ^d > /tmp/ls.txt
		more /tmp/ls.txt

		echo -e "$COLTXT"
		echo "Dans quel dossier voulez-vous effectuer la copie?"
		echo "Complétez le chemin (le dossier sera créé si nécessaire)."
		echo -e "Chemin: ${COLCMD}${PTMNTSTOCK}/${COLSAISIE}\c"
		cd "${PTMNTSTOCK}"
		read -e DOSSTEMP
		cd /root

		DOSSIER=$(echo "$DOSSTEMP" | sed -e "s|/$||g")

		DESTINATION="${PTMNTSTOCK}/${DOSSIER}"
		if [ ! -e "${DESTINATION}" ]; then
			TEMOIN_NOUVEAU_DOSSIER="oui"
		fi
		mkdir -p "$DESTINATION"
	else
		DESTINATION="${PTMNTSTOCK}"
	fi

	echo -e "$COLTXT"
	echo -e "Vous souhaitez effectuer la copie vers ${COLINFO}${DESTINATION}${COLTXT}"

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

	echo -e "${COLTXT}Peut-on poursuivre avec ce choix de dossier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="o"
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




echo -e "$COLTXT"
echo "Copie du contenu du CD..."
echo -e "$COLCMD\c"
arbo_base=$DESTINATION/arbo_$(date +%Y%m%d%H%M%S)
mkdir -p ${arbo_base}
cp -a ${mnt_cdrom}/* ${arbo_base}/


echo -e "$COLPARTIE"
echo "=================="
echo "PARAMETRES DE BOOT"
echo "=================="

# IP
# MASK
# GW
# DNS

REPONSE=2
while [ "$REPONSE" = "2" ]
do
	IP=""
	while [ -z "$IP" ]
	do
		echo -e "$COLTXT"
		echo -e "Adresse IP: [${COLDEFAUT}10.127.164.200${COLTXT}] $COLSAISIE\c"
		read IP

		if [ -z "$IP" ]; then
			IP="10.127.164.200"
		fi

		test=$(echo "$IP" | tr "." "0" | sed -e "s/[0-9]//g" | wc -m)
		if [ "$test" != "1" ]; then
			echo -e "$COLTXT"
			echo -e "Caractères invalides: ---${COLINFO}${test}${COLTXT}---"
			IP=""
		else
			tmpip1=$(echo $IP | cut -d"." -f1)
			tmpip2=$(echo $IP | cut -d"." -f2)
			tmpip3=$(echo $IP | cut -d"." -f3)
			tmpip4=$(echo $IP | cut -d"." -f4)
			#echo -e "tmpip1=$tmpip1"
			#echo -e "tmpip2=$tmpip2"
			#echo -e "tmpip3=$tmpip3"
			#echo -e "tmpip4=$tmpip4"

			if [ -z "$tmpip1" ]; then
				IP=""
			else
				if [ "$tmpip1" != "0" ]; then
					if [ $tmpip1 -lt 1 -o $tmpip1 -gt 255  ]; then
						IP=""
					fi
				fi

				if [ -z "$tmpip2" ]; then
					IP=""
				else
					if [ "$tmpip2" != "0" ]; then
						if [ $tmpip2 -lt 1 -o $tmpip2 -gt 255  ]; then
							IP=""
						fi
					fi

					if [ -z "$tmpip3" ]; then
						IP=""
					else
						if [ "$tmpip3" != "0" ]; then
							if [ $tmpip3 -lt 1 -o $tmpip3 -gt 255  ]; then
								IP=""
							fi
						fi

						if [ -z "$tmpip4" ]; then
							IP=""
						else
							if [ "$tmpip4" != "0" ]; then
								if [ $tmpip4 -lt 1 -o $tmpip4 -gt 255  ]; then
									IP=""
								fi
							fi
						fi
					fi
				fi
			fi
		fi

		if [ -z "$IP" ]; then
			echo -e "$COLTXT"
			echo "Des caractères ou des valeurs invalides ont été saisis."
		fi
	done

	if [ "${IP:0:6}" = "10.127" -o "${IP:0:6}" = "10.176" ]; then
		DEFAULTMASK="255.255.0.0"
	else
		if [ "${IP:0:7}" = "172.21." -o "${IP:0:7}" = "172.20." ]; then
			DEFAULTMASK="255.255.255.192"
		else
			DEFAULTMASK="255.255.255.0"
		fi
	fi

	MASK=""
	while [ -z "$MASK" ]
	do
		echo -e "$COLTXT"
		#echo -e "Masque: [${COLDEFAUT}255.255.0.0${COLTXT}] $COLSAISIE\c"
		echo -e "Masque: [${COLDEFAUT}${DEFAULTMASK}${COLTXT}] $COLSAISIE\c"
		read MASK

		if [ -z "$MASK" ]; then
			#MASK="255.255.0.0"
			MASK=${DEFAULTMASK}
		fi

		test=$(echo "$MASK" | tr "." "0" | sed -e "s/[0-9]//g" | wc -m)
		if [ "$test" != "1" ]; then
			MASK=""
		else
			tmpmask1=$(echo $MASK | cut -d"." -f1)
			tmpmask2=$(echo $MASK | cut -d"." -f2)
			tmpmask3=$(echo $MASK | cut -d"." -f3)
			tmpmask4=$(echo $MASK | cut -d"." -f4)

			if [ -z "$tmpmask1" ]; then
				MASK=""
			else
				if [ "$tmpmask1" != "0" ]; then
					if [ $tmpmask1 -lt 1 -o $tmpmask1 -gt 255  ]; then
						MASK=""
					fi
				fi

				if [ -z "$tmpmask2" ]; then
					MASK=""
				else
					if [ "$tmpmask2" != "0" ]; then
						if [ $tmpmask2 -lt 1 -o $tmpmask2 -gt 255  ]; then
							MASK=""
						fi
					fi

					if [ -z "$tmpmask3" ]; then
						MASK=""
					else
						if [ "$tmpmask3" != "0" ]; then
							if [ $tmpmask3 -lt 1 -o $tmpmask3 -gt 255  ]; then
								MASK=""
							fi
						fi

						if [ -z "$tmpmask4" ]; then
							MASK=""
						else
							if [ "$tmpmask4" != "0" ]; then
								if [ $tmpmask4 -lt 1 -o $tmpmask4 -gt 255  ]; then
									MASK=""
								fi
							fi
						fi
					fi
				fi
			fi
		fi

		if [ -z "$MASK" ]; then
			echo -e "$COLTXT"
			echo "Des caractères invalides ont été saisis."
		fi
	done

	TMPNETWORK=$(calcule_reseau $IP $MASK)
	TMPBROADCAST=$(calcule_broadcast $IP $MASK)

	echo -e "$COLTXT"
	echo -e "Réseau: [${COLDEFAUT}${TMPNETWORK}${COLTXT}] $COLSAISIE\c"
	read NETWORK

	if [ -z "$NETWORK" ]; then
		NETWORK="$TMPNETWORK"
	fi

	echo -e "$COLTXT"
	echo -e "Broadcast: [${COLDEFAUT}${TMPBROADCAST}${COLTXT}] $COLSAISIE\c"
	read BROADCAST

	if [ -z "$BROADCAST" ]; then
		BROADCAST="${TMPBROADCAST}"
	fi

	tmpip1=$(echo $IP | cut -d"." -f1)
	tmpip2=$(echo $IP | cut -d"." -f2)
	tmpip3=$(echo $IP | cut -d"." -f3)
	if [ "$MASK" = "255.255.0.0" ]; then
		TMPGW="$tmpip1.$tmpip2.164.1"
	else
		if [ "$MASK" = "255.255.255.192" ]; then
			tmpip4=$(echo $NETWORK | cut -d"." -f4)
			tmpip4=$(($tmpip4+1))
			TMPGW="$tmpip1.$tmpip2.$tmpip3.$tmpip4"
		else
			TMPGW="$tmpip1.$tmpip2.$tmpip3.1"
		fi
	fi

	echo -e "$COLTXT"
	echo -e "Passerelle: [${COLDEFAUT}${TMPGW}${COLTXT}] $COLSAISIE\c"
	read GW

	if [ -z "$GW" ]; then
		GW="${TMPGW}"
	fi

	if [ "$MASK" = "255.255.0.0" -o "$MASK" = "255.255.255.192" ]; then
		#tmpip1=$(echo $IP | cut -d"." -f1)
		#tmpip2=$(echo $IP | cut -d"." -f2)
		#TMPDNS="$tmpip1.$tmpip2.164.1"
		TMPDNS=$GW
	else
		TMPDNS="${DNS_ACAD}"
	fi

	echo -e "$COLTXT"
	echo -e "Serveur DNS: [${COLDEFAUT}${TMPDNS}${COLTXT}] $COLSAISIE\c"
	read DNS

	if [ -z "$DNS" ]; then
		DNS="${TMPDNS}"
	fi

	echo -e "$COLINFO"
	echo "Rappel de la configuration choisie:"
	echo -e " ${COLTXT}IP:        ${COLINFO}${IP}"
	echo -e " ${COLTXT}MASK:      ${COLINFO}${MASK}"
	echo -e " ${COLTXT}NETWORK:   ${COLINFO}${NETWORK}"
	echo -e " ${COLTXT}BROADCAST: ${COLINFO}${BROADCAST}"
	echo -e " ${COLTXT}GW:        ${COLINFO}${GW}"
	echo -e " ${COLTXT}DNS:       ${COLINFO}${DNS}"

	POURSUIVRE_OU_CORRIGER "1"
done


# CLE_SSH
echo -e "$COLTXT"
echo "Vous allez maintenant choisir les clés qui seront autorisées."
ls /root/cles_pub_ssh/ > $tmp/liste_cles.txt
liste=""
while read A
do
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous autoriser ${COLINFO}${A}${COLTXT}? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE < /dev/tty
		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		cle=$(echo ${A} | cut -d"." -f1)
		liste="$liste,$cle"
	fi
done < $tmp/liste_cles.txt

liste=${liste:1}



echo -e "$COLTXT"
echo "Veuillez maintenant fournir le RNE de l'établissement."
REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo -e "RNE: $COLSAISIE\c"
	read RNE

	tst=$(echo "$RNE" | sed -e "s/[0-9a-zA-Z]//g")
	if [ -n "$tst" ]; then
		RNE=""
	fi

	if [ -z "$RNE" ]; then
		REPONSE=""
	else
		POURSUIVRE_OU_CORRIGER "1"
	fi
done


#mv ${arbo_base}/isolinux/isolinux.cfg ${arbo_base}/isolinux/isolinux.cfg.ini
#grep -B 10000 "label assist" ${arbo_base}/isolinux/isolinux.cfg.ini | grep -v "^label assist$" > ${arbo_base}/isolinux/isolinux.cfg
cp ${arbo_base}/isolinux/reserve/isolinux.bin.reserve ${arbo_base}/isolinux/isolinux.bin
#echo "
#label assist
#  kernel rescuecd
#  append initrd=initram.igz scandelay=1 setkmap=fr ip=$IP mask=$MASK gw=$GW dns=$DNS cle_ssh=${liste} work=assistance_ssh.sh autoruns=0 ar_nowait
#
## Ne pas creer d autre LABEL sous le label assist" >> ${arbo_base}/isolinux/isolinux.cfg

mv ${arbo_base}/isolinux/isolinux.cfg ${arbo_base}/isolinux/isolinux.cfg.ini
sed -e "s|###ASSIST### ||g" ${arbo_base}/isolinux/isolinux.cfg.modele > ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|###IP_ASSIST###|$IP|g" ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|###MASK_ASSIST###|$MASK|g" ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|###GW_ASSIST###|$GW|g" ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|###DNS_ASSIST###|$DNS|g" ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|###LISTE_CLES_PUB###|$liste|g" ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|^ONTIMEOUT .*|ONTIMEOUT assist|g" ${arbo_base}/isolinux/isolinux.cfg
sed -i "s|^MENU DEFAULT .*|MENU DEFAULT assist|g" ${arbo_base}/isolinux/isolinux.cfg
#============================================================================


echo -e "$COLPARTIE"
echo "==================="
echo "Génération de l'ISO"
echo "==================="

# Proposer un autre emplacement?

echo -e "$COLCMD\c"

chaine_utf8_ou_pas=""
#chaine_utf8_ou_pas=" -input-charset utf-8 "

suffixe=$RNE
auteur="Steph"
producteur="Ac-Rouen"
nom_iso="CD_ASSISTANCE_${RNE}_$(date +%Y%m%d)"
chemin_iso=$DESTINATION

#mkisofs -J -R -l -v -volid "$suffixe" -p "$auteur" -publisher "$producteur" -A "Created 'Barts way' using MKISOFS/CDRECORD" -b isolinux/isolinux.bin ${chaine_utf8_ou_pas} -no-emul-boot -boot-load-size 4 -boot-info-table -hide isolinux.bin -hide-joliet isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -joliet-long -o $chemin_iso/${nom_iso}.iso $arbo_base
cd $chemin_iso
mkisofs -J -R -l -v -volid "$suffixe" -p "$auteur" -publisher "$producteur" -A "Created 'Barts way' using MKISOFS/CDRECORD" -b isolinux/isolinux.bin ${chaine_utf8_ou_pas} -no-emul-boot -boot-load-size 4 -boot-info-table -hide isolinux.bin -hide-joliet isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -joliet-long -o $chemin_iso/${nom_iso}.iso $(basename $arbo_base)


cd /root


echo -e "$COLTXT"
echo "Démontage de $PTMNTSTOCK"
echo -e "${COLCMD}umount $PTMNTSTOCK"
umount $PTMNTSTOCK

echo -e "${COLTITRE}"
echo "********"
echo "Terminé!"
echo "********"

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour finir."
read PAUSE
exit 0

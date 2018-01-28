#!/bin/bash

# Script de changement de mot de passe GRUB ou LILO:
# Version du: 24/06/2013

COLPARTIE="\033[1;34m"
COLINFO="\033[0;33m"
COLTITRE="\033[1;35m"
COLTXT="\033[0;37m"
COLCMD="\033[1;37m"
COLSAISIE="\033[1;32m"
COLERREUR="\033[1;31m"
COLCHOIX="\033[1;33m"
COLDEFAUT="\033[0;33m"

echo -e "$COLPARTIE"
echo "*********************************************"
echo "* Changement du mot de passe du Boot Loader *"
echo "*********************************************"

. /bin/crob_fonctions.sh

# Pour eliminer les options ar_nowait,... qui ne permettent pas de d�finir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

#test_dd_monte=$(mount | grep "/dev/" | egrep -v "(/dev/pts|/dev/loop|/dev/shm)")
test_dd_monte=$(mount | egrep "(^/dev/sda|^/dev/hda|^/dev/sdb|^/dev/hdb)" | grep " on / type ")
if [ -z "$test_dd_monte" ]; then
	echo -e "$COLERREUR"
	echo "Aucun disque dur n'a l'air monte."

	echo -e "$COLINFO"
	echo "Tentative de montage..."

	if [ "$change_mdp" = "auto" ]; then
		BOOTDISK=$(GET_DEFAULT_DISK)

		tst=$(sfdisk -s /dev/$BOOTDISK 2>/dev/null)
		if [ -z "${tst}" -o "${tst}" = "0" ]; then
			echo -e "${COLERREUR}Le disque '$BOOTDISK' n'existe pas.${COLTXT}"
			temoin_erreur="y"
		fi

		if [ "$temoin_erreur" != "y" ]; then
			BOOTDISK_CLEAN=$(echo ${BOOTDISK}|sed -e "s|[^0-9A-Za-z]|_|g")
			fdisk -l /dev/$BOOTDISK > /tmp/fdisk_l_${BOOTDISK_CLEAN}.txt 2>&1
			#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${BOOTDISK}'" /tmp/fdisk_l_${BOOTDISK_CLEAN}.txt|cut -d"'" -f2)

			if [ "$(IS_GPT_PARTTABLE ${BOOTDISK})" = "y" ]; then
				disque_en_GPT=/dev/${BOOTDISK}
			else
				disque_en_GPT=""
			fi

			if [ -z "$disque_en_GPT" ]; then
				liste_tmp=($(fdisk -l /dev/${BOOTDISK} | grep "/dev/${BOOTDISK}[0-9]" | grep "Linux" | grep -v "Linux swap" | grep -v "xt" | cut -d" " -f1))
			else
				BOOTDISK_CLEAN=$(echo ${BOOTDISK}|sed -e "s|[^0-9A-Za-z]|_|g")
				parted /dev/${BOOTDISK_CLEAN} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${BOOTDISK_CLEAN}.txt

				cpt_tmp=0
				while read A
				do
					NUM_PART=$(echo "$A"|cut -d" " -f1)
					TMP_TYPE=$(parted /dev/${BOOTDISK}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
					if [ "$TMP_TYPE" = "ext2" -o "$TMP_TYPE" = "ext3" -o "$TMP_TYPE" = "ext4" -o "$TMP_TYPE" = "reiserfs" -o "$TMP_TYPE" = "xfs" -o "$TMP_TYPE" = "jfs" ]; then
						liste_tmp[${cpt_tmp}]=$(echo "${BOOTDISK}${NUM_PART}")
						cpt_tmp=$((cpt_tmp+1))
					fi
				done < /tmp/partitions_${BOOTDISK_CLEAN}.txt
			fi

			DOSS_RAND=$RANDOM
			DEFAULTPART=""
			cpt=0
			test_lilo=$(head /dev/sda | strings | grep "LILO")
			while [ $cpt -le ${#liste_tmp[*]} ]
			do
				mkdir -p /mnt/$DOSS_RAND
				mount ${liste_tmp[$cpt]} /mnt/$DOSS_RAND
				if [ -n "$test_lilo" ]; then
					if [ -e "/mnt/$DOSS_RAND/etc/lilo.conf" ]; then
						DEFAULTPART=$(echo ${liste_tmp[$cpt]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
						umount /mnt/$DOSS_RAND
						break
					fi
				else
					if [ -e "/mnt/$DOSS_RAND/boot/grub" ]; then
						DEFAULTPART=$(echo ${liste_tmp[$cpt]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
						umount /mnt/$DOSS_RAND
						break
					fi
				fi
				umount /mnt/$DOSS_RAND
			
				cpt=$(($cpt+1))
			done
			
			if [ -z "$DEFAULTPART" ]; then
				echo -e "${COLERREUR}Le disque '$BOOTDISK' n'existe pas.${COLTXT}"
				temoin_erreur="y"
			else
				PART=$DEFAULTPART
				DETECTED_TYPE=$(TYPE_PART $PART)

				echo -e "$COLCMD\c"
				if mount | grep "$PART " > /dev/null; then
					umount /dev/$PART
					sleep 1
				fi
				
				PTMNTSTOCK=/mnt/$PART
				mkdir -p ${PTMNTSTOCK}
				if mount | grep "${PTMNTSTOCK}" > /dev/null; then
					umount "${PTMNTSTOCK}"
					sleep 1
				fi
				
				PARTSTOCK=/dev/${PART}
				
				echo -e "$COLTXT"
				echo "Montage de la partition ${PARTSTOCK} en ${PTMNTSTOCK}:"
				if [ -z "$TYPE" ]; then
					echo -e "${COLCMD}mount ${PARTSTOCK} ${PTMNTSTOCK}"
					mount ${PARTSTOCK} "${PTMNTSTOCK}"||ERREUR "Le montage de ${PARTSTOCK} a échoué!"
				else
					if [ "$TYPE" = "ntfs" ]; then
						echo -e "${COLCMD}ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G}"
						ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a échoué!"
					else
						echo -e "${COLCMD}mount -t $TYPE ${PARTSTOCK} ${PTMNTSTOCK}"
						mount -t $TYPE ${PARTSTOCK} "${PTMNTSTOCK}" || ERREUR "Le montage de ${PARTSTOCK} a échoué!"
					fi
				fi
			fi
		fi
	else
		DEFAULTDISK=$(GET_DEFAULT_DISK)
		
		BOOTDISK=""
		while [ -z "$BOOTDISK" ]
		do
			echo -e "$COLTXT"
			echo -e "Sur quel disque le systeme boote-t-il? [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] ${COLSAISIE}\c"
			read BOOTDISK
		
			if [ -z "$BOOTDISK" ]; then
				BOOTDISK=${DEFAULTDISK}
			fi
		
			tst=$(sfdisk -s /dev/$BOOTDISK 2>/dev/null)
			if [ -z "${tst}" -o "${tst}" = "0" ]; then
				echo -e "${COLERREUR}Le disque '$BOOTDISK' n'existe pas.${COLTXT}"
				BOOTDISK=""
			fi
		done

		echo -e "$COLTXT"
		echo "Quelle est la partition racine Linux?"
		echo "Voici la/les partition(s) susceptibles de convenir:"
		echo -e "$COLCMD"
		BOOTDISK_CLEAN=$(echo ${BOOTDISK}|sed -e "s|[^0-9A-Za-z]|_|g")
		fdisk -l /dev/$BOOTDISK > /tmp/fdisk_l_${BOOTDISK_CLEAN}.txt 2>&1
		#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${BOOTDISK}'" /tmp/fdisk_l_${BOOTDISK_CLEAN}.txt|cut -d"'" -f2)

		if [ "$(IS_GPT_PARTTABLE ${BOOTDISK})" = "y" ]; then
			disque_en_GPT=/dev/${BOOTDISK}
		else
			disque_en_GPT=""
		fi

		if [ -z "$disque_en_GPT" ]; then
			fdisk -l /dev/${BOOTDISK} | grep "/dev/${BOOTDISK}[0-9]" | grep "Linux" | grep -v "Linux swap" | grep -v "xt"
			liste_tmp=($(fdisk -l /dev/${BOOTDISK} | grep "/dev/${BOOTDISK}[0-9]" | grep "Linux" | grep -v "Linux swap" | grep -v "xt" | cut -d" " -f1))
		else
			BOOTDISK_CLEAN=$(echo ${BOOTDISK}|sed -e "s|[^0-9A-Za-z]|_|g")
			parted /dev/${BOOTDISK_CLEAN} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${BOOTDISK_CLEAN}.txt

			cpt_tmp=0
			while read A
			do
				NUM_PART=$(echo "$A"|cut -d" " -f1)
				TMP_TYPE=$(parted /dev/${BOOTDISK}${NUM_PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
				if [ "$TMP_TYPE" = "ext2" -o "$TMP_TYPE" = "ext3" -o "$TMP_TYPE" = "ext4" -o "$TMP_TYPE" = "reiserfs" -o "$TMP_TYPE" = "xfs" -o "$TMP_TYPE" = "jfs" ]; then
					echo "${BOOTDISK}${A}"
					liste_tmp[${cpt_tmp}]=$(echo "${BOOTDISK}${NUM_PART}")
					cpt_tmp=$((cpt_tmp+1))
				fi
			done < /tmp/partitions_${BOOTDISK_CLEAN}.txt
		fi

		DOSS_RAND=$RANDOM
		
		DEFAULTPART=""
		cpt=0
		while [ $cpt -le ${#liste_tmp[*]} ]
		do
			mkdir -p /mnt/$DOSS_RAND
			mount ${liste_tmp[$cpt]} /mnt/$DOSS_RAND
			if [ -e "/mnt/$DOSS_RAND/boot/grub" ]; then
				DEFAULTPART=$(echo ${liste_tmp[$cpt]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
				umount /mnt/$DOSS_RAND
				break
			fi
			umount /mnt/$DOSS_RAND
		
			cpt=$(($cpt+1))
		done
		
		if [ -z "$DEFAULTPART" ]; then
			if [ ! -z "${liste_tmp[0]}" ]; then
				DEFAULTPART=$(echo ${liste_tmp[0]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
			else
				DEFAULTPART=""
			fi
		fi
		
		PART=""
		while [ -z "$PART" ]
		do
			echo -e "$COLTXT"
			echo -e "Quelle est la partition systeme Linux? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
			read PART
		
			if [ -z "$PART" ]; then
				PART=${DEFAULTPART}
			fi
		
			if [ ! -e /dev/$PART ]; then
				echo -e "${COLERREUR}La partition '$PART' n'existe pas.${COLTXT}"
				PART=""
			else
				tst=$(sfdisk -s /dev/$PART 2>/dev/null)
				if [ -z "${tst}" -o "${tst}" = "0" -o ! -e "/sys/block/${BOOTDISK}/${PART}/partition" ]; then
					echo -e "${COLERREUR}La partition '$PART' n'existe pas.${COLTXT}"
					PART=""
				fi
			fi
		done
		
		echo -e "$COLTXT"
		echo "Quel est le type de la partition $PART?"
		echo "(ext2, ext3, xfs,...)"
		DETECTED_TYPE=$(TYPE_PART $PART)
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
		if mount | grep "$PART " > /dev/null; then
			umount /dev/$PART
			sleep 1
		fi
		
		PTMNTSTOCK=/mnt/$PART
		mkdir -p ${PTMNTSTOCK}
		if mount | grep "${PTMNTSTOCK}" > /dev/null; then
			umount "${PTMNTSTOCK}"
			sleep 1
		fi
		
		PARTSTOCK=/dev/${PART}
		
		echo -e "$COLTXT"
		echo "Montage de la partition ${PARTSTOCK} en ${PTMNTSTOCK}:"
		if [ -z "$TYPE" ]; then
			echo -e "${COLCMD}mount ${PARTSTOCK} ${PTMNTSTOCK}"
			mount ${PARTSTOCK} "${PTMNTSTOCK}"||ERREUR "Le montage de ${PARTSTOCK} a échoué!"
		else
			if [ "$TYPE" = "ntfs" ]; then
				echo -e "${COLCMD}ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G}"
				ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a échoué!"
			else
				echo -e "${COLCMD}mount -t $TYPE ${PARTSTOCK} ${PTMNTSTOCK}"
				mount -t $TYPE ${PARTSTOCK} "${PTMNTSTOCK}" || ERREUR "Le montage de ${PARTSTOCK} a échoué!"
			fi
		fi

	fi

fi

if [ "$temoin_erreur" != "y" ]; then
	if [ -n "$test_dd_monte" ]; then
		t=$(head /dev/sda | strings | grep "LILO")
		if [ -n "$t" ]; then
			#/bin/change_mdp_lilo.sh
			/root/scripts_pour_sysresccd_sur_hd/change_mdp_lilo.sh
		else
			t=$(head /dev/sda | strings | grep "GRUB")
			if [ -n "$t" ]; then
				#/bin/change_mdp_grub.sh
				/root/scripts_pour_sysresccd_sur_hd/change_mdp_grub.sh
			else
				echo -e "$COLERREUR"
				echo "Le chargeur de demarrage installe n'a pas ete identifie."
		
				REP=""
				while [ -z "${REP}" ]
				do
					echo -e "${COLTXT}"
					echo -e "Voulez-vous:"
					echo -e " (${COLCHOIX}1${COLTXT}) Reinstaller LILO"
					echo -e " (${COLCHOIX}2${COLTXT}) Reinstaller GRUB"
					echo -e " (${COLCHOIX}3${COLTXT}) Abandonner"
					echo -e "Votre choix: [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
					read REP
		
					if [ -z "$REP" ]; then
						REP=2
					fi
		
					if [ "$REP" != "1" -a "$REP" != "2" -a "$REP" != "3" ]; then
						REP=""
					fi
				done
		
				if [ "$REP" = "1" ]; then
					#/bin/change_mdp_lilo.sh
					/root/scripts_pour_sysresccd_sur_hd/change_mdp_lilo.sh
				else
					if [ "$REP" = "2" ]; then
						#/bin/change_mdp_grub.sh
						/root/scripts_pour_sysresccd_sur_hd/change_mdp_grub.sh
					else
						echo -e "$COLERREUR"
						echo "ABANDON"
					fi
				fi
			fi
		fi
	else
		cp /bin/crob_fonctions.sh ${PTMNTSTOCK}/bin/
		cp /root/scripts_pour_sysresccd_sur_hd/change_mdp_grub.sh ${PTMNTSTOCK}/bin/
		cp /root/scripts_pour_sysresccd_sur_hd/change_mdp_lilo.sh ${PTMNTSTOCK}/bin/
		chmod +x ${PTMNTSTOCK}/bin/*

		t=$(head /dev/sda | strings | grep "LILO")
		if [ -n "$t" ]; then
			echo "mount -o bind /proc ${PTMNTSTOCK}/proc
mount -o bind /dev ${PTMNTSTOCK}/dev
mount -o bind /sys ${PTMNTSTOCK}/sys"
			mount -o bind /proc ${PTMNTSTOCK}/proc
			mount -o bind /dev ${PTMNTSTOCK}/dev
			mount -o bind /sys ${PTMNTSTOCK}/sys
			echo "chroot ${PTMNTSTOCK} /bin/change_mdp_lilo.sh"
			chroot ${PTMNTSTOCK} /bin/change_mdp_lilo.sh
			echo "umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys"
			umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys
		else
			t=$(head /dev/sda | strings | grep "GRUB")
			if [ -n "$t" ]; then
				echo "mount -o bind /proc ${PTMNTSTOCK}/proc
mount -o bind /dev ${PTMNTSTOCK}/dev
mount -o bind /sys ${PTMNTSTOCK}/sys"
				mount -o bind /proc ${PTMNTSTOCK}/proc
				mount -o bind /dev ${PTMNTSTOCK}/dev
				mount -o bind /sys ${PTMNTSTOCK}/sys
				echo "chroot ${PTMNTSTOCK} /bin/change_mdp_grub.sh"
				chroot ${PTMNTSTOCK} /bin/change_mdp_grub.sh
				echo "umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys"
				umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys
			else
				echo -e "$COLERREUR"
				echo "Le chargeur de demarrage installe n'a pas ete identifie."
			fi
		fi
	fi

	echo -e "${COLTITRE}"
	echo "Terminé."
	echo -e "${COLTXT}"
else
	echo -e "${COLERREUR}"
	echo "ABANDON"
	echo -e "${COLTXT}"
fi

if [ -z "$delais_reboot" ]; then
	# Pour etre sur que le nettoyage de tache ait le temps de passer
	delais_reboot=120
fi

t=$(grep "auto_reboot=y" /proc/cmdline)
if [ -n "$t" ]; then
	echo -e "$COLTXT"
	#echo "Reboot dans $delais_reboot secondes..."
	#sleep $delais_reboot
	COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes..."
	reboot
fi

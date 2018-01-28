#!/bin/bash

# Script de (re)installation de Grub
# Derniere modification: 08/04/2014

mnt_cdrom=/livemnt/boot

# Chargement d'une bibliotheque de fonctions
#source /bin/crob_fonctions.sh
if [ -e /bin/crob_fonctions.sh ]; then
	. /bin/crob_fonctions.sh
else
	if [ -e ${mnt_cdrom}/sysresccd/scripts/crob_fonctions.sh ]; then
		. ${mnt_cdrom}/sysresccd/scripts/crob_fonctions.sh
	else
		echo "ERREUR: La bibliotheque de fonctions crob_fonctions.sh n'a pas ete trouvee:"
		#echo "        ni en /bin/crob_fonctions.sh (dans le sysrcd.dat)"
		echo "        ni copiee depuis ${mnt_cdrom}/sysresccd/scripts.tar.gz via l'autorun"
		echo "        ni en ${mnt_cdrom}/sysresccd/scripts/crob_fonctions.sh"
		echo "ABANDON."
		sleep 3
		exit
	fi
fi

echo -e "$COLTITRE"
echo "*********************************"
echo "* Script de reinstallation GRUB *"
echo "*********************************"

AFFICHHD

DEFAULTDISK=$(GET_DEFAULT_DISK)

BOOTDISK=""
temoin_erreur="n"

# Pour eliminer les options ar_nowait,... qui ne permettent pas de définir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

if echo "$*" |grep -q "reinstall_grub=auto"; then
	reinstall_grub="auto"
fi

if [ "$reinstall_grub" = "auto" ]; then
	BOOTDISK=$DEFAULTDISK

	tst=$(sfdisk -s /dev/$BOOTDISK)
	if [ -z "${tst}" -o "${tst}" = "0" ]; then
		echo -e "${COLERREUR}Le disque '$BOOTDISK' n'existe pas.${COLTXT}"
		temoin_erreur="y"
	fi
fi

if [ "$temoin_erreur" = "n" ]; then
	while [ -z "$BOOTDISK" ]
	do
		echo -e "$COLTXT"
		echo -e "Sur quel disque le systeme boote-t-il? [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] ${COLSAISIE}\c"
		read BOOTDISK
	
		if [ -z "$BOOTDISK" ]; then
			BOOTDISK=${DEFAULTDISK}
		fi
	
		tst=$(sfdisk -s /dev/$BOOTDISK)
		if [ -z "${tst}" -o "${tst}" = "0" -o ! -e "/sys/block/$BOOTDISK" ]; then
			echo -e "${COLERREUR}Le disque '$BOOTDISK' n'existe pas.${COLTXT}"
			BOOTDISK=""
		fi
	done
	
	# MODELE
	#default         0
	#timeout         5
	#color cyan/blue white/blue
	#title           Debian GNU/Linux, kernel 2.6.24-etchnhalf.1-686
	#root            (hd0,4)
	#kernel          /boot/vmlinuz-2.6.24-etchnhalf.1-686 root=/dev/sda5 ro
	#initrd          /boot/initrd.img-2.6.24-etchnhalf.1-686
	#savedefault
	
	# Pour le moment, on ne gere que la reinstallation de Grub
	
	echo -e "$COLTXT"
	echo "Quelle est la partition racine Linux?"
	echo "Voici la/les partition(s) susceptibles de convenir:"
	echo -e "$COLCMD"
	#fdisk -l /dev/${BOOTDISK} | grep "/dev/${BOOTDISK}[0-9]" | grep "Linux" | grep -v "Linux swap" | grep -v "xt"
	#liste_tmp=($(fdisk -l /dev/${BOOTDISK} | grep "/dev/${BOOTDISK}[0-9]" | grep "Linux" | grep -v "Linux swap" | grep -v "xt" | cut -d" " -f1))
	LISTE_PART ${BOOTDISK} afficher_liste=y avec_tableau_liste=y type_part_cherche=linux

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
	if [ "$reinstall_grub" = "auto" ]; then
		if [ -z "$DEFAULTPART" ]; then
			echo -e "$COLERREUR"
			echo "La partition Linux n'a pas ete idendifiee."
		else
			PART=$DEFAULTPART

			tst=$(sfdisk -s /dev/$PART)
			if [ -z "${tst}" -o "${tst}" = "0" -o ! -e "/sys/block/$BOOTDISK/$PART/partition" ]; then
				echo -e "${COLERREUR}La partition '$PART' n'existe pas.${COLTXT}"
				PART=""

				temoin_erreur="y"
			fi
		fi
	fi

	if [ "$temoin_erreur" = "n" ]; then
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
				tst=$(sfdisk -s /dev/$PART)
				if [ -z "${tst}" -o "${tst}" = "0" ]; then
					echo -e "${COLERREUR}La partition '$PART' n'existe pas.${COLTXT}"
					PART=""
				fi
			fi
		done
		
		echo -e "$COLTXT"
		echo "Quel est le type de la partition $PART?"
		echo "(ext2, ext3, xfs,...)"
		DETECTED_TYPE=$(TYPE_PART $PART)

		if [ "$reinstall_grub" = "auto" ]; then
			TYPE=$DETECTED_TYPE
		else
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
			mount ${PARTSTOCK} "${PTMNTSTOCK}"||ERREUR "Le montage de ${PARTSTOCK} a Ã©chouÃ©!"
		else
			if [ "$TYPE" = "ntfs" ]; then
				echo -e "${COLCMD}ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G}"
				ntfs-3g ${PARTSTOCK} ${PTMNTSTOCK} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a Ã©chouÃ©!"
			else
				echo -e "${COLCMD}mount -t $TYPE ${PARTSTOCK} ${PTMNTSTOCK}"
				mount -t $TYPE ${PARTSTOCK} "${PTMNTSTOCK}" || ERREUR "Le montage de ${PARTSTOCK} a Ã©chouÃ©!"
			fi
		fi
		
		# Controler le /etc/fstab et le /boot/grub/menu.lst
		# Si ca ne coincide pas, corriger d'apres le fstab
		# Ca n'ira pas si on a des UUID
		
		# La partition racine:
		echo -e "$COLTXT"
		echo "Voici le contenu du fichier fstab de la partition:"
		echo -e "$COLCMD\c"
		cat ${PTMNTSTOCK}/etc/fstab
		
		DEF_RACINE=$(cat ${PTMNTSTOCK}/etc/fstab | grep -v "^#" | tr "\t" " "| grep " / " | sed -e "s|^ ||g" | grep -v "^tmpfs" | cut -d" " -f1)
		RACINE=""

		if [ "$reinstall_grub" = "auto" ]; then
			RACINE=$DEF_RACINE
		fi

		while [ -z "$RACINE" ]
		do
			echo -e "$COLTXT"
			echo -e "Quelle est la partition racine? [${COLDEFAUT}${DEF_RACINE}${COLTXT}] ${COLSAISIE}\c"
			read RACINE
		
			if [ -z "$RACINE" ]; then
				RACINE=${DEF_RACINE}
			fi
		done
		
		tmp=/tmp/grub_$(date +%Y%m%d%H%M%S)
		mkdir -p ${tmp}
		
		if [ -e ${PTMNTSTOCK}/boot/grub/grub.cfg -a -e ${PTMNTSTOCK}/etc/grub.d/00_header ]; then
			# Cas de Grub>=1.97
			grep "\-\-fs-uuid" ${PTMNTSTOCK}/boot/grub/grub.cfg > ${tmp}/grub_kernel_lst.txt
			grep "root=" ${PTMNTSTOCK}/boot/grub/grub.cfg >> ${tmp}/grub_kernel_lst.txt
		else
			TEMOIN=""
			grep "^kernel" ${PTMNTSTOCK}/boot/grub/menu.lst > ${tmp}/grub_kernel_lst.txt
		fi
		
		while read A
		do
			if echo "$A" | grep ${RACINE} > /dev/null; then
				TEMOIN="OK"
			fi
		done < ${tmp}/grub_kernel_lst.txt
		
		if [ -z "$TEMOIN" ]; then
			echo -e "${COLERREUR}"
			echo "Le fichier menu.lst de GRUB ne semble pas correspondre au fichier fstab."
			echo -e "${COLTXT}La partition racine dans le fstab est ${COLINFO}${RACINE}${COLTXT}"
			echo -e "et le fichier menu.lst fait reference a:"
			echo -e "${COLCMD}\c"
			cat ${tmp}/grub_kernel_lst.txt
			echo -e "${COLTXT}"
			echo "Appuyez sur ENTREE pour quitter..."
			read PAUSE
		
			echo -e "${COLTXT}"
			echo "Demontage de $PART"
			echo -e "${COLCMD}\c"
			umount ${PTMNTSTOCK}
		
			echo -e "${COLTXT}"
			exit
		fi

		# Il faudrait aussi verifier si le noyau correspondant est bien present.
		
		echo -e "${COLTXT}"
		echo "Plusieurs demarches permettent de reinstaller GRUB:"
		echo -e " (${COLCHOIX}1${COLTXT}) Avec chroot"
		echo -e " (${COLCHOIX}2${COLTXT}) Sans chroot"
		
		CHROOT_OU_PAS=""
		DEFAUT_CHROOT_OU_PAS="2"

		if [ "$reinstall_grub" = "auto" ]; then
			CHROOT_OU_PAS="${DEFAUT_CHROOT_OU_PAS}"
		fi

		while [ "$CHROOT_OU_PAS" != "1" -a "$CHROOT_OU_PAS" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Quelle demarche souhaitez-vous utiliser? [${COLDEFAUT}${DEFAUT_CHROOT_OU_PAS}${COLTXT}] ${COLSAISIE}\c"
			read CHROOT_OU_PAS
		
			if [ -z "$CHROOT_OU_PAS" ]; then
				CHROOT_OU_PAS=${DEFAUT_CHROOT_OU_PAS}
			fi
		done
		
		echo -e "${COLTXT}"
		echo "Reinstallation de GRUB:"
		echo -e "${COLCMD}\c"
		if [ "$CHROOT_OU_PAS" = "1" ]; then
			echo "mount -o bind /proc ${PTMNTSTOCK}/proc
mount -o bind /dev ${PTMNTSTOCK}/dev
mount -o bind /sys ${PTMNTSTOCK}/sys"
			mount -o bind /proc ${PTMNTSTOCK}/proc
			mount -o bind /dev ${PTMNTSTOCK}/dev
			mount -o bind /sys ${PTMNTSTOCK}/sys

			if [ "$reinstall_grub" != "auto" ]; then
				if [ -e ${PTMNTSTOCK}/bin/change_mdp_grub.sh ]; then
					echo -e "$COLTXT"
					echo "Il semble que la partition choisie contienne un script de changement des mots de passe GRUB."
					REPONSE=""
					while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
					do
						echo -e "$COLTXT"
						echo -e "Voulez-vous exécuter ce script avant de réinstaller GRUB? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
						read REPONSE
					done

					if [ "$REPONSE" = "o" ]; then
						chroot ${PTMNTSTOCK} /bin/change_mdp_grub.sh
					fi
				fi
			fi

			if [ -e "${PTMNTSTOCK}/usr/sbin/update-grub" ]; then
				echo "chroot ${PTMNTSTOCK} update-grub"
				chroot ${PTMNTSTOCK} update-grub
			fi

			if [ -e "${PTMNTSTOCK}/usr/sbin/grub-install" ]; then
				echo "chroot ${PTMNTSTOCK} grub-install /dev/${BOOTDISK}"
				chroot ${PTMNTSTOCK} grub-install /dev/${BOOTDISK}
			elif [ -e "${PTMNTSTOCK}/usr/sbin/grub2-install" ]; then
				echo "chroot ${PTMNTSTOCK} grub2-install /dev/${BOOTDISK}"
				chroot ${PTMNTSTOCK} grub2-install /dev/${BOOTDISK}
			else
				echo -e "$COLERREUR"
				echo "ERREUR: Il n'a ete trouve ni grub-install ni grub2-install dans /usr/sbin/ sur ${PTMNTSTOCK}"
				sleep 2
				echo -e "${COLCMD}\c"
			fi

			if [ "$change_mdp" = "auto" ]; then
				cp /bin/crob_fonctions.sh ${PTMNTSTOCK}/bin/
				cp /root/scripts_pour_sysresccd_sur_hd/change_mdp_grub.sh ${PTMNTSTOCK}/bin/
				cp /root/scripts_pour_sysresccd_sur_hd/change_mdp_lilo.sh ${PTMNTSTOCK}/bin/
				chmod +x ${PTMNTSTOCK}/bin/*

				echo "chroot ${PTMNTSTOCK} /bin/change_mdp_grub.sh"
				chroot ${PTMNTSTOCK} /bin/change_mdp_grub.sh
			fi

			echo "umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys"
			umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys
		else
			if [ -e ${PTMNTSTOCK}/boot/grub/grub.cfg -a -e ${PTMNTSTOCK}/etc/grub.d/00_header ]; then
				echo "grub2-install --recheck --root-directory=${PTMNTSTOCK} /dev/${BOOTDISK}"
				grub2-install --recheck --root-directory=${PTMNTSTOCK} /dev/${BOOTDISK}
			
				if [ "$?" != "0" ]; then
					echo -e "${COLERREUR}"
					echo "Il semble qu'une erreur se soit produite."
			
					REPONSE=""
					while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
					do
						echo -e "${COLTXT}"
						echo -e "Voulez-vous réessayer avec la méthode chroot? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
						read REPONSE
					done
			
					if [ "$REPONSE" = "o" ]; then
						echo "mount -o bind /proc ${PTMNTSTOCK}/proc
mount -o bind /dev ${PTMNTSTOCK}/dev
mount -o bind /sys ${PTMNTSTOCK}/sys"
						mount -o bind /proc ${PTMNTSTOCK}/proc
						mount -o bind /dev ${PTMNTSTOCK}/dev
						mount -o bind /sys ${PTMNTSTOCK}/sys
						if [ -e "${PTMNTSTOCK}/usr/sbin/update-grub" ]; then
							echo "chroot ${PTMNTSTOCK} update-grub"
							chroot ${PTMNTSTOCK} update-grub
						fi

						if [ -e "${PTMNTSTOCK}/usr/sbin/grub-install" ]; then
							echo "chroot ${PTMNTSTOCK} grub-install /dev/${BOOTDISK}"
							chroot ${PTMNTSTOCK} grub-install /dev/${BOOTDISK}
						elif [ -e "${PTMNTSTOCK}/usr/sbin/grub2-install" ]; then
							echo "chroot ${PTMNTSTOCK} grub2-install /dev/${BOOTDISK}"
							chroot ${PTMNTSTOCK} grub2-install /dev/${BOOTDISK}
						else
							echo -e "$COLERREUR"
							echo "ERREUR: Il n'a ete trouve ni grub-install ni grub2-install dans /usr/sbin/ sur ${PTMNTSTOCK}"
							sleep 2
							echo -e "${COLCMD}\c"
						fi

						echo "umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys"
						umount ${PTMNTSTOCK}/proc ${PTMNTSTOCK}/dev ${PTMNTSTOCK}/sys
					fi
				fi
			else
				echo "grub-install --recheck --root-directory=${PTMNTSTOCK} /dev/${BOOTDISK}"
				grub-install --recheck --root-directory=${PTMNTSTOCK} /dev/${BOOTDISK}
			fi
		fi
		
		if [ "$reinstall_grub" != "auto" ]; then
			echo -e "${COLTXT}"
			echo "Appuyez sur ENTREE pour quitter..."
			read PAUSE
		fi
	
		echo -e "${COLTXT}"
		echo "Demontage de $PART"
		echo -e "${COLCMD}\c"
		umount ${PTMNTSTOCK}
	fi
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

echo -e "${COLTXT}"
sleep 3


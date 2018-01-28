#!/bin/bash

# Auteur: Stephane Boireau
# Derniere modification: 08/07/2014

# Passer en parametres...
# src_part 			partition a sauvegarder
# dest_part 		partition de stockage
#                   ou destination distante:
#                           smb:user:mdp@ip:partage:chemin
# nom_image 		nom de la sauvegarde
# reboot			y ou n
# delais_reboot		le delais avant reboot en secondes

source /bin/crob_fonctions.sh

option_fsarchiver="-v"
# gzip niveau 6
niveau_compression_fsarchiver="3"

# Chemin vers le programme ntfsclone
chemin_ntfs="/usr/sbin"

# Passer en parametre les variables indiquees plus haut via la ligne de commande de boot:
#source /proc/cmdline 2> /dev/null

src_infos=/proc/cmdline
# Pour pouvoir tester hors modif de /proc/cmdline:
if [ -e "/root/tmp/param_test.txt" ]; then
	#source /root/tmp/param_test.txt
	src_infos=/root/tmp/param_test.txt
fi

src_part=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^src_part="|cut -d"=" -f2)
dest_part=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^dest_part="|cut -d"=" -f2)
nom_image=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^nom_image="|cut -d"=" -f2)
#reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^reboot="|cut -d"=" -f2)
auto_reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^auto_reboot="|cut -d"=" -f2)
delais_reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^delais_reboot="|cut -d"=" -f2)
del_old_svg=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^del_old_svg="|cut -d"=" -f2)

nom_machine=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^nom_machine="|cut -d"=" -f2)
mac_machine=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^mac_machine="|cut -d"=" -f2)

wget_script=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^wget_script="|cut -d"=" -f2)

# 20130213
seven_test_taille_part=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^seven_test_taille_part="|cut -d"=" -f2)
if [ -z "$seven_test_taille_part" ]; then
	seven_test_taille_part=3000
fi

type_svg=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^type_svg="|cut -d"=" -f2)
if [ -z "$type_svg" ]; then
	type_svg="partimage"
fi
if [ "$type_svg" != "partimage" -a "$type_svg" != "ntfsclone" -a "$type_svg" != "fsarchiver" ]; then
	type_svg="partimage"
fi

case ${type_svg} in
	"partimage")
		suffixe_svg="000"
	;;
	"ntfsclone")
		suffixe_svg="ntfs"
	;;
	"dar")
		suffixe_svg="1.dar"
	;;
	"fsarchiver")
		suffixe_svg="fsa"
	;;
esac

url_authorized_keys=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^url_authorized_keys="|cut -d"=" -f2)
if [ -n "$url_authorized_keys" ]; then
	echo -e "$COLTXT"
	echo "Telechargement de $url_authorized_keys"
	echo -e "$COLCMD"
	cd /tmp
	wget --tries=3 -O authorized_keys $url_authorized_keys
	if [ "$?" = "0" ]; then
		mkdir -p /root/.ssh
		chmod 700 /root/.ssh
		mv authorized_keys /root/.ssh/
		#/etc/init.d/sshd start
		/etc/init.d/sshd_crob start
	fi
fi

doss_rapport="/livemnt/tftpmem"
#mkdir -p ${doss_rapport}
#chmod 755 ${doss_rapport}
rapport="$doss_rapport/resultat_sauvegarde.txt"

echo -e "$COLTITRE"
echo "************************"
echo "* Script de sauvegarde *"
echo "************************"

echo -e "$COLTXT"
echo "Parametres passes:"
echo -e "${COLTXT}src_part=      ${COLINFO}$src_part"

# Si il y a un compte/mdp, ne pas afficher le détail... ou seulement en mode debug
if [ "${dest_part:0:4}" = "smb:" ]; then
	compte=$(echo "${dest_part}" | cut -d":" -f2)
	mdp=$(echo "${dest_part}" | cut -d":" -f3 | cut -d"@" -f1)
	serveur=$(echo "${dest_part}" | cut -d"@" -f2 | cut -d":" -f1)
	partage=$(echo "${dest_part}" | cut -d"@" -f2 | cut -d":" -f2)
	chemin_distant=$(echo "${dest_part}" | cut -d"@" -f2 | cut -d":" -f3)

	echo -e "${COLTXT}dest_part=     ${COLINFO}$compte:XXXXX@$serveur:$partage:$chemin_distant"
else
	echo -e "${COLTXT}dest_part=     ${COLINFO}$dest_part"
fi

echo -e "${COLTXT}nom_image=     ${COLINFO}$nom_image"
#echo "reboot=        $reboot"
echo -e "${COLTXT}type_svg=     ${COLINFO}$type_svg"
echo -e "${COLTXT}auto_reboot=   ${COLINFO}$auto_reboot"
echo -e "${COLTXT}delais_reboot= ${COLINFO}$delais_reboot"
if [ -n "${del_old_svg}" ]; then
	echo -e "${COLTXT}del_old_svg= ${COLINFO}${del_old_svg}"
fi

echo -e "${COLTXT}"
echo -e "Lancement de thttpd pour permettre une recuperation du rapport de sauvegarde..."
echo -e "${COLCMD}"
/etc/init.d/thttpd start

if [ "$src_part" = "auto" ]; then
	HD=$(GET_DEFAULT_DISK)

	# Sauvegarde d'une partition Win:
	#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | egrep -i "(W95|Win95|HPFS/NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
	#if [ ! -z "${liste_tmp}" ]; then
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows
	if [ ! -z "${liste_tmp[0]}" ]; then
		src_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")

		# Taille $seven_test_taille_part en MB destinee a ne pas sauvegarder la petite partition presente en debut de disque avec certaines install seven
		if [ -n "$seven_test_taille_part" ]; then
			taille_part_src=$(fdisk -s /dev/$src_part)
			taille_part_src=$(($taille_part_src/1024))
			if [ $taille_part_src -lt $seven_test_taille_part ]; then
				#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | egrep -i "(W95|Win95|HPFS/NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
				LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows
				cpt=0
				src_part=""
				while [ $cpt -lt ${#liste_tmp[*]} ]
				do
					taille_part_src=$(fdisk -s ${liste_tmp[$cpt]})
					taille_part_src=$(($taille_part_src/1024))
					if [ $taille_part_src -ge $seven_test_taille_part ]; then
						src_part=$(echo ${liste_tmp[$cpt]} | sed -e "s|^/dev/||")
						break
					fi
					cpt=$((cpt+1))
				done
				
				if [ -z "$src_part" ]; then
					echo "ECHEC" > ${rapport}
					echo "La partition a sauvegarder n'a pas ete identifiee" >> ${rapport}
					echo "Aucune partition Window$ ne depassait $seven_test_taille_part MB" >> ${rapport}

					if [ -z "$delais_reboot" ]; then
						delais_reboot=90
					fi

					echo -e "$COLTXT"
					COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
					echo -e "$COLCMD\c"
					reboot
					exit
				fi
			fi
		fi
	else
		# Sauvegarde d'une partition Linux:
		#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep "Linux" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
		#if [ ! -z "${liste_tmp}" ]; then
		LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
		if [ ! -z "${liste_tmp[0]}" ]; then
			#src_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")
			src_part=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			echo "ECHEC" > ${rapport}
			echo "La partition a sauvegarder n'a pas ete identifiee" >> ${rapport}

			if [ -z "$delais_reboot" ]; then
				delais_reboot=90
			fi

			echo -e "$COLTXT"
			COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
			echo -e "$COLCMD\c"
			reboot
			exit
		fi
	fi
	echo -e "${COLTXT}"
	echo -e "Partition a sauvegarder detectee: ${COLINFO}$src_part${COLTXT}"
fi

if [ "$dest_part" = "auto" ]; then
	HD=$(GET_DEFAULT_DISK)

	# Sauvegarde sur une partition Linux:
	#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "/dev/$src_part " | grep "Linux" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
	#if [ ! -z "${liste_tmp}" ]; then
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux avec_part_exclue_du_tableau=$src_part
	if [ ! -z "${liste_tmp[0]}" ]; then
		dest_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")
	else
		# Sauvegarde sur une partition Win:
		#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "/dev/$src_part " | egrep -i "(W95|Win95|HPFS/NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
		#if [ ! -z "${liste_tmp}" ]; then
		LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows avec_part_exclue_du_tableau=$src_part
		if [ ! -z "${liste_tmp[0]}" ]; then
			dest_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")
		else
			echo "ECHEC" > ${rapport}
			echo "La partition de stockage n'a pas ete identifiee" >> ${rapport}

			if [ -z "$delais_reboot" ]; then
				delais_reboot=90
			fi

			echo -e "$COLTXT"
			COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
			echo -e "$COLCMD\c"
			reboot
			exit
		fi
	fi
	echo -e "${COLTXT}"
	echo -e "Partition de stockage detectee: ${COLINFO}$dest_part${COLTXT}"
fi

sleep 3

echo -e "${COLCMD}"

if echo "$src_part" | grep "^/dev/" > /dev/null; then
	src_part=$(echo "$src_part" | sed -e "s|^/dev/||")
fi

# Verification de l'existence des partitions:
src_hd=$(echo "$src_part" | sed -e "s/[0-9]//g")
#test_source=$(fdisk -l /dev/$src_hd | grep "/dev/$src_part ")
# On ne sauvegarde que si la source existe:
#if [ -z "$test_source" ]; then
test_source=$(fdisk -s /dev/$src_part 2>/dev/null)
if [ -z "$test_source" -o ! -e "/sys/block/$src_hd/$src_part/partition" ]; then
	echo "ECHEC" > ${rapport}
	echo "La partition a sauvegarder n existe pas." >> ${rapport}
	echo "src_part=$src_part" >> ${rapport}
	echo "Partitions du disque source:" >> ${rapport}
	#fdisk -l /dev/$src_hd >> ${rapport}
	LISTE_PART ${src_hd} afficher_liste=y >> ${rapport}

	if [ -z "$delais_reboot" ]; then
		delais_reboot=90
	fi

	echo -e "$COLTXT"
	COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
	echo -e "$COLCMD\c"
	reboot
	exit
fi

rapport_wget_script=/tmp/rapport_wget_script.txt
if [ -n "$wget_script" ]; then
	echo -e "${COLTXT}"
	echo "Telechargement du script $wget_script" |tee -a $rapport_wget_script
	echo -e "${COLCMD}\c"
	tmp=/tmp/root_wget_script_$(date +%Y%m%d%H%M%S)
	mkdir -p -m 700 $tmp
	cd $tmp
	wget --no-check-certificate ${wget_script}

	if [ "$?" != "0" ]; then
		rapport_wget_script="Echec du telechargement de $wget_script" |tee -a $rapport_wget_script
	else
		wg_script=$(basename ${wget_script})
		chmod +x ${wg_script}

		echo -e "${COLTXT}"
		echo "Execution du script..." |tee -a $rapport_wget_script
		${wg_script} ${src_part} ${dest_part} |tee -a $rapport_wget_script
	fi

	cat $rapport_wget_script >> ${rapport}
fi

if [ "${dest_part:0:4}" = "smb:" ]; then
	#compte=$(echo "${dest_part}" | sed -e "s|^smb:||" | cut -d"@" -f1)
	compte=$(echo "${dest_part}" | cut -d":" -f2)
	mdp=$(echo "${dest_part}" | cut -d":" -f3 | cut -d"@" -f1)
	serveur=$(echo "${dest_part}" | cut -d"@" -f2 | cut -d":" -f1)
	partage=$(echo "${dest_part}" | cut -d"@" -f2 | cut -d":" -f2)
	chemin_distant=$(echo "${dest_part}" | cut -d"@" -f2 | cut -d":" -f3)

	mkdir -p /mnt/smb
	mount -t cifs -o username=$compte,password=$mdp //$serveur/$partage /mnt/smb
	if [ "$?" != "0" ]; then
		echo "ECHEC" > ${rapport}
		echo "Le montage du partage //$serveur/$partage avec le compte et mot de passe fournis a echoue." >> ${rapport}
		echo "src_part=$src_part" >> ${rapport}
		#echo "dest_part=$dest_part" >> ${rapport}
		echo "Partitions du disque source:" >> ${rapport}
		#fdisk -l /dev/$src_hd >> ${rapport}
		LISTE_PART ${src_hd} afficher_liste=y >> ${rapport}
	
		if [ -z "$delais_reboot" ]; then
			delais_reboot=90
		fi
	
		echo -e "$COLTXT"
		COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
		echo -e "$COLCMD\c"
		reboot
		exit
	fi

	chemin_dest=/mnt/smb/$chemin_distant
	mkdir -p $chemin_dest

	if mount | grep "/dev/$dest_part " > /dev/null; then
		umount /dev/$dest_part
	fi

	if [ -z "$nom_image" ]; then
		nom_image="image_${src_part}_$(date +%Y%m%d%H%M%S)"
	fi

	tmp=/tmp/sauvegarde_$(date +%Y%m%d%H%M%S)
	mkdir -p ${tmp}
	chmod 700 ${tmp}
	if [ -e "$chemin_dest/${nom_image}.${suffixe_svg}" ]; then
		echo "" > ${tmp}/sauvegarde_du_meme_nom.txt
		echo "La sauvegarde a ete lancee apres suppression d une sauvegarde du meme nom:" >> ${tmp}/sauvegarde_du_meme_nom.txt
		ls -lh $chemin_dest/${nom_image}.* >> ${tmp}/sauvegarde_du_meme_nom.txt
		rm -f $chemin_dest/${nom_image}.0*
		rm -f $chemin_dest/${nom_image}.SUCCES.txt
		rm -f $chemin_dest/${nom_image}.ECHEC.txt
		rm -f $chemin_dest/${nom_image}.nom_machine.txt
		rm -f $chemin_dest/${nom_image}.mac_machine.txt
		rm -f $chemin_dest/${nom_image}.type_compression.txt
		rm -f $chemin_dest/${nom_image}.ntfs
		rm -f $chemin_dest/${nom_image}.fsa
		rm -f $chemin_dest/${nom_image}.partitionnement.out
	fi

	if [ -n "$del_old_svg" ]; then
		mkdir -p $chemin_dest
		if [ "$del_old_svg" = "all" ]; then
			echo "Suppression de toutes les sauvegardes anterieures: " > ${tmp}/menage.txt
			ls -lh $chemin_dest/* >> ${tmp}/menage.txt
			echo "Suppression de toutes les sauvegardes anterieures: "
			#ls -lh $chemin_dest/*
			#rm -f $chemin_dest/*
			cd $chemin_dest/

			#find . -maxdepth 1 -type f | while read A
			#do
			#	echo "Suppression de $chemin_dest/$A" >> ${tmp}/menage.txt
			#	echo "Suppression de $chemin_dest/$A"
			#	rm -f $A
			#done

			for ext in partitionnement.out SUCCES.txt ECHEC.txt ntfs type_compression.txt fsa nom_machine.txt mac_machine.txt
			do
				find . -maxdepth 1 -name "*.$ext" | while read A
				do
					echo "Suppression de $chemin_dest/$A" >> ${tmp}/menage.txt
					echo "Suppression de $chemin_dest/$A"
					rm -f $A
				done
			done

			find . -maxdepth 1 -name "*.[0-9][0-9][0-9]" | while read A
			do
				echo "Suppression de $chemin_dest/$A" >> ${tmp}/menage.txt
				echo "Suppression de $chemin_dest/$A"
				rm -f $A
			done

			cd /root
		else
			# Nombre de mois
			t=$(echo "$del_old_svg"|sed -e "s|[0-9]||g")
			if [ -z "$t" ]; then
				echo "Suppression des sauvegardes de plus de $del_old_svg mois: " > ${tmp}/menage.txt
				echo "Suppression des sauvegardes de plus de $del_old_svg mois: "
				nb_sec=$(($del_old_svg*30*24*3600))
				cd $chemin_dest
				v_ref=$(date +%s)
				for ext in partitionnement.out SUCCES.txt ECHEC.txt ntfs type_compression.txt fsa nom_machine.txt mac_machine.txt
				do
					ls *.$ext | while read A
					do
						if [ -f "$A" ]; then
							v_fich=$(stat -c '%Y' $A)
							t=$(($v_ref-$v_fich))
							if [ $t -gt $nb_sec ]; then
								echo "Suppression de $chemin_dest/$A" >> ${tmp}/menage.txt
								echo "Suppression de $chemin_dest/$A"
								rm -f $A
							fi
						fi
					done
				done

				ls "*.[0-9][0-9][0-9]" | while read A
				do
					if [ -f "$A" ]; then
						v_fich=$(stat -c '%Y' $A)
						t=$(($v_ref-$v_fich))
						if [ $t -gt $nb_sec ]; then
							echo "Suppression de $chemin_dest/$A" >> ${tmp}/menage.txt
							echo "Suppression de $chemin_dest/$A"
							rm -f $A
						fi
					fi
				done

				cd /root
			else
				echo "Suppression: Valeur invalide pour le nombre de mois: '$del_old_svg'" > ${tmp}/menage.txt
				echo "Suppression: Valeur invalide pour le nombre de mois: '$del_old_svg'"
			fi
		fi
	fi

	echo -e "$COLTXT"
	echo "Extraction d'infos materielles avec lshw, dmidecode, lspci, lsmod, lsusb..."
	echo -e "$COLCMD\c"
	FICHIERS_RAPPORT_CONFIG_MATERIELLE ${chemin_dest} ${nom_machine}

	echo -e "$COLTXT"
	echo "Sauvegarde des 5 premiers Mo de $src_hd avec dd..."
	echo -e "$COLCMD\c"
	dd if="/dev/${src_hd}" of="${chemin_dest}/${src_hd}_premiers_MO.bin" bs=1M count=5

	echo -e "$COLTXT"
	echo "Sauvegarde des 5 premiers Mo de $src_part avec dd..."
	echo -e "$COLCMD\c"
	dd if="/dev/${src_part}" of="${chemin_dest}/${src_part}_premiers_MO.bin" bs=1M count=5

	echo -e "$COLTXT"
	echo -e "Sauvegarde de ${COLINFO}${src_part}${COLTXT} sous le nom ${COLINFO}${nom_image}"
	echo -e "${COLCMD}\c"
	mkdir -p $chemin_dest
	echo "$nom_machine" > $chemin_dest/${nom_image}.nom_machine.txt
	echo "$mac_machine" > $chemin_dest/${nom_image}.mac_machine.txt
	sleep 3
	# Pour une sauvegarde à travers le reseau, on decoupe la sauvegarde (il y a une limite a 2Go pour les fichiers a travers le reseau, mais j'ai coupe a 650M)
	case $type_svg in
		"partimage")
			partimage -b -c -d -f0 -V650 save /dev/$src_part $chemin_dest/${nom_image}
		;;
		"fsarchiver")
			fsarchiver -o -z${niveau_compression_fsarchiver} -s 650 ${option_fsarchiver} savefs $chemin_dest/${nom_image} /dev/$src_part
		;;
		"ntfsclone")
			echo "gzip" > $chemin_dest/${nom_image}.type_compression.txt
			$chemin_ntfs/ntfsclone --save-image -o - /dev/$src_part | gzip -c  | split -b 650m - $chemin_dest/${nom_image}.ntfs
		;;
	esac

	# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
	# A FAIRE: Voir comment remonter les infos de succes ou d'echec de la sauvegarde...
	# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
	if [ "$?" = "0" ]; then
		temoin="succes"
		echo "partition=$src_part" > $chemin_dest/${nom_image}.SUCCES.txt
		echo "image=$chemin_dest/${nom_image}.000" >> $chemin_dest/${nom_image}.SUCCES.txt

		echo "Infos sur $chemin_dest/${nom_image}.000" >> $chemin_dest/${nom_image}.SUCCES.txt
		echo "Sauvegarde de $src_part" >> $chemin_dest/${nom_image}.SUCCES.txt
		echo "Sauvegarde effectuee sur: $serveur/$partage/$chemin_distant" >> $chemin_dest/${nom_image}.SUCCES.txt
		echo "Poste sauvegarde: $nom_machine ($mac_machine)" >> $chemin_dest/${nom_image}.SUCCES.txt
		echo "Type de la sauvegarde: $type_svg" >> $chemin_dest/${nom_image}.SUCCES.txt
		echo "Date de la sauvegarde:" >> $chemin_dest/${nom_image}.SUCCES.txt
		date >> $chemin_dest/${nom_image}.SUCCES.txt

		echo "Volume de la sauvegarde:" >> $chemin_dest/${nom_image}.SUCCES.txt
		#ls -lh $chemin_dest/${nom_image}.* >> $chemin_dest/${nom_image}.SUCCES.txt
		du -sh $chemin_dest/${nom_image}.* >> $chemin_dest/${nom_image}.SUCCES.txt

		#echo "Espace total/occupe/encore disponible:" >> $chemin_dest/${nom_image}.SUCCES.txt
		#df -h | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | grep "^/dev/$dest_part " | cut -d" " -f 2,3,4 | sed -e "s| |/|g" >> $chemin_dest/${nom_image}.SUCCES.txt

		SRC_HD_CLEAN=$(echo ${src_hd}|sed -e "s|[^0-9A-Za-z]|_|g")
		fdisk -l /dev/$src_hd > /tmp/fdisk_l_${SRC_HD_CLEAN}.txt 2>&1
		#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${src_hd}'" /tmp/fdisk_l_${SRC_HD_CLEAN}.txt|cut -d"'" -f2)

		if [ "$(IS_GPT_PARTTABLE ${src_hd})" = "y" ]; then
			TMP_disque_en_GPT=/dev/${src_hd}
		else
			TMP_disque_en_GPT=""
		fi

		if [ -z "$TMP_disque_en_GPT" ]; then
			sfdisk -d /dev/$src_hd > $chemin_dest/${nom_image}.partitionnement.out
		else
			sgdisk -b $chemin_dest/${nom_image}.gpt_partitionnement.out /dev/$src_hd
		fi

		#cp $chemin_dest/${nom_image}.SUCCES.txt /home/${slitaz_user}/Public/
		#chmod 755 /home/${slitaz_user}/Public/${nom_image}.SUCCES.txt
		echo "SUCCES" > ${rapport}
		cat $chemin_dest/${nom_image}.SUCCES.txt >> ${rapport}

		echo "Espace total/occupe/encore disponible:" >> $chemin_dest/${nom_image}.SUCCES.txt
		df -h | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | grep "^/dev/$dest_part " | cut -d" " -f 2,3,4 | sed -e "s| |/|g" >> $chemin_dest/${nom_image}.SUCCES.txt

		df -h | grep "^/dev/$dest_part " > $doss_rapport/df.txt

		cp $chemin_dest/${nom_image}.partitionnement.out $doss_rapport/partitionnement.out
		chmod 755 ${rapport}
		chmod 755 $doss_rapport/partitionnement.out
		chmod 755 $doss_rapport/df.txt
	else
		temoin="echec"
		ls -lh $chemin_dest/${nom_image}.* > $chemin_dest/${nom_image}.ECHEC.txt
		ls -lh $chemin_dest/pi* >> $chemin_dest/${nom_image}.ECHEC.txt
		df -h >> $chemin_dest/${nom_image}.ECHEC.txt
		date >> $chemin_dest/${nom_image}.ECHEC.txt
		#cp $chemin_dest/${nom_image}.ECHEC.txt /home/${slitaz_user}/Public/
		#chmod 755 /home/${slitaz_user}/Public/${nom_image}.ECHEC.txt
		echo "ECHEC" > ${rapport}
		cat $chemin_dest/${nom_image}.ECHEC.txt >> ${rapport}
		chmod 755 ${rapport}
		#read PAUSE
	fi

	if [ -e ${tmp}/sauvegarde_du_meme_nom.txt ]; then
		cat ${tmp}/sauvegarde_du_meme_nom.txt >> ${rapport}
	fi

	if [ -e ${tmp}/menage.txt ]; then
		cat ${tmp}/menage.txt >> ${rapport}
	fi

	umount /mnt/smb

else
	
	if echo "$dest_part" | grep "^/dev/" > /dev/null; then
		dest_part=$(echo "$dest_part" | sed -e "s|^/dev/||")
	fi

	# Verification de l'existence des partitions:
	dest_hd=$(echo "$dest_part" | sed -e "s/[0-9]//g")
	#test_dest=$(fdisk -l /dev/$dest_hd | grep "/dev/$dest_part ")
	# On ne sauvegarde que si la destination existe:
	#if [ ! -z "$test_dest" ]; then
	test_dest=$(fdisk -s /dev/$dest_part 2>/dev/null)
	if [ -n "$test_dest" -a -e "/sys/block/$dest_hd/$dest_part/partition" ]; then
		if mount | grep "/mnt/$dest_part " > /dev/null; then
			umount /mnt/$dest_part
		fi
	
		if mount | grep "/dev/$dest_part " > /dev/null; then
			umount /dev/$dest_part
		fi
	
		# Montage de la partition de stockage:
		mkdir -p /mnt/$dest_part
		type_part=$(TYPE_PART $dest_part)
		if [ -z "$type_part" ]; then
			mount /dev/$dest_part /mnt/$dest_part
		else
			if [ "$type_part" = "ntfs" ]; then
				ntfs-3g /dev/$dest_part /mnt/$dest_part
			else
				mount -t $type_part /dev/$dest_part /mnt/$dest_part
			fi
		fi
	
		# Sauvegarde si le montage a reussi:
		if [ "$?" = "0" ]; then
			if [ -z "$nom_image" ]; then
				nom_image="image_${src_part}_$(date +%Y%m%d%H%M%S)"
			fi
	
			tmp=/tmp/sauvegarde_$(date +%Y%m%d%H%M%S)
			if [ -e "/mnt/$dest_part/oscar/${nom_image}.000" ]; then
				mkdir -p ${tmp}
				chmod 700 ${tmp}
				echo "" > ${tmp}/sauvegarde_du_meme_nom.txt
				echo "La sauvegarde a ete lancee apres suppression d une sauvegarde du meme nom:" >> ${tmp}/sauvegarde_du_meme_nom.txt
				ls -lh /mnt/$dest_part/oscar/${nom_image}.* >> ${tmp}/sauvegarde_du_meme_nom.txt
				rm -f /mnt/$dest_part/oscar/${nom_image}.0*
				rm -f /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				rm -f /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt
			fi
	
			if [ -n "$del_old_svg" ]; then
				mkdir -p /mnt/$dest_part/oscar
				if [ "$del_old_svg" = "all" ]; then
					mkdir -p ${tmp}
					chmod 700 ${tmp}
					echo "Suppression de toutes les sauvegardes anterieures: " > ${tmp}/menage.txt
					ls -lh /mnt/$dest_part/oscar/* >> ${tmp}/menage.txt
					echo "Suppression de toutes les sauvegardes anterieures: "
					#ls -lh /mnt/$dest_part/oscar/*
					#rm -f /mnt/$dest_part/oscar/*
					cd /mnt/$dest_part/oscar/
					find . -maxdepth 1 -type f | while read A
					do
						echo "Suppression de /mnt/$dest_part/oscar/$A" >> ${tmp}/menage.txt
						echo "Suppression de /mnt/$dest_part/oscar/$A"
						rm -f $A
					done
					cd /root
				else
					# Nombre de mois
					t=$(echo "$del_old_svg"|sed -e "s|[0-9]||g")
					if [ -z "$t" ]; then
						echo "Suppression des sauvegardes de plus de $del_old_svg mois: " > ${tmp}/menage.txt
						echo "Suppression des sauvegardes de plus de $del_old_svg mois: "
						nb_sec=$(($del_old_svg*30*24*3600))
						cd /mnt/$dest_part/oscar
						v_ref=$(date +%s)
						ls | while read A
						do
							if [ -f "$A" ]; then
								v_fich=$(stat -c '%Y' $A)
								t=$(($v_ref-$v_fich))
								if [ $t -gt $nb_sec ]; then
									echo "Suppression de /mnt/$dest_part/oscar/$A" >> ${tmp}/menage.txt
									echo "Suppression de /mnt/$dest_part/oscar/$A"
									rm -f $A
								fi
							fi
						done
						cd /root
					else
						echo "Suppression: Valeur invalide pour le nombre de mois: '$del_old_svg'" > ${tmp}/menage.txt
						echo "Suppression: Valeur invalide pour le nombre de mois: '$del_old_svg'"
					fi
				fi
			fi

			echo -e "$COLTXT"
			echo "Extraction d'infos materielles avec lshw, dmidecode, lspci, lsmod, lsusb..."
			echo -e "$COLCMD\c"
			mkdir -p /mnt/$dest_part/oscar
			FICHIERS_RAPPORT_CONFIG_MATERIELLE /mnt/$dest_part/oscar

			echo -e "$COLTXT"
			echo "Sauvegarde des 5 premiers Mo de $src_hd avec dd..."
			echo -e "$COLCMD\c"
			dd if="/dev/${src_hd}" of="/mnt/$dest_part/oscar/${src_hd}_premiers_MO.bin" bs=1M count=5

			echo -e "$COLTXT"
			echo "Sauvegarde des 5 premiers Mo de $src_part avec dd..."
			echo -e "$COLCMD\c"
			dd if="/dev/${src_part}" of="/mnt/$dest_part/oscar/${src_part}_premiers_MO.bin" bs=1M count=5

			echo -e "$COLTXT"
			echo -e "Sauvegarde de ${COLINFO}${src_part}${COLTXT} sous le nom ${COLINFO}${nom_image}"
			echo -e "${COLCMD}\c"
			mkdir -p /mnt/$dest_part/oscar
			sleep 3
			case $type_svg in
				"partimage")
					partimage -b -c -d -f0 save /dev/$src_part /mnt/$dest_part/oscar/${nom_image}
				;;
				"fsarchiver")
					fsarchiver -o -z${niveau_compression_fsarchiver} ${option_fsarchiver} savefs /mnt/$dest_part/oscar/${nom_image} /dev/$src_part
				;;
				"ntfsclone")
					echo "gzip" > /mnt/$dest_part/oscar/${nom_image}.type_compression.txt
					$chemin_ntfs/ntfsclone --save-image -o - /dev/$src_part | gzip -c > /mnt/$dest_part/oscar/${nom_image}.ntfs
				;;
			esac
			# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
			# A FAIRE: Voir comment remonter les infos de succes ou d'echec de la sauvegarde...
			# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
			if [ "$?" = "0" ]; then
				temoin="succes"
				echo "partition=$src_part" > /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				echo "image=/mnt/$dest_part/oscar/${nom_image}.000" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
	
				echo "Infos sur /mnt/$dest_part/oscar/${nom_image}.000" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				echo "Sauvegarde de $src_part" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				echo "Type de la sauvegarde: $type_svg" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				echo "Date de la sauvegarde:" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				date >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
	
				echo "Volume de la sauvegarde:" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				#ls -lh /mnt/$dest_part/oscar/${nom_image}.* >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				du -sh /mnt/$dest_part/oscar/${nom_image}.* >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
	
				#echo "Espace total/occupe/encore disponible:" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				#df -h | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | grep "^/dev/$dest_part " | cut -d" " -f 2,3,4 | sed -e "s| |/|g" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt

				SRC_HD_CLEAN=$(echo ${src_hd}|sed -e "s|[^0-9A-Za-z]|_|g")
				fdisk -l /dev/$src_hd > /tmp/fdisk_l_${SRC_HD_CLEAN}.txt 2>&1
				#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${src_hd}'" /tmp/fdisk_l_${SRC_HD_CLEAN}.txt|cut -d"'" -f2)

				if [ "$(IS_GPT_PARTTABLE ${src_hd})" = "y" ]; then
					TMP_disque_en_GPT=/dev/${src_hd}
				else
					TMP_disque_en_GPT=""
				fi

				if [ -z "$TMP_disque_en_GPT" ]; then
					sfdisk -d /dev/$src_hd > /mnt/$dest_part/oscar/${nom_image}.partitionnement.out
				else
					sgdisk -b /mnt/$dest_part/oscar/${nom_image}.gpt_partitionnement.out /dev/$src_hd
				fi

				#cp /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt /home/${slitaz_user}/Public/
				#chmod 755 /home/${slitaz_user}/Public/${nom_image}.SUCCES.txt
				echo "SUCCES" > ${rapport}
				cat /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt >> ${rapport}
	
				echo "Espace total/occupe/encore disponible:" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
				df -h | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | grep "^/dev/$dest_part " | cut -d" " -f 2,3,4 | sed -e "s| |/|g" >> /mnt/$dest_part/oscar/${nom_image}.SUCCES.txt
	
				df -h | grep "^/dev/$dest_part " > $doss_rapport/df.txt
	
				cp /mnt/$dest_part/oscar/${nom_image}.partitionnement.out $doss_rapport/partitionnement.out
				chmod 755 ${rapport}
				chmod 755 $doss_rapport/partitionnement.out
				chmod 755 $doss_rapport/df.txt
			else
				temoin="echec"
				ls -lh /mnt/$dest_part/oscar/${nom_image}.* > /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt
				ls -lh /mnt/$dest_part/oscar/pi* >> /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt
				df -h >> /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt
				date >> /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt
				#cp /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt /home/${slitaz_user}/Public/
				#chmod 755 /home/${slitaz_user}/Public/${nom_image}.ECHEC.txt
				echo "ECHEC" > ${rapport}
				cat /mnt/$dest_part/oscar/${nom_image}.ECHEC.txt >> ${rapport}
				chmod 755 ${rapport}
				#read PAUSE
			fi
	
			if [ -e ${tmp}/sauvegarde_du_meme_nom.txt ]; then
				cat ${tmp}/sauvegarde_du_meme_nom.txt >> ${rapport}
			fi
	
			if [ -e ${tmp}/menage.txt ]; then
				cat ${tmp}/menage.txt >> ${rapport}
			fi
	
			umount /mnt/$dest_part
		else
			echo "ECHEC" > ${rapport}
			echo "Le montage de la partition de sauvegarde a echoue." >> ${rapport}
			echo "src_part=$src_part" >> ${rapport}
			echo "dest_part=$dest_part" >> ${rapport}
			echo "Partitions du disque source:" >> ${rapport}
			#fdisk -l /dev/$src_hd >> ${rapport}
			LISTE_PART ${src_hd} afficher_liste=y >> ${rapport}
			echo "Partitions du disque destination:" >> ${rapport}
			#fdisk -l /dev/$dest_hd >> ${rapport}
			LISTE_PART ${dest_hd} afficher_liste=y >> ${rapport}
		fi
	else
		echo "ECHEC" > ${rapport}
		echo "Une des partitions n'existe pas." >> ${rapport}
		echo "src_part=$src_part" >> ${rapport}
		echo "dest_part=$dest_part" >> ${rapport}
		echo "Partitions du disque source:" >> ${rapport}
		#fdisk -l /dev/$src_hd >> ${rapport}
		LISTE_PART ${src_hd} afficher_liste=y >> ${rapport}
		echo "Partitions du disque destination:" >> ${rapport}
		#fdisk -l /dev/$dest_hd >> ${rapport}
		LISTE_PART ${dest_hd} afficher_liste=y >> ${rapport}

		if [ -z "$delais_reboot" ]; then
			delais_reboot=90
		fi
	
		echo -e "$COLTXT"
		COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
		echo -e "$COLCMD\c"
		reboot
		exit
	fi

fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# A FAIRE:
# Ajouter un test a ce niveau:
# Si les variables src_part et dest_part ne sont pas renseignees, on passe en interactif
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

# Verification de l'existence des partitions:
src_hd=$(echo "$src_part" | sed -e "s/[0-9]//g")
#test_source=$(fdisk -l /dev/$src_hd | grep "/dev/$src_part ")
test_source=$(fdisk -s /dev/$src_part 2>/dev/null)
#if [ -z "$test_source" -o ! -e "/sys/block/$src_hd/$src_part/partition" ]; then


if [ "$temoin" = "succes" ]; then
	echo -e "$COLTXT"
	echo "Operation terminee avec succes."
else
	echo -e "$COLERREUR"
	echo "L'operation a echoue."
fi

#echo "reboot=$reboot"
#echo "auto_reboot=$auto_reboot"
#sleep 3
#if [ ! -z "$reboot" ]; then
if [ ! -z "$auto_reboot" ]; then
	#delais=$(($reboot*60))
	#sleep $delais
	#reboot

	if [ -z "$delais_reboot" ]; then
		#delais_reboot=10
		delais_reboot=90
	fi

	#if [ "$reboot" = "y" ]; then
	if [ "$auto_reboot" = "y" ]; then
		echo -e "$COLTXT"
		#echo "Reboot dans $delais_reboot secondes."
		#sleep $delais_reboot
		COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
		echo -e "$COLCMD\c"
		reboot
	else
		if [ "$auto_reboot" = "halt" ]; then
			echo -e "$COLTXT"
			#echo "Reboot dans $delais_reboot secondes."
			#sleep $delais_reboot
			COMPTE_A_REBOURS "Extinction dans" $delais_reboot "secondes."
			echo -e "$COLCMD\c"
			halt
		else
			#sleep 5
			COMPTE_A_REBOURS "On quitte dans" 5 "secondes."
		fi
	fi
fi


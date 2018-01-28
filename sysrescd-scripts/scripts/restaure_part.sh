#!/bin/sh

# Auteur: Stephane Boireau
# Derniere modification: 25/06/2013

# Passer en parametres...
# dest_part 		partition a restaurer
# src_part 			partition de stockage
#                   ou source distante:
#                           smb:user:mdp@ip:partage:chemin
# nom_image 		nom de la sauvegarde a restaurer
# reboot			y ou n
# delais_reboot		le delais avant reboot en secondes

source /bin/crob_fonctions.sh

option_fsarchiver="-v"
# gzip niveau 6
#niveau_compression_fsarchiver="3"

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
reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^reboot="|cut -d"=" -f2)
delais_reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^delais_reboot="|cut -d"=" -f2)

nom_machine=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^nom_machine="|cut -d"=" -f2)
mac_machine=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^mac_machine="|cut -d"=" -f2)

# 20130213
seven_test_taille_part=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^seven_test_taille_part="|cut -d"=" -f2)
if [ -z "$seven_test_taille_part" ]; then
	seven_test_taille_part=3000
fi

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
mkdir -p ${doss_rapport}
chmod 755 ${doss_rapport}
rapport="$doss_rapport/resultat_restauration.txt"

echo -e "$COLTITRE"
echo "**************************"
echo "* Script de restauration *"
echo "**************************"

echo -e "$COLTXT"
echo "Parametres passes:"

# Si il y a un compte/mdp, ne pas afficher le détail... ou seulement en mode debug
if [ "${src_part:0:4}" = "smb:" ]; then
	compte=$(echo "${src_part}" | cut -d":" -f2)
	mdp=$(echo "${src_part}" | cut -d":" -f3 | cut -d"@" -f1)
	serveur=$(echo "${src_part}" | cut -d"@" -f2 | cut -d":" -f1)
	partage=$(echo "${src_part}" | cut -d"@" -f2 | cut -d":" -f2)
	chemin_distant=$(echo "${src_part}" | cut -d"@" -f2 | cut -d":" -f3)

	echo -e "${COLTXT}src_part=      ${COLINFO}$compte:XXXXX@$serveur:$partage:$chemin_distant"
else
	echo -e "${COLTXT}src_part=      ${COLINFO}$src_part"
fi
echo -e "${COLTXT}dest_part=     ${COLINFO}$dest_part"
echo -e "${COLTXT}nom_image=     ${COLINFO}$nom_image"
#echo "reboot=        $reboot"
echo -e "${COLTXT}auto_reboot=   ${COLINFO}$auto_reboot"
echo -e "${COLTXT}delais_reboot= ${COLINFO}$delais_reboot"

echo -e "${COLTXT}"
echo -e "Lancement de thttpd pour permettre une recuperation du rapport de restauration..."
echo -e "${COLCMD}"
/etc/init.d/thttpd start

if [ "$dest_part" = "auto" ]; then
	HD=$(GET_DEFAULT_DISK)

	# Restauration d'une partition Win:
	#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | egrep -i "(W95|Win95|HPFS/NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)

	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows

	if [ ! -z "${liste_tmp}" ]; then
		dest_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")


		# Taille $seven_test_taille_part en MB destinee a ne pas restaurer sur la petite partition presente en debut de disque avec certaines install seven
		if [ -n "$seven_test_taille_part" ]; then
			taille_part_dest=$(fdisk -s /dev/$dest_part 2>/dev/null)
			taille_part_dest=$(($taille_part_dest/1024))
			if [ $taille_part_dest -lt $seven_test_taille_part ]; then
				#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | egrep -i "(W95|Win95|HPFS/NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
				LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows
				cpt=0
				dest_part=""
				while [ $cpt -lt ${#liste_tmp[*]} ]
				do
					taille_part_dest=$(fdisk -s ${liste_tmp[$cpt]} 2>/dev/null)
					taille_part_dest=$(($taille_part_dest/1024))
					if [ $taille_part_dest -ge $seven_test_taille_part ]; then
						dest_part=$(echo ${liste_tmp[$cpt]} | sed -e "s|^/dev/||")
						break
					fi
					cpt=$((cpt+1))
				done
				
				if [ -z "$dest_part" ]; then
					echo "ECHEC" > ${rapport}
					echo "La partition a restaurer n'a pas ete identifiee" >> ${rapport}
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
		# Restauration d'une partition Linux:
		#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep "Linux" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
		LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
		if [ ! -z "${liste_tmp}" ]; then
			dest_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")
		else
			echo "ECHEC" > ${rapport}
			echo "La partition a restaurer n'a pas ete identifiee" >> ${rapport}

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
	echo -e "Partition a restaurer detectee: ${COLINFO}$dest_part${COLTXT}"
fi

if [ "$src_part" = "auto" ]; then
	HD=$(GET_DEFAULT_DISK)

	# Restauration depuis une partition Linux:
	#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "/dev/$dest_part " | grep "Linux" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux avec_part_exclue_du_tableau=$dest_part
	if [ ! -z "${liste_tmp}" ]; then
		src_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")
	else
		# Restauration depuis une partition Win:
		#liste_tmp=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "/dev/$dest_part " | egrep -i "(W95|Win95|HPFS/NTFS)" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1 | head -n 1)
		LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=windows avec_part_exclue_du_tableau=$dest_part
		if [ ! -z "${liste_tmp}" ]; then
			src_part=$(echo ${liste_tmp} | sed -e "s|^/dev/||")
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
	echo -e "Partition de stockage detectee: ${COLINFO}$src_part${COLTXT}"
fi

sleep 3

if echo "$src_part" | grep "^/dev/" > /dev/null; then
	src_part=$(echo "$src_part" | sed -e "s|^/dev/||")
fi

if echo "$dest_part" | grep "^/dev/" > /dev/null; then
	dest_part=$(echo "$dest_part" | sed -e "s|^/dev/||")
fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# A FAIRE:
# Ajouter un test a ce niveau:
# Si les variables src_part et dest_part ne sont pas renseignees, on passe en interactif
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

# Verification de l'existence des partitions:
dest_hd=$(echo "$dest_part" | sed -e "s/[0-9]//g")
#test1=$(fdisk -l /dev/$dest_hd | grep "/dev/$dest_part ")
# On ne restaure que si la destination existe:
#if [ -z "$test1" ]; then
test1=$(fdisk -s /dev/$dest_part 2>/dev/null)
if [ -z "$test1" -o ! -e "/sys/block/$dest_hd/$dest_part/partition" ]; then
	echo "ECHEC" > ${rapport}
	echo "La partition a restaurer n'existe pas." >> ${rapport}
	echo "dest_part=$dest_part" >> ${rapport}
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



if [ "${src_part:0:4}" = "smb:" ]; then
	compte=$(echo "${src_part}" | cut -d":" -f2)
	mdp=$(echo "${src_part}" | cut -d":" -f3 | cut -d"@" -f1)
	serveur=$(echo "${src_part}" | cut -d"@" -f2 | cut -d":" -f1)
	partage=$(echo "${src_part}" | cut -d"@" -f2 | cut -d":" -f2)
	chemin_distant=$(echo "${src_part}" | cut -d"@" -f2 | cut -d":" -f3)

	mkdir -p /mnt/smb
	mount -t cifs -o username=$compte,password=$mdp //$serveur/$partage /mnt/smb
	if [ "$?" != "0" ]; then
		echo "ECHEC" > ${rapport}
		echo "Le montage du partage //$serveur/$partage avec le compte et mot de passe fournis a echoue." >> ${rapport}
	
		if [ -z "$delais_reboot" ]; then
			delais_reboot=90
		fi
	
		echo -e "$COLTXT"
		COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
		echo -e "$COLCMD\c"
		reboot
		exit
	fi

	chemin_src=/mnt/smb/$chemin_distant
	mkdir -p $chemin_src

	# On demonte si necessaire la partition a restaurer
	if mount | grep "/dev/$dest_part " > /dev/null; then
		umount /dev/$dest_part
	fi


	if [ -z "$nom_image" ]; then
		echo -e "$COLTXT"
		echo "Recherche de l'image..."
		echo -e "$COLCMD\c"
		rm -f /root/tmp/liste_svg.txt
		touch /root/tmp/liste_svg.txt
		if [ -e "$chemin_src/$mac_machine" ]; then 
			ls -t -1 $chemin_src/$mac_machine/*.000 $chemin_src/$mac_machine/*.fsa $chemin_src/$mac_machine/*.ntfs* > /root/tmp/liste_svg.txt 2>/dev/null
		fi
		ls -t -1 $chemin_src/*.000 $chemin_src/*.fsa $chemin_src/*.ntfs* >> /root/tmp/liste_svg.txt 2>/dev/null

		while read A
		do
			if [ -z "$nom_image" ]; then
				t=$(echo "$A"|grep "000$")
				if [ -n "$t" ]; then
					B=$(echo "$A" | sed -e "s/.000$//")
					if [ -e "$B.SUCCES.txt" ]; then
						nom_image=$(basename "$A")
					fi
				else
					t=$(echo "$A"|grep "fsa$")
					if [ -n "$t" ]; then
						B=$(echo "$A" | sed -e "s/.fsa$//")
						if [ -e "$B.SUCCES.txt" ]; then
							nom_image=$(basename "$A")
						fi
					else
						t=$(echo "$A"|grep "ntfs$")
						t2=$(echo "$A"|grep "ntfsaa$")
						if [ -n "$t" -o -n "$t2" ]; then
							B=$(echo "$A" | sed -e "s/.ntfs$//")
							if [ -e "$B.SUCCES.txt" ]; then
								nom_image=$(basename "$A")
							else
								B=$(echo "$A" | sed -e "s/.ntfsaa$//")
								if [ -e "$B.SUCCES.txt" ]; then
									nom_image=$(basename "$A")
								fi
							fi
						fi
					fi
				fi
			fi
		done < /root/tmp/liste_svg.txt
		# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
		# A FAIRE: Si nom_image est vide, proposer de choisir l'image a restaurer...
		# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

		if [ -z "$nom_image" ]; then
			echo "ECHEC" > ${rapport}
			echo "Aucune sauvegarde n'a ete trouvee dans //$serveur/$partage/$chemin_distant :" >> ${rapport}
			ls $chemin_src/ >> ${rapport}

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

	#t1=$(echo "${nom_image}"|grep "000$")
	#t2=$(echo "${nom_image}"|grep "fsa$")
	#t3=$(echo "${nom_image}"|grep "ntfs$")

	if [ ! -e "$chemin_src/${nom_image}" -a  ! -e "$chemin_src/$mac_machine/${nom_image}" ]; then
		# Il manque probablement le suffixe/extension du fichier

		t=$(ls "$chemin_src/${nom_image}.000" 2>/dev/null)
		t2=$(ls "$chemin_src/$mac_machine/${nom_image}.000" 2>/dev/null)
		if [ -n "$t" -o -n "$t2" ]; then
			nom_image=${nom_image}.000
			type_svg="partimage"
		else
			t=$(ls "$chemin_src/${nom_image}.fsa" 2>/dev/null)
			t2=$(ls "$chemin_src/$mac_machine/${nom_image}.fsa" 2>/dev/null)
			if [ -n "$t" -o -n "$t2" ]; then
				nom_image=${nom_image}.fsa
				type_svg="fsarchiver"
			else
				t=$(ls "$chemin_src/${nom_image}.ntfs" 2>/dev/null)
				t2=$(ls "$chemin_src/$mac_machine/${nom_image}.ntfs" 2>/dev/null)
				if [ -n "$t" -o -n "$t2" ]; then
					nom_image=${nom_image}.ntfs
					type_svg="ntfsclone"
				else
					t=$(ls "$chemin_src/${nom_image}.ntfsaa" 2>/dev/null)
					t2=$(ls "$chemin_src/$mac_machine/${nom_image}.ntfsaa" 2>/dev/null)
					if [ -n "$t" -o -n "$t2" ]; then
						nom_image=${nom_image}.ntfs
						type_svg="ntfsclone"
					else
						echo "ECHEC" > ${rapport}
						echo "La sauvegarde au nom $nom_image dans //$serveur/$partage/$chemin_distant n'a pas ete trouvee:" >> ${rapport}
						ls $chemin_src/ >> ${rapport}
	
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
		fi

		if [ -n "$t2" ]; then
			image_avec_chemin="$chemin_src/$mac_machine/${nom_image}"
		else
			image_avec_chemin="$chemin_src/${nom_image}"
		fi

	else
		t=$(echo ${nom_image} | grep -i ".000$")
		if [ -n "$t" ]; then
			type_svg="partimage"

			if [ -e "$chemin_src/$mac_machine/${nom_image}" ]; then
				image_avec_chemin="$chemin_src/$mac_machine/${nom_image}"
			else
				image_avec_chemin="$chemin_src/${nom_image}"
			fi
		else
			t=$(echo ${nom_image} | grep -i ".fsa$")
			if [ -n "$t" ]; then
				type_svg="fsarchiver"

				if [ -e "$chemin_src/$mac_machine/${nom_image}" ]; then
					image_avec_chemin="$chemin_src/$mac_machine/${nom_image}"
				else
					image_avec_chemin="$chemin_src/${nom_image}"
				fi
			else
				t=$(echo ${nom_image} | grep -i ".ntfs$")
				t2=$(echo ${nom_image} | grep -i ".ntfsaa$")
				if [ -n "$t" -o -n "$t2" ]; then
					type_svg="ntfsclone"

					if [ -e "$chemin_src/$mac_machine/${nom_image}" ]; then
						chemin_image="$chemin_src/$mac_machine"
					else
						chemin_image="$chemin_src"
					fi

					if [ -n "$t2" ]; then
						nom_image=$(echo ${nom_image} | sed -e "s|aa$||")
					fi

					image_avec_chemin="$chemin_image/${nom_image}"
				else
					echo "ECHEC" > ${rapport}
					echo "Le type de la sauvegarde $nom_image dans //$serveur/$partage/$chemin_distant n'a pas ete identifie:" >> ${rapport}
					if [ -e "$chemin_src/$mac_machine" ]; then
						ls $chemin_src/$mac_machine/* >> ${rapport}
					fi
					ls $chemin_src/* >> ${rapport}

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
	fi


	echo -e "$COLTXT"
	echo -e "Restauration de ${COLINFO}${dest_part}${COLTXT} d'apres ${COLINFO}${nom_image}"
	echo -e "${COLCMD}\c"
	sleep 3
	case $type_svg in
		"partimage")
			partimage -b -f0 restore /dev/$dest_part ${image_avec_chemin}
		;;
		"fsarchiver")
			fsarchiver -v restfs ${image_avec_chemin} id=0,dest=/dev/$dest_part
		;;
		"ntfsclone")
			# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
			# .ntfsaa, .ntfsab, .ntfsac, .ntfsad,...
			#chemin_et_prefixe_nom_image=$(echo "${image_avec_chemin}"|sed -e "s|.ntfs$||"|sed -e "s|.ntfsaa$||")
			chemin_et_prefixe_nom_image=$(echo "${image_avec_chemin}"|sed -e "s|.ntfs$||")
			TYPE_COMPRESS=$(cat ${chemin_et_prefixe_nom_image}.type_compression.txt 2>/dev/null)
			if [ -z "$TYPE_COMPRESS" ]; then
				TYPE_COMPRESS="gzip"
			fi
			case $TYPE_COMPRESS in
				"aucune")
					cat ${image_avec_chemin}* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$dest_part -
				;;
				"gzip")
					cat ${image_avec_chemin}* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$dest_part -
				;;
				"bzip2")
					cat ${image_avec_chemin}* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$dest_part -
				;;
			esac
		;;
	esac


	# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
	# A FAIRE: Voir comment remonter les infos de succes ou d'echec de la restauration...
	# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
	if [ "$?" = "0" ]; then
		temoin="succes"
		echo -e "$COLTXT"
		echo "Succes."
		echo -e "$COLCMD\c"
		#umount /mnt/$src_part
		umount /mnt/smb
		echo "SUCCES" > ${rapport}
		echo "Succes de la restauration de ${nom_image}" >> ${rapport}
		chmod 755 ${rapport}
	else
		temoin="echec"
		echo -e "$COLERREUR"
		echo "Echec."
		echo -e "$COLCMD\c"
		echo "ECHEC" > ${rapport}
		echo "Echec de la restauration de ${nom_image}" >> ${rapport}
		chmod 755 ${rapport}
	fi

else
	src_hd=$(echo "$src_part" | sed -e "s/[0-9]//g")
	#test2=$(fdisk -l /dev/$src_hd | grep "/dev/$src_part ")

	# On ne restaure que si la source existe:
	#if [ ! -z "$test2" ]; then
	test2=$(fdisk -s /dev/$src_part 2>/dev/null)
	if [ -n "$test2" -a -e "/sys/block/$src_hd/$src_part/partition" ]; then
		if mount | grep "/mnt/$src_part " > /dev/null; then
			umount /mnt/$src_part
		fi
	
		if mount | grep "/dev/$src_part " > /dev/null; then
			umount /dev/$src_part
		fi
	
		# Montage de la partition de stockage:
		mkdir -p /mnt/$src_part
		type_part=$(TYPE_PART $src_part)
		if [ -z "$type_part" ]; then
			mount /dev/$src_part /mnt/$src_part
		else
			mount -t $type_part /dev/$src_part /mnt/$src_part
		fi

		chemin_src=/mnt/$src_part/oscar
		# Sauvegarde si le montage a reussi:
		if [ "$?" = "0" ]; then
			if [ -z "$nom_image" ]; then
				ls -t -1 $chemin_src/*.000 $chemin_src/*.fsa $chemin_src/*.ntfs* > /root/tmp/liste_svg.txt 2>/dev/null
		
				while read A
				do
					if [ -z "$nom_image" ]; then
						t=$(echo "$A"|grep "000$")
						if [ -n "$t" ]; then
							B=$(echo "$A" | sed -e "s/.000$//")
							if [ -e "$B.SUCCES.txt" ]; then
								nom_image=$(basename "$A")
							fi
						else
							t=$(echo "$A"|grep "fsa$")
							if [ -n "$t" ]; then
								B=$(echo "$A" | sed -e "s/.fsa$//")
								if [ -e "$B.SUCCES.txt" ]; then
									nom_image=$(basename "$A")
								fi
							else
								t=$(echo "$A"|grep "ntfs$")
								t2=$(echo "$A"|grep "ntfsaa$")
								if [ -n "$t" -o -n "$t2" ]; then
									B=$(echo "$A" | sed -e "s/.ntfs$//")
									if [ -e "$B.SUCCES.txt" ]; then
										nom_image=$(basename "$A")
									else
										B=$(echo "$A" | sed -e "s/.ntfsaa$//")
										if [ -e "$B.SUCCES.txt" ]; then
											nom_image=$(basename "$A")
										fi
									fi
								fi	
							fi
						fi
					fi
				done < /root/tmp/liste_svg.txt
				# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
				# A FAIRE: Si nom_image est vide, proposer de choisir l'image a restaurer...
				# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
			fi

			if [ ! -e "$chemin_src/${nom_image}" ]; then
				t=$(ls "$chemin_src/${nom_image}.000" 2>/dev/null)
				if [ -n "$t" ]; then
					nom_image=${nom_image}.000
					type_svg="partimage"
				else
					t=$(ls "$chemin_src/${nom_image}.fsa" 2>/dev/null)
					if [ -n "$t" ]; then
						nom_image=${nom_image}.fsa
						type_svg="fsarchiver"
					else
						t=$(ls "$chemin_src/${nom_image}.ntfs" 2>/dev/null)
						if [ -n "$t" ]; then
							nom_image=${nom_image}.ntfs
							type_svg="ntfsclone"
						else
							t=$(ls "$chemin_src/${nom_image}.ntfsaa" 2>/dev/null)
							if [ -n "$t" ]; then
								nom_image=${nom_image}.ntfs
								type_svg="ntfsclone"
							else
								echo "ECHEC" > ${rapport}
								echo "La sauvegarde au nom $nom_image dans $chemin_src n'a pas ete trouvee:" >> ${rapport}
								ls $chemin_src/ >> ${rapport}
			
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
				fi
			else
				t=$(echo ${nom_image} | grep -i ".000$")
				if [ -n "$t" ]; then
					type_svg="partimage"
				else
					t=$(echo ${nom_image} | grep -i ".fsa$")
					if [ -n "$t" ]; then
						type_svg="fsarchiver"
					else
						t=$(echo ${nom_image} | grep -i ".ntfs$")
						t2=$(echo ${nom_image} | grep -i ".ntfsaa$")
						if [ -n "$t" -o -n "$t2" ]; then
							type_svg="ntfsclone"
						else
							echo "ECHEC" > ${rapport}
							echo "Le type de la sauvegarde $nom_image dans $chemin_src n'a pas ete identifie:" >> ${rapport}
							ls $chemin_src/ >> ${rapport}
		
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
			fi
	
			#if [ -f "$chemin_src/${nom_image}" ]; then
				echo -e "$COLTXT"
				echo -e "Restauration de ${COLINFO}${dest_part}${COLTXT} d'apres ${COLINFO}${nom_image}"
				echo -e "${COLCMD}\c"
				sleep 3
				case $type_svg in
					"partimage")
						partimage -b -f0 restore /dev/$dest_part $chemin_src/${nom_image}
					;;
					"fsarchiver")
						fsarchiver -v restfs $chemin_src/${nom_image} id=0,dest=/dev/$dest_part
					;;
					"ntfsclone")
						# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
						# .ntfsaa, .ntfsab, .ntfsac, .ntfsad,...
						prefixe_nom_image=$(echo "${nom_image}"|sed -e "s|.ntfs$||"|sed -e "s|.ntfsaa$||")
						TYPE_COMPRESS=$(cat $chemin_src/${prefixe_nom_image}.type_compression.txt 2>/dev/null)
						if [ -z "$TYPE_COMPRESS" ]; then
							TYPE_COMPRESS="gzip"
						fi
						case $TYPE_COMPRESS in
							"aucune")
								cat $chemin_src/${nom_image}* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$dest_part -
							;;
							"gzip")
								cat $chemin_src/${nom_image}* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$dest_part -
							;;
							"bzip2")
								cat $chemin_src/${nom_image}* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$dest_part -
							;;
						esac
					;;
				esac
	
				# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
				# A FAIRE: Voir comment remonter les infos de succes ou d'echec de la restauration...
				# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
				if [ "$?" = "0" ]; then
					temoin="succes"
					echo -e "$COLTXT"
					echo "Succes."
					echo -e "$COLCMD\c"
					umount /mnt/$src_part
					echo "SUCCES" > ${rapport}
					echo "Succes de la restauration de ${nom_image}" >> ${rapport}
					chmod 755 ${rapport}
				else
					temoin="echec"
					echo -e "$COLERREUR"
					echo "Echec."
					echo -e "$COLCMD\c"
					echo "ECHEC" > ${rapport}
					echo "Echec de la restauration de ${nom_image}" >> ${rapport}
					chmod 755 ${rapport}
				fi
			#else
			#	temoin="echec"
			#	echo -e "$COLERREUR"
			#	echo "Le fichier n'existe pas."
			#	echo -e "$COLCMD\c"
			#	echo "ECHEC" > ${rapport}
			#	echo "Echec de la restauration (${nom_image} n'existe pas)" >> ${rapport}
			#	chmod 755 ${rapport}
			#fi
		fi
	else
		echo "ECHEC" > ${rapport}
		echo "La partition source de restauration n'existe pas." >> ${rapport}
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
fi


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

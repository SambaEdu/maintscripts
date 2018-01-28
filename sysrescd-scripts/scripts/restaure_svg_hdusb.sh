#!/bin/bash

# Script de restauration depuis un disque dur USB
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 25/06/2013

# Chargement d'une bibliotheque de fonctions
if [ -e /bin/crob_fonctions.sh ]; then
	. /bin/crob_fonctions.sh
else
	if [ -e ${mnt_cdrom}/sysresccd/scripts/crob_fonctions.sh ]; then
		. ${mnt_cdrom}/sysresccd/scripts/crob_fonctions.sh
	else
		echo "ERREUR: La bibliotheque de fonctions crob_fonctions.sh n'a pas ete trouvee:"
		echo "        ni en /bin/crob_fonctions.sh (dans le sysrcd.dat)"
		echo "        ni en ${mnt_cdrom}/sysresccd/scripts/crob_fonctions.sh"
		echo ""
		echo "ABANDON."
		echo -e "Appuyez sur ENTREE pour quitter..."
		read PAUSE
		exit
	fi
fi

# Ajouter une option de boot:
# work=restaure_svg_hdusb.sh

# Variable pour permettre de relancer le script manuellement sans rebooter
ladate=$(date +%Y%m%d%H%M%S)

# Recherche du point de montage eventuellement passe en parametre sous la forme 'mnt=/mnt/truc'
t=$(echo "$*"|egrep "(^mnt=| mnt=)"|sed -e "s| |\n|g"|grep "^mnt="|cut -d"=" -f2)
if [ -n "${t}" ]; then
	ptmnt=${t}
else
	ptmnt=/mnt/part_svg
fi

if ! mount | grep -q " on ${ptmnt} "; then
	# Il faut effectuer le montage de la ressource

	# On commence par initialiser les variables en supposant que l'on boote sur le DD USB avec une partition pour la sauvegarde

	part_sysrcd=$(mount|grep " on ${mnt_cdrom} "|cut -d" " -f1)
	if [ "$part_sysrcd" = "/dev/sr0" ]; then
		echo -e "${COLINFO}"
		echo "Vous avez boote sur un CD."
		COMPTEUR=1
	else
		hd_usb=$(echo ${part_sysrcd}| sed -e "s|^/dev/||" | sed -e "s|[0-9]$||g")
	
		boot_hd_usb=${hd_usb}
	
		t=$(find /sys/block/${hd_usb} -name partition)
		t2=$(readlink /sys/block/${hd_usb}|grep "/usb")
		if [ -n "$t" -a -n "$t2" ]; then
			# On a probablement boote sur un disque dur usb
			COMPTEUR=0
		else
			COMPTEUR=1
		fi
	fi

	TEMOIN_PART_TROUVEE="n"
	while [ "$TEMOIN_PART_TROUVEE" != "y" ]
	do
#		removable=$(cat /sys/block/${hd_usb}/removable)
#		if [ "${removable}" = "0" ]; then
#			# On a probablement boote sur un CD avec l'option 'rescusb'
#			# Ce test ne fonctionne pas: Pour un disque dur USB, on a 0, c'est-a-dire qu'il n'apparait pas comme amovible.

		# Pour faire un tour dans la boucle si on a boote sur un disque dur/cle
		# Et ensuite seulement, on cherche un autre DD
		if [ "$COMPTEUR" -ge 1 ]; then
			hd_usb=""

			touch /tmp/liste_dd_testes_${ladate}.txt

			# On tente de trouver un DD USB connecte
			ls /sys/block/ | egrep -v "(^loop|^ram)" > /tmp/liste_drive.txt
			while read TEST_DRIVE
			do
				if ! grep -q "^${TEST_DRIVE}$" /tmp/liste_dd_testes_${ladate}.txt; then
#					t=$(find /sys/block/${TEST_DRIVE}/ -name removable)
					t=$(readlink /sys/block/${TEST_DRIVE}|grep "/usb")
					if [ -n "$t" ]; then
						# TEST_DRIVE est bien un peripherique amovible car usb...
						# On fait un autre test pour verifier s'il y a des partitions sur ce peripherique (pour eliminer un lecteur cd/dvd ou autre peripherique usb)
						t=$(find /sys/block/${TEST_DRIVE}/ -name partition)
						if [ -n "$t" ]; then
							#hd_usb=/dev/${TEST_DRIVE}
							hd_usb=${TEST_DRIVE}
							echo -e "${COLINFO}On utilise ${COLCHOIX}${hd_usb}${COLINFO} pour disque dur USB"
							break
						fi
					fi
				else
					echo -e "${COLTXT}"
					echo -e "Le disque ${COLCHOIX}${TEST_DRIVE}${COLTXT} a deja ete teste."
				fi
			done < /tmp/liste_drive.txt

			# Ce dispositif ne permet pas de monter automatiquement la partition de sauvegarde si on boote sur une cle usb et souhaite effectuer la restauration depuis un DD usb.
			# Dans ce cas, il faut effectuer le montage hors du script lancer:
			# Si la partition de sauvegarde a ete montee en /mnt/part_svg:
			#   /bin/restaure_svg_hdusb.sh
			# Sinon:
			#   /bin/restaure_svg_hdusb.sh POINT_MONTAGE

			# Euh... ce n'est plus vrai.
			# J'ai ajoute des tests qui devraient le permettre.
			if [ -z "${hd_usb}" ]; then
			#if [ -z "${hd_usb}" -a "$TEMOIN_PART_TROUVEE" != "y" ]; then
				echo -e "${COLERREUR}"
				echo -e "Aucun disque amovible avec dossier 'sauvegardes' n'a ete trouve."
				echo -e "${COLTXT}"
				echo -e "Appuyez sur ENTREE pour quitter..."
				read PAUSE
				exit
			fi
		fi

		echo -e "$COLINFO"
		echo "Recherche de la partition de stockage des sauvegardes"
		echo "La premiere partition contenant un dossier 'sauvegardes' sera retenue."
		sleep 1

		#liste_part=($(fdisk -l ${hd_usb} | grep "^/dev/" | grep -v "${part_sysrcd} " | cut -d" " -f1))

		# Pour effectuer un montage ntfs-3g:
		#REP_NTFS=1
		#COMMANDE_MONTAGE_NTFS="mount -t ntfs"
		REP_NTFS=2
		COMMANDE_MONTAGE_NTFS="ntfs-3g"
	
		#fdisk -l ${hd_usb} | grep "^/dev/" | grep -v "${part_sysrcd} " | cut -d" " -f1 > /tmp/liste_partitions_dd_usb.txt
		#fdisk -l /dev/${hd_usb} | grep "^/dev/" | sed -e "s|^/dev/||" | cut -d" " -f1 > /tmp/liste_partitions_dd_usb.txt
		LISTE_PART ${hd_usb} avec_tableau_liste=y
		cp /tmp/liste_part_extraite_par_LISTE_PART.txt /tmp/liste_partitions_dd_usb.txt
		while read TMP_PART
		do
			PART=$(echo "$TMP_PART"|sed -e "s|^/dev/||")
			echo -e "$COLTXT"
			echo "Montage de /dev/$PART"
			echo -e "$COLCMD\c"
			if mount | tr "\t" " " | grep -q "/dev/$PART "; then
				echo "La partition est deja montee."
				if [ -e "/mnt/${PART}/sauvegardes" ]; then
					echo -e "$COLINFO"
					echo "Dossier 'sauvegardes' trouve sur la partition /mnt/${PART}"
					echo -e "$COLTXT"
					ptmnt=/mnt/${PART}
					TEMOIN_PART_TROUVEE="y"
					break
				fi
			else
				mkdir -p /mnt/$PART
			
				TYPE_PART=$(TYPE_PART $PART)
			
				if [ "$TYPE_PART" = "ntfs" ]; then
					if [ "${REP_NTFS}" = "1" ]; then
						#echo "${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART"
						${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART || echo -e "${COLERREUR}ERREUR${COLTXT}"
					else
						#echo "${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART -o ${OPT_LOCALE_NTFS3G}"
						${COMMANDE_MONTAGE_NTFS} /dev/$PART /mnt/$PART -o ${OPT_LOCALE_NTFS3G} || echo -e "${COLERREUR}ERREUR${COLTXT}"
					fi
				else
					if [ -z "${TYPE_PART}" ]; then
						#echo "mount /dev/$PART /mnt/$PART"
						mount /dev/$PART /mnt/$PART || echo -e "${COLERREUR}ERREUR${COLTXT}"
					else
						#echo "mount -t ${TYPE_PART} /dev/$PART /mnt/$PART"
						mount -t ${TYPE_PART} /dev/$PART /mnt/$PART || echo -e "${COLERREUR}ERREUR${COLTXT}"
					fi
				fi
	
				if [ -e "/mnt/${PART}/sauvegardes" ]; then
					echo -e "$COLINFO"
					echo "Dossier 'sauvegardes' trouve sur la partition /mnt/${PART}"
					echo -e "$COLTXT"
					ptmnt=/mnt/${PART}
					TEMOIN_PART_TROUVEE="y"
					break
				else
					echo -e "$COLINFO"
					echo "La partition /mnt/${PART} ne contient pas de dossier 'sauvegardes'."
					echo -e "$COLCMD\c"
					if mount | grep -q "/mnt/${PART} "; then
						umount /mnt/${PART}
					fi
				fi
			fi
		done < /tmp/liste_partitions_dd_usb.txt

		echo "${hd_usb}" >> /tmp/liste_dd_testes_${ladate}.txt
		COMPTEUR=$((COMPTEUR+1))
	done
fi

svg=${ptmnt}/sauvegardes

if [ ! -e "${svg}" ]; then
	echo -e "$COLERREUR"
	echo -e "Le dossier ${COLCHOIX}${svg}${COLERREUR} n'existe pas."
	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour quitter."
	read PAUSE
	exit
fi

# Afficher une page de liste de sauvegardes
#GET_LISTE_SVG

liste=/tmp/liste_des_csv_de_sauvegarde.txt

# Chaque fichier liste_svg.csv doit etre de la forme:
#    num_part;type_svg;nom_image;
# avec eventuellement plusieurs lignes de sauvegardes:
#    1;ntfsclone;dell_optiplex_330_sda1_xp
#    5;partimage;dell_optiplex_330_sda5_ubuntu_racine
#    6;fsarchiver;dell_optiplex_330_sda6_ubuntu_home
# Le fichier peut/doit aussi contenir une ligne de description entouree de la chaine ###
#    ### Dell Optiplex 330 avec XPsp3 et Ubuntu 9.10 ###
#
# Le format
#    num_part;type_svg;nom_image;
# est le minimum indispensable, mais on peut le completer avec d'autres champs, comme
#    num_part;type_svg;nom_image;taille_part;
# Si ce 4ème champ existe, la taille originale de la partition sauvegardee est affichee.
# Cela peut etre commode si on restaure sur un disque de taille differente ou avec des partitions differentes pour re-preparer les partitions avec des dimensions permettant la restauration et sans perte de place.
#

# Remplir un tableau avec la liste des fichiers decrivant une sauvegarde
find ${svg} -iname liste_svg.csv > ${liste}

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	cpt=0
	while read ligne
	do
		tab_csv[${cpt}]=$ligne
	
		description=$(grep "###" "$ligne"|sed -e "s|###||g;s|^ ||g;s| $||g")
		if [ -n "$description" ]; then
			tab_desc[${cpt}]=$description
		else
			tab_desc[${cpt}]=$(echo "$ligne"|sed -e "s|^${svg}/||;s|/liste_svg.csv$||I")
		fi
	
		cpt=$((${cpt}+1))
	done < ${liste}
	
	nb_fichiers_csv=${cpt}
	
	nb_par_page=15
	
	num_page=1
	nb_pages=$((1+$(echo ${nb_fichiers_csv})/${nb_par_page}))
	
	cpt=0
	while [ "1" = "1" ]
	do
	
		if [ ${cpt} -ge ${nb_fichiers_csv} ]; then
			cpt=0
		fi
	
		clear
		echo -e "${COLTITRE}\c"
		echo -e "-------------------------------------------------------------------"
		echo -e " Choix de sauvegarde (${nb_fichiers_csv} fichiers de description)"
		echo "-------------------------------------------------------------------"
		echo -e "${COLCMD}\c"
	
		cpt_ini=${cpt}
		while [ ${cpt} -le $((${cpt_ini}+${nb_par_page})) -a -n "${tab_csv[${cpt}]}" ]
		do
			echo -e "${cpt} - ${tab_desc[${cpt}]}"
			cpt=$((${cpt}+1))
		done
	
		echo -e "$COLTXT"
		echo "Effectuez votre choix,"
		echo -e "ou appuyez sur ${COLCHOIX}ENTREE${COLTXT} pour passer a la suite des images,"
		echo -e "ou encore tapez ${COLCHOIX}q${COLTXT} et ${COLCHOIX}ENTREE${COLTXT} pour abandonner"
		echo -e "Choix: $COLSAISIE\c"
		read CHOIX
		if [ -n "$CHOIX" ]; then
			if [ "$CHOIX" = "q" ]; then
				echo -e "$COLERREUR"
				echo "Abandon..."
				sleep 3
				exit
			fi

			t=$(echo "$CHOIX"|sed -e "s|[0-9]||g")
			if [ -n "$t" ]; then
				echo -e "$COLERREUR"
				echo "Erreur: Choix invalide"
				sleep 2
			else
				break
			fi
		fi
	done

	if [ -n "${tab_csv[${CHOIX}]}" ]; then
		echo -e "$COLINFO"
		echo "Vous avez choisi ${tab_csv[${CHOIX}]}"
		echo -e "$COLTXT"
		echo "En voici le contenu:"
		echo -e "$COLCMD"
		#cat ${tab_csv[${CHOIX}]}
		while read ligne
		do
			if [ -z "${ligne}" ]; then
				echo ""
			else
				if [ "${ligne:0:1}" = "#" ]; then
					echo "${ligne}"
				else
					num_part=$(echo "${ligne}" | cut -d";" -f1 2>/dev/null)
					type_svg=$(echo "${ligne}" | cut -d";" -f2 2>/dev/null)
					nom_image=$(echo "${ligne}" | cut -d";" -f3 2>/dev/null)
					taille_part=$(echo "${ligne}" | cut -d";" -f4 2>/dev/null)
	
					t=$(echo "$num_part"|sed -e "s|[0-9]||g")
					#if [ -n "$t" -o -z "$num_part" -o ! -e "/sys/block/${HD}/${HD}${num_part}/partition" ]; then
					# A ce stade le disque destination n'est pas encore choisi
					if [ -n "$t" -o -z "$num_part" ]; then
						echo -e "${COLERREUR}${num_part}${COLCMD};\c"
						if [ -n "$type_svg" ]; then
							echo -e "$type_svg;\c"
						fi
						if [ -n "$nom_image" ]; then
							echo -e "$nom_image;\c"
						fi
						if [ -n "$taille_part" ]; then
							echo -e "$taille_part;\c"
						fi
						echo -e "${COLERREUR}La partition ${num_part} n existe pas${COLCMD}"
					else
						human_taille_part=""
						if [ -n "$taille_part" -a -z "$(echo $taille_part | sed -e 's/[0-9]//g')" ]; then
							human_taille_part=$(CALCULE_TAILLE $taille_part)
							echo "${ligne};${human_taille_part}"
						else
							echo "${ligne}"
						fi
					fi
				fi
			fi
		done < ${tab_csv[${CHOIX}]}

		POURSUIVRE_OU_CORRIGER "1"
	else
		echo -e "$COLERREUR"
		echo "Erreur: Choix invalide"
		sleep 2
	fi
done

# Recuperation du peripherique sur lequel on a boote:
HDUSB=$(mount|grep " on ${mnt_cdrom} "|cut -d" " -f1|sed -e "s|^/dev/||;s|[0-9]||g")

# Choisir le disque destination de la restauration

HD=""
while [ -z "$HD" ]
do
	AFFICHHD

	liste_tmp=($(sfdisk -g 2>/dev/null| grep "^/dev/" | grep -v "^/dev/${HDUSB}" | cut -d":" -f1 | cut -d"/" -f3))
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTDISK=${liste_tmp[0]}
	else
		DEFAULTDISK="sda"
	fi

	echo -e "${COLINFO}"
	echo -e "Vous avez boote sur la partition ${COLCHOIX}${part_sysrcd}${COLINFO} de ${COLCHOIX}${boot_hd_usb}${COLINFO} (evitez de l'ecraser;o)"

	echo -e "${COLTXT}"
	echo "Sur quel disque se trouve la ou les partitions Ã  restaurer?"
	echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
	echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] ${COLSAISIE}\c"
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

# On recupere la table de partitions actuelle du disque destination pour comparer avec une eventuelle sauvegarde
TMP_HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
fdisk -l /dev/$HD > /tmp/fdisk_l_${TMP_HD_CLEAN}.txt 2>&1
#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${TMP_HD_CLEAN}.txt|cut -d"'" -f2)
if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
	TMP_disque_en_GPT=/dev/${HD}
else
	TMP_disque_en_GPT=""
fi

if [ -z "$TMP_disque_en_GPT" ]; then
	sfdisk -d /dev/$HD > /tmp/$HD.out
else
	sgdisk -b /tmp/gpt_$HD.out /dev/$HD
fi

fichier_csv_choisi=${tab_csv[${CHOIX}]}

dossier_choisi=$(dirname ${fichier_csv_choisi})
cd ${dossier_choisi}

# Rechercher les *.out et proposer de refaire la table de partitions, de choisir un des fichiers .out
find . -iname "*.out" > /tmp/liste_fichiers_out.txt
nb_out=$(wc -l /tmp/liste_fichiers_out.txt|cut -d" " -f1)
if [ "${nb_out}" = "0" ]; then
	echo -e "$COLTXT"
	echo "Aucun fichier de partitionnement n'a ete trouve."
else
	REPONSE="n"


	if [ -e "${HD}_premiers_MO.bin" ]; then
		echo -e "$COLERREUR"
		echo -e "EXPERIMENTAL:$COLINFO"
		echo "Les premiers Mo du disque ont ete sauvegardes."

		echo "Il semble necessaire de les restaurer dans le cas d'une restauration"
		echo "de Window$ Seven ou peut-etre avec un BIOS UEFI."
		echo "Des choses semblent cachees entre le MBR et la premiere partition."
		echo ""
		echo "Si vous choisissez de restaurer ces premiers Mo, la table de partition"
		echo "sera aussi refaite d apres la sauvegarde."

		echo ""
		#echo "Dans 20 secondes, on poursuivra sans les restaurer."

		REP=""
		while [ "$REP" != "o" -a "$REP" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous les restaurer? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
			#read -t 20 REP
			read REP

			if [ -z "$REP" ]; then
				REP="n"
			fi
		done

		if [ "$REP" = "o" ]; then
			echo -e "$COLTXT"
			echo "Restauration des premiers Mo du disque."
			echo -e "$COLCMD"
			dd if="${HD}_premiers_MO.bin" of=/dev/${HD} bs=1M count=5
			partprobe /dev/${HD}
			restauration_debut_dd="o"
		fi
	fi


	if [ "${nb_out}" = "1" ]; then
		echo -e "$COLTXT"
		echo "Un fichier de partitionnement a ete trouve."

		# Comparer comme dans les scripts CDRESTAURE

		fichier_partition_out=$(cat /tmp/liste_fichiers_out.txt)

		if [ -z "$TMP_disque_en_GPT" ]; then
			test_diff=$(diff -abB /tmp/${HD}.out $fichier_partition_out)
		else
			test_diff=$(diff -abB /tmp/gpt_${HD}.out $fichier_partition_out)
		fi

		if [ ! -z "${test_diff}" -o "$restauration_debut_dd" = "o" ]; then
			echo -e "$COLTXT"
			echo "La table de partition semble avoir change depuis votre sauvegarde."
			if [ -z "$TMP_disque_en_GPT" ]; then
				echo "La table de partition actuelle est:"
				echo -e "$COLCMD\c"
				cat /tmp/${HD}.out
	
				echo -e "$COLTXT"
				echo "Votre sauvegarde de la table de partition est:"
				#cat $(cat /tmp/liste_fichiers_out.txt)
				cat $fichier_partition_out
			fi

			if [ "$restauration_debut_dd" = "o" ]; then
				echo -e "$COLTXT"
				echo "Appuyez sur ENTREE pour poursuivre..."
				read PAUSE
			fi

			DEFAUT_REFAIRE_PART="o"
		else
			echo -e "$COLTXT"
			echo "La table de partitions actuelle et la table sauvegardees sont identiques."
			echo "La restauration de la table parait inutile."
		
			DEFAUT_REFAIRE_PART="n"
		fi

		REPONSE=""
		if [ "$restauration_debut_dd" = "o" ]; then
			REPONSE="o"
		fi
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous refaire la table de partition? [${COLDEFAUT}${DEFAUT_REFAIRE_PART}${COLTXT}] (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		
			if [ -z "$REPONSE" ]; then
				REPONSE=${DEFAUT_REFAIRE_PART}
			fi
		done

	else
		echo -e "$COLTXT"
		echo "Plusieurs fichiers de partitionnement ont ete trouves."

		if [ -z "$TMP_disque_en_GPT" ]; then
			echo "La table de partition actuelle est:"
			echo -e "$COLCMD\c"
			cat /tmp/${HD}.out

			# Proposer d'en afficher le contenu
			# Proposer d'en choisir un
			# Comparer comme dans les scripts CDRESTAURE

			cpt=0
			while read ligne_out
			do
				test_diff=$(diff -abB /tmp/${HD}.out $ligne_out)
				if [ -n "$test_diff" ]; then
					echo -e "$COLTXT"
					echo "Contenu de la sauvegarde ${ligne_out} ($cpt) de la table de partition est:"
					cat ${ligne_out}
	
					tab_out[$cpt]=${ligne_out}
	
					cpt=$(($cpt+1))
				else
					echo -e "$COLTXT"
					echo "La sauvegarde ${ligne_out} coincide avec la table de partition actuelle."
				fi

				echo -e "$COLTXT"
				echo "Appuyez sur ENTREE pour poursuivre..."
				read PAUSE < /dev/tty
			done < /tmp/liste_fichiers_out.txt
		else
			cpt=0
			while read ligne_out
			do
				test_diff=$(diff -abB /tmp/gpt_${HD}.out $ligne_out)
				if [ -n "$test_diff" ]; then
					echo -e "$COLTXT"
					echo "Fichier different de votre paritionnement actuel: ${ligne_out} ($cpt)"

					tab_out[$cpt]=${ligne_out}

					cpt=$(($cpt+1))
				else
					echo -e "$COLTXT"
					echo "La sauvegarde ${ligne_out} coincide avec la table de partition actuelle."
				fi
			done < /tmp/liste_fichiers_out.txt
		fi

		#fichier_partition_out
		REPONSE=""
		while [ -z "$REPONSE" ]
		do
			echo -e "$COLTXT"
			echo "Voulez-vous choisir un de ces fichiers? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE

			if [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]; then
				REPONSE=""
			fi
		done

		if [ "$REPONSE" = "o" ]; then

			cpt=0
			while [ $cpt -lt ${nb_out} ]
			do
				echo "$cpt - ${tab_out[$cpt]}"
				cpt=$(($cpt+1))
			done

			CHOIX_OUT=""
			while [ -z "$CHOIX_OUT" ]
			do
				echo -e "$COLTXT"
				echo "Quel fichier souhaitez-vous utiliser? $COLSAISIE\c"
				read CHOIX_OUT

				t=$(echo "$CHOIX_OUT"|sed -e "s|[0-9]||g")
				if [ -n "$t" ]; then
					CHOIX_OUT=""
				else
					if [ -z "${tab_out[$CHOIX_OUT]}" ]; then
						CHOIX_OUT=""
					fi
				fi
			done

			fichier_partition_out=${tab_out[$CHOIX_OUT]}
		fi
	fi

	# Refaire si demande la table de partitions

	if [ "$REPONSE" = "o" ]; then
		echo -e "$COLTXT"
		echo "Restauration de la table de partition..."
		echo -e "$COLCMD"
		sleep 1

		if [ -z "$TMP_disque_en_GPT" ]; then
			sfdisk /dev/$HD < ${fichier_partition_out}
			if [ "$?" != "0" ]; then
				echo -e "$COLERREUR"
				echo "Une erreur s est semble-t-il produite."
				REPONSE=""
				if [ "$restauration_debut_dd" = "o" ]; then
					REPONSE="o"
				fi
				while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				do
					echo -e "$COLTXT"
					echo -e "Voulez-vous forcer le repartitionnement avec l option -f de sfdisk? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
					read REPONSE
				done
	
				echo -e "$COLCMD"
				if [ "$REPONSE" = "o" ]; then
					sfdisk -f /dev/$HD < ${fichier_partition_out} > /tmp/repartitionnement_${ladate}.txt 2>&1
					if grep -qi "BLKRRPART: Device or resource busy" /tmp/repartitionnement_${ladate}.txt; then
						echo -e "$COLERREUR"
						echo "Il semble que la relecture de la table de partitions ait echoue."
						echo "On force la relecture:"
						echo -e "$COLCMD"
						echo "hdparm -z /dev/$HD"
						hdparm -z /dev/$HD
					fi
				fi
			fi
		else
			sgdisk -l ${fichier_partition_out} /dev/$HD
			if [ "$?" != "0" ]; then
				echo -e "$COLERREUR"
				echo "Une erreur s est semble-t-il produite."
			fi
		fi
	else
		echo -e "$COLTXT"
		echo "On ne modifie pas la table de partition."
	fi

	sleep 2
fi


# Lancer la restauration des sauvegardes.
t1_global=$(date +%s)
t2_global=""
while read A
do
	if [ -n "${A}" -a "${A:0:1}" != "#" ]; then

		num_part=$(echo "${A}" | cut -d";" -f1)

		t=$(echo "$num_part"|sed -e "s|[0-9]||g")
		# Test a ameliorer...
		if [ -n "$t" -o -z "$num_part" -o ! -e "/sys/block/${HD}/${HD}${num_part}/partition" ]; then
			echo -e "$COLERREUR"
			echo -e "Si ${COLINFO}${HD}${num_part}${COLERREUR} est censee etre une partition,"
			echo "la table de partition comporte une erreur."
			echo "Sinon, la ligne suivante ne correspond pas a une sauvegarde:"
			echo -e "$COLCMD\c"
			echo "$A"
		else

			echo -e "$COLTXT"
			echo "La partition a restaurer est la numero ${num_part}"

			t=$(fdisk -s /dev/${HD}${num_part} 2> /dev/null)
			if [ -z "$t" ]; then
				echo -e "$COLERREUR"
				echo "La partition /dev/${HD}${num_part} n'existe pas."
			else

				type_svg=$(echo "${A}" | cut -d";" -f2)

				if [ "${type_svg}" != "partimage" -a "${type_svg}" != "fsarchiver" -a "${type_svg}" != "ntfsclone" -a "${type_svg}" != "dar" ]; then
					echo -e "$COLERREUR"
					echo "Le type de la sauvegarde est inconnu: $COLCMD\c"
					echo "${type_svg}"
				else
					case $type_svg in
						"partimage")
							extension="000"
						;;
						"ntfsclone")
							extension="ntfs"
						;;
						"fsarchiver")
							extension="fsa"
						;;
						"dar")
							extension="1.dar"
						;;
					esac

					image=$(echo "${A}" | cut -d";" -f3)
	
					if [ ! -e "$image.$extension" ]; then
						echo -e "$COLERREUR"
						echo "Le fichier de sauvegarde n'a pas ete trouve: $COLCMD\c"
						echo "$image.$extension"
					else

						if [ -e "${image}_premiers_MO.bin" ]; then
							echo -e "$COLERREUR"
							echo -e "EXPERIMENTAL:$COLINFO"
							echo "Les premiers Mo de la partition ont ete sauvegardes."
							echo "Leur restauration n'est normalement pas necessaire."
							echo ""
							echo "Dans 20 secondes, on poursuivra sans les restaurer."

							REP=""
							while [ "$REP" != "o" -a "$REP" != "n" ]
							do
								echo -e "$COLTXT"
								echo -e "Voulez-vous les restaurer? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
								read -t 20 REP

								if [ -z "$REP" ]; then
									REP="n"
								fi
							done

							if [ "$REP" = "o" ]; then
								echo -e "$COLTXT"
								echo "Restauration des premiers Mo de la partition."
								echo -e "$COLCMD"
								dd if="${image}_premiers_MO.bin" of=/dev/${HD}${num_part} bs=1M count=5
							fi
						fi

						if [ -e "$image.txt" ]; then
							echo -e "$COLTXT"
							echo -e "Commentaire saisi:"
							echo -e "$COLINFO"
							cat "$image.txt"
						fi

						echo -e "$COLTXT"
						cpt=9
						while [ "$cpt" -ge 0 ]
						do
							echo -en "\rLe script va se poursuivre dans $cpt seconde(s). "
							cpt=$(($cpt-1))
							sleep 1
						done
						echo ""
						#echo -e "$COLCMD\c"

						t1_part=$(date +%s)
						t2_part=""
						case $type_svg in
							"partimage")
								echo -e "$COLTXT"
								echo "Lancement de la restauration..."

								partimage -b -f3 -w restore /dev/${HD}${num_part} $image.000
							;;
							"ntfsclone")
								premier_morceau=$(${image}.ntfs*|head -n 1)
								if file ${premier_morceau} | grep -qi "bzip2 compressed data"; then
									cat ${image}.ntfs* | bzip2 -d -c | ntfsclone --restore-image --overwrite /dev/${HD}${num_part} -
								else
									if file ${premier_morceau} | grep -qi "gzip compressed data"; then
									cat ${image}.ntfs* | gunzip -c | ntfsclone --restore-image --overwrite /dev/${HD}${num_part} -
									else
										cat ${image}.ntfs* | ntfsclone --restore-image --overwrite /dev/${HD}${num_part} -
									fi
								fi
							;;
							"fsarchiver")
								fsarchiver -v restfs ${image}.fsa id=0,dest=/dev/${HD}${num_part}
							;;
							"dar")
								REPONSE=""
								while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
								do
									echo -e "$COLTXT"
									echo -e "Voulez-vous vider la partition avant de lancer la restauration? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
									read REPONSE
								done
								
								echo -e "$COLTXT"
								echo -e "Montage de la partition..."
								echo -e "$COLCMD\c"
								mkdir -p /mnt/${HD}${num_part}
								TYPE_FS=$(TYPE_PART /dev/${HD}${num_part})

								if [ ! -z "$TYPE_FS" ]; then
									if [ "$TYPE_FS" = "ntfs" ]; then
										ntfs-3g /dev/${HD}${num_part} /mnt/${HD}${num_part}
										# Il ne me semble pas que dar permette de restaurer du NTFS.
										# Si on passe par là, le pire est a craindre...
									else
										mount -t $TYPE_FS /dev/${HD}${num_part} /mnt/${HD}${num_part}
									fi
								else
									mount /dev/${HD}${num_part} /mnt/${HD}${num_part}
								fi

								if [ "$REPONSE" = "o" ]; then
									echo -e "$COLTXT"
									echo -e "Suppression du contenu de la partition avant restauration..."
									echo -e "$COLCMD\c"
									rm -fr /mnt/${HD}${num_part}/*
								fi

								echo -e "$COLINFO"
								echo -e "Lancement de la restauration"
								echo -e "$COLCMD\c"
								sleep 2

								dar -x /$image -R /mnt/${HD}${num_part} -b -wa -v
							;;
						esac

						if [ "$?" != "0" ]; then
							echo -e "${COLERREUR}"
							echo "Il semble qu'une erreur se soit produite."

							POURSUIVRE
						else
							t2_part=$(date +%s)
							duree_rest_part=$(CALCULE_DUREE $t1_part $t2_part)
							echo -e "${COLTXT}Duree: ${COLINFO}${duree_rest_part}${COLTXT}"

							sleep 5
						fi

					fi
				fi
			fi
		fi
	fi
done < ${fichier_csv_choisi}
t2_global=$(date +%s)
duree_rest_globale=$(CALCULE_DUREE $t1_global $t2_global)
echo -e "${COLTXT}Duree globale: ${COLINFO}${duree_rest_globale}${COLTXT}"

# Proposer de nettoyer le secteur de boot... ou de reinstaller un grub/lilo
REP=""
#t=$(fdisk -l /dev/${HD}|grep -i "Linux$")
#if [ -z "$t" ]; then
LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
if [ ! -z "${liste_tmp[0]}" ]; then
	# Il n'y a pas de partition Linux sur ${HD}
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous nettoyer le secteur de boot (avec ${COLINFO}install-mbr /dev/${HD}${COLTXT}) ? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
		read REPONSE
	done

	if [ "$REPONSE" = "o" ]; then
		REP=2
	fi
else
	while [ "$REP" != "1" -a "$REP" != "2" -a "$REP" != "3" -a "$REP" != "4" ]
	do
		echo -e "$COLTXT"
		echo "Voulez-vous:"
		echo -e " (${COLCHOIX}1${COLTXT}) ne rien faire,"
		echo -e " (${COLCHOIX}2${COLTXT}) nettoyer le secteur de boot (avec ${COLINFO}install-mbr /dev/${HD}${COLTXT}),"
		echo -e " (${COLCHOIX}3${COLTXT}) reinstaller un LILO"
		echo -e "     (il faut que la partition Linux contienne un /etc/lilo.conf correctement"
		echo -e "      renseigne)"
		echo -e " (${COLCHOIX}4${COLTXT}) reinstaller un GRUB."
		echo -e "     (il faut que la partition Linux contienne un /boot/grub/menu.lst"
		echo -e "      correctement renseigne)"
		echo -e "Votre choix: $COLSAISIE\c"
		read REP
	done
fi

case $REP in
2)
	echo -e "$COLTXT"
	echo "Nettoyage du secteur de boot..."
	echo -e "$COLCMD\c"
	install-mbr /dev/${HD}
;;
3)
	echo -e "$COLTXT"
	echo "Lancement du script de reinstallation de LILO..."
	echo -e "$COLCMD\c"
	if [ -e "/bin/reinstall_lilo.sh" ]; then
		/bin/reinstall_lilo.sh
	else
		if [ -e "${mnt_cdrom}/sysresccd/scripts/reinstall_lilo.sh" ]; then
			sh ${mnt_cdrom}/sysresccd/scripts/reinstall_lilo.sh
		else
			echo -e "$COLERREUR"
			echo "ERREUR: Le script n'a pas ete trouve."
		fi
	fi
;;
4)
	echo -e "$COLTXT"
	echo "Lancement du script de reinstallation de GRUB..."
	echo -e "$COLCMD\c"
	if [ -e "/bin/reinstall_grub.sh" ]; then
		/bin/reinstall_grub.sh
	else
		if [ -e "${mnt_cdrom}/sysresccd/scripts/reinstall_grub.sh" ]; then
			sh ${mnt_cdrom}/sysresccd/scripts/reinstall_grub.sh
		else
			echo -e "$COLERREUR"
			echo "ERREUR: Le script n'a pas ete trouve."
		fi
	fi
;;
esac


#NUM_PART=$(CHECK_PART_ACTIVE)
NUM_PART=$(CHECK_PART_ACTIVE $HD)
if [ -z "$NUM_PART" ]; then
	echo -e "${COLERREUR}"
	echo -e "ATTENTION: Aucune partition n'a l'air bootable."
	echo -e "           Cela peut empecher le boot du systeme."
	echo -e "${COLCMD}"
	#fdisk -l /dev/${HD}
	parted -s /dev/${HD} print

	#echo -e "${COLTXT}"
	#echo -e "Lancez ${COLCMD}fdisk /dev/${HD}${COLTXT} pour rendre une partition active/bootable."
	#echo ""

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous rendre une partition bootable? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
		read REPONSE
	done

	if [ "$REPONSE" = "o" ]; then
		NUM_PART=""
		while [ -z "$NUM_PART" ]
		do
			echo -e "${COLTXT}"
			echo -e "Quel est le numero de la partition a rendre active? [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
			read NUM_PART

			if [ -z "$NUM_PART" ]; then
				NUM_PART="1"
			fi

			#t=$(fdisk -l /dev/${HD} | tr "\t" " " | grep "^/dev/${HD}${NUM_PART} ")
			#if [ -z "$t" ]; then
			t=$(fdisk -s /dev/${HD}${NUM_PART} 2>/dev/null)
			if [ -z "$t" -o ! -e "/sys/block/${HD}/${HD}${NUM_PART}/partition" ]; then
				echo -e "${COLERREUR}"
				echo "Partition /dev/${HD}${NUM_PART} invalide."
				NUM_PART=""
			fi
		done

		echo -e "$COLTXT"
		echo -e "Positionnement du drapeau Bootable sur la partition ${COLINFO}${HD}${NUM_PART}"
		echo -e "$COLCMD\c"
		echo "parted -s /dev/${HD} toggle ${NUM_PART} boot"
		parted -s /dev/${HD} toggle ${NUM_PART} boot

		sleep 2
		
		echo -e "$COLTXT"
		echo "Nouvel etat:"
		echo -e "$COLCMD\c"
		parted -s /dev/${HD} print
		
		#NUM_PART=$(CHECK_PART_ACTIVE)
		NUM_PART=$(CHECK_PART_ACTIVE $HD)
		if [ -z "$NUM_PART" ]; then
			echo -e "$COLERREUR"
			echo "Il semble qu'aucune partition ne soit bootable..."

			if [ -z "$TMP_disque_en_GPT" ]; then
				echo -e "$COLTXT"
				echo -e "Nouvel essai pour rendre bootable la partition ${COLINFO}${HD}${NUM_PART}"
				echo -e "$COLCMD\c"
				echo "a
${NUM_PART}
w" | fdisk /dev/$HD

				sleep 2
		
				echo -e "$COLTXT"
				echo "Nouvel etat:"
				echo -e "$COLCMD\c"
				parted -s /dev/${HD} print
		
				NUM_PART=$(CHECK_PART_ACTIVE)
				if [ -z "$NUM_PART" ]; then
					echo -e "$COLERREUR"
					echo "Il semble encore qu'aucune partition ne soit bootable..."
					echo "Vous allez devoir operer a la main:("
				fi
			else
				echo -e "$COLTXT"
				echo "Vous allez devoir corriger cela a la main."
			fi
		fi
	fi

	#echo -e "Appuyez sur ENTREE pour quitter..."
	#read PAUSE
fi

echo -e "$COLTITRE"
echo "Termine."
echo -e "$COLTXT"
echo -e "Appuyez sur ENTREE pour quitter..."
read PAUSE


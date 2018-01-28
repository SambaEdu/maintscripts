#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# D'après un script de Franck Molle (12/2003),
# lui-même inspiré par les scripts du CD StoneHenge,...
# Dernière modification: 01/06/2016

# **********************************
# Version adaptée à System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

clear
echo -e "${COLTITRE}"
echo "***************************************************"
echo "*      Ce script doit vous aider à restaurer      *"
echo "*        une image réalisée avec partimage,       *"
echo "*                 dar ou ntfsclone                *"
echo "*                                                 *"
echo "*             Celle-ci doit se trouver            *"
echo "*                   sur un cd/dvd,                *"
echo "*                 sur une partition               *"
echo "*        autre que celle que vous restaurez,      *"
#echo "*         sur un partage Samba/Win distant,       *"
echo "*       ou sur un partage Samba/Win distant.      *"
#Le module lufs a l'air absent...
#echo "*               ou accessible via FTP.            *"
echo "***************************************************"

echo -e "$COLPARTIE"
echo "================================="
echo "Choix de la partition à restaurer"
echo "================================="


HD=""
while [ -z "${HD}" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "${COLTXT}"
	echo "Sur quel disque se trouve la partition à restaurer?"
	echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
	echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] ${COLSAISIE}\c"
	read HD
	
	if [ -z "${HD}" ]; then
		HD=${DEFAULTDISK}
	fi

	tst=$(sfdisk -s /dev/${HD} 2>/dev/null)
	if [ -z "$tst" -o ! -e "/sys/block/${HD}" ]; then
		echo -e "$COLERREUR"
		echo "Le disque ${HD} n'existe pas."
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour corriger."
		read PAUSE
		HD=""
	fi
done


REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "${COLTXT}"
	echo "Voici les partitions sur le disque /dev/${HD}:"
	echo -e "${COLCMD}\c"

	LISTE_PART ${HD} afficher_liste=y avec_tableau_liste=y

	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART="${HD}1"
	fi
	
	echo -e "${COLTXT}"
	echo -e "Quelle est la partition cible à restaurer ?"
	echo -e "Attention toutes les données de cette partition seront effacées par l'image !!!"
	#echo -e "Partition à restaurer? [${COLDEFAUT}hda1${COLTXT}] ${COLSAISIE}\c"
	#echo -e "Partition à restaurer? [${COLDEFAUT}${HD}1${COLTXT}] ${COLSAISIE}\c"
	echo -e "Partition à restaurer? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] ${COLSAISIE}\c"
	read CHOIX_CIBLE
	
	if [ -z "$CHOIX_CIBLE" ]; then
		CHOIX_CIBLE="${DEFAULTPART}"
	fi

	if ! fdisk -s /dev/$CHOIX_CIBLE > /dev/null; then
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

PART_CIBLE="/dev/$CHOIX_CIBLE"

if mount | grep "/dev/$CHOIX_CIBLE " > /dev/null; then
	umount /dev/$CHOIX_CIBLE
	if [ "$?" != "0" ]; then
		echo -e "$COLERREUR"
		echo "Il semble que la partition /dev/$CHOIX_CIBLE soit montée"
		echo "et qu'elle ne puisse pas être démontée."
		echo "Il n'est pas possible de restaurer la partition avec partimage ou ntfsclone"
		echo "dans ces conditions..."
		echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de régler"
		echo "le problème (démonter la partition /dev/$CHOIX_CIBLE)"
		echo "avant de poursuivre."
	fi
fi

echo -e "$COLPARTIE"
echo "==================================="
echo "Choix de la source de la sauvegarde"
echo "==================================="

RESTAURATIONDEPUISCD="n"

REPONSE=""
#while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" -a "$REPONSE" != "4" ]
while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" -a "$REPONSE" != "4" -a "$REPONSE" != "5" ]
#while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
do
	echo -e "${COLTXT}"
	echo "Souhaitez-vous effectuer?"
	echo -e "     (${COLCHOIX}1${COLTXT}) une restauration depuis une partition locale,"
	echo -e "     (${COLCHOIX}2${COLTXT}) une restauration depuis un CD/DVD,"
	echo -e "     (${COLCHOIX}3${COLTXT}) une restauration depuis un partage Samba/win,"
	echo -e "     (${COLCHOIX}4${COLTXT}) une restauration depuis un serveur SSH."
	#Le module lufs a l'air absent...
	# lufis remplace lufsmount
	echo -e "     (${COLCHOIX}5${COLTXT}) une restauration depuis un dossier FTP."
	#echo -e "     (${COLCHOIX}4${COLTXT}) une sauvegarde via scp."
	echo -e "Mode choisi: [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE=1
	fi
done

case "$REPONSE" in
	1)
		echo -e "$COLPARTIE"
		echo "**************************************************************"
		echo "Vous avez choisi une restauration depuis une partition locale."
		echo "**************************************************************"

		VERIF=""
		while [ "${VERIF}" != "OK" ]
		do
			RESTHD=""
			CHOIX_SOURCE=""

			AFFICHHD

			echo -e "${COLTXT}"
			echo "Sur quel disque se situe la sauvegarde à restaurer?"
			echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
			echo -e "Disque: [${COLDEFAUT}${HD}${COLTXT}] ${COLSAISIE}\c"
			read RESTHD

			if [ -z "$RESTHD" ]; then
				#RESTHD="hda"
				RESTHD=${HD}
			fi

			echo -e "${COLTXT}"
			echo "Voici les partitions sur le disque /dev/$RESTHD:"
			echo -e "${COLCMD}"
			#fdisk -l /dev/$RESTHD | grep "/dev/$RESTHD[0-9]"
			# A VOIR: Le avec_part_exclue_du_tableau=${CHOIX_CIBLE} n'a pas l'air de fonctionner.
			LISTE_PART ${RESTHD} afficher_liste=y avec_tableau_liste=y avec_part_exclue_du_tableau=${CHOIX_CIBLE}

			#liste_tmp=($(fdisk -l /dev/$RESTHD | grep "^/dev/$RESTHD" | tr "\t" " " | grep -v "^/dev/${CHOIX_CIBLE} " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
			if [ ! -z "${liste_tmp[0]}" ]; then
				DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
			else
				DEFAULTPART="hda5"
			fi

			echo -e "${COLTXT}"
			echo -e "Quelle est la partition contenant l'image de restauration? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] ${COLSAISIE}\c"
			read CHOIX_SOURCE

			if [ -z "$CHOIX_SOURCE" ]; then
				CHOIX_SOURCE=${DEFAULTPART}
			fi

			#if ! fdisk -l /dev/${RESTHD} | grep "${CHOIX_SOURCE} " > /dev/null; then
			t=$(fdisk -s /dev/${CHOIX_SOURCE} 2>/dev/null)
			if [ -z "$t" -o ! -e "/sys/block/${RESTHD}/${CHOIX_SOURCE}/partition" ] > /dev/null; then
				echo -e "$COLERREUR"
				echo "ERREUR: La partition proposée n'existe pas!"

				VERIF="ERREUR"

				echo -e "${COLTXT}"
				echo "Appuyez sur ENTREE pour corriger votre choix."
				read PAUSE
			else
				if [ "${CHOIX_SOURCE}" = "${CHOIX_CIBLE}" ]; then
					echo -e "$COLERREUR"
					echo "ERREUR: La partition à restaurer ne peut pas être celle qui contient"
					echo "        la sauvegarde."

					VERIF="ERREUR"

					echo -e "${COLTXT}"
					echo "Appuyez sur ENTREE pour corriger votre choix."
					read PAUSE
				else
					VERIF="OK"
				fi
			fi
		done

		DEVSOURCE="/dev/$CHOIX_SOURCE"
		CHEMINSOURCE="/dev/$CHOIX_SOURCE"
		PTMNTSTOCK="/mnt/$CHOIX_SOURCE"

		echo -e "${COLCMD}"
		mkdir -p $PTMNTSTOCK

		echo -e "${COLTXT}"
		echo "Quel est le type de la partition $DEVSOURCE?"
		echo "(vfat (pour FAT32), ext2, ext3,...)"
		DETECTED_TYPE=$(TYPE_PART $DEVSOURCE)
		if [ ! -z "${DETECTED_TYPE}" ]; then
			echo -e "Type: [${COLDEFAUT}${DETECTED_TYPE}${COLTXT}] ${COLSAISIE}\c"
			read TYPE

			if [ -z "$TYPE" ]; then
				TYPE=${DETECTED_TYPE}
			fi
		else
			echo -e "Type: ${COLSAISIE}\c"
			read TYPE
		fi

		echo -e "${COLCMD}"
		if mount | grep "$DEVSOURCE " > /dev/null; then
			umount $DEVSOURCE
			sleep 1
		fi

		if mount | grep $PTMNTSTOCK > /dev/null; then
			umount $PTMNTSTOCK
			sleep 1
		fi

		if [ -z "$TYPE" ]; then
			mount $DEVSOURCE $PTMNTSTOCK||ERREUR "Le montage a échoué!"
		else
			mount -t $TYPE $DEVSOURCE $PTMNTSTOCK||ERREUR "Le montage a échoué!"
		fi
	;;
	2)
		echo -e "$COLPARTIE"
		echo "***************************************************"
		echo "Vous avez choisi une restauration depuis un CD/DVD."
		echo "***************************************************"

		RESTAURATIONDEPUISCD="o"

		echo -e "$COLPARTIE"
		echo "=============================="
		echo "Choix du lecteur CD/DVD source"
		echo "=============================="

		echo -e "${COLTXT}"
		echo "Ejection du CD de boot:"
		echo -e "${COLCMD}"
		eject ${mnt_cdrom}

		echo -e "$COLINFO"
		echo -e "Si vous n'avez pas booté avec l'option 'docache' pour SysRescCD,\nil se peut que vous obteniez un refus d'éjection."
		echo -e "Dans ce cas, si vous n'avez pas un deuxième lecteur,\n vous serez contraint de rebooter avec l'option 'docache'."
		echo -e "Si vous avez un deuxième lecteur,\nvous pouvez aussi insérer le CD dans le deuxième lecteur."

		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Insérez le cd ou dvd contenant votre sauvegarde avant de continuer."
			echo -e "Peut-on continuer ? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
			read REPONSE
		done

		if [ "$REPONSE" = "o" ]; then

			echo -e "${COLTXT}"
			echo "Dans quel lecteur se trouve votre CD/DVD?"
			echo -e "${COLCMD}\c"

			LECTEUR_CD_DVD_PAR_DEFAUT

			DEV_SOURCE=""

			while [ -z "$DEV_SOURCE" ]
			do
				echo -e "${COLTXT}"
				echo "Quel lecteur contient votre CD/DVD?"
				echo "(exemples: hda, hdb, hdc,..., sda, sdb,...)"
				if [ -z "$LECTDEFAUT" ]; then
					echo -e "Lecteur: ${COLSAISIE}\c"
					read DEV_SOURCE
				else
					echo -e "Lecteur: [${COLDEFAUT}${LECTDEFAUT}${COLTXT}] ${COLSAISIE}\c"
					read DEV_SOURCE
					if [ -z "$DEV_SOURCE" ]; then
						DEV_SOURCE="$LECTDEFAUT"
					fi
				fi
			done

			DEVSOURCE="/dev/$DEV_SOURCE"
			CHEMINSOURCE="/dev/$DEV_SOURCE"

			PTMNTSTOCK="/mnt/cd_${DEV_SOURCE}"

			echo -e "${COLCMD}"
			if mount | grep "$PTMNTSTOCK" > /dev/null; then
				umount $PTMNTSTOCK
			fi

			if mount | grep "$DEVSOURCE " > /dev/null; then
				umount $DEVSOURCE
			fi

			mkdir -p $PTMNTSTOCK

			mount -t iso9660 $DEVSOURCE $PTMNTSTOCK ||ERREUR "Le montage a échoué!"
		else
			ERREUR "Vous n'avez pas souhaité poursuivre."
		fi
	;;
	3)
		echo -e "$COLPARTIE"
		echo "**************************************************************"
		echo "Vous avez choisi une restauration depuis un partage Samba/win."
		echo "**************************************************************"

		PTMNTSTOCK="/mnt/smb"
		if mount | grep $PTMNTSTOCK > /dev/null; then
			#smbumount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
			umount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
		fi


		CONFIG_RESEAU


		echo -e "${COLTXT}"
		echo -e "Quelle est l'adresse IP du serveur? ${COLSAISIE}\c"
		read IP

		if grep "^$IP " /etc/hosts > /dev/null; then
			DEFNOMNETBIOS=$(grep "^$IP " /etc/hosts | cut -d" " -f2)

			echo -e "${COLTXT}"
			echo -e "Quel est le nom NETBIOS du serveur? [${COLDEFAUT}${DEFNOMNETBIOS}${COLTXT}] ${COLSAISIE}\c"
			read NOMNETBIOS

			if [ -z "$NOMNETBIOS" ]; then
				NOMNETBIOS=$DEFNOMNETBIOS
			fi
		else
			echo -e "${COLTXT}"
			echo -e "Quel est le nom NETBIOS du serveur? ${COLSAISIE}\c"
			read NOMNETBIOS
		fi

		if cat /etc/hosts | grep "^$IP " > /dev/null; then
			if ! cat /etc/hosts | grep "^$IP " | egrep "( $NOMNETBIOS$| $NOMNETBIOS )" > /dev/null; then
				chaine1=$(cat /etc/hosts | grep "^$IP ")
				chaine2="${chaine1} ${NOMNETBIOS}"
				sed -e "s/^$chaine1$/$chaine2/" /etc/hosts > /tmp/hosts
				cp -f /tmp/hosts /etc/hosts
			fi
		else
			echo "$IP $NOMNETBIOS" >> /etc/hosts
		fi

		echo -e "${COLTXT}"
		if ping -c 1 $NOMNETBIOS > /dev/null; then
			echo -e "La machine ${COLINFO}${NOMNETBIOS}${COLTXT} a répondu au ping."
		else
			echo -e "La machine ${COLINFO}${NOMNETBIOS}${COLTXT} n'a pas répondu au ping."
			echo "Si la machine filtre les ping, c'est normal."
			echo "Sinon, vous devriez annuler."
			echo -e "Voulez-vous tout de même poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
			read REPONSE

			if [ "$REPONSE" != "o" ]; then
				ERREUR "Vous n'avez pas souhaité poursuivre."
			fi
		fi

		if [ -e /usr/bin/smbclient -o -e /usr/sbin/smbclient ]; then
			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Voulez-vous rechercher les partages proposés par cette machine? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				read REPONSE
			done
	
			if [ "$REPONSE" = "o" ]; then
				REPONSE=""
				while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
				do
					echo -e "${COLTXT}"
					echo -e "Voulez-vous effectuer la recherche:"
					echo -e "   (${COLCHOIX}1${COLTXT}) en vous identifiant"
					echo -e "   (${COLCHOIX}2${COLTXT}) ou en anonyme (partages publics seulement)"
					echo -e "Votre choix: (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] ${COLSAISIE}\c"
					read REPONSE
	
					if [ -z "$REPONSE" ]; then
						REPONSE="2"
					fi
				done
	
				if [ "$REPONSE" = "2" ]; then
					echo -e "${COLTXT}"
					echo "Voici la liste des partages publics trouvés:"
					echo -e "${COLCMD}"
					#smbclient -L $IP -N > /tmp/liste_partages.txt 2> /dev/null
					smbclient -L $IP -N > /tmp/liste_partages.txt
				else
					echo -e "${COLTXT}"
					echo -e "Veuillez saisir le nom du login: ${COLSAISIE}\c"
					read NOMLOGIN
	
					echo -e "${COLTXT}"
					echo "Pour afficher la liste des partages visibles par $NOMLOGIN,"
					echo "vous allez devoir fournir un mot de passe:"
					echo -e "${COLCMD}\c"
					#smbclient -L $IP -N > /tmp/liste_partages.txt 2> /dev/null
					smbclient -L $IP -U $NOMLOGIN > /tmp/liste_partages.txt
				fi
				FINPARTAGES=""
				cat /tmp/liste_partages.txt | tr "\t" " " | while read A
				do
					if echo "$A" | grep "Workgroup            Master" > /dev/null; then
						FINPARTAGES="o"
					fi
					if echo "$A" | grep "Server               Comment" > /dev/null; then
						FINPARTAGES="o"
					fi
					if [ "$FINPARTAGES" != "o" ]; then
						if ! echo "$A" | grep " Printer " > /dev/null; then
							echo "$A"
						fi
					fi
				done
			fi
		fi

		echo -e "${COLTXT}"
		echo -e "Quel est le nom du partage sur le serveur? ${COLSAISIE}\c"
		read PARTAGE

		echo -e "${COLTXT}"
		echo -e "Le partage nécessite-t-il un login particulier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
		read LOGIN

		if [ -z "$LOGIN" ]; then
			LOGIN="n"
		fi

		NOMPRECEDENT="$NOMLOGIN"
		NOMLOGIN=""
		if [ "$LOGIN" = "o" ]; then
			echo -e "${COLTXT}"
			if [ -z "$NOMPRECEDENT" ]; then
				echo -e "Veuillez saisir le nom du login: ${COLSAISIE}\c"
				read NOMLOGIN
			else
				echo -e "Veuillez saisir le nom du login: [${COLDEFAUT}${NOMPRECEDENT}${COLTXT}] ${COLSAISIE}\c"
				read NOMLOGIN

				if [ -z "$NOMLOGIN" ]; then
					NOMLOGIN="$NOMPRECEDENT"
				fi
			fi
		fi

		if [ "$LOGIN" = "o" ]; then
			CHOIX="o"
		else
			CHOIX="n"
		fi
		echo -e "${COLTXT}"
		echo -e "Le partage nécessite-t-il un mot de passe? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${CHOIX}${COLTXT}] ${COLSAISIE}\c"
		read MDP

		if [ -z "$MDP" ]; then
			MDP="$CHOIX"
		fi

		MOTDEPASSE=""
		if [ "$MDP" = "o" ]; then
			echo -e "${COLTXT}"
			echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
			read MOTDEPASSE
			echo -e "\033[0;39m                                                                                "
		fi

		PTMNTSTOCK="/mnt/smb"
		echo -e "${COLTXT}"
		echo "Création du point de montage:"
		echo -e "${COLCMD}"
		echo "mkdir -p ${PTMNTSTOCK}"
		mkdir -p ${PTMNTSTOCK}
		echo -e "${COLTXT}"
		echo "Montage du partage:"
		echo -e "${COLCMD}\c"

		OPTIONS=""
		if [ ! -z "$NOMLOGIN" ]; then
			OPTIONS="username=$NOMLOGIN"
			#if [ ! -z "MOTDEPASSE" ]; then
			if [ "$MDP" = "o" ]; then
				OPTIONS="$OPTIONS,password=$MOTDEPASSE"
			fi
		else
			#if [ ! -z "MOTDEPASSE" ]; then
			if [ "$MDP" = "o" ]; then
				OPTIONS="password=$MOTDEPASSE"
			else
				OPTIONS="guest"
			fi
		fi

		#if [ ! -z "MOTDEPASSE" ]; then
		#	if [ -z "$OPTIONS" ]; then
		#		OPTIONS="password=$MOTDEPASSE"
		#	else
		#		OPTIONS="$OPTIONS,password=$MOTDEPASSE"
		#	fi
		#fi

		#if [ -z "$OPTIONS" ]; then
		#	OPTIONS="guest"
		#fi

		if mount | grep "//$NOMNETBIOS/$PARTAGE" > /dev/null; then
			umount "//$NOMNETBIOS/$PARTAGE" || ERREUR "//$NOMNETBIOS/$PARTAGE est déjà monté\net n'a pas pu être démonté."
		fi

		if mount | grep "${PTMNTSTOCK}" > /dev/null; then
			#smbumount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
			umount "${PTMNTSTOCK}" || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
		fi

		NOPWOPT=$(echo "$OPTIONS" | sed -e "s/password=$MOTDEPASSE/password=XXXXXX/")
		#echo "smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $NOPWOPT"
		#smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS || ERREUR "Le montage a échoué!"

		# BIZARRE: Avec la 0.4.2, j'ai des problèmes pour monter //se3/Progs avec CIFS
		#if [ "${BOOT_IMAGE}" = "rescuecd" ]; then
		#if [ "${BOOT_IMAGE}" = "rescuecd" ]; then
		# smbmount a a nouveau disparu en 1.6.2
		if [ ! -e /usr/bin/smbmount -a ! -e /usr/sbin/smbmount ]; then
			echo "mount -t cifs //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $NOPWOPT"
			mount -t cifs //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS
			# || ERREUR "Le montage a échoué!"
			# Traitement d'erreur supprimé à ce niveau parce qu'il a tendance à se produire une erreur sans grande conséquence du type:
			# CIFS VFS: Send error in SETFSUnixInfo = -5
			# Par contre, le $? contient quand même zéro.
		else
			echo "smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $NOPWOPT"
			smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS || ERREUR "Le montage a échoué!"
		fi
		if [ "$?" != "0" ]; then
			#ERREUR "//$NOMNETBIOS/$PARTAGE est déjà monté\net n'a pas pu être démonté."
			echo -e "$COLERREUR"
			echo "ERREUR: Le montage a échoué!"
			#VERIF="PB"
		fi
		echo ""

		#CHEMINSOURCE="//$IP/$PARTAGE"
		CHEMINSOURCE="//$NOMNETBIOS/$PARTAGE"

		if mount | grep ${PTMNTSTOCK} > /dev/null; then
			echo -e "${COLTXT}Voici ce qui est monté en ${PTMNTSTOCK}"
			echo -e "${COLCMD}\c"
			mount | grep ${PTMNTSTOCK}
		else
			echo -e "${COLERREUR}Il semble que rien ne soit monté en ${PTMNTSTOCK}"

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Voulez-vous poursuivre néanmoins? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				read REPONSE
			done

			if [ "$REPONSE" != "o" ]; then
				ERREUR "Vous n'avez pas souhaité poursuivre."
			fi
		fi

		echo -e "${COLTXT}"
		echo "Appuyez sur ENTREE pour poursuivre..."
		read PAUSE

	;;
	4)
		echo -e "$COLPARTIE"
		echo "********************************************************"
		echo "Vous avez choisi une restauration depuis un serveur SSH."
		echo "********************************************************"

		PTMNTSTOCK="/mnt/ssh"
		if mount | grep $PTMNTSTOCK > /dev/null; then
			umount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
		fi


		CONFIG_RESEAU


		echo -e "${COLTXT}"
		echo "Nom DNS ou Adresse du serveur SSH"
		echo -e "Dans la plupart des cas, saisir l'IP vous évitera\ndes problèmes de résolution des noms de machines."
		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do
			echo -e "${COLTXT}"
			echo -e "Quel est le nom DNS ou l'IP du serveur? ${COLSAISIE}\c"
			read SERVEUR

			echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$SERVEUR"

			POURSUIVRE_OU_CORRIGER 1
		done

		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do
			echo -e "${COLTXT}"
			echo -e "Veuillez saisir le nom de login: [${COLDEFAUT}root${COLTXT}] ${COLSAISIE}\c"
			read NOMLOGIN

			if [ -z "$NOMLOGIN" ]; then
				NOMLOGIN="root"
			fi

			echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$NOMLOGIN"

			POURSUIVRE_OU_CORRIGER 1
		done

		#echo -e "${COLTXT}"
		#echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
		#read MOTDEPASSE
		#echo -e "\033[0;39m                                                                                "

		echo -e "${COLTXT}"
		echo -e "On accède généralement à la racine en sshfs."
		echo -e "Vous pourrez choisir le sous-dossier contenant la sauvegarde plus loin."
		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do
			echo -e "${COLTXT}"
			echo -e "Veuillez choisir le dossier racine distante à monter: [${COLDEFAUT}/${COLTXT}] ${COLSAISIE}\c"
			read DOSSIERDISTANT

			if [ -z "$DOSSIERDISTANT" ]; then
				DOSSIERDISTANT="/"
			fi

			echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$DOSSIERDISTANT"

			POURSUIVRE_OU_CORRIGER 1
		done

		echo -e "${COLTXT}"
		echo -e "Le port sur lequel tourne SSH est généralement le port 22."
		echo -e "Modifiez la valeur si le serveur a une configuration différente."
		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do
			echo -e "${COLTXT}"
			echo -e "Veuillez choisir le port du serveur SSH: [${COLDEFAUT}22${COLTXT}] ${COLSAISIE}\c"
			read PORTSSH

			if [ -z "$PORTSSH" ]; then
				PORTSSH="22"
			fi

			echo -e "${COLTXT}Vous avez choisi: ${COLINFO}$PORTSSH"

			POURSUIVRE_OU_CORRIGER 1
		done

		echo -e "${COLTXT}"
		echo "Création du point de montage:"
		echo -e "${COLCMD}"
		echo "mkdir -p $PTMNTSTOCK"
		mkdir -p $PTMNTSTOCK

		# Le module fuse est devenu inutile avec la version 0.3.8
		# La fonctionnalité est directement dans le noyau
		#echo -e "${COLTXT}"
		#echo "Chargement du module fuse:"
		#echo -e "${COLCMD}\c"
		#modprobe fuse

		echo -e "${COLTXT}"
		echo "Montage du partage:"
		echo -e "${COLCMD}\c"

		echo "sshfs -p $PORTSSH ${NOMLOGIN}@${SERVEUR}:${DOSSIERDISTANT} $PTMNTSTOCK"
		sshfs -p $PORTSSH ${NOMLOGIN}@${SERVEUR}:${DOSSIERDISTANT} $PTMNTSTOCK || ERREUR "Le montage a échoué!"
		echo ""

		#PART_CIBLE="sshfs://${SERVEUR}"


		if mount | grep ${PTMNTSTOCK} > /dev/null; then
			echo -e "${COLTXT}Voici ce qui est monté en ${PTMNTSTOCK}"
			echo -e "${COLCMD}\c"
			mount | grep ${PTMNTSTOCK}
		else
			echo -e "${COLERREUR}Il semble que rien ne soit monté en ${PTMNTSTOCK}"

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Voulez-vous poursuivre néanmoins? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				read REPONSE
			done

			if [ "$REPONSE" != "o" ]; then
				ERREUR "Vous n'avez pas souhaité poursuivre."
			fi
		fi

		echo -e "${COLTXT}"
		echo "Appuyez sur ENTREE pour poursuivre..."
		read PAUSE

		#CHEMINSOURCE="ftpfs://${SERVEUR}"
		CHEMINSOURCE="sshfs://${SERVEUR}"

		;;
	5)
		echo -e "$COLPARTIE"
		echo "********************************************************"
		echo "Vous avez choisi une restauration depuis un serveur FTP."
		echo "********************************************************"

		PTMNTSTOCK="/mnt/ftp"
		if mount | grep $PTMNTSTOCK > /dev/null; then
			umount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
		fi



		CONFIG_RESEAU


		echo -e "${COLTXT}"
		echo "Nom ou Adresse du serveur FTP:"
		echo -e "Dans la plupart des cas, l'IP vous évitera\ndes problèmes de résolution des noms de machines."
		echo -e "Quel est le nom ou IP du serveur? ${COLSAISIE}\c"
		read SERVEUR

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "${COLTXT}"
			echo -e "S'agit-t-il d'un FTP anonyme (${COLCHOIX}1${COLTXT}) ou faut-il un compte/mot de passe (${COLCHOIX}2${COLTXT})? ${COLSAISIE}\c"
			read REPONSE
		done

		if [ "$REPONSE" = "2" ]; then
			echo -e "${COLTXT}"
			echo -e "Veuillez saisir le nom du login: ${COLSAISIE}\c"
			read NOMLOGIN

			echo -e "${COLTXT}"
			echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
			read MOTDEPASSE
			echo -e "\033[0;39m                                                                                "

			echo -e "${COLTXT}"
			echo "Création du point de montage:"
			echo -e "${COLCMD}"
			echo "mkdir -p $PTMNTSTOCK"
			mkdir -p $PTMNTSTOCK
			echo -e "${COLTXT}"
			echo "Montage du partage:"
			echo -e "${COLCMD}\c"

			#echo "lufsmount ftpfs://${NOMLOGIN}:XXXXXX@${SERVEUR} $PTMNTSTOCK"
			#lufsmount ftpfs://${NOMLOGIN}:${MOTDEPASSE}@${SERVEUR} $PTMNTSTOCK||ERREUR "Le montage a échoué!"
			echo "lufis fs=ftpfs,host=${SERVEUR},username=${NOMLOGIN},password=XXXXXX ${PTMNTSTOCK} -s"
			lufis fs=ftpfs,host=${SERVEUR},username=${NOMLOGIN},password=${MOTDEPASSE} ${PTMNTSTOCK} -s||ERREUR "Le montage a échoué!"
			echo ""
		else

			echo -e "${COLTXT}"
			echo "Création du point de montage:"
			echo -e "${COLCMD}"
			echo "mkdir -p $PTMNTSTOCK"
			mkdir -p $PTMNTSTOCK
			echo -e "${COLTXT}"
			echo "Montage du partage:"
			echo -e "${COLCMD}\c"

			#echo "lufsmount ftpfs://${SERVEUR} $PTMNTSTOCK"
			#lufsmount ftpfs://${SERVEUR} $PTMNTSTOCK||ERREUR "Le montage a échoué!"
			echo "lufis fs=ftpfs,host=${SERVEUR} ${PTMNTSTOCK} -s"
			lufis fs=ftpfs,host=${SERVEUR} ${PTMNTSTOCK} -s||ERREUR "Le montage a échoué!"
			echo ""
		fi

		#PART_CIBLE="ftpfs://${SERVEUR}"

		if mount | grep ${PTMNTSTOCK} > /dev/null; then
			echo -e "${COLTXT}Voici ce qui est monté en ${PTMNTSTOCK}"
			echo -e "${COLCMD}\c"
			mount | grep ${PTMNTSTOCK}
		else
			echo -e "${COLERREUR}Il semble que rien ne soit monté en ${PTMNTSTOCK}"

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Voulez-vous poursuivre néanmoins? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				read REPONSE
			done

			if [ "$REPONSE" != "o" ]; then
				ERREUR "Vous n'avez pas souhaité poursuivre."
			fi
		fi

		echo -e "${COLTXT}"
		echo "Appuyez sur ENTREE pour poursuivre..."
		read PAUSE

		CHEMINSOURCE="ftpfs://${SERVEUR}"

		;;
	*)
		ERREUR "La source de restauration semble incorrecte."
	;;
esac




#============================================================================================
# Repenser le script pour afficher les sauvegardes disponibles
# (et choisir la sauvegarde?),
# avant de choisir le type de la sauvegarde.

echo -e "$COLPARTIE"
echo "======================="
echo " Type de la sauvegarde "
echo "======================="

echo -e "$COLINFO"
echo -e "Les sauvegardes ont pu être effectuées à divers formats:"
echo -e "${COLTXT}\c"
#echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions, mais encore instable"
#echo -e "                si le noyau Linux utilisé est en version 2.6.x"
echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions."
echo -e "                  (mais sauvegarde ext4 non supporté)"
echo -e " (${COLCHOIX}2${COLTXT}) dar: pour les partitions non-NTFS quel que soit le noyau Linux."
echo -e " (${COLCHOIX}3${COLTXT}) ntfsclone: pour les partitions NTFS quel que soit le noyau Linux."
echo -e " (${COLCHOIX}4${COLTXT}) FsArchiver: pour toutes les partitions"
echo -e "                  (support NTFS:"
echo -e "                   http://www.fsarchiver.org/Cloning-ntfs"
echo -e "                   fsarchiver permet de restaurer vers"
echo -e "                   une partition plus petite que l'originale)."

#echo -e "${COLTXT}"
#echo -e "Voici le noyau actuellement utilisé:"
#echo -e "${COLCMD}\c"
#cat /proc/version

# TESTER ls -t -1|egrep "(000$|ntfs$||)"|head -n1 pour identifier le type du fichier le plus récent.
# Pb dans le cas de la sauvegarde de la partition de boot en plus au format partimage.

FORMAT_DEFAUT=1

fich_test_svg=$(ls -t -1 $PTMNTSTOCK/oscar/ $PTMNTSTOCK/ $PTMNTSTOCK/sauv*/ $PTMNTSTOCK/sav*/ $PTMNTSTOCK/home/sauv*/ 2> /dev/null|egrep "(\.000$|\.ntfs$|\.ntfsaa$|1\.dar|\.fsa)"|head -n1)
if [ -n "$fich_test_svg" ]; then
	t1=$(echo "$fich_test_svg"|grep "\.000$")
	t2=$(echo "$fich_test_svg"|grep "\.ntfs$")
	t3=$(echo "$fich_test_svg"|grep "\.ntfsaa$")
	t4=$(echo "$fich_test_svg"|grep "\.dar")
	t5=$(echo "$fich_test_svg"|grep "\.fsa")
	if [ -n "$t1" ]; then
		FORMAT_DEFAUT=1
	elif [ -n "$t2" ]; then
		FORMAT_DEFAUT=3
	elif [ -n "$t3" ]; then
		FORMAT_DEFAUT=3
	elif [ -n "$t4" ]; then
		FORMAT_DEFAUT=2
	elif [ -n "$t5" ]; then
		FORMAT_DEFAUT=4
	fi
fi

#NOM_IMAGE_DEFAUT="image.partimage"
#SUFFIXE_SVG="000"
# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
# 000, 001, 002,...

#NOM_IMAGE_DEFAUT="image_dar"
#SUFFIXE_SVG="1.dar"
# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
# 1.dar, 2.dar, 3.dar,...

#NOM_IMAGE_DEFAUT="image"
#SUFFIXE_SVG="ntfs"
# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
# .ntfsaa, .ntfsab, .ntfsac, .ntfsad,...

#NOM_IMAGE_DEFAUT="image.FsArchiver"
#SUFFIXE_SVG="fsa"

#FORMAT_DEFAUT=1
FORMAT_SVG=""
while [ "$FORMAT_SVG" != "1" -a "$FORMAT_SVG" != "2" -a "$FORMAT_SVG" != "3" -a "$FORMAT_SVG" != "4" ]
do
	echo -e "${COLTXT}"
	echo -e "Quel est le format de sauvegarde à restaurer? [${COLDEFAUT}${FORMAT_DEFAUT}${COLTXT}] ${COLSAISIE}\c"
	read FORMAT_SVG


	if [ -z "$FORMAT_SVG" ]; then
		FORMAT_SVG=${FORMAT_DEFAUT}
	fi
done

if [ "$FORMAT_SVG" = "2" ]; then
	echo -e "$COLINFO"
	echo "La restauration d'une sauvegarde 'dar' nécessite de monter"
	echo "la partition /dev/$CHOIX_CIBLE"
	echo "Le type du système de fichier doit donc être précisé."
	echo "Cela peut-être: vfat, ext2, ext3 ou ext4."

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "${COLTXT}"
		echo -e "Quel est le type de la partition?"
		DETECTED_TYPE=$(TYPE_PART $CHOIX_CIBLE)
		if [ ! -z "${DETECTED_TYPE}" ]; then
			echo -e "Type: [${COLDEFAUT}${DETECTED_TYPE}${COLTXT}] ${COLSAISIE}\c"
			read TYPE_FS

			if [ -z "$TYPE_FS" ]; then
				TYPE_FS=${DETECTED_TYPE}
			fi
		else
			echo -e "Type: ${COLSAISIE}\c"
			read TYPE_FS
		fi

		echo -e "${COLTXT}"
		echo -e "Tentative de montage..."
		echo -e "${COLCMD}"
		mkdir -p /mnt/$CHOIX_CIBLE
		if [ ! -z "$TYPE_FS" ]; then
			mount -t $TYPE_FS /dev/$CHOIX_CIBLE /mnt/$CHOIX_CIBLE
		else
			mount /dev/$CHOIX_CIBLE /mnt/$CHOIX_CIBLE
		fi
		umount /mnt/$CHOIX_CIBLE


		echo -e "${COLTXT}"
		echo "Si aucune erreur n'est affichée, le type doit convenir..."

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "${COLTXT}"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? ${COLSAISIE}\c"
			read REPONSE
		done
	done

fi

case $FORMAT_SVG in
	1)
		NOM_IMAGE_DEFAUT="image.partimage"
		SUFFIXE_SVG="000"
		# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
		# 000, 001, 002,...
	;;
	2)
		NOM_IMAGE_DEFAUT="image_dar"
		#SUFFIXE_SVG="dar"
		SUFFIXE_SVG="1.dar"
		# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
		# 1.dar, 2.dar, 3.dar,...
	;;
	3)
		NOM_IMAGE_DEFAUT="image"
		SUFFIXE_SVG="ntfs"
		# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
		# .ntfsaa, .ntfsab, .ntfsac, .ntfsad,...
	;;
	4)
		NOM_IMAGE_DEFAUT="image.FsArchiver"
		SUFFIXE_SVG="fsa"
		# Si l'image est scindee en morceaux, les suffixes des morceaux seront:
		# .fsa, .f01, .f02, .f03,...
	;;
esac
#============================================================================================





echo -e "$COLPARTIE"
echo "============================"
echo "Choix de l'image à restaurer"
echo "============================"

valtest=1
while [ "$valtest" = "1" ]
do
	echo -e "${COLTXT}"
	echo -e "Les images seront trouvées si elles sont situées à la racine de $PTMNTSTOCK\nou directement dans un sous-dossier 'sauv...', 'sav...', 'oscar'."
	echo -e "${COLCMD}\c"

	date_tmp_liste_images=$(date +%Y%m%d%H%M%S)
	#ls -1 $PTMNTSTOCK/*.$SUFFIXE_SVG $PTMNTSTOCK/sauv*/*.$SUFFIXE_SVG $PTMNTSTOCK/sav*/*.$SUFFIXE_SVG $PTMNTSTOCK/home/sauv*/*.$SUFFIXE_SVG $PTMNTSTOCK/oscar/*.$SUFFIXE_SVG > /tmp/liste_${date_tmp_liste_images}.txt 2> /dev/null
	ls -1t $PTMNTSTOCK/oscar/*.$SUFFIXE_SVG $PTMNTSTOCK/*.$SUFFIXE_SVG $PTMNTSTOCK/sauv*/*.$SUFFIXE_SVG $PTMNTSTOCK/sav*/*.$SUFFIXE_SVG $PTMNTSTOCK/home/sauv*/*.$SUFFIXE_SVG > /tmp/liste_${date_tmp_liste_images}.txt 2> /dev/null
	nb=$(cat /tmp/liste_${date_tmp_liste_images}.txt | wc -l)
	if [ "$nb" = "0" ]; then
		echo -e "${COLTXT}\c"
		echo "Aucune image n'a été trouvée dans un des dossiers classiques."
	else
		echo -e "${COLTXT}\c"
		echo -e "Voici les images disponibles:"
		echo -e "${COLCMD}"
		cat /tmp/liste_${date_tmp_liste_images}.txt

		NOM_IMAGE_DEFAUT=$(cat /tmp/liste_${date_tmp_liste_images}.txt | head -n 1 | sed -e "s|^$PTMNTSTOCK/||" | sed -e "s|.$SUFFIXE_SVG$||")
	fi

#	if ls -1 $PTMNTSTOCK/*.$SUFFIXE_SVG > /dev/null; then
#		ls -1 $PTMNTSTOCK/*.$SUFFIXE_SVG
#	fi
#	if ls -1 $PTMNTSTOCK/sauv*/*.$SUFFIXE_SVG > /dev/null; then
#		ls -1 $PTMNTSTOCK/sauv*/*.$SUFFIXE_SVG
#	fi
#	if ls -1 $PTMNTSTOCK/sav*/*.$SUFFIXE_SVG > /dev/null; then
#		ls -1 $PTMNTSTOCK/sav*/*.$SUFFIXE_SVG
#	fi
#	if ls -1 $PTMNTSTOCK/home/sauv*/*.$SUFFIXE_SVG > /dev/null; then
#		ls -1 $PTMNTSTOCK/home/sauv*/*.$SUFFIXE_SVG
#	fi
#	if ls -1 $PTMNTSTOCK/oscar/*.$SUFFIXE_SVG > /dev/null; then
#		ls -1 $PTMNTSTOCK/oscar/*.$SUFFIXE_SVG
#	fi


	echo -e "${COLTXT}"
	echo -e "Voulez-vous effectuer une recherche plus approfondie? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
	read REPONSE

	#if [ "$REPONSE" = "o" ]; then
	#	echo -e "${COLCMD}"
	#	find $PTMNTSTOCK -name *.000
	#fi

	if [ "$REPONSE" = "o" ]; then
		echo -e "${COLCMD}"
		if [ "$FORMAT_SVG" = "3" ]; then
			find $PTMNTSTOCK -name *.$SUFFIXE_SVG*
			# L'image peut être scindée avec split.
		else
			find $PTMNTSTOCK -name *.$SUFFIXE_SVG
		fi
	fi

	if [ "$FORMAT_SVG" = "3" ]; then
		echo -e "$COLINFO"
		echo "Si l'image est scindée en morceaux, les suffixes des morceaux seront:"
		echo "   .ntfsaa, .ntfsab, .ntfsac, .ntfsad,..."
 		echo "Il ne faut pas donner l'extension aa,... à la question ci-dessous."
	fi

	IMAGE=""
	while [ -z "$IMAGE" ]
	do
		echo -e "${COLTXT}"
		echo -e "Quel est le nom de l'image à restaurer? [${COLDEFAUT}${NOM_IMAGE_DEFAUT}.${SUFFIXE_SVG}${COLTXT}]"
		echo -e "IMAGE: ${COLCMD}${PTMNTSTOCK}/${COLSAISIE}\c"
		cd "${PTMNTSTOCK}"
		read -e IMAGE
		cd /root

		if [ -z "$IMAGE" ]; then
			IMAGE="${NOM_IMAGE_DEFAUT}.${SUFFIXE_SVG}"
		fi

		TEMOIN_ECHEC=""
		#PREFIMAGE=$(echo "$IMAGE" | sed -e "s|.000$|.txt|")
		PREFIMAGE=$(echo "$IMAGE" | sed -e "s|.${SUFFIXE_SVG}$||")
		if [ -e "${PTMNTSTOCK}/$PREFIMAGE.SUCCES.txt" ]; then
			echo -e "${COLTXT}"
			echo "Un témoin de succès a été renseigné lors de la sauvegarde réalisation"
			echo "de cette sauvegarde."
		else
			if [ -e "${PTMNTSTOCK}/$PREFIMAGE.ECHEC.txt" ]; then
				echo -e "${COLERREUR}"
				echo "Un témoin d'échec a été renseigné lors de la sauvegarde réalisation"
				echo "de cette sauvegarde."
				TEMOIN_ECHEC="y"
				IMAGE=""
			fi
		fi

		#if [ -e "${PTMNTSTOCK}/$PREFIMAGE.txt" ]; then
		if [ -e "${PTMNTSTOCK}/$PREFIMAGE.txt" -a -z "$TEMOIN_ECHEC" ]; then
			echo -e "${COLTXT}"
			echo "Voici le contenu de $PREFIMAGE.txt"
			echo -e "${COLCMD}"
			cat ${PTMNTSTOCK}/$PREFIMAGE.txt

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Peut-on poursuivre (${COLCHOIX}o${COLTXT}) ou préférez-vous changer d image (${COLCHOIX}n${COLTXT})? ${COLSAISIE}\c"
				read REPONSE
			done

			if [ "$REPONSE" = "n" ]; then
				IMAGE=""
			fi
		fi

	done

	valtest=2

	#if [ ! -e "${PTMNTSTOCK}/${IMAGE}" ]; then
	if [ ! -e "${PTMNTSTOCK}/${IMAGE}" -a ! -e "${PTMNTSTOCK}/${IMAGE}aa" ]; then
		echo -e "${COLTXT}"
		echo -e "L'image ${COLERREUR}${PTMNTSTOCK}/${IMAGE}${COLTXT} n'a pas été trouvée."
		echo "Vous avez peut-être fait une faute de frappe."
		valtest=1

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "${COLTXT}"
			echo -e "Voulez-vous refaire le choix de l'image (${COLCHOIX}1${COLTXT}) ou abandonner (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="1"
			fi
		done

		if [ "$REPONSE" != "1" ]; then
			ERREUR "Vous n'avez pas souhaité poursuivre."
		fi
	fi
done


TMP_CHEMIN_IMAGE="$PTMNTSTOCK/$IMAGE"
NB_AVEC_SLASH=$(echo ${TMP_CHEMIN_IMAGE} | wc -m)
NB_SANS_SLASH=$(echo ${TMP_CHEMIN_IMAGE} | sed -e "s|/||g" | wc -m)
NB_SLASH=$(($NB_AVEC_SLASH-$NB_SANS_SLASH))
DOSSIER_CONTENANT_IMAGE=$(echo ${TMP_CHEMIN_IMAGE} | cut -d"/" -f1-$NB_SLASH)

if [ -e "${DOSSIER_CONTENANT_IMAGE}/${HD}_premiers_MO.bin" ]; then
	echo -e "$COLERREUR"
	echo -e "EXPERIMENTAL:$COLINFO"
	echo "Les premiers Mo du disque dur $HD ont été sauvegardés."

	echo "Il semble necessaire de les restaurer dans le cas d'une restauration"
	echo "de Window$ Seven ou peut-etre avec un BIOS UEFI."
	echo "Des choses semblent cachées entre le MBR et la première partition."
	echo ""
	if [ -e "${DOSSIER_CONTENANT_IMAGE}/${HD}.out" ]; then
		echo "Si vous choisissez de restaurer ces premiers Mo, la table de partition"
		echo "sera aussi refaite d apres la sauvegarde."
	fi

	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous les restaurer? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
		read REP
	done

	if [ "$REP" = "o" ]; then
		echo -e "$COLTXT"
		echo "Restauration des premiers Mo du disque."
		echo -e "$COLCMD"
		dd if="${DOSSIER_CONTENANT_IMAGE}/${HD}_premiers_MO.bin" of=/dev/${HD} bs=1M count=5
		sleep 2
		partprobe /dev/${HD}
		sleep 1
		restauration_debut_dd="o"
	fi
fi

if [ -e "${DOSSIER_CONTENANT_IMAGE}/${HD}.out" ]; then
	echo -e "${COLTXT}"
	echo "Test de différences de table de partition..."
	echo -e "${COLCMD}\c"
	if grep "# partition table of " ${DOSSIER_CONTENANT_IMAGE}/${HD}.out > /dev/null; then

		tmp_date=$(date +%Y%m%d%H%M%S)
		sfdisk -d /dev/${HD} > /tmp/${HD}.${tmp_date}.out
		test_diff=$(diff -abB /tmp/${HD}.${tmp_date}.out ${DOSSIER_CONTENANT_IMAGE}/${HD}.out)
		if [ ! -z "${test_diff}" -o "$restauration_debut_dd" = "o" ]; then

			echo -e "$COLPARTIE"
			echo "==============="
			echo "Partitionnement"
			echo "==============="
			#echo ""

			echo -e "${COLTXT}"
			echo "Le dossier ${DOSSIER_CONTENANT_IMAGE} contient un fichier ${HD}.out"
			echo "En voici le contenu:"
			echo -e "${COLCMD}\c"
			cat ${DOSSIER_CONTENANT_IMAGE}/${HD}.out

			if [ "$restauration_debut_dd" != "o" ]; then
				POURSUIVRE "o"
			else
				sleep 3
			fi

			echo -e "${COLTXT}"
			echo "Et voici le partitionnement actuel du disque:"
			echo -e "${COLCMD}\c"
			#cat /tmp/${HD}.$(date +%Y%m%d%H%M%S).out
			cat /tmp/${HD}.${tmp_date}.out

			REPONSE=""
			if [ "$restauration_debut_dd" = "o" ]; then
				REPONSE="o"
			fi
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Voulez-vous restaurer la table de partition"
				echo -e "comme indiqué dans le fichier de sauvegarde? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				read REPONSE
			done

			if [ "$REPONSE" = "o" ]; then
				echo -e "${COLTXT}"
				echo "Restauration de la table de partition de ${HD} d'après le fichier"
				echo "${DOSSIER_CONTENANT_IMAGE}/${HD}.out"
				echo -e "${COLCMD}\c"
				sfdisk /dev/${HD} < ${DOSSIER_CONTENANT_IMAGE}/${HD}.out

				if [ "$?" != "0" ]; then
					echo -e "$COLERREUR"
					echo "Une erreur s'est semble-t-il produite."
					REPONSE=""
					if [ "$restauration_debut_dd" = "o" ]; then
						REPONSE="o"
					fi
					while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
					do
						echo -e "${COLTXT}"
						echo -e "Voulez-vous forcer le repartitionnement avec l'option -f de sfdisk? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
						read REPONSE
					done

					echo -e "${COLCMD}"
					if [ "$REPONSE" = "o" ]; then
						ladate=$(date +%Y%m%d%H%M%S)
						sfdisk -f /dev/${HD} < ${DOSSIER_CONTENANT_IMAGE}/${HD}.out > /tmp/repartitionnement_${ladate}.txt 2>&1
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

				POURSUIVRE
			fi
		fi
	else
		echo -e "${COLTXT}... pas de différence."
	fi
elif [ -e "${DOSSIER_CONTENANT_IMAGE}/gpt_${HD}.out" ]; then
	echo -e "${COLTXT}"
	echo "Test de différences de table de partition..."
	echo -e "${COLCMD}\c"

	tmp_date=$(date +%Y%m%d%H%M%S)
	echo "sgdisk -b /tmp/gpt_$HD.${tmp_date}.out /dev/$HD"
	sgdisk -b /tmp/gpt_$HD.${tmp_date}.out /dev/$HD
	test_diff=$(diff -abB /tmp/gpt_${HD}.${tmp_date}.out ${DOSSIER_CONTENANT_IMAGE}/gpt_${HD}.out)
	if [ ! -z "${test_diff}" -o "$restauration_debut_dd" = "o" ]; then

		echo -e "$COLPARTIE"
		echo "==============="
		echo "Partitionnement"
		echo "==============="
		#echo ""

		echo -e "${COLTXT}"
		echo "La table de partitions a semble-t-il change."

		REPONSE=""
		if [ "$restauration_debut_dd" = "o" ]; then
			REPONSE="o"
		fi
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Voulez-vous restaurer la table de partition"
			echo -e "comme indiqué dans le fichier de sauvegarde? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
			read REPONSE
		done

		if [ "$REPONSE" = "o" ]; then
			echo -e "${COLTXT}"
			echo "Restauration de la table de partition de ${HD} d'après le fichier"
			echo "${DOSSIER_CONTENANT_IMAGE}/gpt_${HD}.out"
			echo -e "${COLCMD}\c"
			sgdisk -l ${DOSSIER_CONTENANT_IMAGE}/gpt_${HD}.out /dev/$HD

			if [ "$?" != "0" ]; then
				echo -e "$COLERREUR"
				echo "Une erreur s'est semble-t-il produite."

				#REPONSE=""
				#if [ "$restauration_debut_dd" = "o" ]; then
				#	REPONSE="o"
				#fi
				#while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				#do
				#	echo -e "${COLTXT}"
				#	echo -e "Voulez-vous forcer le repartitionnement avec l'option -f de sfdisk? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				#	read REPONSE
				#done

				#echo -e "${COLCMD}"
				#if [ "$REPONSE" = "o" ]; then
				#	sfdisk -f /dev/${HD} < ${DOSSIER_CONTENANT_IMAGE}/${HD}.out
				#fi
			fi

			POURSUIVRE
		fi
	elif [ -z "${test_diff}" ]; then
		echo -e "${COLINFO}"
		echo "La table de partitions n'a pas change depuis la sauvegarde."
	fi

	#echo -e "${COLTXT}... pas de différence."

fi

if [ -e "$PTMNTSTOCK/${PREFIMAGE}_premiers_MO.bin" ]; then
	echo -e "$COLERREUR"
	echo -e "EXPERIMENTAL:$COLINFO"
	echo "Les premiers Mo de la partition /dev/${CHOIX_CIBLE} ont été sauvegardés."
	echo "Leur restauration n'est normalement pas nécessaire."

	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous les restaurer? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
		read REP

		if [ -z "$REP" ]; then
			REP="n"
		fi
	done

	if [ "$REP" = "o" ]; then
		echo -e "$COLTXT"
		echo "Restauration des premiers Mo de la partition."
		echo -e "$COLCMD"
		dd if="$PTMNTSTOCK/${PREFIMAGE}_premiers_MO.bin" of=/dev/${CHOIX_CIBLE} bs=1M count=5
	fi
fi

echo -e "$COLPARTIE"
echo "============================"
echo "Lancement de la restauration"
echo "============================"
echo ""

echo -e "${COLINFO}RECAPITULATIF:"
echo -e "${COLTXT}"
echo -e "${COLTXT}Partition destination"
echo -e "${COLTXT}(qui sera écrasée) :               ${COLINFO}${PART_CIBLE}"
echo -e "${COLTXT}Source :                           ${COLINFO}${CHEMINSOURCE}"
echo -e "${COLTXT}Point de montage de la source :    ${COLINFO}${PTMNTSTOCK}"
echo -e "${COLTXT}Nom de l'image :                   ${COLINFO}${IMAGE}"

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Peut-on continuer ? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
	read REPONSE
done


if [ "$REPONSE" = "o" ]; then

	if [ "$RESTAURATIONDEPUISCD" = "o" ]; then
		echo -e "${COLTXT}"
		echo "Création du script 'next.sh' pour permettre le changement de CD/DVD."
		echo -e "Son utilisation nécessite que vous ayez booté avec l'option 'docache'\nsi vous ne disposez que d'un lecteur."
		echo "Lorsque l'image suivante sera réclamée:"
		echo " - appuyez sur ALT+F2"
		echo " - tapez 'next.sh' et validez"
		echo " - suivez les instructions qui s'affichent alors"
		echo " - appuyez sur ALT+F1"
		echo " - tapez le chemin demandé dans la boite de dialogue et validez."

		mkdir -p /tmp/bin

		echo "#!/bin/sh" > /tmp/bin/next.sh

		echo 'COLPARTIE="\033[1;34m"' >> /tmp/bin/next.sh
		echo 'COLINFO="\033[0;33m"' >> /tmp/bin/next.sh
		echo 'COLTITRE="\033[1;35m"' >> /tmp/bin/next.sh
		echo 'COLTXT="\033[0;37m"' >> /tmp/bin/next.sh
		echo 'COLCMD="\033[1;37m"' >> /tmp/bin/next.sh
		echo 'COLSAISIE="\033[1;32m"' >> /tmp/bin/next.sh
		echo 'COLERREUR="\033[1;31m"' >> /tmp/bin/next.sh

		echo 'echo -e "$COLPARTIE"' >> /tmp/bin/next.sh
		echo 'echo "Ejection du CD/DVD"' >> /tmp/bin/next.sh
		echo 'echo -e "${COLCMD}"' >> /tmp/bin/next.sh
		echo "eject $PTMNTSTOCK" >> /tmp/bin/next.sh
		echo 'echo -e "${COLTXT}"' >> /tmp/bin/next.sh
		echo 'echo "Insérez le CD/DVD suivant et validez avec ENTREE"' >> /tmp/bin/next.sh
		echo 'read PAUSE' >> /tmp/bin/next.sh
		echo 'echo -e "${COLCMD}"' >> /tmp/bin/next.sh
		echo "mount -t iso9660 $SOURCE $PTMNTSTOCK" >> /tmp/bin/next.sh
		echo 'echo -e "${COLTITRE}"' >> /tmp/bin/next.sh
		echo 'echo "Vous pouvez rebasculer vers la console initiale pour poursuivre la restauration."' >> /tmp/bin/next.sh
		echo 'echo -e "${COLTXT}"' >> /tmp/bin/next.sh

		chmod +x /tmp/bin/next.sh

		export PATH=$PATH:/tmp/bin

		echo "Appuyez sur ENTREE pour continuer."
		read PAUSE
	fi

	t1=$(date +%s)
	t2=""
	#sleep 1
	#partimage -f0 -b -w restore $PART_CIBLE $PTMNTSTOCK/$IMAGE
	case $FORMAT_SVG in
		1)
			echo -e "$COLINFO"
			echo "Lancement de la restauration..."
			sleep 1
			echo -e "${COLCMD}"
			partimage -f0 -b -w restore $PART_CIBLE $PTMNTSTOCK/$IMAGE
		;;
		2)
			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Voulez-vous vider la partition avant de lancer la restauration? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
				read REPONSE
			done

			echo -e "${COLTXT}"
			echo -e "Montage de la partition..."
			echo -e "${COLCMD}\c"
			mkdir -p /mnt/$CHOIX_CIBLE
			if [ ! -z "$TYPE_FS" ]; then
				mount -t $TYPE_FS /dev/$CHOIX_CIBLE /mnt/$CHOIX_CIBLE
			else
				mount /dev/$CHOIX_CIBLE /mnt/$CHOIX_CIBLE
			fi

			if [ "$REPONSE" = "o" ]; then
				echo -e "${COLTXT}"
				echo -e "Suppression du contenu de la partition avant restauration..."
				echo -e "${COLCMD}"
				rm -fr /mnt/$CHOIX_CIBLE/*
			fi

			echo -e "$COLINFO"
			echo "Lancement de la restauration..."
			echo -e "${COLCMD}\c"
			sleep 1
			$chemin_dar/dar -x $PTMNTSTOCK/$PREFIMAGE -R /mnt/$CHOIX_CIBLE -b -wa -v
		;;
		3)
			#if [ -e ${PTMNTSTOCK}/$IMAGE.type_compression.txt ]; then
			if [ -e ${PTMNTSTOCK}/$PREFIMAGE.type_compression.txt ]; then
				#TYPE_COMPRESS=$(cat ${PTMNTSTOCK}/$IMAGE.type_compression.txt)
				TYPE_COMPRESS=$(cat ${PTMNTSTOCK}/$PREFIMAGE.type_compression.txt)
			else
				if [ -e "${PTMNTSTOCK}/$IMAGE" ]; then
					if file ${PTMNTSTOCK}/$IMAGE | grep "gzip compressed data" > /dev/null; then
						TYPE_COMPRESS="gzip"
					else
						if file ${PTMNTSTOCK}/$IMAGE | grep "bzip2 compressed data" > /dev/null; then
							TYPE_COMPRESS="bzip2"
						else
							echo -e "$COLINFO"
							echo -e "Le mode de compression n'a pas été identifié..."

							echo -e "${COLTXT}"
							echo "La sauvegarde peut:"
							echo -e " - ne pas être compressée: ${COLCHOIX}${COLTXT} (laisser vide)"
							echo -e " - être gzippée: ${COLCHOIX}gzip${COLTXT}"
							echo -e " - être bzippée: ${COLCHOIX}bzip2${COLTXT}"
							echo -e "${COLTXT}"
							echo -e "Quel est le type de compression de la sauvegarde? ${COLSAISIE}\c"
							# Si la sauvegarde n'est pas en morceaux, on doit pouvoir l'identifier avec 'file'.
							read TYPE_COMPRESS
						fi
					fi
				else
					if file ${PTMNTSTOCK}/${IMAGE}aa | grep "gzip compressed data" > /dev/null; then
						TYPE_COMPRESS="gzip"
					else
						if file ${PTMNTSTOCK}/${IMAGE}aa | grep "bzip2 compressed data" > /dev/null; then
							TYPE_COMPRESS="bzip2"
						else
							echo -e "$COLINFO"
							echo -e "Le mode de compression n'a pas été identifié..."

							echo -e "${COLTXT}"
							echo "La sauvegarde peut:"
							echo -e " - ne pas être compressée: ${COLCHOIX}${COLTXT} (laisser vide)"
							echo -e " - être gzippée: ${COLCHOIX}gzip${COLTXT}"
							echo -e " - être bzippée: ${COLCHOIX}bzip2${COLTXT}"
							echo -e "${COLTXT}"
							echo -e "Quel est le type de compression de la sauvegarde? ${COLSAISIE}\c"
							# Si la sauvegarde n'est pas en morceaux, on doit pouvoir l'identifier avec 'file'.
							read TYPE_COMPRESS
						fi
					fi
				fi
			fi

			if [ -z "$TYPE_COMPRESS" ]; then
				TYPE_COMPRESS="aucune"
			fi

			echo -e "$COLINFO"
			echo "Lancement de la restauration..."
			sleep 1
			echo -e "${COLCMD}"
			case $TYPE_COMPRESS in
				"aucune")
					#cat ${PTMNTSTOCK}/$IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$CHOIX_CIBLE -
					cat ${PTMNTSTOCK}/$IMAGE* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$CHOIX_CIBLE -
				;;
				"gzip")
					#cat ${PTMNTSTOCK}/$IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$CHOIX_CIBLE -
					cat ${PTMNTSTOCK}/$IMAGE* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$CHOIX_CIBLE -
				;;
				"bzip2")
					#cat ${PTMNTSTOCK}/$IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$CHOIX_CIBLE -
					cat ${PTMNTSTOCK}/$IMAGE* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$CHOIX_CIBLE -
				;;
			esac
		;;
		4)
			echo -e "$COLINFO"
			echo "Lancement de la restauration..."
			sleep 1
			echo -e "${COLCMD}"
			fsarchiver -v restfs $PTMNTSTOCK/$IMAGE id=0,dest=$PART_CIBLE
		;;
	esac

	if [ "$?" != "0" ]; then
		ERREUR "La restauration a échoué.\nIl arrive sur des partitions ext2 qu un ext2fs -p -y /dev/hdaX soit nécessaire."
	else
		echo -e "${COLTXT}"
		#echo -e "La restauration a réussi.\nLe script va se poursuivre après 5 secondes."
		echo -e "La restauration a réussi."

		t2=$(date +%s)
		duree_rest=$(CALCULE_DUREE $t1 $t2)
		echo -e "${COLTXT}Duree: ${COLINFO}${duree_rest}${COLTXT}"

		#sleep 5
		COMPTE_A_REBOURS "Le script va poursuivre dans" 5 "secondes."
	fi
else
	ERREUR "Vous avez souhaité annuler la restauration."
fi

#clear
echo -e "$COLPARTIE"
echo -e "Restauration terminée!"

echo -e "$COLINFO"
echo "Si le secteur de boot comportait un chargeur de démarrage LILO et que le Linux"
echo "n'est plus présent, il faut penser à 'nettoyer' le secteur de boot."
REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Faut-il 'nettoyer' le secteur de boot? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	echo -e "${COLTXT}"
	echo "Nettoyage du secteur de boot."
	echo -e "${COLCMD}\c"
	install-mbr /dev/${HD}
fi


echo -e "$COLINFO"
echo "Si un fichier bootsector.bin de sauvegarde du secteur de boot a été créé lors"
echo "de la sauvegarde, vous pouvez le restaurer maintenant."
REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Faut-il restaurer le secteur de boot? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

echo -e "${COLCMD}\c"
if [ "$REPONSE" = "o" ]; then
	if [ -e "${PTMNTSTOCK}/$IMAGE" ]; then
		DOSSIER_SVG=$(dirname "${PTMNTSTOCK}/$IMAGE")
	else
		if [ -e "${PTMNTSTOCK}/$PREFIMAGE.type_compression.txt" ]; then
			DOSSIER_SVG=$(dirname "${PTMNTSTOCK}/$PREFIMAGE.type_compression.txt")
		else
			echo -e "${COLTXT}"
			echo -e "Où se trouve le fichier bootsector.bin à restaurer?"
			echo -e "Chemin: ${COLINFO}${PTMNTSTOCK}/${COLSAISIE}\c"
			cd ${PTMNTSTOCK}
			read -e DOSSIER_SVG

			DOSSIER_SVG="${PTMNTSTOCK}/$DOSSIER_SVG"
		fi
	fi

	echo -e "${COLCMD}"
	if [ ! -z "$DOSSIER_SVG" -a -e "$DOSSIER_SVG/bootsector.bin" ]; then
		echo -e "$COLINFO"
		echo -e "La partition de boot est (s'il n'y a pas eu de changement) la partition active."

		echo -e "${COLTXT}"
		echo -e "Les partitions définies sont les suivantes:"
		echo -e "${COLCMD}\c"
		#fdisk -l /dev/${HD}
		LISTE_PART ${HD} afficher_liste=y

		echo -e "${COLTXT}"
		echo -e "Sur quelle partition s'effectue le boot? [${COLDEFAUT}${HD}1${COLTXT}] ${COLSAISIE}\c"
		read PARTBOOT

		if [ -z "$PARTBOOT" ]; then
			PARTBOOT=${HD}1
		fi

		echo -e "${COLTXT}"
		echo -e "Restauration du secteur de boot..."
		echo -e "${COLCMD}\c"
		dd if=$DOSSIER_SVG/bootsector.bin of=/dev/${PARTBOOT} bs=512 count=1
	else
		echo -e "${COLTXT}"
		echo -e "Le ${COLINFO}bootsector.bin${COLTXT} n'a pas été trouvé dans ${COLINFO}${DOSSIER_SVG}/"
	fi
fi

NUM_PART=$(CHECK_PART_ACTIVE)
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
		parted -s /dev/${HD} toggle ${NUM_PART} boot
		echo -e "$COLTXT"
		echo "Nouvel etat:"
		echo -e "$COLCMD\c"
		parted -s /dev/${HD} print
	fi

	#echo -e "Appuyez sur ENTREE pour quitter..."
	#read PAUSE
fi

echo -e "${COLTXT}"
echo -e "Démontage de $PTMNTSTOCK"
echo -e "${COLCMD}"
umount $PTMNTSTOCK

echo -e "${COLTITRE}"
echo "********"
echo "Terminé!"
echo "********"
echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour finir."
read PAUSE
exit 0


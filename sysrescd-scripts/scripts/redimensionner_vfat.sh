#!/bin/bash

# Script destiné à effectuer le redimensionnement de partition FAT32
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 24/06/2013

# **********************************
# Version adaptée à System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

# Chemin vers les programmes dar
chemin_dar="/usr/bin"

datetemp=$(date '+%Y%m%d-%H%M%S')

echo -e "$COLTITRE"
echo "*******************************"
echo "* Script de redimensionnement *"
echo "*     de partition FAT32      *"
echo "*******************************"

echo -e "$COLINFO"
echo "Le redimensionnement de partition FAT32 avec parted pose des problèmes"
echo "(sur lesquels les développeurs travaillent)."
echo "En attendant, une solution consiste à:"
echo "   - sauvegarder le contenu de la partition FAT32,"
echo "   - supprimer la partition,"
echo "   - la recréer avec une taille plus petite,"
echo "   - restaurer les données sauvegardées plus haut."
echo "Comme partimage ne permet pas de restaurer les données vers une partition"
echo "plus petite, c'est avec dar (un tar amélioré) que l'opération de"
echo "sauvegarde/restauration est effectuée."

echo -e "${COLERREUR}ATTENTION:${COLTXT} Ce script est encore expérimental."
echo "           Il se peut qu'il reste des bugs sévères."

echo -e "${COLERREUR}EXPERIMENTAL:${COLTXT} Lors de mes tests, il a généralement"
echo "              fallu booter sur une disquette W98 (ou w98 sur le multiboot)"
echo "              et lancer un 'sys C:' pour permettre au système de booter."

POURSUIVRE "o"



echo -e "$COLPARTIE"
echo "======================================"
echo "Choix de la partition à redimensionner"
echo "======================================"

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

echo -e "$COLTXT"
echo "Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD\c"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
LISTE_PART ${HD} afficher_liste=y avec_tableau_liste=y
if [ ! -z "${liste_tmp[0]}" ]; then
	DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
else
	DEFAULTPART="hda1"
fi

echo -e "$COLTXT"
echo -e "Quelle est la partition à redimensionner ? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
read CHOIX_SOURCE

if [ -z "$CHOIX_SOURCE" ]; then
	CHOIX_SOURCE="${DEFAULTPART}"
fi

PART_SOURCE="/dev/$CHOIX_SOURCE"


echo -e "$COLPARTIE"
echo "============================"
echo "Destination de la sauvegarde"
echo "============================"

echo -e "$COLINFO"
echo "Avant de détruire/recréer la partition, nous allons en sauvegarder le"
echo "contenu pour le restaurer ensuite."

REPONSE=""
while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
do
	echo -e "$COLTXT"
	echo "Souhaitez vous effectuer?"
	echo -e "     (${COLCHOIX}1${COLTXT}) une sauvegarde vers une partition locale,"
	echo -e "     (${COLCHOIX}2${COLTXT}) une sauvegarde vers un partage Samba/win."
	echo -e "     (${COLCHOIX}3${COLTXT}) une sauvegarde vers un serveur FTP."
	echo -e "Mode choisi: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE=1
	fi
done

case "$REPONSE" in
	1)
		echo -e "$COLPARTIE"
		echo "**********************************************************"
		echo "Vous avez choisi une sauvegarde vers une partition locale."
		echo "**********************************************************"

		echo -e "$COLPARTIE"
		echo "==================================="
		echo " Choix de la partition de stockage "
		echo "         de la sauvegarde          "
		echo "==================================="

		AFFICHHD

		DEFAULTDISK=$(GET_DEFAULT_DISK)

		echo -e "$COLTXT"
		echo -e "Sur quel disque se trouve la partition\nde stockage de la sauvegarde?"
		echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
		echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
		read SAVEHD

		if [ -z "$SAVEHD" ]; then
			SAVEHD=${DEFAULTDISK}
		fi

		echo -e "$COLTXT"
		echo "La partition de destination ne doit pas être de type NTFS (ni Linux SWAP)."
		echo "Voici la/les partition(s) susceptibles de convenir:"
		echo -e "$COLCMD"
		#fdisk -l /dev/$SAVEHD | grep "/dev/${SAVEHD}[0-9]" | grep -v NTFS | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility"
		#liste_tmp=($(fdisk -l /dev/$SAVEHD | grep "^/dev/$SAVEHD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v NTFS | grep -v "Dell Utility"))
		LISTE_PART ${SAVEHD} afficher_liste=y avec_tableau_liste=y type_part_cherche=non_ntfs
		if [ ! -z "${liste_tmp[0]}" ]; then
			# Avec ${liste_tmp[0]} on ne récupère que le '/dev/sda1' sans la suite des infos données par le fdisk
			# L'espace est dans les séparateurs pris en compte dans $IFS
			#DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")

			# Plus propre quand même:
			DEFAULTPART=$(echo ${liste_tmp[0]} | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||")
		else
			DEFAULTPART="hda1"
		fi

		echo -e "$COLTXT"
		#echo -e "Quelle est la partition destination? [${COLDEFAUT}hda5${COLTXT}] $COLSAISIE\c"
		echo -e "Quelle est la partition destination? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
		read CHOIX_DEST

		if [ -z "$CHOIX_DEST" ]; then
			#CHOIX_DEST=hda5
			CHOIX_DEST=$DEFAULTPART
		fi

		PARTSTOCK="/dev/$CHOIX_DEST"
		PTMNTSTOCK="/mnt/$CHOIX_DEST"
		mkdir -p $PTMNTSTOCK

		#if ! fdisk -l /dev/$SAVEHD | grep $PARTSTOCK > /dev/null; then
		t=$(fdisk -s /dev/$PARTSTOCK)
		if [ -z "$t" -o ! -e "/sys/block/$SAVEHD/$PARTSTOCK" ]; then
			echo -e "$COLERREUR"
			echo "ERREUR: La partition proposée n'existe pas!"
			echo -e "$COLTXT"
			read PAUSE
			exit 1
		fi

		echo -e "$COLTXT"
		echo "Quel est le type de la partition $PARTSTOCK?"
		echo "(vfat (pour FAT32), ext2, ext3,...)"
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

		echo -e "$COLCMD\c"
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

		echo -e "$COLTXT"
		echo "L'espace disponible sur cette partition:"
		echo -e "$COLCMD\c"
		df -h | egrep "(Filesystem|$PARTSTOCK)"
	;;

	2)
		echo -e "$COLPARTIE"
		echo "**********************************************************"
		echo "Vous avez choisi une sauvegarde vers un partage samba/win."
		echo "**********************************************************"

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
		do
			echo -e "$COLTXT"
			echo "Il est donc nécessaire d'effectuer la configuration réseau."
			CHOIX=2

			if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
				if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:" > /dev/null; then
					echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
					ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:"
					CHOIX=1
				fi
			else
				if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 " > /dev/null; then
					echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
					ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 "
					CHOIX=1
				fi
			fi

			echo -e "${COLTXT}Si le réseau est OK, tapez       ${COLCHOIX}1${COLTXT}"
			echo -e "Pour configurer le réseau, tapez ${COLCHOIX}2${COLTXT}"
			echo -e "Pour abandonner, tapez           ${COLCHOIX}3${COLTXT}"
			echo -e "Votre choix: [${COLDEFAUT}${CHOIX}${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE=${CHOIX}
			fi
		done

		if [ "$REPONSE" = "3" ]; then
			echo -e "$COLERREUR"
			echo "ABANDON!"
			echo -e "$COLTXT"
			read PAUSE
			exit
		fi

		if [ "$REPONSE" = "2" ]; then
			echo -e "$COLINFO"
			echo "Le script net-setup de SystemRescueCD (depuis la version 0.3.1) pose des"
			echo "problèmes lorsqu'il est lancé sans être passé par une console avant le lancement"
			echo "(cas du lancement via l'autorun)."
			echo "Un script alternatif est proposé, mais il ne permet pas, contrairement au script"
			echo "net-setup officiel, de configurer une interface wifi."
			REPNET=""
			while [ "$REPNET" != "1" -a "$REPNET" != "2" ]
			do
				echo -e "$COLTXT"
				echo -e "Quel script souhaitez-vous utiliser? (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
				read REPNET

				if [ -z "$REPNET" ]; then
					REPNET=2
				fi
			done

			REP="o"
			while [ "$REP" = "o" ]
			do
				echo -e "$COLCMD"
				#SysRescCD:
				if [ "$REPNET" = "1" ]; then
					net-setup eth0
					iface=eth0
				else
					/bin/net_setup.sh
					iface=$(cat /tmp/iface.txt)
				fi
				#Puppy:
				#net-setup.sh

				echo -e "$COLTXT"
				echo "Voici la config IP:"
				echo -e "$COLCMD\c"
				if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
					echo "ifconfig $iface | grep inet | grep -v \"inet6 addr:\""
					ifconfig $iface | grep inet | grep -v "inet6 addr:"
				else
					echo "ifconfig $iface | grep inet | grep -v \"inet6 \""
					ifconfig $iface | grep inet | grep -v "inet6 "
				fi

				echo -e "$COLTXT"
				echo -e "Voulez-vous corriger/modifier cette configuration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
				read REP

				if [ -z "$REP" ]; then
					REP="n"
				fi
			done
		fi

		echo -e "$COLTXT"
		echo -e "Quelle est l'adresse IP du serveur? $COLSAISIE\c"
		read IP

		if grep "^$IP " /etc/hosts > /dev/null; then
			DEFNOMNETBIOS=$(grep "^$IP " /etc/hosts | cut -d" " -f2)

			echo -e "$COLTXT"
			echo -e "Quel est le nom NETBIOS du serveur? [${COLDEFAUT}${DEFNOMNETBIOS}${COLTXT}] $COLSAISIE\c"
			read NOMNETBIOS

			if [ -z "$NOMNETBIOS" ]; then
				NOMNETBIOS=$DEFNOMNETBIOS
			fi
		else
			echo -e "$COLTXT"
			echo -e "Quel est le nom NETBIOS du serveur? $COLSAISIE\c"
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

		echo -e "$COLTXT"
		if ping -c 1 $NOMNETBIOS > /dev/null; then
			echo -e "La machine ${COLINFO}${NOMNETBIOS}${COLTXT} a répondu au ping."
		else
			echo -e "La machine ${COLINFO}${NOMNETBIOS}${COLTXT} n'a pas répondu au ping."
			echo "Si la machine filtre les ping, c'est normal."
			echo "Sinon, vous devriez annuler."
			echo -e "Voulez-vous tout de même poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ "$REPONSE" != "o" ]; then
				ERREUR "Vous n'avez pas souhaité poursuivre."
			fi
		fi

		if [ -e /usr/bin/smbclient -o -e /usr/sbin/smbclient ]; then
			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous rechercher les partages proposés par cette machine? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
				read REPONSE
			done
	
			if [ "$REPONSE" = "o" ]; then
				REPONSE=""
				while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
				do
					echo -e "$COLTXT"
					echo -e "Voulez-vous effectuer la recherche:"
					echo -e "   (${COLCHOIX}1${COLTXT}) en vous identifiant"
					echo -e "   (${COLCHOIX}2${COLTXT}) ou en anonyme (partages publics seulement)"
					echo -e "Votre choix: (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
					read REPONSE
	
					if [ -z "$REPONSE" ]; then
						REPONSE="2"
					fi
				done
	
				if [ "$REPONSE" = "2" ]; then
					echo -e "$COLTXT"
					echo "Voici la liste des partages publics trouvés:"
					echo -e "$COLCMD"
					#smbclient -L $IP -N > /tmp/liste_partages.txt 2> /dev/null
					smbclient -L $IP -N > /tmp/liste_partages.txt
				else
					echo -e "$COLTXT"
					echo -e "Veuillez saisir le nom du login: $COLSAISIE\c"
					read NOMLOGIN
	
					echo -e "$COLTXT"
					echo "Pour afficher la liste des partages visibles par $NOMLOGIN,"
					echo "vous allez devoir fournir un mot de passe:"
					echo -e "$COLCMD\c"
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

		echo -e "$COLTXT"
		echo -e "Quel est le nom du partage sur le serveur? $COLSAISIE\c"
		read PARTAGE

		echo -e "$COLTXT"
		echo -e "Le partage nécessite-t-il un login particulier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read LOGIN

		if [ -z "$LOGIN" ]; then
			LOGIN="n"
		fi

		NOMPRECEDENT="$NOMLOGIN"
		NOMLOGIN=""
		if [ "$LOGIN" = "o" ]; then
			echo -e "$COLTXT"
			if [ -z "$NOMPRECEDENT" ]; then
				echo -e "Veuillez saisir le nom du login: $COLSAISIE\c"
				read NOMLOGIN
			else
				echo -e "Veuillez saisir le nom du login: [${COLDEFAUT}${NOMPRECEDENT}${COLTXT}] $COLSAISIE\c"
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
		echo -e "$COLTXT"
		echo -e "Le partage nécessite-t-il un mot de passe? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${CHOIX}${COLTXT}] $COLSAISIE\c"
		read MDP

		if [ -z "$MDP" ]; then
			MDP="$CHOIX"
		fi

		MOTDEPASSE=""
		if [ "$MDP" = "o" ]; then
			echo -e "$COLTXT"
			echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
			read MOTDEPASSE
			echo -e "\033[0;39m                                                                                "
		fi

		PTMNTSTOCK="/mnt/smb"
		echo -e "$COLTXT"
		echo "Création du point de montage:"
		echo -e "$COLCMD\c"
		echo "mkdir -p ${PTMNTSTOCK}"
		mkdir -p ${PTMNTSTOCK}
		echo -e "$COLTXT"
		echo "Montage du partage:"
		echo -e "$COLCMD\c"

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

		echo -e "$COLCMD\c"
		if mount | grep "//$NOMNETBIOS/$PARTAGE" > /dev/null; then
			umount "//$NOMNETBIOS/$PARTAGE" || ERREUR "//$NOMNETBIOS/$PARTAGE est déjà monté\net n'a pas pu être démonté."
		fi

		if mount | grep "${PTMNTSTOCK}" > /dev/null; then
			#smbumount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
			umount "${PTMNTSTOCK}" || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
		fi

		NOPWOPT=$(echo "$OPTIONS" | sed -e "s/password=$MOTDEPASSE/password=XXXXXX/")
		# BIZARRE: Avec la 0.4.2, j'ai des problèmes pour monter //se3/Progs avec CIFS
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
			#smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS||ERREUR "Le montage a échoué!"
			#smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS
			smbmount //$NOMNETBIOS/$PARTAGE ${PTMNTSTOCK} -o $OPTIONS||ERREUR "Le montage a échoué!"
		fi
		if [ "$?" != "0" ]; then
			#ERREUR "//$NOMNETBIOS/$PARTAGE est déjà monté\net n'a pas pu être démonté."
			echo -e "$COLERREUR"
			echo "ERREUR: Le montage a échoué!"
			#VERIF="PB"
		fi
		echo ""

		PARTSTOCK="//$NOMNETBIOS/$PARTAGE"

		if mount | grep ${PTMNTSTOCK} > /dev/null; then
			echo -e "${COLTXT}Voici ce qui est monté en ${PTMNTSTOCK}"
			echo -e "${COLCMD}\c"
			mount | grep ${PTMNTSTOCK}

			#Test:
			echo -e "${COLTXT}"
			echo "Test d'écriture..."
			echo -e "${COLCMD}\c"
			la_date_de_test=$(date +"%Y.%m.%d-%H.%M.%S");
			if ! echo "Test" > "${PTMNTSTOCK}/$la_date_de_test.txt"; then
				echo -e "$COLERREUR"
				echo "Il semble qu'il ne soit pas possible d'écrire dans ${PTMNTSTOCK}"
				echo "Le partage est peut-être en lecture seule."
				echo "Ou alors vous n'avez pas le droit d'écrire à la racine du partage,"
				echo "mais peut-être avez-vous le droit dans un sous-dossier."

				REPONSE=""
				while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				do
					echo -e "$COLTXT"
					echo -e "Voulez-vous poursuivre néanmoins? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
					read REPONSE

					if [ -z "$REPONSE" ]; then
						REPONSE="n"
					fi
				done

				if [ "$REPONSE" != "o" ]; then
					ERREUR "Vous n'avez pas souhaité poursuivre."
				fi
			else
				echo "OK."
				rm -f "${PTMNTSTOCK}/$la_date_de_test.txt"
			fi
		else
			echo -e "${COLERREUR}Il semble que rien ne soit monté en ${PTMNTSTOCK}"

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous poursuivre néanmoins? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="n"
				fi
			done

			if [ "$REPONSE" != "o" ]; then
				ERREUR "Vous n'avez pas souhaité poursuivre."
			fi
		fi

		;;
	3)
		echo -e "$COLPARTIE"
		echo "****************************************************"
		echo "Vous avez choisi une sauvegarde vers un serveur FTP."
		echo "****************************************************"

		PTMNTSTOCK="/mnt/ftp"
		if mount | grep $PTMNTSTOCK > /dev/null; then
			umount $PTMNTSTOCK || ERREUR "Le point de montage $PTMNTSTOCK est déjà support d'un montage\net n'a pas pu être démonté."
		fi

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
		do
			echo -e "$COLTXT"
			echo "Il est donc nécessaire d'effectuer la configuration réseau."
			CHOIX=2
			if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
				if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:" > /dev/null; then
					echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
					ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:"
					CHOIX=1
				fi
			else
				if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 " > /dev/null; then
					echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
					ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 "
					CHOIX=1
				fi
			fi
			echo -e "${COLTXT}"
			echo -e "Si le réseau est OK, tapez       ${COLCHOIX}1${COLTXT}"
			echo -e "Pour configurer le réseau, tapez ${COLCHOIX}2${COLTXT}"
			echo -e "Pour abandonner, tapez           ${COLCHOIX}3${COLTXT}"
			echo -e "Votre choix: [${COLDEFAUT}${CHOIX}${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE=${CHOIX}
			fi
		done

		if [ "$REPONSE" = "3" ]; then
			echo -e "$COLERREUR"
			echo "ABANDON!"
			echo -e "$COLTXT"
			exit
		fi

		if [ "$REPONSE" = "2" ]; then
			echo -e "$COLINFO"
			echo "Le script net-setup de SystemRescueCD (depuis la version 0.3.1) pose des"
			echo "problèmes lorsqu'il est lancé sans être passé par une console avant le lancement"
			echo "(cas du lancement via l'autorun)."
			echo "Un script alternatif est proposé, mais il ne permet pas, contrairement au script"
			echo "net-setup officiel, de configurer une interface wifi."
			REPNET=""
			while [ "$REPNET" != "1" -a "$REPNET" != "2" ]
			do
				echo -e "$COLTXT"
				echo -e "Quel script souhaitez-vous utiliser? (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
				read REPNET

				if [ -z "$REPNET" ]; then
					REPNET=2
				fi
			done

			REP="o"
			while [ "$REP" = "o" ]
			do
				echo -e "$COLCMD"
				#SysRescCD:
				if [ "$REPNET" = "1" ]; then
					net-setup eth0
					iface=eth0
				else
					/bin/net_setup.sh
					iface=$(cat /tmp/iface.txt)
				fi
				#Puppy:
				#net-setup.sh

				echo -e "$COLTXT"
				echo "Voici la config IP:"
				echo -e "$COLCMD\c"
				if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
					echo "ifconfig $iface | grep inet | grep -v \"inet6 addr:\""
					ifconfig $iface | grep inet | grep -v "inet6 addr:"
				else
					echo "ifconfig $iface | grep inet | grep -v \"inet6 \""
					ifconfig $iface | grep inet | grep -v "inet6 "
				fi

				echo -e "$COLTXT"
				echo -e "Voulez-vous corriger/modifier cette configuration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
				read REP

				if [ -z "$REP" ]; then
					REP="n"
				fi
			done
		fi

		echo -e "$COLTXT"
		echo "Nom ou Adresse du serveur FTP:"
		echo "Dans la plupart des cas, l'IP vous évitera des problèmes de résolution des noms de machines."
		echo -e "Quel est le nom ou IP du serveur? $COLSAISIE\c"
		read SERVEUR

		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "S'agit-t-il d'un FTP anonyme (${COLCHOIX}1${COLTXT}) ou faut-il un compte/mot de passe (${COLCHOIX}2${COLTXT})? $COLSAISIE\c"
			read REPONSE
		done

		if [ "$REPONSE" = "2" ]; then
			echo -e "$COLTXT"
			echo -e "Veuillez saisir le nom du login: $COLSAISIE\c"
			read NOMLOGIN

			echo -e "$COLTXT"
			echo -e "Veuillez saisir le mot de passe: \033[41;31m\c"
			read MOTDEPASSE
			echo -e "\033[0;39m                                                                                "

			echo -e "$COLTXT"
			echo "Création du point de montage:"
			echo -e "$COLCMD\c"
			echo "mkdir -p $PTMNTSTOCK"
			mkdir -p $PTMNTSTOCK
			echo -e "$COLTXT"
			echo "Montage du partage:"
			echo -e "$COLCMD\c"

			#echo "lufsmount ftpfs://${NOMLOGIN}:XXXXXX@${SERVEUR} $PTMNTSTOCK"
			#lufsmount ftpfs://${NOMLOGIN}:${MOTDEPASSE}@${SERVEUR} $PTMNTSTOCK||ERREUR "Le montage a échoué!"
			echo "lufis fs=ftpfs,host=${SERVEUR},username=${NOMLOGIN},password=XXXXXX ${PTMNTSTOCK} -s"
			lufis fs=ftpfs,host=${SERVEUR},username=${NOMLOGIN},password=${MOTDEPASSE} ${PTMNTSTOCK} -s||ERREUR "Le montage a échoué!"
			echo ""
		else

			echo -e "$COLTXT"
			echo "Création du point de montage:"
			echo -e "$COLCMD\c"
			echo "mkdir -p $PTMNTSTOCK"
			mkdir -p $PTMNTSTOCK
			echo -e "$COLTXT"
			echo "Montage du partage:"
			echo -e "$COLCMD\c"

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

		PARTSTOCK="ftpfs://${SERVEUR}"

		;;
	*)
		ERREUR "Le mode de sauvegarde semble incorrect."
	;;
esac


#AJOUTER UN CHOIX DE SOUS-DOSSIER
REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Voulez-vous effectuer la sauvegarde\ndans un sous-dossier de ${PTMNTSTOCK}? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	#...
	echo -e "$COLTXT"

	echo -e "$COLTXT"
	echo "Voici les dossiers contenus dans ${PTMNTSTOCK}:"
	echo -e "$COLCMD"
	ls -l ${PTMNTSTOCK} | grep ^d > /tmp/ls.txt
	more /tmp/ls.txt

	echo -e "$COLTXT"
	echo "Dans quel dossier voulez-vous effectuer la sauvegarde?"
	echo "Complétez le chemin (le dossier sera créé si nécessaire)."
	echo -e "Chemin: ${COLCMD}${PTMNTSTOCK}/${COLSAISIE}\c"
	cd "${PTMNTSTOCK}"
	read -e DOSSTEMP
	cd /root

	DOSSIER=$(echo "$DOSSTEMP" | sed -e "s|/$||g")

	DESTINATION="${PTMNTSTOCK}/${DOSSIER}"
	mkdir -p "$DESTINATION"
else
	DESTINATION="${PTMNTSTOCK}"
fi

echo -e "$COLTXT"
echo -e "Vous souhaitez effectuer la sauvegarde vers ${COLINFO}${DESTINATION}${COLTXT}"

echo -e "${COLTXT}Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
read REPONSE

if [ -z "$REPONSE" ]; then
	REPONSE="o"
fi

if [ "$REPONSE" != "o" ]; then
	echo -e "$COLERREUR"
	echo "ABANDON!"
	echo -e "$COLTXT"
	exit
fi

echo -e "$COLPARTIE"
echo "=========="
echo "Sauvegarde"
echo "=========="

# Génération d'un identifiant:
ladate=$(date +"%Y%m%d-%H%M%S")

echo -e "$COLTXT"
#echo "Sauvegarde de la table de partition actuelle de $SAVEHD..."
echo "Sauvegarde de la table de partition actuelle de $HD..."
echo -e "$COLCMD"
HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt|cut -d"'" -f2)

if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
	TMP_disque_en_GPT=/dev/${HD}
else
	TMP_disque_en_GPT=""
fi

if [ -z "$TMP_disque_en_GPT" ]; then
	sfdisk -d /dev/$HD > $DESTINATION/${HD}.initiale.${ladate}.out
else
	sgdisk -b $DESTINATION/${HD}.initiale.${ladate}.out /dev/$HD
fi

PARTSAVE="/dev/$CHOIX_SOURCE"
SUFFPARTSAVE=$CHOIX_SOURCE
NOM_IMAGE_DEFAUT="${SUFFPARTSAVE}.image_dar"
SUFFIXE_SVG="1.dar"

IMAGE=${NOM_IMAGE_DEFAUT}.${ladate}

echo -e "$COLINFO"
echo "La sauvegarde avec 'dar' ou 'tar' nécessite de monter la partition /dev/$SUFFPARTSAVE"
echo "Le type du système de fichier doit donc être précisé."
echo "Cela peut-être: vfat, ext2 ou ext3"

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo -e "Quel est le type de la partition?"
	DETECTED_TYPE=$(TYPE_PART $PARTSAVE)
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
	echo -e "$COLCMD\c"
	mkdir -p /mnt/$SUFFPARTSAVE
	if [ ! -z "$TYPE_FS" ]; then
		mount -t $TYPE_FS /dev/$SUFFPARTSAVE /mnt/$SUFFPARTSAVE
	else
		mount /dev/$SUFFPARTSAVE /mnt/$SUFFPARTSAVE
	fi
	umount /mnt/$SUFFPARTSAVE

	echo -e "$COLTXT"
	echo "Si aucune erreur n'est affichée, le type doit convenir..."

	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? $COLSAISIE\c"
		read REPONSE
	done
done

echo -e "$COLTXT"
echo -e "Quel niveau de compression souhaitez-vous?"
echo -e " - ${COLCHOIX}0${COLTXT} Aucune compression"
echo "     (rapide mais image volumineuse:"
echo "      la sauvegarde pourra être supprimée ensuite;"
echo "      c'est un bon choix si vous avez de la place)"
echo -e " - ${COLCHOIX}1${COLTXT} Compression gzip"
echo -e " - ${COLCHOIX}2${COLTXT} Compression bzip2"
echo "     (compression plus forte, mais plus lente)"
COMPRESS=""
while [ "$COMPRESS" != "0" -a "$COMPRESS" != "1" -a "$COMPRESS" != "2" ]
do
	echo -e "$COLTXT\c"
	echo -e "Niveau de compression: [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
	read COMPRESS

	if [ -z "$COMPRESS" ]; then
		COMPRESS=1
	fi
done

NIVEAU=$COMPRESS

echo -e "$COLINFO"
echo "La sauvegarde va être effectuée dans quelques secondes."
sleep 3

echo -e "$COLCMD"
mkdir -p /mnt/$SUFFPARTSAVE
#echo "mkdir -p /mnt/$SUFFPARTSAVE" >> "$DESTINATION/restaure.sh"
if [ ! -z "$TYPE_FS" ]; then
	mount -t $TYPE_FS $PARTSAVE /mnt/$SUFFPARTSAVE
else
	mount $PARTSAVE /mnt/$SUFFPARTSAVE
fi

case $NIVEAU in
	0)
		OPT_COMPRESS=""
	;;
	1)
		OPT_COMPRESS="-z2"
	;;
	2)
		OPT_COMPRESS="-y2"
	;;
esac
if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
	$chemin_dar/dar -c $DESTINATION/$IMAGE -s ${VOLUME}M $OPT_COMPRESS -v -R /mnt/$SUFFPARTSAVE
	#$chemin_dar/dar -c $DESTINATION/$IMAGE -s ${VOLUME}M $OPT_COMPRESS -v -R $DESTINATION
else
	$chemin_dar/dar -c $DESTINATION/$IMAGE $OPT_COMPRESS -v -R /mnt/$SUFFPARTSAVE
	#$chemin_dar/dar -c $DESTINATION/$IMAGE $OPT_COMPRESS -v -R $DESTINATION
fi

if [ "$?" = "0" ]; then
	echo -e "${COLTXT}"
	echo "La sauvegarde a semble-t-il réussi."
else
	echo -e "${COLERREUR}"
	echo "La sauvegarde a semble-t-il échoué."
	echo "Il n'est pas certain que la restauration fonctionne correctement"
	echo "si vous poursuivez."
	echo "Il serait plus prudent d'abandonner."

	POURSUIVRE "n"
fi

taille_part=$(df -h | tr "\t" " " | sed -e 's/ \{2,\}/ /g' | grep "^/dev/$SUFFPARTSAVE " | cut -d' ' -f2)
taille_occupe=$(df -h | tr "\t" " " | sed -e 's/ \{2,\}/ /g' | grep "^/dev/$SUFFPARTSAVE " | cut -d' ' -f3)
taille_libre=$(df -h | tr "\t" " " | sed -e 's/ \{2,\}/ /g' | grep "^/dev/$SUFFPARTSAVE " | cut -d' ' -f4)

echo -e "${COLTXT}"
echo -e "Démontage de la partition sauvegardée ${COLINFO}${CHOIX_SOURCE}"
echo -e "${COLCMD}\c"
cd /
umount /dev/${CHOIX_SOURCE}


echo -e "$COLPARTIE"
echo "================="
echo "Repartitionnement"
echo "================="

echo -e "$COLINFO"
echo "La partition ${CHOIX_SOURCE} actuelle a une taille de $taille_part"
echo "dont $taille_occupe occupés."

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo -e "Quelle nouvelle taille souhaitez-vous (en Mo)? ${COLSAISIE}\c"
	read NOUVELLE_TAILLE

	test=$(echo "$NOUVELLE_TAILLE" | sed -e "s/[0-9]//g")
	if [ ! -z "$test" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La valeur doit être numérique."
		REPONSE=2
	else
		echo -e "$COLTXT"
		echo -e "Vous avez choisi une nouvelle taille de: ${COLINFO}${NOUVELLE_TAILLE}${COLTXT}Mo"

		POURSUIVRE_OU_CORRIGER
	fi
done

num_part=$(parted /dev/$CHOIX_SOURCE print | grep "^ " | tr "\t" " " | sed -e 's/ \{2,\}/ /g' | cut -d" " -f2)
#nb_part=$(parted /dev/$SAVEHD print | grep "^ " | wc -l)
nb_part=$(parted /dev/$HD print | grep "^ " | wc -l)

#part_bootable=$(fdisk -l /dev/$HD | tr "\t" " " | sed -e 's/ \{2,\}/ /g'  | grep "^/dev/$CHOIX_SOURCE " | grep '*')
part_bootable=$(CHECK_PART_ACTIVE $HD)
if [ -z "$part_bootable" ]; then
	num_champ=2
else
	num_champ=3
fi

#debut=$(fdisk -l /dev/$SAVEHD | tr "\t" " " | sed -e 's/ \{2,\}/ /g'  | grep "^/dev/$CHOIX_SOURCE " | cut -d" " -f$num_champ)
debut=$(fdisk -l /dev/$HD | tr "\t" " " | sed -e 's/ \{2,\}/ /g'  | grep "^/dev/$CHOIX_SOURCE " | cut -d" " -f$num_champ)

if [ "$nb_part" = "1" ]; then
	echo "d
n" > /tmp/liste_redim.${ladate}.txt
else
	echo "d
$num_part
n" > /tmp/liste_redim.${ladate}.txt
fi

if [ $num_part -le 4 ]; then
	echo "p
$num_part" >> /tmp/liste_redim.${ladate}.txt
else
	echo "l
$num_part" >> /tmp/liste_redim.${ladate}.txt
fi

echo "$debut
+${NOUVELLE_TAILLE}M" >> /tmp/liste_redim.${ladate}.txt

if [ "$TYPE_FS" = "vfat" ]; then
	if [ "$nb_part" = "1" ]; then
		echo "t
b" >> /tmp/liste_redim.${ladate}.txt
	else
		echo "t
$num_part
b" >> /tmp/liste_redim.${ladate}.txt
	fi
fi
# Et si ce n'est pas vfat?

if [ ! -z "$part_bootable" ]; then
	#if [ "$nb_part" = "1" ]; then
	#	echo "a" >> /tmp/liste_redim.${ladate}.txt
	#else
		echo "a
$num_part" >> /tmp/liste_redim.${ladate}.txt
	#fi
fi

echo "w
" >> /tmp/liste_redim.${ladate}.txt

echo -e "${COLTXT}"
echo -e "Application des changements..."
echo -e "${COLCMD}\c"
#fdisk /dev/$SAVEHD < /tmp/liste_redim.${ladate}.txt
fdisk /dev/$HD < /tmp/liste_redim.${ladate}.txt

if [ "$?" = "0" ]; then
	echo -e "${COLTXT}"
	echo "L'opération de redimensionnement a semble-t-il réussi."
else
	echo -e "${COLERREUR}"
	echo "L'opération de redimensionnement a semble-t-il échoué."

	# Il faut restaurer l'état initial de la table de partitions et restaurer les données
	exit
fi

echo -e "${COLTXT}"
echo "Voici le nouveau partitionnement:"
echo -e "${COLCMD}\c"
fdisk -l /dev/$HD

POURSUIVRE "o"

echo -e "$COLPARTIE"
echo "========="
echo "Formatage"
echo "========="

echo -e "${COLTXT}"
echo "Formatage de la partition /dev/$CHOIX_SOURCE"
echo -e "${COLCMD}\c"
if [ "${TYPE_FS}" = "vfat" ]; then
	mkfs.vfat /dev/$CHOIX_SOURCE
else
	if [ -z "${TYPE_FS}" ]; then
		mkfs.ext3 /dev/$CHOIX_SOURCE
	else
		if [ -e "/sbin/mkfs.${TYPE_FS}" -o -e "/usr/sbin/mkfs.${TYPE_FS}" ]; then
			mkfs.${TYPE_FS} /dev/$CHOIX_SOURCE
		else
			echo -e "${COLERREUR}"
			echo "Le type n'a pas été identifié."
			exit
		fi
	fi
fi

if [ "$?" = "0" ]; then
	REP="o"
else
	echo -e "${COLERREUR}"
	echo "Il semble qu'une erreur se soit produite."
	REP="n"
fi

POURSUIVRE $REP

echo -e "$COLPARTIE"
echo "========================"
echo "Restauration des données"
echo "========================"

echo -e "${COLTXT}"
echo "Montage de la partition..."
echo -e "${COLCMD}\c"
if [ ! -z "$TYPE_FS" ]; then
	mount -t $TYPE_FS $PARTSAVE /mnt/$SUFFPARTSAVE
else
	mount $PARTSAVE /mnt/$SUFFPARTSAVE
fi

echo -e "${COLTXT}"
echo "Restauration des données..."
echo -e "${COLCMD}\c"
sleep 2
#$chemin_dar/dar -x $DESTINATION/$IMAGE -R /mnt/$SUFFPARTSAVE -b -wa -v
$chemin_dar/dar -x $DESTINATION/$IMAGE -R /mnt/$SUFFPARTSAVE -b -wa -v

if [ "$?" = "0" ]; then
	echo -e "${COLTXT}"
	echo "L'opération semble avoir réussi..."
else
	echo -e "${COLERREUR}"
	echo "Il semble qu'une erreur se soit produite."
fi

echo -e "${COLTXT}"
echo -e "Démontage de la partition ${COLINFO}${PARTSTOCK}"
echo -e "${COLCMD}\c"
cd /
umount ${PTMNTSTOCK}

echo -e "${COLTXT}"
echo "NOTE: Lors d'un essai, j'ai dû rebooter sur une disquette W98"
echo "      (ou 'w98' sur le multiboot) et effectuer 'sys C:' en fin"
echo "      de boot pour que le W98 démarre."
echo "      Peut-être qu'un"
echo "          dd if=/dev/hda1 of=bootsector.bin bs=512 count=1"
echo "      pour sauvegarder et"
echo "          dd if=bootsector.bin of=/dev/hda1 bs=512 count=1"
echo "      pour restaurer règlerait le problème."

echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour quitter..."
read PAUSE

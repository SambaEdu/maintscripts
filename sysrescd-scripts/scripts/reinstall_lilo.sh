#!/bin/sh

# Script de reinstallation de LILO
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 08/04/2014

mnt_cdrom=livemnt/boot

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
		exit
	fi
fi

if cat /proc/cmdline | grep "reinstall_lilo_auto=y" > /dev/null; then
	interactif="n"

	#if cat /proc/cmdline | grep "HD=" > /dev/null; then
	#	source /proc/cmdline

	#	if [ -z "$(sfdisk -s /dev/$HD)" ]; then
	#		HD=""
	#	fi
	#fi

	source /proc/cmdline

	if [ ! -z "$HD" ]; then
		if [ -z "$(sfdisk -s /dev/$HD)" ]; then
			HD=""
		fi
	fi

	if [ "$debug" = "y" ]; then
		echo "Contenu du /proc/cmdline"
		cat /proc/cmdline
		echo "HD=$HD"
		echo "auto_reboot=$auto_reboot"
		sleep 2
	fi
elif echo "$*"|grep "reinstall_lilo_auto=y" > /dev/null; then
	interactif="n"

	HD=$(echo "$*"|sed -e "s| |\n|g"|grep "^HD="|cut -d"=" -f2)

	if [ ! -z "$HD" ]; then
		if [ -z "$(sfdisk -s /dev/$HD)" ]; then
			HD=""
		fi
	fi

	if [ "$debug" = "y" ]; then
		echo "Contenu du /proc/cmdline"
		cat /proc/cmdline
		echo "Parametres de lancement de la ligne de commande : $*"
		echo "HD=$HD"
		echo "auto_reboot=$auto_reboot"
		sleep 2
	fi
else
	interactif="y"
fi

clear
echo -e "$COLTITRE"
echo "*******************************"
echo "*  Ce script doit vous aider  *"
echo "*    a reinstaller un LILO    *"
echo "*******************************"

echo -e "$COLINFO"
echo "La reinstallation de LILO peut être delicate s'il faut monter plusieurs"
echo "partitions."
echo "Ex.: Si vous avez des partitions separees pour /, /boot et /usr"
echo "Sinon, le present script devrait convenir."

if [ "$interactif" = "y" ]; then
	POURSUIVRE
else
	sleep 1
fi

echo -e "$COLPARTIE"
echo "========================================"
echo "Choix du disque dur puis de la partition"
echo "========================================"
if [ -z "$HD" ]; then

	#echo -e "$COLTXT"
	#echo "Voici la liste des disques detectes sur votre machine:"
	#echo -e "$COLCMD"

	HD=""
	while [ -z "$HD" ]
	do
		AFFICHHD
	
		DEFAULTDISK=$(GET_DEFAULT_DISK)
	
		#if [ "$interactif" = "y" ]; then
			echo -e "$COLTXT"
			echo "Sur quel disque se trouve la partition a monter?"
			echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
			echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
			read HD
	
			if [ -z "$HD" ]; then
				HD=${DEFAULTDISK}
			fi
		#else
		#	echo -e "$COLTXT"
		#	echo -e "${COLTXT}Utilisation du disque ${COLINFO}${HD}"
		#	sleep 1
		#fi

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
else
	echo -e "$COLTXT"
	echo -e "${COLTXT}Utilisation du disque ${COLINFO}${HD}"
	sleep 1
fi

echo -e "$COLTXT"
echo "Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
LISTE_PART ${HD} afficher_liste=y

#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -i "linux" | cut -d" " -f1))
LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
if [ ! -z "${liste_tmp[0]}" ]; then
	DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
else
	DEFAULTPART="${HD}1"
fi

if [ "$interactif" = "n" ]; then
	#test=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -i "linux" | cut -d" " -f1 | wc -l)
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
	test=$(wc -l /tmp/liste_part_extraite_par_LISTE_PART.txt)
	if [ "$test" = "1" ]; then
		PART=${DEFAULTPART}

		echo -e "$COLTXT"
		echo -e "${COLTXT}Utilisation de la partition ${COLINFO}${PART}"
		sleep 1
	fi
fi

if [ -z "$PART" ]; then
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quelle est la partition a monter? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
		read PART
	
		if [ -z "$PART" ]; then
			PART=${DEFAULTPART}
		fi

		#if ! fdisk -s /dev/$PART > /dev/null; then
		t=$(fdisk -s /dev/$PART)
		if [ -z "$t" -o ! -e "/sys/block/$HD/$PART" ]; then
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
fi

#if ! fdisk -l /dev/$HD | grep "/dev/$PART " > /dev/null; then
t=$(fdisk -s /dev/$PART)
if [ -z "$t" -o ! -e "/sys/block/$HD/$PART" ]; then
	echo -e "$COLERREUR"
	echo "ERREUR: La partition proposee n'existe pas!"
	echo -e "$COLTXT"
	read PAUSE
	exit 1
fi

#if ! fdisk -l /dev/$HD | grep "/dev/$PART " | grep Linux > /dev/null; then
TMP_TYPE=$(parted /dev/${PART} print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
#if [ "$TMP_TYPE" = "ext2" -o "$TMP_TYPE" = "ext3" -o "$TMP_TYPE" = "ext4" -o "$TMP_TYPE" = "reiserfs" -o "$TMP_TYPE" = "xfs" -o "$TMP_TYPE" = "jfs" ]; then
if [ "$TMP_TYPE" != "ext2" -a "$TMP_TYPE" != "ext3" -a "$TMP_TYPE" != "ext4" -a "$TMP_TYPE" != "reiserfs" -a "$TMP_TYPE" != "xfs" -a "$TMP_TYPE" != "jfs" ]; then
	echo -e "$COLERREUR"
	echo "ERREUR: La partition proposee n'est pas de type Linux!"
	echo -e "$COLTXT"
	read PAUSE
	exit 1
fi

echo -e "$COLPARTIE"
echo "======================="
echo "Montage de la partition"
echo "======================="

echo -e "$COLTXT"
echo "Montage de la partition..."
echo -e "$COLCMD\c"
mkdir -p /mnt/tmplilo
mount /dev/$PART /mnt/tmplilo || ERREUR "Erreur lors du montage de la partition."


if [ "$interactif" = "y" ]; then
	echo -e "$COLPARTIE"
	echo "======================="
	echo "Traitement du lilo.conf"
	echo "======================="

	if [ ! -e "/mnt/tmplilo/etc/lilo.conf" ]; then
		ERREUR "Il semble que la partition choisie ne contienne pas un /etc/lilo.conf"
	fi

	if [ -e "/mnt/tmplilo/bin/change_mdp_lilo.sh" ]; then
		echo -e "$COLTXT"
		echo "Il semble que la partition choisie contienne un script de changement des mots de passe LILO."
		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous executer ce script avant de reinstaller LILO? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		done

		if [ "$REPONSE" = "o" ]; then
			chroot /mnt/tmplilo /bin/change_mdp_lilo.sh
			umount /mnt/tmplilo
			exit 1
		fi
	else
		echo -e "$COLTXT"
		echo "Le fichier /etc/lilo.conf est bien present dans la partition choisie."
	fi

	POURSUIVRE
fi

echo -e "$COLPARTIE"
echo "======================"
echo "Reinstallation du LILO"
echo "======================"

echo -e "$COLTXT"
echo "Reinstallation de LILO..."
echo -e "$COLCMD\c"
chmod 600 /mnt/tmplilo/etc/lilo.conf
chroot /mnt/tmplilo lilo > /tmp/reinstall_lilo.log 2>&1
cat /tmp/reinstall_lilo.log

if grep "P ignore" /tmp/reinstall_lilo.log > /dev/null; then
	DEFREP="y"
else
	DEFREP="n"
fi

if [ "$interactif" = "y" ]; then
	echo -e "$COLINFO"
	echo "NB: On obtient generalement un avertissement sans consequence:"
	echo -e "$COLERREUR    Warning: '/proc/partitions' doesn't exist, disk scan bypassed"
	echo -e "$COLINFO"
	echo "   En revanche, si le message ci-dessus indique quelque chose comme"
	echo "   ce qui suit, il faut refaire l'installation de LILO"
	echo -e "$COLERREUR\c"
	echo "   Device 0x0800: Inconsistent partition table, 2nd entry
		CHS address in PT:  832:0:1  -->  LBA (13366080)
		LBA address in PT:  12579840  -->  CHS (783:15:1)
	Fatal: Either FIX-TABLE or IGNORE-TABLE must be specified
	If not sure, first try IGNORE-TABLE (-P ignore)"
	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Avez-vous obtenu ce deuxieme message? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${DEFREP}${COLTXT}] $COLSAISIE\c"
		read REP

		if [ -z "$REP" ]; then
			REP="${DEFREP}"
		fi
	done
else
	REP="${DEFREP}"
	if [ "$REP" = "o" ]; then
		echo -e "$COLINFO"
		echo "Un souci a ete releve... on va reinstaller le LILO."
	fi
fi

if [ "$REP" = "o" ]; then
	echo -e "$COLTXT"
	echo "Reinstallation de LILO"
	echo -e "$COLCMD"
	chroot /mnt/tmplilo lilo -P ignore
fi

echo -e "$COLTXT"
echo -e "Demontage de la partition ${COLINFO}${PART}"
echo -e "$COLCMD\c"
umount /mnt/tmplilo

echo -e "$COLTITRE"
echo "Termine!"

if [ "$interactif" = "y" ]; then
	echo -e "$COLTXT"
	echo "Appuyez sur une touche pour quitter."
	read PAUSE
else

	if [ -z "$delais_reboot" ]; then
		# Pour etre sur que le nettoyage de tache ait le temps de passer
		delais_reboot=120
	fi

	sleep 1
	if [ "$auto_reboot" = "y" ]; then
		echo -e "$COLTXT"
		#echo "Reboot dans $delais_reboot secondes..."
		#sleep $delais_reboot
		COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes..."
		reboot
	fi
	read PAUSE
fi


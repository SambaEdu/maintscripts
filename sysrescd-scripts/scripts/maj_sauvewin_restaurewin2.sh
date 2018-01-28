#!/bin/bash

# Script de mise à jour des scripts d'un SystemRescueCD installé sur une partition
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 02/02/2013

# Parametres du script:
#   - no_wget : pas de tentative de telechargement des scripts (donc utilisation de ceux du CD,... sur lequel on a booté)
#   - mode=auto : pour laisser trouver tout seul les partitions,...
#   - auto_reboot=y : pour rebooter en fin d'operation
#   - delais_reboot=30 : pour fixer le delais avant reboot

#version_scripts_sauvewin_and_cie=20120326
fich_param=/etc/parametres_svgrest.sh

source /bin/crob_fonctions.sh

src_infos=/proc/cmdline
auto_reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^auto_reboot="|cut -d"=" -f2)
delais_reboot=$(cat ${src_infos}|sed -e "s| |\n|g"|grep "^delais_reboot="|cut -d"=" -f2)

t=$(echo "$*"|grep "auto_reboot=y")
if [ -n "$t" ]; then
	auto_reboot=y
fi

t=$(echo "$*"|sed -e "s| |\n|g"|grep "delais_reboot="|cut -d"=" -f2)
if [ -n "$t" ]; then
	delais_reboot=$t
fi

clear
echo -e "$COLTITRE"
echo "***********************************************"
echo "*      Script de mise à jour des scripts       *"
echo "* d'un SystemRescueCD installé sur disque dur *"
echo "***********************************************"
#echo ""

echo -e "$COLERREUR"
echo "ATTENTION:"
echo -e "$COLINFO\c"
echo "Ce script n'est pas concu pour un SysRescCD sur disque USB,"
echo "mais pour un dispositif de sauvegarde/restauration installe"
echo "derriere une partition Window$ et lance via LILO/GRUB."
echo -e "$COLTXT"
echo "Pressez CTRL+C si vous voulez abandonner, sinon, patientez 5 secondes."
sleep 5

mode="interactif"
t=$(echo "$*"|grep "mode=auto")
if [ -n "$t" ]; then
	mode="auto"
fi

src_scripts_parent=${mnt_cdrom}/sysresccd/scripts
src_scripts=$src_scripts_parent/scripts_pour_sysresccd_sur_hd

# Est-ce qu'on tente de telecharger les scripts?
t=$(echo "$*"|grep "no_wget")
if [ -z "$t" ]; then
	#t=$(grep "nameserver 8.8.8.8" /etc/resolv.conf)
	echo -e "$COLTXT"
	echo "Test de la resolution DNS..."
	if [ "$(TEST_DNS)" != "0" ]; then
		echo -e "$COLTXT"
		echo "Recherche d'un serveur DNS pour permettre le telechargement des scripts..."
		echo -e "$COLCMD\c"
		CHERCHE_DNS "verbeux"
		sleep 2
	fi

	#t=$(fping wawadeb.crdp.ac-caen.fr 2>/dev/null|grep "is alive")
	t=$(TEST_PING wawadeb.crdp.ac-caen.fr)
	if [ -n "$t" ]; then
		echo -e "$COLTXT"
		echo "Telechargement des scripts sur wawadeb..."
		echo -e "$COLCMD\c"
		tmp=/tmp/maj_scripts_$(date +%Y%m%d%H%M%S)
		mkdir $tmp
		cd $tmp
		wget -t 3 http://wawadeb.crdp.ac-caen.fr/iso/sysresccd/versions.txt
		if [ "$?" = "0" ]; then
			wget -t 3 http://wawadeb.crdp.ac-caen.fr/iso/sysresccd/scripts.tar.gz
			if [ "$?" = "0" ]; then
				md5_scripts=$(md5sum scripts.tar.gz | cut -d" " -f1)
				#echo "md5_scripts=$md5_scripts"
				md5_verif=$(grep ";scripts.tar.gz$" versions.txt | cut -d";" -f2)
				#echo "md5_verif=$md5_verif"
				date_verif=$(grep ";scripts.tar.gz$" versions.txt | cut -d";" -f1)
				#echo "date_verif=$date_verif"
				if [ "$md5_scripts" = "$md5_verif" ]; then

					REP=""
					if [ "$mode" = "auto" ]; then
						REP="1"
					fi

					while [ "$REP" != "1" -a "$REP" != "2" ]
					do
						echo -e "$COLTXT"
						echo "Un paquet scripts.tar.gz du ${COLINFO}$date_verif${COLTXT} a été trouvé sur"
						echo -e "${COLINFO}     http://wawadeb.crdp.ac-caen.fr/iso/sysresccd/"
						echo -e "${COLTXT}Voulez-vous "
						echo -e "(${COLCHOIX}1${COLTXT}) utiliser ce fichier ou préférez-vous utiliser"
						echo -e "(${COLCHOIX}2${COLTXT}) les scripts présents sur le CD? [${COLDEFAUT}1${COLTXT}] \c$COLSAISIE"
						read REP
					
						if [ -z "$REP" ]; then
							REP="1"
						fi
					done

					if [ "$REP" = "1" ]; then
						tar -xzf scripts.tar.gz
						if [ "$?" = "0" ]; then
							src_scripts_parent=$tmp/scripts
							src_scripts=$tmp/scripts/scripts_pour_sysresccd_sur_hd
						fi
					fi
				else
					echo -e "$COLERREUR"
					echo "Erreur lors du téléchargement."
				fi
			fi
		fi
	fi
fi

echo -e "$COLINFO"
echo "Verification de l'acces aux scripts en ${src_scripts}"
echo -e "$COLCMD\c"
#if grep /proc/cmdline docache > /dev/null; then
test=$(ls ${src_scripts}/)
if [ -z "${test}" ]; then
	echo -e "$COLERREUR"
	echo "Le CD doit être monté et le dossier"
	echo "   ${mnt_cdrom}/sysresccd/scripts/scripts_pour_sysresccd_sur_hd"
	echo "doit contenir les nouveaux scripts pour que la mise à jour"
	echo "puisse être effectuée..."
	echo "... ou alors il faut booter avec config reseau effectuée pour"
	echo "récupérer les scripts sur le net."
	exit
fi

echo -e "$COLINFO"
echo "Les scripts proposés dans un SysRescCD installé sur disque dur évoluent."
echo "Ce script est destiné à mettre à jour les scripts d'un SysRescCD installé"
echo "sur disque dur."
echo "Les scripts concernés par la mise à jour sont:"
echo " - /bin/sauvewin.sh"
echo " - /bin/restaurewin.sh"
echo " - /bin/suppr_svg.sh"
echo " - /bin/change_mdp_lilo.sh"
echo " - /bin/crob_fonctions.sh"
echo " - /bin/console.sh"
echo " - /root/.zsh/rc/zework.rc"

if [ "$mode" != "auto" ]; then
	POURSUIVRE
else
	sleep 5
fi

echo -e "$COLPARTIE"
echo "===================================================="
echo "Détermination de la partition contenant le SysRescCD"
echo "===================================================="

if [ "$mode" = "auto" ]; then
	SYSRESCDHD=$(GET_DEFAULT_DISK)

	echo -e "$COLTXT"
	echo "Le disque trouvé est $SYSRESCDHD"
	echo -e "$COLCMD\c"
	#liste_tmp=($(fdisk -l /dev/$SYSRESCDHD | grep "^/dev/$SYSRESCDHD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | egrep -v "(FAT|NTFS)" | grep "Linux" | cut -d" " -f1))
	LISTE_PART ${SYSRESCDHD} avec_tableau_liste=y type_part_cherche=linux
	if [ ! -z "${liste_tmp[0]}" ]; then
		SYSRESCDPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")

		t=$(grep "^/dev/$SYSRESCDPART " /etc/fstab)
		if [ -z "$t" ]; then
			mkdir -p /mnt/$SYSRESCDPART
			mount /dev/$SYSRESCDPART /mnt/$SYSRESCDPART

			if [ "$?" = "0" ]; then
				if [ -e "/mnt/$SYSRESCDPART/root/ChangeLog-x86" ]; then
					t=$(grep "www.sysresccd.org" /mnt/$SYSRESCDPART/root/ChangeLog-x86)
					if [ -z "$t" ]; then
						mode="interactif"
					fi
				else
					mode="interactif"
				fi
				umount /mnt/$SYSRESCDPART
			else
				mode="interactif"
			fi
		else
			if [ -e "/root/ChangeLog-x86" ]; then
				t=$(grep "www.sysresccd.org" /root/ChangeLog-x86)
				if [ -z "$t" ]; then
					mode="interactif"
				fi
			else
				mode="interactif"
			fi
		fi
	else
		echo -e "$COLERREUR"
		echo "Partition du SysRescCD installé non identifiée"
		echo -e "$COLTXT"
		mode="interactif"
	fi
fi

if [ "$mode" != "auto" ]; then
	SUITE=""
	while [ "$SUITE" != "o" ]
	do
		SUITE="o"

		AFFICHHD

		DEFAULTDISK=$(GET_DEFAULT_DISK)

		echo -e "$COLTXT"
		echo "Quel est le disque dur contenant SysRescCD?"
		echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
		echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
		read SYSRESCDHD

		if [ -z "$SYSRESCDHD" ]; then
			SYSRESCDHD=${DEFAULTDISK}
		fi

		#liste_tmp=($(fdisk -l /dev/$SYSRESCDHD | grep "^/dev/$SYSRESCDHD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | egrep -v "(FAT|NTFS)" | grep "Linux" | cut -d" " -f1))
		LISTE_PART ${SYSRESCDHD} avec_tableau_liste=y type_part_cherche=linux
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			echo -e "$COLERREUR"
			echo "Aucune partition de type Linux n'a été trouvée sur ce disque dur."
			SUITE=""
		fi
	done
fi

if [ "$(is_dev_usb_stick ${SYSRESCDHD})" = "0" -o  "$(is_dev_usb_hd ${SYSRESCDHD})" = "0" ]; then
	echo -e "$COLERREUR"
	echo "Le disque /dev/${SYSRESCDHD} est amovible."
	get_infos_dev ${SYSRESCDHD}
	echo "Le script $0 n'est pas concu"
	echo "pour un SysRescCD sur disque USB, mais pour un dispositif de"
	echo "sauvegarde/restauration installe derriere une partition Window$"
	echo " et lance via LILO/GRUB."
	echo -e "$COLTXT"
	exit
fi

if [ "$mode" != "auto" ]; then
	SUITE=""
	while [ "$SUITE" != "o" ]
	do
		SUITE="o"

		echo -e "$COLTXT"
		echo "Voici les partitions sur le disque /dev/$SYSRESCDHD:"
		echo -e "$COLCMD"
		#fdisk -l /dev/$SYSRESCDHD
		LISTE_PART ${SYSRESCDHD} afficher_liste=y

		#liste_tmp=($(fdisk -l /dev/$SYSRESCDHD | grep "^/dev/$SYSRESCDHD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | egrep -v "(FAT|NTFS)" | grep "Linux" | cut -d" " -f1))
		LISTE_PART ${SYSRESCDHD} avec_tableau_liste=y type_part_cherche=linux
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			DEFAULTPART="${SYSRESCDHD}1"
		fi

		echo -e "$COLTXT"
		echo "Quelle est la partition contenant SysRescCD?"
		echo -e "Partition SysRescCD: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
		read SYSRESCDPART

		if [ -z "$SYSRESCDPART" ]; then
			SYSRESCDPART=${DEFAULTPART}
		fi

		#Vérification:
		#if ! fdisk -s /dev/$SYSRESCDPART > /dev/null; then
		t=$(fdisk -s /dev/$SYSRESCDPART)
		if [ -z "$t" -o ! -e "/sys/block/$SYSRESCDHD/$SYSRESCDPART/partition" ]; then
			echo -e "$COLERREUR"
			echo "ERREUR: La partition proposée n'existe pas!"
			SUITE=""
		else
			#if ! fdisk -l /dev/$SYSRESCDHD | tr "\t" " " | grep "/dev/$SYSRESCDPART " | grep "Linux" | grep -v "Linux swap" > /dev/null; then
			TMP_TYPE=$(parted /dev/$SYSRESCDPART print |grep -E '^ [0-9]+' | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6)
			if [ "$TMP_TYPE" != "ext2" -a "$TMP_TYPE" != "ext3" -a "$TMP_TYPE" != "ext4" -a "$TMP_TYPE" != "reiserfs" -a "$TMP_TYPE" != "xfs" -a "$TMP_TYPE" != "jfs" ]; then
				echo -e "$COLERREUR"
				echo "ERREUR: La partition proposée n'est pas de type Linux!"
				SUITE=""
			fi
		fi
	done
fi

echo -e "$COLTXT"
echo -e "Montage de la partition ${COLINFO}/dev/$SYSRESCDPART${COLTXT} en ${COLINFO}/mnt/$SYSRESCDPART${COLTXT}"
echo -e "$COLCMD"
mkdir -p /mnt/$SYSRESCDPART
mount /dev/$SYSRESCDPART /mnt/$SYSRESCDPART

echo -e "$COLTXT"
echo -e "Tentative d'identification de la partition système Window$..."
echo -e "$COLCMD\c"
if [ ! -e "/mnt/$SYSRESCDPART/bin/sauvewin.sh" ]; then
	echo -e "$COLERREUR"
	echo "ABANDON: Il semble qu'il n'existe pas de script /bin/sauvewin.sh sur la"
	echo "         partition choisie pour le SystemRescue installé."

	if [ "$mode" != "auto" ]; then
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour quitter."
		read PAUSE
	else
		sleep 60
	fi
	exit
fi

PARDOS=""
if [ -e "/mnt/$SYSRESCDPART/${fich_param}" ]; then
	PARDOS=$(grep "^PARDOS=" /mnt/$SYSRESCDPART/${fich_param} | cut -d" " -f2)
else
	if grep "^PARDOS=" /mnt/$SYSRESCDPART/bin/sauvewin.sh > /dev/null; then
		PARDOS=$(grep "^PARDOS=" /mnt/$SYSRESCDPART/bin/sauvewin.sh | cut -d" " -f2)
	else
		PARDOS=$(cat /mnt/$SYSRESCDPART/bin/sauvewin.sh | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | sed -e "s/^ //g" | grep "^partimage" | cut -d"/" -f3 | sed -e "s/ //g")
	fi

	if grep "partimage" /mnt/$SYSRESCDPART/bin/sauvewin.sh > /dev/null; then
		TYPE_SVG='partimage'
	else
		if grep "ntfsclone" /mnt/$SYSRESCDPART/bin/sauvewin.sh > /dev/null; then
			TYPE_SVG='ntfsclone'
		else
			TYPE_SVG='dar'

			TYPE_PARDOS_FS=$(TYPE_PART $PARDOS)
		fi
	fi

	if [ ! -e "/mnt/$SYSRESCDPART/etc/svgrest_arret_ou_reboot.txt" ]; then
		svgrest_arret_ou_reboot="reboot"
	else
		svgrest_arret_ou_reboot=$(cat /mnt/$SYSRESCDPART/etc/svgrest_arret_ou_reboot.txt)
	fi

	if [ -e "/mnt/$SYSRESCDPART/etc/svgrest_automatique.txt" ]; then
		svgrest_auto="o"
	else
		svgrest_auto="n"
	fi
fi

if [ -z "$PARDOS" ]; then
	echo -e "$COLERREUR"
	echo "ABANDON: La partition n'a pas été identifiée???"

	if [ "$mode" != "auto" ]; then
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour quitter."
		read PAUSE
	else
		sleep 60
	fi
	exit
else
	echo -e "$COLTXT"
	echo -e "Partition système Window$: ${COLINFO}$PARDOS"
fi

REPONSE=""
if [ "$mode" = "auto" ]; then
	REPONSE="o"
fi
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Est-ce correct? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "n" ]; then
	AFFICHHD

	echo -e "$COLTXT"
	echo -e "Disque dur contenant le système Window$: [${COLDEFAUT}hda${COLTXT}] $COLSAISIE\c"
	read BOOTDISK

	if [ -z "$BOOTDISK" ]; then
		BOOTDISK="hda"
	fi

	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$BOOTDISK:"
	echo -e "$COLCMD"
	#fdisk -l /dev/$BOOTDISK
	LISTE_PART ${BOOTDISK} afficher_liste=y
	echo ""

	#liste_tmp=($(fdisk -l /dev/$BOOTDISK | grep "^/dev/$BOOTDISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | cut -d" " -f1))
	LISTE_PART ${BOOTDISK} avec_tableau_liste=y
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART="hda1"
	fi


	echo -e "$COLTXT"
	echo "Quelle est la partition système de Window$ (partition de boot)?"
	echo " (probablement hda1,...)"
	echo -e "Partition window$: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read PARDOS
	echo ""

	if [ -z "$PARDOS" ]; then
		PARDOS=${DEFAULTPART}
	fi

	#Vérification:
	#if ! fdisk -s /dev/$PARDOS > /dev/null; then
	t=$(fdisk -s /dev/$PARDOS)
	if [ -z "$t" -o ! -e "/sys/block/$BOOTDISK/$PARDOS/partition" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposée n'existe pas!"
		exit
	fi
fi

echo -e "$COLPARTIE"
echo "======================="
echo "Mise à jour des scripts"
echo "======================="

if [ -e "/mnt/$SYSRESCDPART/etc/version_scripts_sauvewin_and_cie" ]; then
	rm /mnt/$SYSRESCDPART/etc/version_scripts_sauvewin_and_cie
fi

echo -e "$COLINFO"
echo "Les scripts vont maintenant être mis à jour."

if [ "$mode" != "auto" ]; then
	POURSUIVRE
else
	sleep 5
fi
	

if [ ! -e "/mnt/$SYSRESCDPART/${fich_param}" ]; then
	echo '# Paramètres pour un SysRescCD installé sur disque dur.

# Partition à sauvegarder/restaurer:
PARDOS="'${PARDOS}'"

# Partition de boot W$ (laisser vide si c est la meme que PARDOS)
PARBOOTDOS=""

# Partition du système SysRescCD:
SYSRESCDPART="'${SYSRESCDPART}'"

# Format de sauvegarde:
# - partimage
# - ntfsclone
# - dar
TYPE_SVG="'${TYPE_SVG}'"

# Préciser le type de la partition à sauvegarder dans le cas d une sauvegarde dar
# Le type peut être vfat, ext3,...
TYPE_PARDOS_FS="'${TYPE_PARDOS_FS}'"

# Nom de l image par défaut
NOM_IMAGE_DEFAUT="image.${TYPE_SVG}"

# Sauvegarde/restauration automatique avec le nom d image par défaut:
svgrest_auto="'${svgrest_auto}'"

# Action après sauvegarde/restauration:
# - reboot
# ou
# - arret
svgrest_arret_ou_reboot="'${svgrest_arret_ou_reboot}'"

# Emplacement de stockage des sauvegardes:
EMPLACEMENT_SVG="/home/sauvegarde"



# ================================================
# Chemin de ntfsclone
chemin_ntfs="/usr/sbin"

# Chemin de dar
chemin_dar="/usr/bin"

# ================================================
# Adaptation de l extension au type de sauvegarde:
case ${TYPE_SVG} in
	"partimage")
		SUFFIXE_SVG="000"
	;;
	"ntfsclone")
		SUFFIXE_SVG="ntfs"
	;;
	"dar")
		SUFFIXE_SVG="1.dar"
	;;
esac


# Restaurer par defaut les premiers Mo du disque dur:
RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD="n"

# Sauvegarder par defaut la partition de boot W$ (si elle existe) lors des sauvegardes de la partition systeme:
SVG_PARBOOTDOS="o"
' > /mnt/$SYSRESCDPART/${fich_param}
fi


ladate=$(date "+%Y%m%d-%H%M%S")

echo -e "$COLCMD\c"
mkdir -p /mnt/$SYSRESCDPART/root/tmp
if [ -e /mnt/$SYSRESCDPART/bin/sauvewin.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/sauvewin.sh /mnt/$SYSRESCDPART/bin/sauvewin.sh.$ladate
fi

if [ -e /mnt/$SYSRESCDPART/bin/suppr_svg.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/suppr_svg.sh /mnt/$SYSRESCDPART/bin/suppr_svg.sh.$ladate
fi

if [ -e /mnt/$SYSRESCDPART/bin/restaurewin.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/restaurewin.sh /mnt/$SYSRESCDPART/bin/restaurewin.sh.$ladate
fi

if [ -e /mnt/$SYSRESCDPART/bin/change_mdp_lilo.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/change_mdp_lilo.sh /mnt/$SYSRESCDPART/bin/change_mdp_lilo.sh.$ladate
fi

if [ -e /mnt/$SYSRESCDPART/bin/change_mdp_grub.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/change_mdp_grub.sh /mnt/$SYSRESCDPART/bin/change_mdp_grub.sh.$ladate
fi

if [ -e /mnt/$SYSRESCDPART/bin/console.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/console.sh /mnt/$SYSRESCDPART/bin/console.sh.$ladate
fi

if [ -e /mnt/$SYSRESCDPART/root/.zsh/rc/zework.rc ]; then
	cp -f /mnt/$SYSRESCDPART/root/.zsh/rc/zework.rc /mnt/$SYSRESCDPART/root/tmp/zework.rc.${ladate}
fi

if [ -e /mnt/$SYSRESCDPART/bin/crob_fonctions.sh ]; then
	cp -f /mnt/$SYSRESCDPART/bin/crob_fonctions.sh /mnt/$SYSRESCDPART/bin/crob_fonctions.sh.${ladate}
fi

cp ${src_scripts_parent}/crob_fonctions.sh /mnt/$SYSRESCDPART/bin/
cp ${src_scripts}/*.sh /mnt/$SYSRESCDPART/bin/
chmod +x /mnt/$SYSRESCDPART/bin/*.sh

cp ${src_scripts}/zework.rc /mnt/$SYSRESCDPART/root/.zsh/rc/


# Renseignement du témoin de version des scripts:
#echo "$version_scripts_sauvewin_and_cie" > /mnt/$SYSRESCDPART/etc/version_scripts_sauvewin_and_cie



echo -e "$COLTXT"
echo "Les anciennes versions des scripts ont été déplacées re-copiées"
echo "dans /bin avec le suffixe $ladate"

echo -e "$COLTXT"
echo "Démontage de la partition accueillant SystemRescueCD..."
echo -e "$COLCMD\c"
umount /mnt/$SYSRESCDPART

echo -e "$COLTITRE"
echo "La mise à jour est maintenant effectuée."
echo -e "$COLTXT"

if [ "$mode" != "auto" ]; then
	echo "Appuyez sur ENTREE pour revenir au menu."
	read PAUSE
else
	sleep 5
fi

if [ ! -z "$auto_reboot" ]; then
	if [ -z "$delais_reboot" ]; then
		delais_reboot=90
	fi

	if [ "$auto_reboot" = "y" ]; then
		echo -e "$COLTXT"
		COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
		echo -e "$COLCMD\c"
		reboot
	else
		if [ "$auto_reboot" = "halt" ]; then
			echo -e "$COLTXT"
			COMPTE_A_REBOURS "Extinction dans" $delais_reboot "secondes."
			echo -e "$COLCMD\c"
			halt
		else
			COMPTE_A_REBOURS "On quitte dans" 5 "secondes."
		fi
	fi
fi


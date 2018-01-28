#!/bin/bash

# Script de mise en place d'une DLL modifiée pour W9x de façon à griser le champ domaine de la fenêtre de login
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 02/02/2013

source /bin/crob_fonctions.sh

# Pour une automatisation passer en paramètres:
#   w9x_dom_auto=y
#   dom_grise=y ou n
#   auto_reboot=y ou n

if cat /proc/cmdline | grep "w9x_dom_auto=y" > /dev/null; then
	interactif="n"

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
else
	interactif="y"
fi

dossier_cd="sysresccd/9x_griser_champ_domaine"

clear
echo -e "$COLTITRE"
echo "*******************************"
echo "*  Ce script doit vous aider  *"
echo "*    à mettre en place une    *"
echo "*   DLL modifiée pour W98SE   *"
echo "* de façon à griser le champ  *"
echo "*           domaine           *"
echo "*******************************"

echo -e "$COLINFO"
echo "La DLL proposée n'est valide que pour W98SE."
echo "N'essayez pas de la mettre en place sur une autre version de W$."

temoin_cd="ok"
#if cat /proc/cmdline | grep docache > /dev/null; then
#fi
if ! mount | grep cdrom > /dev/null; then
	echo -e "$COLERREUR"
	echo "ERREUR: Le CD n'est pas monté."
	echo "        La DLL doit être récupérée sur le CD."
	echo "        Il faut insérer le CD et le monter en /mnt/cdrom"
	echo "        pour que le script puisse fonctionner."
	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour quitter..."
	read PAUSE
	exit
fi

if [ "$interactif" = "y" ]; then
	POURSUIVRE
else
	sleep 1
fi

echo -e "$COLPARTIE"
echo "========================================"
echo "Choix du disque dur puis de la partition"
echo "========================================"

VERIF=""
while [ "$VERIF" != "OK" ]
do
	if [ -z "$HD" ]; then

		#echo -e "$COLTXT"
		#echo "Voici la liste des disques détectés sur votre machine:"
		#echo -e "$COLCMD"

		AFFICHHD

		DEFAULTDISK=$(GET_DEFAULT_DISK)

		#if [ "$interactif" = "y" ]; then
			echo -e "$COLTXT"
			echo "Sur quel disque se trouve la partition système Window\$98SE à monter?"
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

	#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -i "FAT" | cut -d" " -f1))
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=fat
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		VERIF="OK"
	else
		#DEFAULTPART="${HD}1"
		echo -e "$COLERREUR"
		echo "ERREUR: Aucune partition FAT32 n'a été trouvée sur ce disque."
		HD=""
	fi
done

if [ "$interactif" = "n" ]; then
	#test=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -i "FAT" | cut -d" " -f1 | wc -l)
	#if [ "$test" = "1" ]; then
	if [ "${#liste_tmp[*]}" = "1" ]; then
		PART=${DEFAULTPART}

		echo -e "$COLTXT"
		echo -e "${COLTXT}Utilisation de la partition ${COLINFO}${PART}"
		sleep 1
	fi
fi

if [ -z "$PART" ]; then
	echo -e "$COLTXT"
	echo -e "Quelle est la partition à monter? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read PART

	if [ -z "$PART" ]; then
		PART=${DEFAULTPART}
	fi
fi

#if ! fdisk -l /dev/$HD | grep "/dev/$PART " > /dev/null; then
t=$(fdisk -s /dev/$PART)
if [ -z "$t" -o ! -e "/sys/block/$HD/$PART" ]; then
	echo -e "$COLERREUR"
	echo "ERREUR: La partition proposée n'existe pas!"
	echo -e "$COLTXT"
	read PAUSE
	exit 1
fi


#if ! fdisk -l /dev/$HD | grep "/dev/$PART " | grep -i "FAT" > /dev/null; then
type_fs=$(TYPE_PART $PART)
if [ "$type_fs" != "vfat" ]; then
	echo -e "$COLERREUR"
	echo "ERREUR: La partition proposée n'est pas de type FAT32 !"
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
mkdir -p /mnt/w98
if mount | grep "/mnt/w98 " > /dev/null; then
	umount /mnt/w98
fi
mount -t vfat /dev/$PART /mnt/w98 || ERREUR "Erreur lors du montage de la partition."


echo -e "$COLPARTIE"
echo "======================="
echo "Mise en place de la DLL"
echo "======================="

dossier_w98=$(ls -1 /mnt/w98/ | grep -i "^windows$")
dossier_system=$(ls -1 /mnt/w98/${dossier_w98} | grep -i "^system$")

if [ -z "$dom_grise" ]; then
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo "Voulez-vous mettre en place la DLL:"
		echo -e " (${COLCHOIX}1${COLTXT}) grisant le champ Domaine de la fenêtre de login"
		echo -e " (${COLCHOIX}2${COLTXT}) rétablissant le champ Domaine de la fenêtre de login"
		echo -e "Votre choix: ${COLSAISIE}\c"
		read REPONSE
	done
else
	if [ "${dom_grise}" = "y" ]; then
		REPONSE=1
	else
		REPONSE=2
	fi
fi

echo -e "$COLTXT"
echo -e "Sauvegarde de la DLL actuellement en place."
echo -e "$COLCMD\c"
mprserv_dll=$(ls -1 /mnt/w98/${dossier_w98}/${dossier_system} | grep -i "^mprserv.dll$")
if [ ! -z ${mprserv_dll} -a -e "/mnt/w98/${dossier_w98}/${dossier_system}/${mprserv_dll}" ]; then
	mv "/mnt/w98/${dossier_w98}/${dossier_system}/${mprserv_dll}" "/mnt/w98/${dossier_w98}/${dossier_system}/${mprserv_dll}.$(date +%Y%m%d%H%M%S)"
else
	# On écrase???
	echo -e "$COLERREUR"
	echo "La DLL n'a pas été trouvée???"

	liste=$(ls -1 /mnt/w98/${dossier_w98}/${dossier_system} | grep -i "^mprserv.dll")
	if [ ! -z "$liste" ]; then
		echo -e "$COLTXT"
		echo -e "Mais un ou des fichiers ressemblant à mprserv.dll ont été trouvés:"
		echo -e "$COLCMD\c"
		ls -1 /mnt/w98/${dossier_w98}/${dossier_system} | grep -i "^mprserv.dll"
	fi

	#echo -e "$COLTXT"
	#echo "Appuyez sur ENTREE pour quitter..."
	#read PAUSE

	#echo -e "$COLTXT"
	#echo -e "Démontage de la partition ${COLINFO}${PART}"
	#echo -e "$COLCMD\c"
	#umount /mnt/w98
	#exit

	POURSUIVRE
fi

if [ "$REPONSE" = "1" ]; then
	echo -e "$COLTXT"
	echo "Mise en place de la DLL grisant le champ domaine..."
	echo -e "$COLCMD\c"
	cp /mnt/cdrom/${dossier_cd}/grise/mprserv.dll /mnt/w98/${dossier_w98}/${dossier_system}/
else
	echo -e "$COLTXT"
	echo "Mise en place de la DLL rétablissant le champ domaine..."
	echo -e "$COLCMD\c"
	cp /mnt/cdrom/${dossier_cd}/standard/mprserv.dll /mnt/w98/${dossier_w98}/${dossier_system}/
fi

echo -e "$COLTXT"
echo -e "Démontage de la partition ${COLINFO}${PART}"
echo -e "$COLCMD\c"
umount /mnt/w98

echo -e "$COLTITRE"
echo "Terminé!"

if [ "$interactif" = "y" ]; then
	echo -e "$COLTXT"
	echo "Appuyez sur une touche pour quitter."
	read PAUSE
else
	sleep 1
	if [ "$auto_reboot" = "y" ]; then
		reboot
	fi
	read PAUSE
fi

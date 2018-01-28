#!/bin/sh

# Script de lecture de la DOC HTML incluse sur le multiboot
# Dernière modification: 17/05/2012

source /bin/crob_fonctions.sh

# **********************************
# Version adaptée à System Rescue CD
# **********************************

#Couleurs
COLTITRE="\033[1;35m"	# Rose
COLPARTIE="\033[1;34m"	# Bleu

COLTXT="\033[0;37m"	# Gris
COLCHOIX="\033[1;33m"	# Jaune
COLDEFAUT="\033[0;33m"	# Brun-jaune
COLSAISIE="\033[1;32m"	# Vert

COLCMD="\033[1;37m"	# Blanc

COLERREUR="\033[1;31m"	# Rouge
COLINFO="\033[0;36m"	# Cyan

ERREUR()
{
	echo -e "$COLERREUR"
	echo "ERREUR!"
	echo -e "$1"
	echo -e "$COLTXT"
	read PAUSE
	exit 0
}

echo -e "$COLTITRE"
echo "*******************************************"
echo "* Lecture de la documentation HTML sur CD *"
echo "*******************************************"

echo -e "$COLINFO"
echo "La doc de ce multiboot est situee dans ${mnt_cdrom}/doc/"
echo ""
echo "La documentation officielle SysRescCD n'est a jour"
echo "que sur le site officiel en ligne."

echo -e "$COLCMD"
if ! ls ${mnt_cdrom}/doc > /dev/null; then
	echo -e "${COLERREUR}Vous avez booté en mode cdcache!"
	echo "Veuillez réinsérer le CD SysRescCD."

	read PAUSE

	echo -e "$COLTXT"
	echo "Voici la liste des lecteurs/graveurs CD/DVD-ROM repérés sur votre machine:"
	echo -e "$COLCMD"
	dmesg | grep hd | grep drive | grep -v driver | grep -v Cache | grep ROM
	dmesg | grep sd | grep SCSI | grep ROM
	#dmesg | grep sd | grep drive | grep -v driver | grep -v Cache | grep ROM

	echo -e "$COLTXT"
	echo "Dans quel lecteur se trouve le CD?"
	echo " (probablement hda, hdb, hdc, hdd,...)"
	echo -e "Lecteur de CD: [${COLDEFAUT}hdc${COLTXT}] $COLSAISIE\c"
	read CDDRIVE

	if [ -z "$CDDRIVE" ]; then
		CDDRIVE="hdc"
	fi

	echo -e "$COLCMD"
	mount -t iso9660 /dev/$CDDRIVE ${mnt_cdrom} || ERREUR "Le montage du CDROM est un échec!"
fi

#echo -e "$COLTXT"
#echo -e "Avez-vous booté en mode 'nofb' (${COLCHOIX}1${COLTXT}) ou avec framebuffer (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
#read GRAPHIC

#if [ -z "$GRAPHIC" ]; then
#	GRAPHIC=1
#fi

#if [ "$GRAPHIC" == "1" ]; then
#	/usr/bin/lynx ${mnt_cdrom}/manual/french/html/index.html
#	#/usr/bin/links ${mnt_cdrom}/manual/french/html/index.html
#else
	#/usr/bin/links -g ${mnt_cdrom}/manual/french/html/index.html

	#DESKTOP_SESSION=xfce

	if [ -z "$WMAKER_BIN_NAME" -a -z "$DESKTOP_SESSION" ]; then
		sed -i "s|.*exec /root/winmgr.sh >/dev/null 2>&1|exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc
		sed -i "s|exec /root/winmgr.sh >/dev/null 2>&1|${web_browser_avec_chemin} ${mnt_cdrom}/doc/index.html \& exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc
	
		#CONFXORG
	
		startx
	else
		#${web_browser_avec_chemin} ${mnt_cdrom}/manual/french/html/index.html
		${web_browser_avec_chemin} ${mnt_cdrom}/doc/index.html
	fi
#fi

echo -e "${COLTITRE}"
echo -e "Retour au menu!"
echo -e "${COLTXT}"
echo -e "Appuyez sur ENTREE..."
read PAUSE


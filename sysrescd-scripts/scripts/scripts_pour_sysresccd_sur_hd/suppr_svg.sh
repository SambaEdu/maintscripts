#!/bin/sh

# Script de suppression d'image partimage
# Version du: 01/11/2007

COLPARTIE="\033[1;34m"
COLINFO="\033[0;33m"
COLTITRE="\033[1;35m"
COLTXT="\033[0;37m"
COLCMD="\033[1;37m"
COLSAISIE="\033[1;32m"
COLERREUR="\033[1;31m"
COLCHOIX="\033[1;33m"
COLDEFAUT="\033[0;33m"

# Variables:
#PARDOS=hda1
#SYSRESCDPART=hda2
source /etc/parametres_svgrest.sh

echo -e "$COLPARTIE"
echo "********************************"
echo "* Suppression d'une sauvegarde *"
echo "********************************"

AUTRESUPPR=""
REPSUPPR="o"
while [ "$REPSUPPR" = "o" ]
do
	if [ -z "$1" -o "$AUTRESUPPR" = "o" ]; then
		#VOLUME_DISPO=$(df -h 2> /dev/null | grep /dev/$SYSRESCDPART | tr "\t" " " | sed -e "s| \{1,\}| |g" | cut -d" " -f4)
		# Le "df -h" n indique pas de /dev/$SYSRESCDPART,
		# mais un tmpfs et une autre ligne commence par tmpfs
		# Je recherche donc l espace disponible sur ce qui est monté en / (la racine)
		VOLUME_DISPO=$(df -h 2> /dev/null | tr "\t" " " | grep " /$" | sed -e "s| \{1,\}| |g" | cut -d" " -f4)

		echo -e "${COLTXT}"
		echo -e "L'espace disponible est: ${COLCMD}${VOLUME_DISPO}"

		echo -e "${COLTXT}"
		echo "Les sauvegardes existantes sont:"
		echo -e "${COLCMD}"
		find ${EMPLACEMENT_SVG}/ -name "*.${SUFFIXE_SVG}" | sed -e "s|${EMPLACEMENT_SVG}/||g" | while read A
		do
			#nbpoint=$(($(echo $A | wc -m)-$(echo $A | sed -e "s|\.||g"| wc -m)))
			#prefixe=$(echo $A | cut -d"." -f$nbpoint)
			prefixe=$(echo $A | sed -e "s|.${SUFFIXE_SVG}$||g")
			chaine=""
			du -sh ${EMPLACEMENT_SVG}/$prefixe.* | tr "\t" " " | cut -d" " -f1 | while read B
			do
				chaine="$chaine + $B"
				echo "${chaine:3}" > /tmp/chaine_volume_tmp.txt
			done
			#chaine=$(cat /tmp/chaine_volume_tmp.txt)
			#Bizarre: Sur certains postes, il est arrivé que pour la première sauvegarde
			#le fichier /tmp/chaine_volume_tmp.txt ne soit pas créé.
			#D où affichage d une erreur sur la commande cat
			#et non affichage du volume.
			if [ -e "/tmp/chaine_volume_tmp.txt" ]; then
				chaine=$(cat /tmp/chaine_volume_tmp.txt)
			else
				chaine=$(du -sh "${EMPLACEMENT_SVG}/$A")
				chaine="$chaine (volume non garanti)"
			fi
			rm -f /tmp/chaine_volume_tmp.txt
			echo -e "$A (${COLINFO}${chaine}${COLCMD})"
		done
	fi

	echo -e "${COLTXT}"
	echo "Quelle sauvegarde souhaitez-vous supprimer?"
	echo "(taper le nom du fichier sans l'extension .${SUFFIXE_SVG})"

	#==========================================================
	# Pour contourner le problème de la complétion non assurée:
	if [ ! -z "$PATH" ]; then
		PATH="$PATH:${EMPLACEMENT_SVG}"
	else
		PATH="${EMPLACEMENT_SVG}"
	fi
	export PATH
	#==========================================================

	cd ${EMPLACEMENT_SVG}
	echo -e "${COLSAISIE}\c"
	read -e NOMSUPPRIMAGE

	if [ ! -e "${EMPLACEMENT_SVG}/${NOMSUPPRIMAGE}.${SUFFIXE_SVG}" ]; then
		echo -e "${COLERREUR}"
		echo "ERREUR!"
		echo "La sauvegarde proposée n'existe pas."
	else
		if [ -e "${EMPLACEMENT_SVG}/${NOMSUPPRIMAGE}.txt" ]; then
			echo -e "${COLTXT}"
			echo -e "Vous souhaitez supprimer la sauvegarde ${COLINFO}${NOMSUPPRIMAGE}"
			echo -e "${COLTXT}Voici le commentaire saisi pour cette sauvegarde:${COLINFO}"
			more ${EMPLACEMENT_SVG}/${NOMSUPPRIMAGE}.txt

			echo -e "${COLTXT}"
			echo "Appuyez sur ENTREE..."
			read PAUSE
		fi

		POURSUIVRE=""
		while [ "$POURSUIVRE" != "1" -a "$POURSUIVRE" != "2" ]
		do
			echo -e "${COLTXT}"
			echo "Les fichiers suivants vont être supprimés:"
			echo -e "${COLCMD}\c"
			ls -1 ${EMPLACEMENT_SVG}/${NOMSUPPRIMAGE}.*

			echo -e "${COLTXT}"
			echo -e "Peut-on procéder à la suppression (${COLCHOIX}1${COLTXT}) ou préférez-vous corriger (${COLCHOIX}2${COLTXT})? ${COLSAISIE}\c"
			read POURSUIVRE
		done

		if [ "$POURSUIVRE" = "1" ]; then
			echo -e "${COLTXT}"
			echo -e "Suppression de ${COLINFO}${NOMSUPPRIMAGE}.*"
			echo -e "${COLCMD}\c"
			rm -f ${EMPLACEMENT_SVG}/${NOMSUPPRIMAGE}.*
		fi
	fi

	#VOLUME_DISPO=$(df -h 2> /dev/null | grep /dev/$SYSRESCDPART | tr "\t" " " | sed -e "s| \{1,\}| |g" | cut -d" " -f4)
	# Le "df -h" n indique pas de /dev/$SYSRESCDPART,
	# mais un tmpfs et une autre ligne commence par tmpfs
	# Je recherche donc l espace disponible sur ce qui est monté en / (la racine)
	VOLUME_DISPO=$(df -h 2> /dev/null | tr "\t" " " | grep " /$" | sed -e "s| \{1,\}| |g" | cut -d" " -f4)

	echo -e "${COLTXT}"
	echo -e "L'espace disponible est: ${COLCMD}${VOLUME_DISPO}"

	REPSUPPR=""
	while [ "$REPSUPPR" != "o" -a "$REPSUPPR" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous supprimer une autre sauvegarde? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
		read REPSUPPR
	done

	if [ "$REPSUPPR" = "o" ]; then
		AUTRESUPPR="o"
	fi
done

echo -e "$COLTITRE"
echo "Suppression(s) terminée(s)."
echo -e "${COLTXT}"
echo "Appuyez sur ENTREE."
read PAUSE

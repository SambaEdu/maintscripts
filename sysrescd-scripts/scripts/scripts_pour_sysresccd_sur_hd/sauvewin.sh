#!/bin/bash

# Script de sauvegarde
# Version du: 30/04/2014

COLPARTIE="\033[1;34m"
COLINFO="\033[0;33m"
COLTITRE="\033[1;35m"
COLTXT="\033[0;37m"
COLCMD="\033[1;37m"
COLSAISIE="\033[1;32m"
COLERREUR="\033[1;31m"
COLCHOIX="\033[1;33m"
COLDEFAUT="\033[0;33m"


ERREUR()
{
	echo -e "$COLERREUR"
	echo "ERREUR!"
	echo -e "$1"
	echo -e "${COLTXT}"
	read PAUSE
	exit 0
}

source /bin/crob_fonctions.sh

# Variables:
#PARDOS=hda1
#SYSRESCDPART=hda2
source /etc/parametres_svgrest.sh

echo -e "${COLPARTIE}"
echo "**************************************************"
echo "*      Sauvegarde de la partition /dev/${PARDOS}      *"
echo "**************************************************"

echo -e "${COLCMD}\c"
#mkdir -p ${EMPLACEMENT_SVG}
if [ ! -e "${EMPLACEMENT_SVG}" ]; then
	mkdir -p /oscar && ln -s /oscar ${EMPLACEMENT_SVG}
else
	if [ ! -h "${EMPLACEMENT_SVG}" ]; then
		mkdir -p /oscar && mv ${EMPLACEMENT_SVG}/* /oscar/ && rm -fr ${EMPLACEMENT_SVG} && ln -s /oscar ${EMPLACEMENT_SVG}
	fi
fi

#VOLUME_DISPO=$(df -h 2> /dev/null | grep /dev/$SYSRESCDPART | tr "\t" " " | sed -e "s| \{1,\}| |g" | cut -d" " -f4)
# Le "df -h" n indique pas de /dev/$SYSRESCDPART,
# mais un tmpfs et une autre ligne commence par tmpfs
# Je recherche donc l'espace disponible sur ce qui est monte en / (la racine)
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
	#Bizarre: Sur certains postes, il est arrive que pour la premiere sauvegarde
	#le fichier /tmp/chaine_volume_tmp.txt ne soit pas cree.
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

if [ "${svgrest_auto}" = "y" ]; then
	echo -e "${COLTXT}"
	echo -e "Dans 10 secondes, une sauvegarde automatique vers ${COLDEFAUT}${NOM_IMAGE_DEFAUT}${COLTXT} va etre"
	echo -e "lancee, sauf si vous tapez ${COLCHOIX}i${COLTXT} (i pour interactif)."
	echo -e "Mode: [${COLDEFAUT}auto${COLTXT}] ${COLSAISIE}\c"
	read -t 10 REPAUTO

	if [ -z "$REPAUTO" ]; then
		REPAUTO="auto"
	fi
else
	REPAUTO="i"
fi

if [ "$REPAUTO" = "i" ]; then
	REPONSE=""
	while [ "${REPONSE}" != "o" -a "${REPONSE}" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous supprimer une sauvegarde existante pour faire de la place"
		echo -e "avant de proceder a une nouvelle sauvegarde? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		/bin/suppr_svg.sh BIDON
	fi

	sleep 1

	echo -e "${COLTXT}"
	#if [ $(cat /etc/svgrest_arret_ou_reboot.txt) = "arret" ]; then
	if [ "${svgrest_arret_ou_reboot}" = "arret" ]; then
		echo -e "Apres la sauvegarde le poste va s eteindre."
		CHOIX_DEFAUT_FIN=2
	else
		echo -e "Apres la sauvegarde le poste va rebooter."
		CHOIX_DEFAUT_FIN=1
	fi
	REPFIN=""
	while [ "$REPFIN" != "1" -a "$REPFIN" != "2" ]
	do
		echo -e "${COLTXT}"
		echo "Souhaitez-vous confirmer cette action ou preferez-vous l'action alternative?"
		echo -e " (${COLCHOIX}1${COLTXT}) reboot"
		echo -e " (${COLCHOIX}2${COLTXT}) halt"
		echo -e "Votre choix: [${COLDEFAUT}$CHOIX_DEFAUT_FIN${COLTXT}] ${COLSAISIE}\c"
		read REPFIN

		if [ -z "$REPFIN" ]; then
			REPFIN=$CHOIX_DEFAUT_FIN
		fi
	done

	if [ "$REPFIN" = "1" ]; then
		ACTIONFIN="reboot"
	else
		ACTIONFIN="halt"
	fi

	sleep 1

	HD=$(echo ${PARDOS}|sed -e "s|[0-9]||g")
	#if [ ! -e ${EMPLACEMENT_SVG}/${HD}_premiers_MO.bin ]; then
		echo -e "${COLTXT}"
		echo "Sauvegarde des 5 premiers Mo du disque."
		echo -e "${COLCMD}\c"
		dd if="/dev/${HD}" of="${EMPLACEMENT_SVG}/${HD}_premiers_MO.bin" bs=1M count=5
	#fi

	NOMIMAGE=""
	while [ -z "${NOMIMAGE}" ]
	do
		echo -e "${COLTXT}"
		echo -e "Veuillez saisir le nom de la sauvegarde"
		echo -e "${COLTXT}(ou ENTREE pour le choix par defaut). [${COLDEFAUT}${NOM_IMAGE_DEFAUT}${COLTXT}]"
		echo -e "${COLTXT}Image: ${COLSAISIE}\c"
		cd ${EMPLACEMENT_SVG}
		read -e NOMIMAGE
		if [ -z "${NOMIMAGE}" ]; then
			NOMIMAGE="${NOM_IMAGE_DEFAUT}"
		fi

		tmp_test=$(echo "${NOMIMAGE}" | tr "-" "_" | sed -e "s/[A-Za-z0-9_.]//g" | wc -m)
		if [ "$tmp_test" != 1 ]; then
			echo -e "${COLERREUR}La chaine ${COLINFO}${NOMIMAGE}${COLERREUR} contient des caracteres non valides."
			echo -e "Limitez-vous aux caracteres alphanumeriques sans accents plus le point"
			echo -e "et le tiret bas."
			NOMIMAGE=""
		fi

		if [ ! -e "$(dirname ${EMPLACEMENT_SVG}/${NOMIMAGE})" ]; then
			echo -e "${COLERREUR}Le chemin ${COLINFO}$(dirname ${EMPLACEMENT_SVG}/${NOMIMAGE})${COLERREUR} n'existe pas."
			NOMIMAGE=""
		fi

	done
	# Suppression de la sauvegarde precedente du meme nom.
	if [ -e "${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}" ]; then
		echo -e "${COLTXT}"
		echo -e "Suppression de la sauvegarde precedente du meme nom."
		echo -e "${COLCMD}\c"
		rm -f ${EMPLACEMENT_SVG}/${NOMIMAGE}.*
	fi

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous creer un fichier de commentaires? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] ${COLSAISIE}\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="o"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		echo -e "${COLTXT}"
		echo "Tapez vos commentaires, eventuellement sur plusieurs lignes"
		echo "et pour finir, tapez une ligne ne contenant que le mot \"FIN\"."
		if [ -e "${EMPLACEMENT_SVG}/${NOMIMAGE}.txt" ]; then
			rm -f ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt
		fi
		touch ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt
		LIGNE=""
		echo -e "${COLSAISIE}"
		while [ "$LIGNE" != "FIN" ]
		do
			read LIGNE
			echo "$LIGNE" >> ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt
		done

		cat ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt | sed -e "s/^FIN$//g" > ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt.tmp
		cp -f ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt.tmp ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt
		rm -f ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt.tmp

		echo -e "${COLTXT}"
		echo "Vous avez saisi:"
		echo -e "${COLCMD}"
		cat ${EMPLACEMENT_SVG}/${NOMIMAGE}.txt

		echo -e "${COLTXT}"
		echo "Appuyez sur ENTREE pour poursuivre."
		read PAUSE
	fi
else
	NOMIMAGE=${NOM_IMAGE_DEFAUT}

	# Suppression de la sauvegarde precedente du meme nom.
	if [ -e "${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}" ]; then
		echo -e "${COLTXT}"
		echo -e "Suppression de la sauvegarde precedente du meme nom."
		echo -e "${COLCMD}\c"
		rm -f ${EMPLACEMENT_SVG}/${NOMIMAGE}.*
	fi

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	echo "Sauvegarde lancee le $ladate" > "${EMPLACEMENT_SVG}/${NOMIMAGE}.txt"

	#if [ $(cat /etc/svgrest_arret_ou_reboot.txt) = "arret" ]; then
	if [ "${svgrest_arret_ou_reboot}" = "arret" ]; then
		ACTIONFIN="halt"
	else
		ACTIONFIN="reboot"
	fi
fi

echo -e "${COLTXT}"
echo "Sauvegarde des 5 premiers Mo de la partition."
echo "(en principe inutile)"
echo -e "${COLCMD}\c"
dd if="/dev/${PARDOS}" of="${EMPLACEMENT_SVG}/${NOMIMAGE}_premiers_MO.bin" bs=1M count=5

if [ -n "$PARBOOTDOS" -a "$PARBOOTDOS" != "$PARDOS" ]; then
	if [ -z "$SVG_PARBOOTDOS" ]; then
		SVG_PARBOOTDOS="o"
	fi

	echo -e "$COLTXT"
	echo "Voulez-vous sauvegarder la partition de boot W$ ?"
	echo -e "Dans 20 secondes on poursuivra avec le choix ${COLCHOIX}$SVG_PARBOOTDOS"
	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Choix: (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${SVG_PARBOOTDOS}${COLTXT}] ${COLSAISIE}\c"
		read -t 20 REP

		if [ -z "$REP" ]; then
			REP="$SVG_PARBOOTDOS"
		fi
	done
	
	if [ "$REP" = "o" ]; then
		echo -e "$COLTXT"
		echo "Lancement de la sauvegarde de la partition de boot W$..."
		sleep 1
		echo -e "$COLCMD\c"
		ladate=$(date "+%Y%m%d-%H%M%S")

		DETECTED_TYPE=$(TYPE_PART $PARBOOTDOS)
		if [ "$DETECTED_TYPE" = "ntfs" ]; then
			echo "gzip" > ${EMPLACEMENT_SVG}/${PARBOOTDOS}.$ladate.type_compression.txt
			$chemin_ntfs/ntfsclone --save-image -o - /dev/${PARBOOTDOS} | gzip -c  | split -b 650m - ${EMPLACEMENT_SVG}/${PARBOOTDOS}.$ladate.ntfs
			if [ "$?" = "0" ]; then
				echo -e "$COLTXT"
				echo "SUCCES de la sauvegarde"

				echo "cat ${EMPLACEMENT_SVG}/${PARBOOTDOS}.$ladate.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$PARBOOTDOS - " > ${EMPLACEMENT_SVG}/restaure_$PARBOOTDOS.$ladate.sh
				chmod +x ${EMPLACEMENT_SVG}/restaure_$PARBOOTDOS.$ladate.sh
			else
				echo -e "$COLERREUR"
				echo "ECHEC de la sauvegarde"
			fi
		else
			partimage -b -c -d -f3 -o -z1 save /dev/$PARBOOTDOS ${EMPLACEMENT_SVG}/$PARBOOTDOS.$ladate
			if [ "$?" = "0" ]; then
				echo -e "$COLTXT"
				echo "SUCCES de la sauvegarde"
			fi

			echo "partimage -b -f3 restore /dev/$PARBOOTDOS ${EMPLACEMENT_SVG}/$PARBOOTDOS.$ladate" > ${EMPLACEMENT_SVG}/restaure_$PARBOOTDOS.$ladate.sh
			chmod +x ${EMPLACEMENT_SVG}/restaure_$PARBOOTDOS.$ladate.sh
		fi
	fi
fi

echo -e "${COLINFO}"
echo "Lancement de la sauvegarde..."
sleep 1
echo -e "${COLCMD}\c"

case ${TYPE_SVG} in
	"partimage")
		partimage -z1 -o -d save /dev/${PARDOS} ${EMPLACEMENT_SVG}/${NOMIMAGE} -b -f3
	;;
	"ntfsclone")
		echo "gzip" > ${EMPLACEMENT_SVG}/${NOMIMAGE}.type_compression.txt
		$chemin_ntfs/ntfsclone --save-image -o - /dev/${PARDOS} | gzip -c > ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}
	;;
	"dar")
		mkdir -p /mnt/save
		if [ ! -z "${TYPE_PARDOS_FS}" ]; then
			if [ "${TYPE_PARDOS_FS}" = "ntfs" ]; then
				mount -t ntfs-3g /dev/${PARDOS} /mnt/save
			else
				mount -t ${TYPE_PARDOS_FS} /dev/${PARDOS} /mnt/save
			fi
		else
			mount /dev/${PARDOS} /mnt/save
		fi
		$chemin_dar/dar -c ${EMPLACEMENT_SVG}/${NOMIMAGE} -s 700M -z2 -v -R /mnt/save
	;;
	"fsarchiver")
		NIVEAU_COMPRESSION=3
		option_fsarchiver="-v"
		fsarchiver -o -z$NIVEAU_COMPRESSION ${option_fsarchiver} savefs ${EMPLACEMENT_SVG}/${NOMIMAGE} /dev/${PARDOS}
	;;
esac

if [ "$?" != "0" ]; then
	if [ "$REPAUTO" = "auto" ]; then
		ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
		echo "   ... et achevee le $ladate" >> "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.txt"

		echo "ECHEC de la sauvegarde" >> "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.ECHEC.txt"
	else
		echo "ECHEC de la sauvegarde" >> "${EMPLACEMENT_SVG}/${NOMIMAGE}.ECHEC.txt"
	fi

	ERREUR "La sauvegarde a echoue.
Contrôlez si la partition n est pas pleine.
Il arrive aussi sur des partitions ext2 qu'un
	 e2fsck -p -y /dev/hdaX
soit necessaire."
else
	if [ "$REPAUTO" = "auto" ]; then
		ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
		echo "   ... et achevee le $ladate" >> "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.txt"

		echo "SUCCES de la sauvegarde" >> "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.SUCCES.txt"
	else
		echo "SUCCES de la sauvegarde" >> "${EMPLACEMENT_SVG}/${NOMIMAGE}.SUCCES.txt"
	fi

	echo -e "${COLCMD}\c"
	if [ "${TYPE_SVG}" = "dar" ]; then
		if mount | grep /mnt/save > /dev/null; then
			echo -e "${COLTXT}"
			echo "Demontage de la partition ${PARDOS}"
			echo -e "${COLCMD}\c"
			umount /mnt/save
		fi
	fi

	#Pour que la completion fonctionnne a la restauration, les images doivent etre executables:
	chmod +x ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}*
	if [ "$ACTIONFIN" = "reboot" ]; then
		echo -e "${COLTXT}"
		echo -e "La sauvegarde a reussi."
		echo -e "${COLCMD}"
		ls -lh ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}*
		echo -e "${COLTXT}"
		echo "Vous avez 5 secondes pour interrompre par CTRL+C le reboot."
		sleep 5
		echo -e "${COLTITRE}"
		echo "Reboot."
		echo -e "${COLTXT}"
	else
		echo -e "${COLTXT}"
		echo -e "La sauvegarde a reussi."
		echo -e "${COLCMD}"
		ls -lh ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}*
		echo -e "${COLTXT}"
		echo "Vous avez 5 secondes pour differer l'arret par CTRL+C."
		sleep 5
		echo -e "${COLTITRE}"
		echo "Arret."
		echo -e "${COLTXT}"
	fi
fi
$ACTIONFIN

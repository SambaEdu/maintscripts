#!/bin/bash

# Script de restauration
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

# Variables:
#PARDOS=hda1
#SYSRESCDPART=hda2
source /etc/parametres_svgrest.sh

if [ -e "/bin/crob_fonctions.sh" ]; then
	source /bin/crob_fonctions.sh
else
	POURSUIVRE_OU_CORRIGER()
	{
		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			if [ ! -z "$1" ]; then
				echo -e "$COLTXT"
				echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT}) ? [${COLDEFAUT}${1}${COLTXT}] $COLSAISIE\c"
				if [ -n "$2" ]; then
					read -t $2 REPONSE
				else
					read REPONSE
				fi

				if [ -z "$REPONSE" ]; then
					REPONSE="$1"
				fi
			else
				echo -e "$COLTXT"
				echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT}) ? $COLSAISIE\c"
				read REPONSE
			fi
		done
	}
fi

echo -e "${COLPARTIE}"
echo "**************************************************"
echo "*      Restauration de la partition /dev/${PARDOS}    *"
echo "**************************************************"


echo -e "${COLCMD}\c"
mkdir -p ${EMPLACEMENT_SVG}
cd ${EMPLACEMENT_SVG}
#liste=($(ls -t ${EMPLACEMENT_SVG}/*.${SUFFIXE_SVG} 2> /dev/null))
liste=($(ls -t *.${SUFFIXE_SVG} 2> /dev/null))
cd /root
if [ ${#liste[*]} -ge 1 ]; then
	# Une image au moins.
	NOM_IMAGE_DEFAUT=$(echo ${liste[0]} | sed -e "s/.${SUFFIXE_SVG}$//")

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

		date_et_heure=$(ls --full-time "${EMPLACEMENT_SVG}/$A" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f6,7 | cut -d"." -f1)

		if [ -e "${EMPLACEMENT_SVG}/$A.SUCCES.txt" ]; then
			echo -e "$A (${COLINFO}${chaine}${COLCMD}) (${COLINFO}${date_et_heure}${COLCMD}) (${COLINFO}reussie${COLCMD})"
		else
			if [ -e "${EMPLACEMENT_SVG}/$A.ECHEC.txt" ]; then
				echo -e "$A (${COLINFO}${chaine}${COLCMD}) (${COLINFO}${date_et_heure}${COLCMD}) (${COLERREUR}ECHEC${COLCMD})"
			else
				echo -e "$A (${COLINFO}${chaine}${COLCMD}) (${COLINFO}${date_et_heure}${COLCMD})"
			fi
		fi
	done
else
	echo -e "${COLERREUR}"
	echo -e "Aucune sauvegarde ${COLINFO}${TYPE_SVG}${COLERREUR} n'a ete trouvee dans ${COLINFO}${EMPLACEMENT_SVG}"
fi


#if [ -e "/etc/svgrest_automatique.txt" -a -e "/home/sauvegarde/image.partimage.000" ]; then
if [ "${svgrest_auto}" = "y" -a -e "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.${SUFFIXE_SVG}" ]; then
	echo -e "${COLTXT}"
	echo -e "Dans 10 secondes, une restauration automatique de ${COLDEFAUT}${NOM_IMAGE_DEFAUT}.${SUFFIXE_SVG}${COLTXT} va etre"
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
	VALTEST=""
	while [ "$VALTEST" = "" ]
	do
		echo -e "${COLTXT}"
		echo -e "Veuillez saisir le nom de la sauvegarde"
		echo -e "${COLERREUR}sans le suffixe .${SUFFIXE_SVG}"
		echo -e "${COLTXT}(ou ENTREE pour le choix par defaut): [${COLDEFAUT}${NOM_IMAGE_DEFAUT}${COLTXT}]"
		echo -e "${COLTXT}Image: ${COLSAISIE}\c"
		cd ${EMPLACEMENT_SVG}
		read -e NOMIMAGE

		if [ -z "${NOMIMAGE}" ]; then
			NOMIMAGE=${NOM_IMAGE_DEFAUT}
		fi

		if [ -e "${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}" ]; then
			#PREFIMAGE=$(echo "${NOMIMAGE}" | sed -e "s|.${SUFFIXE_SVG}$|.txt|")
			PREFIMAGE=$(echo "${NOMIMAGE}")
			if [ -e "${EMPLACEMENT_SVG}/${PREFIMAGE}.txt" ]; then
				echo -e "${COLTXT}"
				echo "Voici le contenu de ${PREFIMAGE}.txt"
				echo -e "${COLCMD}"
				cat ${EMPLACEMENT_SVG}/${PREFIMAGE}.txt | more
			fi

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Peut-on poursuivre (${COLCHOIX}o${COLTXT}) ou preferez-vous changer d image (${COLCHOIX}n${COLTXT})? [${COLDEFAUT}o${COLTXT}] ${COLSAISIE}\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="o"
				fi
			done

			if [ "$REPONSE" = "o" ]; then
				VALTEST=1
			else
				VALTEST=""
			fi
		fi
	done
	sleep 1

	echo -e "${COLTXT}"
	#if [ $(cat /etc/svgrest_arret_ou_reboot.txt) = "arret" ]; then
	if [ "${svgrest_arret_ou_reboot}" = "arret" ]; then
		echo -e "Apres la restauration le poste va s eteindre."
		CHOIX_DEFAUT_FIN=2
	else
		echo -e "Apres la restauration le poste va rebooter."
		CHOIX_DEFAUT_FIN=1
	fi

	REPFIN=""
	while [ "$REPFIN" != "1" -a "$REPFIN" != "2" ]
	do
		echo -e "${COLTXT}"
		echo "Souhaitez-vous confirmer cette action ou preferez-vous l action alternative?"
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
else
	NOMIMAGE="${NOM_IMAGE_DEFAUT}"

	# Un saut de ligne pour passer la ligne du "read NOMIMAGE"
	echo ""

	if [ -e "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.txt" ]; then
		echo -e "$COLINFO"
		echo -e "Image ${NOM_IMAGE_DEFAUT}"
		echo -e "${COLCMD}\c"
		cat "${EMPLACEMENT_SVG}/${NOM_IMAGE_DEFAUT}.txt"
		sleep 5
	fi

	#if [ $(cat /etc/svgrest_arret_ou_reboot.txt) = "arret" ]; then
	if [ "${svgrest_arret_ou_reboot}" = "arret" ]; then
		ACTIONFIN="halt"
	else
		ACTIONFIN="reboot"
	fi
fi

if [ -z "$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD" ]; then
	RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD="n"
fi

HD=$(echo ${PARDOS}|sed -e "s|[0-9]||g")
if [ -e "${EMPLACEMENT_SVG}/${HD}_premiers_MO.bin" ]; then
	echo -e "$COLERREUR"
	echo -e "EXPERIMENTAL:$COLINFO"
	echo "Les premiers Mo du disque ont ete sauvegardes."
	echo "Si le demarrage de W$ est casse, il convient de restaurer ces premiers Mo."
	echo "Sinon, cela ne doit pas etre necessaire."
	echo ""
	echo "Si vous restaurez ces premiers Mo, il est recommande de restaurer aussi"
	echo "la partition de boot W$ si elle est separee de la partition systeme W$."
	echo ""
	if [ "$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD" = "n" ]; then
		echo -e "Dans ${COLCHOIX}20 secondes${COLINFO}, on poursuivra sans les restaurer."
	else
		echo -e "Dans ${COLCHOIX}20 secondes${COLINFO}, on les restaurera."
	fi

	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous les restaurer? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD}${COLTXT}] ${COLSAISIE}\c"
		read -t 20 REP

		if [ -z "$REP" ]; then
			REP="$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD"
		fi
	done

	REST_PARBOOTDOS_PAR_DEFAUT="n"
	if [ "$REP" = "o" ]; then
		echo -e "$COLTXT"
		echo "Restauration des premiers Mo du disque."
		echo -e "$COLCMD"
		dd if="${EMPLACEMENT_SVG}/${HD}_premiers_MO.bin" of=/dev/${HD} bs=1M count=5
		REST_PARBOOTDOS_PAR_DEFAUT="o"
	fi
fi

if [ -n "$PARBOOTDOS" -a "$PARBOOTDOS" != "$PARDOS" ]; then
	DEFAULT_PARBOOTDOS_SVG=$(ls -t ${EMPLACEMENT_SVG}/$PARBOOTDOS.*.000 2>/dev/null | head -n1)

	if [ -n "$DEFAULT_PARBOOTDOS_SVG" ]; then
		DEFAULT_PARBOOTDOS_SVG=$(basename $DEFAULT_PARBOOTDOS_SVG)

		echo -e "$COLINFO"
		echo "La partition de boot $PARBOOTDOS a ete sauvegardee."
		echo -e "$COLCMD\c"
		ls -t ${EMPLACEMENT_SVG}/$PARBOOTDOS.*.000

		echo -e "$COLTXT"
		echo "Souhaitez vous la restaurer d'apres un de ces fichiers? "
		echo ""
		if [ "$REST_PARBOOTDOS_PAR_DEFAUT" = "o" ]; then
			echo "Comme vous avez restaure les premiers Mo du disque,"
			echo -e "dans ${COLCHOIX}20 secondes${COLTXT}, on restaurera aussi la partition de boot W$."
		else
			echo -e "Dans ${COLCHOIX}20 secondes${COLTXT}, on poursuivra sans la restaurer."
		fi
		REP=""
		while [ "$REP" != "o" -a "$REP" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous choisir un de ces fichiers de sauvegarde? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${REST_PARBOOTDOS_PAR_DEFAUT}${COLTXT}] ${COLSAISIE}\c"
			read -t 20 REP

			if [ -z "$REP" ]; then
				REP="$REST_PARBOOTDOS_PAR_DEFAUT"
			fi
		done

		if [ "$REP" = "o" ]; then

			REPONSE=""
			while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
			do
				echo -e "$COLTXT"
				echo -e "Fichier: [${COLDEFAUT}${DEFAULT_PARBOOTDOS_SVG}${COLTXT}] ${COLSAISIE}\c"
				cd ${EMPLACEMENT_SVG}
				read -e -t 20 FICH_BOOT

				if [ -z "$FICH_BOOT" ]; then
					FICH_BOOT=${DEFAULT_PARBOOTDOS_SVG}
				fi
				
				POURSUIVRE_OU_CORRIGER "1" 20
			done

			echo -e "$COLTXT"
			echo "Restauration de la partition de boot W$."
			echo -e "$COLCMD"
			partimage -b -f3 restore /dev/$PARBOOTDOS ${EMPLACEMENT_SVG}/$FICH_BOOT
			if [ "$?" != "0" ]; then
				echo -e "$COLERREUR"
				echo "Il s'est produit une erreur lors de la restauration."

				echo -e "$COLTXT"
				echo "Appuyez sur ENTREE pour poursuivre neanmoins..."
				read PAUSE
			fi
		fi

	fi
fi

if [ -e "${EMPLACEMENT_SVG}/${NOMIMAGE}_premiers_MO.bin" ]; then
	echo -e "$COLERREUR"
	echo -e "EXPERIMENTAL:$COLINFO"
	echo "Les premiers Mo de la partition ont ete sauvegardes."
	echo "Il n'est normalement pas necessaire de les restaurer."
	echo ""
	echo -e "Dans ${COLCHOIX}20 secondes${COLINFO}, on poursuivra sans les restaurer."

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
		dd if="${EMPLACEMENT_SVG}/${NOMIMAGE}_premiers_MO.bin" of=/dev/${PARDOS} bs=1M count=5
	fi
fi


case ${TYPE_SVG} in
	"partimage")
		echo -e "$COLINFO"
		echo "Lancement de la restauration..."
		sleep 1
		echo -e "${COLCMD}"
		partimage restore /dev/${PARDOS} ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG} -b -f3
	;;
	"ntfsclone")
		echo -e "$COLINFO"
		echo "Lancement de la restauration..."
		sleep 1
		echo -e "${COLCMD}"
		#echo "gzip" > ${EMPLACEMENT_SVG}/${NOMIMAGE}.type_compression.txt
		#$chemin_ntfs/ntfsclone --save-image -o - /dev/${PARDOS} | gzip -c > ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}
		TYPE_COMPRESS=$(cat ${EMPLACEMENT_SVG}/${NOMIMAGE}.type_compression.txt)
		case $TYPE_COMPRESS in
			"aucune")
				cat ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/${PARDOS} -
			;;
			"gzip")
				cat ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/${PARDOS} -
			;;
			"bzip2")
				cat ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG}* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/${PARDOS} -
			;;
		esac
	;;
	"dar")
		if [ "$REPAUTO" = "auto" ]; then
			REPONSE="o"
		else
			REPONSE=""
		fi

		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Voulez-vous vider la partition avant de lancer la restauration? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
			read REPONSE
		done

		echo -e "${COLTXT}"
		echo -e "Montage de la partition..."
		echo -e "${COLCMD}\c"
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

		if [ "$REPONSE" = "o" ]; then
			echo -e "${COLTXT}"
			echo -e "Suppression du contenu de la partition avant restauration..."
			echo -e "${COLCMD}\c"
			rm -fr /mnt/save/*
		fi

		echo -e "$COLINFO"
		echo "Lancement de la restauration..."
		echo -e "${COLCMD}\c"
		sleep 1
		echo -e "${COLCMD}"
		$chemin_dar/dar -x ${EMPLACEMENT_SVG}/${NOMIMAGE} -R /mnt/save -b -wa -v

	;;
	"fsarchiver")
		echo -e "$COLINFO"
		echo "Lancement de la restauration..."
		sleep 1
		echo -e "${COLCMD}"
		fsarchiver -v restfs ${EMPLACEMENT_SVG}/${NOMIMAGE}.${SUFFIXE_SVG} id=0,dest=/dev/${PARDOS}
	;;
esac


if [ "$?" != "0" ]; then
	ERREUR "La restauration a echoue.
Il arrive sur des partitions ext2 qu un
	e2fsck -p -y /dev/hdaX
soit necessaire."
else

	echo -e "${COLCMD}\c"
	if [ "${TYPE_SVG}" = "dar" ]; then
		if mount | grep /mnt/save > /dev/null; then
			echo -e "${COLTXT}"
			echo "Demontage de la partition ${PARDOS}"
			echo -e "${COLCMD}\c"
			umount /mnt/save
		fi
	fi

	echo -e "${COLTXT}"
	if [ "$ACTIONFIN" = "reboot" ]; then
		echo -e "La restauration a reussi.
Vous avez 5 secondes pour interrompre par CTRL+C le reboot."
		sleep 5
		echo -e "${COLTITRE}"
		echo "Reboot."
		echo -e "${COLTXT}"
	else
		echo -e "La restauration a reussi.
Vous avez 5 secondes pour differer l'arret par CTRL+C."
		sleep 5
		echo -e "${COLTITRE}"
		echo "Arret."
		echo -e "${COLTXT}"
	fi
fi
$ACTIONFIN

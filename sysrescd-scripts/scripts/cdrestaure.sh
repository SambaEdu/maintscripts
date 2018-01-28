#!/bin/sh

# Script lancé par un CD/DVD CDRESTAURE
# pour effectuer une restauration d'image située dans /mnt/cdrom/save/
# et effectuée par un script restaure.sh dans /mnt/cdrom/save/
# Derniere modification: 10/11/2012

#source /bin/crob_fonctions.sh

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

echo -e "$COLTITRE"
echo "**************************"
echo "* Script de restauration *"
echo "**************************"

echo -e "$COLTXT"
echo "Voici la liste des lecteurs/graveurs CD/DVD-ROM repérés sur votre machine:"
echo -e "$COLCMD"
TEMOIN=""
if dmesg | grep hd | grep drive | grep -v driver | grep ROM | grep Cache; then
	TEMOIN="OK"
fi

#dmesg | grep sd | grep drive | grep -v driver | grep -v ROM
if dmesg | grep sd | grep SCSI | grep ROM; then
	TEMOIN="OK"
fi

if [ "$TEMOIN" != "OK" ]; then
	#Sur les IBM Thinkpad, les commandes précédentes ne donnent rien alors que /dev/hda est bien présent.
	#dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"
	if dmesg | grep dev | grep host | grep bus | grep target | grep lun >/dev/null; then
		dmesg | grep dev | grep host | grep bus | grep target | grep lun | cut -d ":" -f 1 | sed -e "s/ //g" | sed -e "s|ide/host0/bus0/target0/lun0|hda|g" | sed -e "s|ide/host0/bus0/target1/lun0|hdb|g" | sed -e "s|ide/host0/bus1/target0/lun0|hdc|g" | sed -e "s|ide/host0/bus1/target1/lun0|hdd|g"
		TEMOIN="OK"
	fi
	#Une alternative sera: ls /dev/hd*
fi

if [ "$TEMOIN" != "OK" ]; then
	if ls /dev/hd* 2> /dev/null | grep -v "[0-9]" > /dev/null; then
		ls /dev/hd* 2> /dev/null | grep -v "[0-9]" | sed -e "s|/dev/||g"
		LECTDEFAUT=""
	fi

	if dmesg | grep sr0 > /dev/null; then
		dmesg | grep --color sr0
		LECTDEFAUT="sr0"
	fi
else
	LISTE=($(dmesg | grep hd | grep drive | grep -v driver | grep ROM | grep Cache))
	LECTDEFAUT=$(echo ${LISTE[0]} | cut -d":" -f1)
fi

if [ -z "${LECTDEFAUT}" ]; then
	#LECTDEFAUT="hdc"
	LECTDEFAUT="sr0"
fi

echo -e "$COLTXT"
echo "Dans quel lecteur se trouve le CD/DVD de restauration?"
echo " (probablement sr0, hda, hdb, hdc, hdd,...)"
echo -e "Lecteur de CD/DVD: [${COLDEFAUT}${LECTDEFAUT}${COLTXT}] $COLSAISIE\c"
read CDDRIVE

if [ -z "${CDDRIVE}" ]; then
	CDDRIVE=${LECTDEFAUT}
fi

temoin_cd=""

t=$(mount | egrep "(/mnt/cdrom|/livemnt/boot type iso9660)")
#if mount | grep /mnt/cdrom > /dev/null; then
if [ -n "$t" ]; then
	t1=$(ls /mnt/cdrom/save/*.out 2>/dev/null)
	t2=$(ls /livemnt/boot/save/*.out 2>/dev/null)
	if [ -n "$t1" -o -n "$t2" ]; then
		DEFAULT_CHANGE_CD="n"
	else
		DEFAULT_CHANGE_CD="o"
	fi

	temoin_cd="o"
	echo -e "$COLINFO"
	echo "Il semble qu'un média soit déjà monté en /mnt/cdrom"
	echo "ou /livemnt/boot"
	echo "Si vous avez booté avec l'option 'docache' et si vous souhaitez changer"
	echo "de CD maintenant, il est possible de le faire."
	echo -e "$COLTXT"
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}Voulez-vous changer de CD? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${DEFAULT_CHANGE_CD}${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=${DEFAULT_CHANGE_CD}
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		echo -e "$COLTXT"
		echo "Démontage du CD..."
		echo -e "$COLCMD\c"
		if mount | grep /mnt/cdrom > /dev/null; then
			umount /mnt/cdrom
			chemin_cd="/mnt/cdrom"
		else
			umount /livemnt/boot
			# Au cas ou le demontage echouerait:
			chemin_cd="/livemnt/boot"
		fi

		if [ "$?" = "0" ]; then
			echo -e "$COLTXT"
			echo "Vous pouvez maintenant éjecter le CD/DVD pour en insérer un autre."
			temoin_cd="n"
		else
			echo -e "$COLERREUR"
			echo "Le CD/DVD n'a pas pu être démonté."
			echo -e "$COLINFO\c"
			echo "Vous n'avez pas booté avec l'option 'docache'"
			echo "ou bien la copie en RAM du système a échoué"
			echo "(la machine n'a peut-être pas suffisamment de RAM)."
		fi

		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour poursuivre, ou sur CTRL+C pour interrompre le script."
		read PAUSE
	else
		if mount | grep /mnt/cdrom > /dev/null; then
			chemin_cd="/mnt/cdrom"
		else
			chemin_cd="/livemnt/boot"
		fi
	fi
else
	temoin_cd="n"
fi

if [ ${temoin_cd} = "n" ]; then
	echo -e "$COLTXT"
	echo "Création du point de montage /mnt/cdrom..."
	echo -e "$COLCMD\c"
	echo "mkdir -p /mnt/cdrom"
	mkdir -p /mnt/cdrom

	echo -e "$COLINFO"
	echo "Si le CD/DVD est déjà monté, il se peut que des erreurs s'affichent."
	echo "Elles sont sans conséquences."
	echo "Elles indiquent seulement que le CD/DVD est déjà monté."

	echo -e "$COLTXT"
	echo "Montage du CD/DVD..."
	echo -e "$COLCMD\c"
	echo "mount -t iso9660 /dev/${CDDRIVE} /mnt/cdrom"
	mount -t iso9660 /dev/${CDDRIVE} /mnt/cdrom

	chemin_cd="/mnt/cdrom"
fi

echo -e "$COLTXT"
echo -e "Si le CD/DVD est bien monté, tapez ${COLCHOIX}OK${COLTXT} (en majuscules)"
echo -e "pour lancer la restauration: $COLSAISIE\c"
read REPONSE

#if [ -e "" ]; then
#chemin_cd

if [ "$REPONSE" = "OK" ]; then
#if echo "$REPONSE" | grep "^OK$" > /dev/null; then
	#cd /mnt/cdrom/save/
	#./restaure.sh
	echo -e "$COLCMD"
	#cp /mnt/cdrom/save/restaure.sh /tmp/
	#cp ${chemin_cd}/save/restaure.sh /tmp/
	if [ -e ${chemin_cd}/save/restaure.sh ]; then
		cp ${chemin_cd}/save/restaure.sh /tmp/
	else
		if [ -e /livemnt/boot/save/restaure.sh ]; then
			cp /livemnt/boot/save/restaure.sh /tmp/
			chemin_cd="/livemnt/boot"
		else
			if [ -e /mnt/cdrom/save/restaure.sh ]; then
				cp /mnt/cdrom/save/restaure.sh /tmp/
				chemin_cd="/mnt/cdrom"
			else
				echo -e "$COLERREUR"
				echo "ANOMALIE: Le script restaure.sh n'a ete trouve ni en"
				echo "             /livemnt/boot/save/restaure.sh"
				echo "          ni en"
				echo "             /mnt/cdrom/save/restaure.sh"

				while [ ! -e "$chemin_cd/save/restaure.sh" ]
				do
					echo -e "$COLTXT"
					echo "Ou est monte le CD/DVD?"
					echo "Donner le chemin sans le suffixe /save/restaure.sh"
					echo -e "Chemin: $COLSAISIE\c"
					read chemin_cd

					if [ ! -e "$chemin_cd/save/restaure.sh" ]; then
						echo -e "$COLERREUR"
						echo "$chemin_cd/save/restaure.sh n'existe pas."
					fi
				done

				echo -e "$COLCMD"
				cp $chemin_cd/save/restaure.sh /tmp/
			fi
		fi

	fi
	chmod +x /tmp/restaure.sh
	#if ls /mnt/cdrom/save/plusieurs_cd.txt; then
	if [ -e "${chemin_cd}/save/plusieurs_cd.txt" ]; then
		echo -e "$COLERREUR"
		echo "ATTENTION:"
		#echo "Pour permettre le changement de CD/DVD en cours de restauration,"
		#echo "Le script va être interrompu ici de façon à ce que vous"
		#echo "accédiez à une console."
		#echo -e "Lancez alors la restauration par: ${COLINFO}/tmp/restaure.sh${COLERREUR}"
		echo "Si la sauvegarde est sur plusieurs CD/DVD:"
		echo "Lorsque le CD/DVD suivant vous sera demandé, basculez vers une deuxième"
		echo -e "console (ALT+F2), tapez ${COLINFO}next.sh${COLERREUR} et suivez les instructions avant de"
		echo "rebasculer vers la première console (ALT+F1) et saisir le chemin demandé."

		sleep 3

		echo -e "$COLCMD"
		echo "#!/bin/sh" > /tmp/next.sh

		echo '#Couleurs
COLTITRE="\033[1;35m"
# Rose
COLPARTIE="\033[1;34m"
# Bleu

COLTXT="\033[0;37m"
# Gris
COLCHOIX="\033[1;33m"
# Jaune
COLDEFAUT="\033[0;33m"
# Brun-jaune
COLSAISIE="\033[1;32m"
# Vert

COLCMD="\033[1;37m"
# Blanc

COLERREUR="\033[1;31m"
# Rouge
COLINFO="\033[0;36m"
# Cyan' >> /tmp/next.sh

		echo 'echo -e "$COLTITRE"' >> /tmp/next.sh
		#echo 'echo "Ejection du CD/DVD"' >> /tmp/next.sh
		echo 'echo "Démontage du CD/DVD"' >> /tmp/next.sh
		echo 'echo -e "$COLCMD"' >> /tmp/next.sh
		#echo "eject /mnt/cdrom" >> /tmp/next.sh
		echo "mkdir -p ${chemin_cd}" >> /tmp/next.sh
		#echo "umount /mnt/cdrom 2>/dev/null" >> /tmp/next.sh
		echo "umount ${chemin_cd} 2>/dev/null" >> /tmp/next.sh
		echo 'echo -e "$COLTXT"' >> /tmp/next.sh
		echo 'echo "Vous pouvez éjecter le CD/DVD..."' >> /tmp/next.sh
		echo 'echo -e "$COLTXT"' >> /tmp/next.sh
		echo 'echo -e "Insérez le CD/DVD suivant et validez avec ENTREE\c"' >> /tmp/next.sh
		echo 'read PAUSE' >> /tmp/next.sh
		echo 'echo -e "$COLCMD"' >> /tmp/next.sh
		echo "mount -t iso9660 /dev/${CDDRIVE} ${chemin_cd}" >> /tmp/next.sh
		echo 'echo -e "$COLINFO"' >> /tmp/next.sh
		echo 'echo -e "Un message doit vous avoir signalé le montage en lecture seule.\nC est tout à fait normal."' >> /tmp/next.sh
		echo 'echo ""' >> /tmp/next.sh
		echo 'echo "Il arrive que le montage ne fonctionne pas depuis le script."' >> /tmp/next.sh
		echo 'echo "Vous pouvez alors l effectuer à la main en tapant:"' >> /tmp/next.sh
		echo "echo \"    mount -t iso9660 /dev/${CDDRIVE} ${chemin_cd}\"" >> /tmp/next.sh
		echo 'echo ""' >> /tmp/next.sh
		echo 'echo -e "$COLTITRE"' >> /tmp/next.sh
		echo 'echo "Vous pouvez rebasculer vers la console initiale (ALT+F1)"' >> /tmp/next.sh
		echo 'echo "pour poursuivre la restauration."' >> /tmp/next.sh
		echo 'echo -e "$COLTXT"' >> /tmp/next.sh

		chmod +x /tmp/next.sh

		echo -e "$COLTXT"
		#echo "Appuyez sur ENTREE pour accéder à la console dans laquelle"
		#echo -e "vous allez lancer ${COLINFO}/tmp/restaure.sh${COLTXT}"
		echo "Appuyez sur ENTREE pour poursuivre.."
		read PAUSE
		echo ""
		#Il est possible de passer en paramètre le ${CDDRIVE} ici.
		#exit

		echo -e "$COLCMD"
		echo "/tmp/restaure.sh \"${CDDRIVE}\" \"${chemin_cd}\""
		/tmp/restaure.sh "${CDDRIVE}" "${chemin_cd}"
	else
		echo -e "$COLCMD"
		cd /tmp
		echo "./restaure.sh \"${CDDRIVE}\" \"${chemin_cd}\""
		./restaure.sh "${CDDRIVE}" "${chemin_cd}"
	fi
else
	echo -e "$COLERREUR"
	echo "ABANDON!"
	echo -e "$COLINFO"
	echo "Pour relancer la restauration, lancez:"
	echo -e "  ${COLCHOIX}cdrestaure.sh"
	echo -e "$COLTXT"
	exit 0
fi

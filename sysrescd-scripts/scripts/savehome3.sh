#!/bin/bash

#J'ai mis /bin/bash pour l'option -e de la commande read

#Script de sauvegarde de dossiers personnels,...
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 26/02/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "*********************************************"
echo "*  Ce script doit vous aider à sauvegarder  *"
echo "*   des dossiers (personnels ou autres)     *"
echo "* avant d'ecraser une partition par exemple *"
echo "*********************************************"
#echo ""

echo -e "$COLTXT"
echo "Les étapes sont les suivantes:"
echo "   - Sélection du disque contenant les données;"
echo "   - Sélection de la partition contenant les données;"
echo "   - Montage de la partition;"
echo "   - Sélection du/des dossier(s) à sauvegarder;"
echo "   - Sélection du disque destiné à recevoir la sauvegarde;"
echo "   - Sélection de la partition destinée à recevoir la sauvegarde;"

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" != "o" ]; then
	echo -e "$COLERREUR"
	echo "ABANDON!"
	echo -e "$COLTXT"
	exit
fi

echo -e "$COLPARTIE"
echo "___________________________________________"
echo "ETAPE 1: LA PARTITION CONTENANT LES DONNEES"
echo "___________________________________________"

AFFICHHD

DEFAULTDISK=$(GET_DEFAULT_DISK)

echo -e "$COLTXT"
echo "Sur quel disque sont situées les données?"
echo "(hda,hdb,hdc,...,sda,sdb,...)"
echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
read DATADISK

if [ -z "$DATADISK" ]; then
	DATADISK=${DEFAULTDISK}
fi

echo -e "$COLTXT"
echo -e "Voici les partitions sur le disque /dev/$DATADISK:"
echo -e "$COLCMD"
#fdisk -l /dev/$DATADISK
LISTE_PART ${DATADISK} afficher_liste=y
echo ""

#liste_tmp=($(fdisk -l /dev/$DATADISK | grep "^/dev/$DATADISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))
LISTE_PART ${DATADISK} avec_tableau_liste=y
if [ ! -z "${liste_tmp[0]}" ]; then
	DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
else
	DEFAULTPART="${DATADISK}1"
fi

echo -e "$COLTXT"
echo "Quelle partition contient les données?"
echo "     (ex.: hda1, hdc2,...)"
echo -e "Partition: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
read DATAPART

if [ -z "$DATAPART" ]; then
	DATAPART=${DEFAULTPART}
fi


echo -e "$COLTXT"
echo "Quel est le type de la partition $DATAPART?"
echo "(vfat (pour FAT32), ext2, ext3,...)"
DETECTED_TYPE=$(TYPE_PART $DATAPART)
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

echo -e "$COLTXT"
echo -e "La partition $DATAPART va etre montee en /mnt/data."
echo "Pour cela, le point de montage va maintenant etre cree:"
echo -e "$COLCMD"
echo "mkdir -p /mnt/data"
mkdir -p /mnt/data

if mount | grep /mnt/data > /dev/null; then
	umount /mnt/data
fi

if mount | grep "/dev/$DATAPART " > /dev/null; then
	umount "/dev/$DATAPART"
fi

echo -e "$COLTXT"
echo "Et la partition va être montée:"
if [ -z "$TYPE" ]; then
	echo -e "$COLCMD"
	echo "mount /dev/$DATAPART /mnt/data"
	mount /dev/$DATAPART /mnt/data||ERREUR "Le montage a échoué!"
else
	echo -e "$COLCMD"
	echo "mount -t $TYPE /dev/$DATAPART /mnt/data"
	mount -t $TYPE /dev/$DATAPART /mnt/data||ERREUR "Le montage a échoué!"
fi

#echo "Si aucune erreur ne s'est produite, la partition est maintenant montée."
#echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
#read REPONSE

#if [ "$REPONSE" != "o" ]; then
#	echo -e "$COLERREUR"
#	echo "ABANDON!"
#	echo -e "$COLTXT"
#	exit
#fi


echo -e "$COLPARTIE"
echo "___________________________________"
echo "ETAPE 2: LES DOSSIERS A SAUVEGARDER"
echo "___________________________________"

echo -e "$COLTXT"
echo "Pour afficher les dossiers présents sur la partition, appuyer sur ENTREE."
read PAUSE

echo -e "$COLTXT"
echo "Voici les dossiers à la racine de /mnt/data:"
echo "(taper sur 'q' pour quitter le listing des dossiers)"
echo -e "$COLCMD"
#ls /mnt/data | more
#ls /mnt/data
if [ -e "/tmp/ls.txt" ]; then
	rm -f /tmp/ls.txt
fi
ls /mnt/data > /tmp/ls.txt
less /tmp/ls.txt

echo -e "$COLTXT"
echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
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

CPT=1
echo -e "$COLTXT"
echo "Voici une suggestion de dossiers à sauvegarder:"
if [ -e "/mnt/data/Mes documents" ]; then
	echo -e "$COLCMD"
	echo "/mnt/data/Mes documents"
	echo -e "$COLTXT"
	echo -e "Voulez-vous sauvegarder ce dossier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="o"
	fi

	if [ "$REPONSE" = "o" ]; then
		LISTE[$CPT]="/mnt/data/Mes documents"
		CPT=$(($CPT+1))
	fi
fi

if [ -e "/mnt/data/Documents and Settings" ]; then
	echo -e "$COLCMD"
	echo "/mnt/data/Documents and Settings"
	echo -e "$COLTXT"
	echo -e "Voulez-vous sauvegarder ce dossier? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE

	if [ "$REPONSE" = "o" ]; then
		LISTE[$CPT]="/mnt/data/Documents and Settings"
		CPT=$(($CPT+1))
	fi
fi

if [ $CPT -le 1 ]; then
	echo -e "$COLTXT"
	echo "Il n'existe apparemment ni dossier 'Mes documents', ni 'Documents and Settings' dans /mnt/data,"
	echo "ou alors vous ne souhaitez pas le(s) sauvegarder."
fi

echo -e "$COLTXT"
echo -e "Voulez-vous sauvegarder d'autres dossiers? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
read REPONSE

if [ -z "$REPONSE" ]; then
	REPONSE="o"
fi

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo "Rappel du contenu de /mnt/data:"
	echo "(taper sur 'q' pour quitter le listing des dossiers)"
	echo -e "$COLCMD"
	#ls /mnt/data | more
	#ls /mnt/data
	if [ -e "/tmp/ls.txt" ]; then
		rm -f /tmp/ls.txt
	fi
	ls /mnt/data > /tmp/ls.txt
	less /tmp/ls.txt

	echo -e "$COLTXT"
	echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
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

	echo -e "$COLTXT"
	echo "Il faut que vous affichiez le contenu d'un dossier pour vous voir proposer"
	echo "de sauvegarder le dossier."
	echo -e "Souhaitez-vous afficher le contenu d'un sous-dossier de /mnt/data? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ "$REPONSE" = "o" ]; then
		while [ "$REPONSE" = "o" ]
		do
			echo -e "$COLTXT"
			#echo -e "De quel dossier souhaitez-vous afficher le contenu? $COLSAISIE\c"
			echo -e "De quel dossier souhaitez-vous afficher le contenu?"
			echo -e "$COLCMD/mnt/data/$COLSAISIE\c"
			cd /mnt/data
			read -e DOSSIER
			cd /root

			#Suppression du / de fin s'il y en a un:
			DOSSIER=$(echo "$DOSSIER" | sed -e "s|/$||g")

			echo -e "$COLTXT"
			echo "Voici le contenu de $DOSSIER:"
			echo "(taper sur 'q' pour quitter le listing des dossiers)"

			echo -e "$COLCMD"
			#ls /mnt/data/$DOSSIER | more
			#ls /mnt/data/$DOSSIER
			if [ -e "/tmp/ls.txt" ]; then
				rm -f /tmp/ls.txt
			fi
			ls "/mnt/data/$DOSSIER" > /tmp/ls.txt
			less /tmp/ls.txt


			echo -e "$COLTXT"
			echo -e "Souhaitez-vous sauvegarder un de ces dossiers? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read SAVE

			if [ "$SAVE" = "o" ]; then
				echo -e "$COLTXT"
				#echo -e "Quel dossier souhaitez-vous sauvegarder? $COLSAISIE\c"
				echo -e "Quel dossier souhaitez-vous sauvegarder?"
				echo -e "$COLCMD/mnt/data/$DOSSIER/$COLSAISIE\c"
				cd "/mnt/data/$DOSSIER"
				read -e SAVE
				cd /root

				#Suppression du / de fin s'il y en a un:
				SAVE=$(echo "$SAVE" | sed -e "s|/$||g")

				if [ -e "/mnt/data/$DOSSIER/$SAVE" ]; then
					LISTE[$CPT]="/mnt/data/$DOSSIER/$SAVE"
					CPT=$(($CPT+1))
					echo -e "$COLTXT"
					echo -e "Vous avez sélectionné ${COLINFO}$DOSSIER/$SAVE"
				else
					echo -e "$COLERREUR"
					echo "Vous avez dû faire une erreur!"
					echo "Le dossier /mnt/data/$DOSSIER/$SAVE n'existe pas."
				fi
			fi

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Souhaitez-vous afficher le contenu d'un autre sous-dossier de /mnt/data? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
				read REPONSE
			done
		done
	fi
fi

if [ "$CPT" -le 1 ]; then
	echo -e "$COLERREUR"
	echo "Il semble que vous ne souhaitiez rien sauvegarder..."
	echo "ABANDON!"
	echo -e "$COLTXT"
	exit
else
	echo -e "$COLTXT"
	echo "Voici la liste des dossiers que vous souhaitez sauvegarder:"
	CPT=1
	while [ $CPT -le ${#LISTE[*]} ]
	do
		echo -e "$COLCMD"
		echo "${LISTE[$CPT]}"
		CPT=$(($CPT+1))
	done
fi

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" != "o" ]; then
	echo -e "$COLERREUR"
	echo "ABANDON!"
	echo -e "$COLTXT"
	exit
fi

echo -e "$COLPARTIE"
echo "____________________________________"
echo "ETAPE 3: DESTINATION DES SAUVEGARDES"
echo "____________________________________"

DEST_SVG

echo -e "$COLPARTIE"
echo "______________________________________"
echo "ETAPE 4: LA SAUVEGARDE PROPREMENT DITE"
echo "______________________________________"

if [ ${#LISTE[*]} -gt 1 ]; then
	echo -e "$COLTXT"
	echo -e "Souhaitez-vous sauvegarder les dossiers dans une archive unique (${COLCHOIX}1${COLTXT}) \nou dans autant d'archives qu'il y a de dossiers à sauvegarder (${COLCHOIX}2${COLTXT})?"
	echo -e "(si plusieurs dossiers/fichiers racines ont le même nom,\nil vaut mieux choisir 1)"
	echo -e "Choix: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE=1
	fi

	if [ "$REPONSE" = "1" ]; then
		echo -e "$COLTXT"
		echo -e "Quel nom souhaitez-vous donner à la sauvegarde? [${COLDEFAUT}data_save.zip${COLTXT}] $COLSAISIE\c"
		read ARCHIVE

		if [ -z "$ARCHIVE" ]; then
			ARCHIVE="data_save.zip"
		fi

		echo -e "${COLTXT}Archivage..."
		#zip -r "$DESTINATION/$ARCHIVE" "${LISTE[*]}"
		echo "Archivage de ${LISTE[1]}"
		echo -e "$COLCMD"
		zip -r "$DESTINATION/$ARCHIVE" "${LISTE[1]}"
		CPT=2
		while [ $CPT -le ${#LISTE[*]} ]
		do
			echo -e "$COLTXT"
			echo -e "Archivage de ${COLINFO}${LISTE[$CPT]}"
			echo -e "$COLCMD"
			zip -rg "$DESTINATION/$ARCHIVE" "${LISTE[$CPT]}"
			CPT=$(($CPT+1))
		done
	else
		CPT=1
		while [ $CPT -le ${#LISTE[*]} ]
		do
			echo -e "$COLTXT"
			echo -e "Archivage de ${COLINFO}${LISTE[$CPT]}"
			echo -e "$COLCMD"
			#Récupération du nom du dossier seul:
			nbcaract=$(echo ${LISTE[$CPT]} | wc -m)
			nbsansslash=$(echo ${LISTE[$CPT]} | sed -e "s|/||g" | wc -m)
			nbslash=$(($nbcaract-$nbsansslash))
			DOSSIER_A_SAUVEGARDER=$(echo ${LISTE[$CPT]} | cut -d"/" -f$(($nbslash+1)))
			#zip -r "$DESTINATION/${LISTE[$CPT]}.zip" "${LISTE[$CPT]}"
			zip -r "$DESTINATION/$DOSSIER_A_SAUVEGARDER.zip" "${LISTE[$CPT]}"
			CPT=$(($CPT+1))
			echo ""
		done

	fi
else
	echo -e "$COLTXT"
	echo -e "Quel nom souhaitez-vous donner à la sauvegarde? [${COLDEFAUT}data_save.zip${COLTXT}] $COLSAISIE\c"
	read ARCHIVE

	if [ -z "$ARCHIVE" ]; then
		ARCHIVE="data_save.zip"
	fi

	echo -e "$COLCMD"
	zip -r "$DESTINATION/$ARCHIVE" "${LISTE[*]}"
fi


echo -e "$COLPARTIE"
echo "La sauvegarde est terminée."

echo -e "$COLTXT"
echo -e "Souhaitez-vous que les partitions/partages soient maintenant démontées (${COLCHOIX}1${COLTXT}) \nou préférez-vous le faire manuellement (${COLCHOIX}2${COLTXT}) plus tard? $COLSAISIE\c"
read REPONSE

if [ "$REPONSE" = "1" ]; then
	cd /
	echo -e "$COLTXT"
	echo "Démontage de la partition (ou partage) contenant les données..."
	umount /mnt/data
	echo -e "$COLTXT"
	echo "Démontage de la partition (ou partage) contenant le(s) sauvegarde(s)..."
	umount $PTMNTSTOCK
fi

echo -e "$COLTITRE"
echo "Taper sur ENTREE pour quitter."
read PAUSE
echo -e "$COLTXT"


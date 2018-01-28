#!/bin/sh

# Script de recherche de MDP inscrits dans un lilo.conf
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 02/02/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "*****************************************"
echo "*       Ce script doit vous aider       *"
echo "*  à rechercher des mots de passe LILO  *"
echo "*****************************************"

echo -e "$COLPARTIE"
echo "==================="
echo "Choix du disque dur"
echo "==================="

#echo -e "$COLTXT"
#echo "Voici la liste des disques détectés sur votre machine:"
#echo -e "$COLCMD"

HD=""
while [ -z "$HD" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque se trouve la partition à monter?"
	echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
	echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
	read HD
	
	if [ -z "$HD" ]; then
		HD=${DEFAULTDISK}
	fi

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

echo -e "$COLTXT"
echo "Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
LISTE_PART ${HD} afficher_liste=y

#REPONSE=""
#while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
#do
#	echo -e "$COLTXT"
#	echo -e "Savez-vous sur quelle partition se trouve le /etc/lilo.conf (${COLDEFAUT}1${COLTXT})"
#	echo -e "ou voulez-vous que le script parcoure toutes les partitions Linux à la recherche d'un /etc/lilo.conf (${COLDEFAUT}2${COLTXT})"
#	echo -e "Votre choix: $COLSAISIE\c"
#	read REPONSE
#done

#fdisk -l /dev/$HD | grep "Linux" | grep -v "Linux extended" | grep -v "Linux swap" | tr "\t" " " | cut -d" " -f1 | sed -e "s|^/dev/||" | while read PART
LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
cat /tmp/liste_part_extraite_par_LISTE_PART.txt | while read TMP_PART
do
	PART=$(echo "$TMP_PART"|sed -e "s|^/dev/||")
	if mount | grep "/dev/$PART " | grep -q " /mnt/$PART "; then
		echo -e "$COLTXT"
		echo "/dev/$PART est deja montee en /mnt/$PART"
	else
		if mount | grep -q "/dev/$PART "; then
			echo -e "$COLTXT"
			echo "Tentative de demontage de /dev/$PART"
			echo -e "$COLCMD\c"
			umount /dev/$PART
		fi

		if mount | grep -q "/mnt/$PART "; then
			echo -e "$COLTXT"
			echo "Tentative de demontage de /mnt/$PART"
			echo -e "$COLCMD\c"
			umount /mnt/$PART
		fi

		echo -e "$COLTXT"
		echo "Montage de /dev/$PART"
		echo -e "$COLCMD\c"
		mkdir -p /mnt/$PART
		mount /dev/$PART /mnt/$PART
	fi

	if [ "$?" = "0" ]; then
		POURSUIVRE="o"
		if [ -e "/mnt/$PART/etc/lilo.conf" ]; then
			if grep password /mnt/$PART/etc/lilo.conf > /dev/null; then
				echo -e "$COLTXT"
				echo "Un ou des mots de passe ont été trouvés:"
				echo -e "$COLINFO\c"
				grep password /mnt/$PART/etc/lilo.conf


				REPONSE=""
				while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				do
					echo -e "$COLTXT"
					echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
					read REPONSE < /dev/tty
				done

				if [ "$REPONSE" != "o" ]; then
					#ERREUR "Abandon!"
					echo -e "$COLERREUR"
					echo "Abandon!"
					POURSUIVRE="n"
				fi
			fi
		else
			echo -e "$COLTXT"
			echo "Pas de /etc/lilo.conf dans cette partition."
		fi
		echo -e "$COLTXT"
		echo "Démontage de /dev/$PART"
		echo -e "$COLCMD\c"
		umount /mnt/$PART

		if [ "$POURSUIVRE" = "n" ]; then
			exit
		fi
	else
		echo -e "$COLERREUR"
		echo "Echec du montage de /dev/$PART ???"
	fi
done

echo -e "$COLTITRE"
echo "Terminé!"
echo -e "$COLTXT"
echo "Appuyez sur une touche pour quitter."
read PAUSE

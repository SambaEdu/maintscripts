#!/bin/bash

#J'ai mis /bin/bash pour l'option -e de la commande read

# Script de configuration du serveur partimaged
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 02/02/2013

source /bin/crob_fonctions.sh

PTMNT="/mnt/save"
mkdir -p ${PTMNT}

# Le mode sans login a l'air de merdoyer...
mode_nologin="n"
# Pour eviter de s'embeter avec un certificat
mode_nossl="y"

if echo "$*" | grep -q "nologin=y"; then
	mode_nologin="y"
fi

if echo "$*" | grep -q "nossl=n"; then
	mode_nossl="n"
fi

clear
echo -e "$COLTITRE"
echo "*********************************************"
echo "*  Ce script doit vous aider à paramétrer   *"
echo "*   le serveur partimaged sur SysRescCD     *"
echo "*     pour une sauvegarde/restauration      *"
echo "*********************************************"

CONFIG_RESEAU

HD=""
while [ -z "$HD" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque souhaitez-vous effectuer la sauvegarde?"
	echo "Ou: sur quel disque se trouve déjà la sauvegarde?"
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

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo "La partition de destination ne doit pas être de type Linux Swap"
	echo "Voici la/les partition(s) susceptibles de convenir:"
	echo -e "$COLCMD"
	#fdisk -l /dev/$HD | grep "/dev/${HD}[0-9]" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd"
	LISTE_PART ${HD} afficher_liste=y

	#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | cut -d" " -f1))
	LISTE_PART ${HD} avec_tableau_liste=y
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART="${HD}1"
	fi
	
	echo -e "$COLTXT"
	echo "Sur quelle partition doit se trouver/être placée la sauvegarde?"
	echo "     (ex.: hda1, hdc2,...)"
	echo -e "Partition: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read PARTITION
	#echo ""
	
	if [ -z "$PARTITION" ]; then
		PARTITION="$DEFAULTPART"
	fi

	#if ! fdisk -s /dev/$PARTITION > /dev/null; then
	t=$(fdisk -s /dev/$PARTITION)
	if [ -z "$t" -o ! -e "/sys/block/$HD/$PARTITION" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposée n'existe pas!"
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

if mount | grep "/dev/$PARTITION on / " > /dev/null; then
	echo -e "$COLTXT"
	echo "La partition choisie semble être celle sur laquelle vous avez démarré."

	CHEMINBASE=""
else
	echo -e "$COLTXT"
	echo "Quel est le type de la partition $PARTITION?"
	echo "(vfat (pour FAT32), ext2, ext3,...)"
	DETECTED_TYPE=$(TYPE_PART $PARTITION)
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

	echo -e "$COLCMD\c"
	if mount | grep "/dev/$PARTITION " > /dev/null; then
		umount /dev/$PARTITION
		sleep 1
	fi

	if mount | grep ${PTMNT} > /dev/null; then
		umount ${PTMNT}
		sleep 1
	fi

	echo -e "$COLTXT"
	echo "Montage de la partition $PARTITION en ${PTMNT}:"
	if [ -z "$TYPE" ]; then
		echo -e "${COLCMD}mount /dev/$PARTITION ${PTMNT}"
		mount /dev/$PARTITION "${PTMNT}"||ERREUR "Le montage de ${PTMNT} a échoué!"
	else
		if [ "$TYPE" = "ntfs" ]; then
			echo -e "${COLCMD}ntfs-3g /dev/$PARTITION ${PTMNT} -o ${OPT_LOCALE_NTFS3G}"
			ntfs-3g /dev/$PARTITION ${PTMNT} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a échoué!"
			sleep 1
		else
			echo -e "${COLCMD}mount -t $TYPE /dev/$PARTITION ${PTMNT}"
			mount -t $TYPE /dev/$PARTITION "${PTMNT}" || ERREUR "Le montage de ${PARTSTOCK} a échoué!"
		fi
	fi

	#echo ""
	echo -e "$COLTXT"
	echo "Si aucune erreur ne s'est produite la partition est maintenant montée."
	echo ""

	CHEMINBASE="${PTMNT}"
fi


#echo -e "Si cette partition est de type Linux, \nil est nécessaire de créer un dossier dans lequel \nl'utilisateur partimag ait le droit d'écrire"
#echo -e "Creer un dossier? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
echo -e "$COLINFO"
echo -e "Si cette partition est de type Linux, \nil est nécessaire de disposer d'un dossier dans lequel \nl'utilisateur partimag ait le droit d'écrire"
echo "Si vous répondez non, c'est la racine de la partition de sauvegarde"
echo "qui sera utilisée."
echo -e "$COLTXT"
echo -e "Définir un dossier? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
read REPONSE
#echo ""

if [ -z "$REPONSE" ]; then
	REPONSE="n"
fi

if [ "$REPONSE" = "o" ]; then
	REPONSE=""
	while [ -z "$REPONSE" ]
	do
		echo -e "$COLTXT"
		echo -e "Veuillez préciser le nom du sous-dossier de $CHEMINBASE à utiliser \n(il sera créé si nécessaire)\n(exemples: sauvegarde ou chemin_relatif/dossier)\nChemin: ${COLCMD}$CHEMINBASE/$COLSAISIE\c"
		cd $CHEMINBASE
		read -e REPONSE
		cd /root
	done

	echo -e "$COLCMD"
	echo "mkdir -p $CHEMINBASE/$REPONSE"
	mkdir -p "$CHEMINBASE/$REPONSE"
	echo "chown partimag:partimag $CHEMINBASE/$REPONSE"
	chown partimag:partimag "$CHEMINBASE/$REPONSE"
	echo "chmod 775 $CHEMINBASE/$REPONSE"
	chmod 775 "$CHEMINBASE/$REPONSE"
	echo "cd $CHEMINBASE/$REPONSE"
	cd "$CHEMINBASE/$REPONSE"

	echo -e "$COLINFO"
	echo "Ne pas s'affoler pour un message indiquant éventuellement:"
	echo -e "$COLERREUR\c"
	echo "     chown: changing ownership of '...': Operation not permitted"
	echo -e "$COLINFO\c"
	echo "Cela arrive quand la partition n'est pas de type Linux."
else
	echo -e "$COLCMD"
	echo "cd $CHEMINBASE/"
	cd $CHEMINBASE/
fi

if ls ./ | grep .000 > /dev/null; then
	echo -e "$COLTXT"
	echo "Le dossier $CHEMINBASE/$REPONSE contient une ou des images:"
	echo -e "$COLCMD"
	ls ./*.000
fi

#echo ""
echo -e "$COLTXT"
echo -e "Création (si nécessaire) du dossier /etc/partimaged \net du fichier /etc/partimaged/partimagedusers (et correction des droits)."
echo -e "$COLCMD"
echo "mkdir -p /etc/partimaged"
mkdir -p /etc/partimaged
echo "chmod 755 /etc/partimaged"
chmod 755 /etc/partimaged
echo "touch /etc/partimaged/partimagedusers"
touch /etc/partimaged/partimagedusers
echo "chmod 600 /etc/partimaged/partimagedusers"
chmod 600 /etc/partimaged/partimagedusers
#echo ""


if [ "$mode_nossl" != "y" -a "$mode_nossl" != "o" ]; then
	if [ ! -e "/etc/partimaged/partimaged.cert" -o ! -e "/etc/partimaged/partimaged.key" ]; then
		echo -e "$COLTXT"
		echo "Creation d'un certificat..."
		echo -e "$COLCMD"
		DOSS_AVANT=$PWD
		cd /etc/partimaged
		openssl req -new -x509 -outform PEM > partimaged.csr < /dev/tty
		openssl rsa -in privkey.pem -out partimaged.key < /dev/tty
		openssl x509 -in partimaged.csr -out partimaged.cert -signkey partimaged.key
		chmod 600 partimaged.csr partimaged.key partimaged.cert privkey.pem
		cd "$DOSS_AVANT"
	fi
	chown partimag /etc/partimaged/*
fi

partimaged_options=""
if [ "$mode_nossl" = "y" -o "$mode_nossl" = "o" ]; then
	partimaged_options="${partimaged_options} -n"
fi

if [ "$mode_nologin" = "y" -o "$mode_nologin" = "o" ]; then
	partimaged_options="${partimaged_options} -L"

	REPONSE="n"
else
	REPONSE=""
fi

while [ "$REPONSE" != "o" -a "$REPONSE" != "n"  ]
do
	echo -e "$COLTXT"
	echo -e "Souhaitez-vous créer un utilisateur autorisé \nà sauvegarder/restaurer ou non? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
	#echo ""
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo -e "Saisissez le nom de login de l'utilisateur: $COLSAISIE\c"
	read LOGIN
	#echo ""
	while [ -z "$LOGIN" ]
	do
		echo -e "$COLTXT"
		echo -e "Saisissez le nom de login de l'utilisateur: $COLSAISIE\c"
		read LOGIN
		#echo ""
	done

	#echo -e "Saisissez un mot de passe pour l'utilisateur $LOGIN: $COLSAISIE\c"
	#read PASSWORD
	#echo ""
	#while [ -z "$PASSWORD" ]
	#do
	#	echo -e "Saisissez un mot de passe pour l'utilisateur $LOGIN: $COLSAISIE\c"
	#	read PASSWORD
	#	echo ""
	#done

	echo -e "$COLTXT"
	echo "Création de l'utilisateur..."
	echo -e "$COLCMD"
	echo "useradd $LOGIN"
	useradd $LOGIN
	#echo ""

	echo -e "$COLTXT"
	echo "Affectation du mot de passe..."
	#echo "$PASSWORD" | passwd $LOGIN --stdin
	echo -e "$COLCMD"
	echo "passwd $LOGIN"
	passwd $LOGIN
	#echo ""

	echo -e "$COLTXT"
	echo -e "Ajout de l'utilisateur $LOGIN à la liste des utilisateurs \nautorisés à contacter le serveur partimaged..."
	echo -e "$COLCMD"
	echo "echo \"$LOGIN\" >> /etc/partimaged/partimagedusers"
	echo "$LOGIN" >> /etc/partimaged/partimagedusers
	#echo ""


	#	echo -e "$COLINFO"
	#	echo "La création d'un mot de passe pour root est nécessaire pour le fonctionnement SSL/SSH."
	#	echo -e "${COLERREUR}A VERIFIER..."
	#	echo -e "$COLTXT"
	#	echo "Création d'un mot de passe pour root:"
	#	echo -e "$COLCMD\c"
	#	passwd
	#
	#	echo -e "$COLTXT"
	#	echo "Démarrage du serveur SSH..."
	#	echo -e "$COLCMD\c"
	#	/etc/init.d/sshd start
	#
	#	echo -e "$COLTXT"
	#	echo "Génération d'une clé /etc/partimaged/partimaged.key"
	#	echo -e "$COLCMD\c"
	#	ssh-keygen -t dsa -f /etc/partimaged/partimaged.key

	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Souhaitez-vous lancer partimaged:"
		echo -e "        - en tâche de fond (${COLCHOIX}1${COLTXT})?"
		echo -e "        - en premier plan  (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}2${COLTXT}] \c${COLSAISIE}"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=2
		fi
	done

	if [ "$REPONSE" = "1" ]; then
		echo -e "$COLTXT"
		echo "Lancement du serveur partimaged en tâche de fond."
		echo -e "$COLCMD"
		#echo "partimaged -D"
		#partimaged -D
		#echo "partimagedssl -D"
		#partimagedssl -D
		echo "partimaged -D ${partimaged_options}"
		partimaged -D ${partimaged_options}

		echo -e "$COLPARTIE"
		echo "Vous pouvez maintenant vous occuper du client."
		echo -e "$COLTXT"
	else
		echo -e "$COLTXT"
		echo "Lancement du serveur partimaged en premier plan."
		echo -e "$COLCMD"
		#echo "partimaged"
		#partimaged
		#echo "partimagedssl"
		#partimagedssl
		echo "partimaged ${partimaged_options}"
		partimaged ${partimaged_options}
	fi
else
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Souhaitez-vous lancer partimaged:"
		echo -e "        - en tâche de fond (${COLCHOIX}1${COLTXT})?"
		echo -e "        - en premier plan  (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}2${COLTXT}] \c${COLSAISIE}"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=2
		fi
	done

	if [ "$REPONSE" = "1" ]; then
		echo -e "$COLTXT"
		echo "Lancement du serveur partimaged en tâche de fond."
		echo -e "$COLCMD"
		#echo "partimaged -D -L"
		#partimaged -D -L
		echo "partimaged -D ${partimaged_options}"
		partimaged -D ${partimaged_options}

		echo -e "$COLPARTIE"
		echo "Vous pouvez maintenant vous occuper du client."
		echo -e "$COLTXT"
	else
		echo -e "$COLTXT"
		echo "Lancement du serveur partimaged en premier plan."
		echo -e "$COLCMD"
		#echo "partimaged -L"
		#partimaged -L
		echo "partimaged ${partimaged_options}"
		partimaged ${partimaged_options}
	fi
fi

#echo ""
echo -e "$COLTITRE"
echo "Terminé!"
echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour finir."
read PAUSE

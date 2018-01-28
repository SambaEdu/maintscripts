#!/bin/bash

#J'ai mis /bin/bash pour l'option -e de la commande read

# Script de configuration du serveur partimaged
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 26/02/2013

source /bin/crob_fonctions.sh

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

PTMNT="/mnt/save"
mkdir -p ${PTMNT}

clear
echo -e "$COLTITRE"
echo "************************************************"
echo "*   Ce script doit vous aider a parametrer     *"
echo "*    le serveur partimaged sur SysRescCD       *"
echo "* pour restaurer une image sur d'autres postes *"
echo "************************************************"

echo -e "$COLTXT"
echo -e "Il s'agit ici de choisir une image partimage ${COLERREUR}existante${COLTXT} qui devra etre restauree"
echo -e "sur des postes clients en faisant en sorte qu'il ne faille cote client que fournir"
echo -e "l'adresse IP du present serveur partimaged."

echo -e "$COLTXT"
echo "Si la sauvegarde n'existe pas encore, vous devrier commencer par effectuer une"
echo -e "sauvegarde avec le script ${COLINFO}save-hda1_papa4.sh${COLTXT} (*)"
echo "(choix 'a' dans le menu autorun)."

echo -e "$COLTXT"
echo "(*) Il faudra que je pense a en changer le nom un jour parce que cela fait un"
echo "    moment maintenant qu'il ne sert plus seulement ‡ mon papa;o)."

touch /tmp/proposer_ip_statique.txt

CONFIG_RESEAU

HD=""
while [ -z "$HD" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque se trouve la sauvegarde a proposer?"
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
	echo "Voici la/les partition(s) susceptibles de contenir une image:"
	echo -e "$COLCMD"
	#fdisk -l /dev/$HD | grep "/dev/${HD}[0-9]" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd"
	LISTE_PART ${HD} afficher_liste=y

	#†On cherche d'abord une partition Linux:
	#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep "Linux" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | cut -d" " -f1))
	LISTE_PART ${HD} avec_tableau_liste=y type_part_cherche=linux
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		#†On cherche sinon une autre partition comme partition par defaut:
		#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | cut -d" " -f1))
		LISTE_PART ${HD} avec_tableau_liste=y
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			DEFAULTPART="${HD}1"
		fi
	fi
	
	echo -e "$COLTXT"
	echo "Sur quelle partition se trouve la sauvegarde?"
	echo "     (ex.: hda1, hdc2,...)"
	echo -e "Partition: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read PARTITION

	if [ -z "$PARTITION" ]; then
		PARTITION="$DEFAULTPART"
	fi

	#if ! fdisk -s /dev/$PARTITION > /dev/null; then
	t=$(fdisk -s /dev/$PARTITION)
	if [ -z "$t" -o ! -e "/sys/block/$HD/$PARTITION" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposee n'existe pas!"
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
	echo "La partition choisie semble etre celle sur laquelle vous avez demarre."

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
	if mount | grep "$PARTITION " > /dev/null; then
		#umount $PARTITION
		#sleep 1

	#fi

	#if mount | grep ${PTMNT} > /dev/null; then
	#	umount ${PTMNT}
	#	sleep 1
	#fi
		PTMNT=$(mount | grep "/dev/$PARTITION " | cut -d" " -f3)
		# On pourrait aussi se contenter de creer un lien symbolique...

		echo -e "$COLTXT"
		echo -e "La partition est deja montee en ${COLINFO}${PTMNT}"
	else
		echo -e "$COLTXT"
		echo "Montage de la partition $PARTITION en ${PTMNT}:"
		if [ -z "$TYPE" ]; then
			echo -e "${COLCMD}mount /dev/$PARTITION ${PTMNT}"
			mount /dev/$PARTITION "${PTMNT}"||ERREUR "Le montage de ${PTMNT} a echoue!"
		else
			if [ "$TYPE" = "ntfs" ]; then
				echo -e "${COLCMD}ntfs-3g /dev/$PARTITION ${PTMNT} -o ${OPT_LOCALE_NTFS3G}"
				ntfs-3g /dev/$PARTITION ${PTMNT} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a echoue!"
				sleep 1
			else
				echo -e "${COLCMD}mount -t $TYPE /dev/$PARTITION ${PTMNT}"
				mount -t $TYPE /dev/$PARTITION "${PTMNT}" || ERREUR "Le montage de ${PARTSTOCK} a echoue!"
			fi
		fi

		#echo ""
		echo -e "$COLTXT"
		echo "Si aucune erreur ne s'est produite la partition est maintenant montee."
		echo ""
	fi

	CHEMINBASE="${PTMNT}"
fi

echo -e "$COLPARTIE"
echo "================"
echo "Choix du dossier"
echo "================"
echo -e "$COLTXT"
echo "Voici le contenu de la partition:"
echo -e "$COLCMD\c"
ls -l "${CHEMINBASE}"

REP=""
while [ "$REP" != "o" ]
do
	echo -e "$COLTXT"
	echo -e "Dans quel ${COLINFO}dossier${COLTXT} se trouve l'image a restaurer sur les postes clients?"
	cd "${CHEMINBASE}"
	echo -e "Dossier: ${COLINFO}${CHEMINBASE}/${COLSAISIE}\c"
	read -e DOSSIER

	if [ ! -e "$CHEMINBASE/$DOSSIER" ]; then
		echo -e "$COLERREUR"
		echo "Le dossier propose n'existe pas."
		REP="n"
	else
		echo -e "$COLTXT"
		echo "Voici les images partimage contenues dans le dossier:"
		echo -e "$COLCMD\c"
		ls -l ${CHEMINBASE}/${DOSSIER}/*.000
		if [ "$?" = "0" ]; then
			P=1
		else
			P=2
		fi

		echo -e "$COLTXT"
		echo "Si l'image a proposer s'y trouve bien, vous pouvez poursuivre."
		echo "Sinon, il faut corriger."

		POURSUIVRE_OU_CORRIGER ${P}

		if [ "$REPONSE" = "1" ]; then
			REP="o"
		else
			REP="n"
		fi
	fi
done

echo -e "$COLPARTIE"
echo "================"
echo "Choix de l'image"
echo "================"
echo -e "$COLCMD\c"
ladate=$(date "+%Y%m%d-%H%M%S")
doss_thttpd=/tmp/restauration_partimaged_${ladate}
mkdir -p "${doss_thttpd}"
chmod 755 "${doss_thttpd}"

default_image=$(basename $(ls ${CHEMINBASE}/${DOSSIER}/*.000 2> /dev/null | head -n1))

REP=""
while [ "$REP" != "o" ]
do
	echo -e "$COLTXT"
	echo "Quelle est l'image a restaurer sur les postes clients?"
	cd "${CHEMINBASE}/${DOSSIER}"
	echo -e "Image: [${COLDEFAUT}${default_image}${COLTXT}] ${COLSAISIE}\c"
	read -e IMAGE

	if [ -z "$IMAGE" ]; then
		IMAGE=${default_image}
	fi

	if [ ! -e "$CHEMINBASE/$DOSSIER/$IMAGE" ]; then
		echo -e "$COLERREUR"
		echo "L'image choisie n'existe pas."
		REP="n"
	else
		echo -e "$COLINFO"
		echo -e "Vous avez choisi: ${COLCHOIX}${IMAGE}"

		POURSUIVRE_OU_CORRIGER "1"

		if [ "$REPONSE" = "1" ]; then
			REP="o"
		else
			REP="n"
		fi
	fi
done

echo "IMAGE=$IMAGE" > "${doss_thttpd}/parametres.txt"

if ls ${CHEMINBASE}/${DOSSIER}/*.out > /dev/null 2>&1; then
	echo -e "$COLTXT"
	echo "Le dossier contient un ou des fichiers de table de partitions:"
	echo -e "$COLCMD\c"
	ls ${CHEMINBASE}/${DOSSIER}/*.out

	default_sda_out=$(basename $(ls ${CHEMINBASE}/${DOSSIER}/*.out|head -n1))

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous choisir un de ces fichiers pour controler la table de partition"
		echo -e "sur les clients avant restauration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] ${COLSAISIE}\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="o"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		REP=""
		while [ "$REP" != "o" ]
		do
			echo -e "$COLTXT"
			echo "Quel est le fichier de table de partitions?"
			cd "${CHEMINBASE}/${DOSSIER}"
			echo -e "Fichier: [${COLDEFAUT}${default_sda_out}${COLTXT}] ${COLSAISIE}\c"
			read -e PARTTABLE

			if [ -z "$PARTTABLE" ]; then
				PARTTABLE=${default_sda_out}
			fi

			if [ ! -e "$CHEMINBASE/$DOSSIER/$PARTTABLE" ]; then
				echo -e "$COLERREUR"
				echo "Le fichier choisi n'existe pas."
				REP="n"
			else
				echo -e "$COLINFO"
				echo -e "Vous avez choisi: ${COLCHOIX}${PARTTABLE}"

				POURSUIVRE_OU_CORRIGER "1"

				if [ "$REPONSE" = "1" ]; then
					REP="o"
				else
					REP="n"
				fi
			fi
		done

		echo -e "$COLCMD\c"
		cp "$CHEMINBASE/$DOSSIER/$PARTTABLE" "${doss_thttpd}/"
		# Il ne faut pas que le fichier soit executable sans quoi le wget echoue:
		chmod 644 "${doss_thttpd}/$PARTTABLE"
	fi
fi

if [ -n "$PARTTABLE" ]; then
	echo "PARTTABLE=$PARTTABLE" >> "${doss_thttpd}/parametres.txt"
else
	echo -e "${COLERREUR}"
	echo -e "ATTENTION:${COLINFO}"
	echo "Aucune table de partition n'a ete trouvee."
	echo "Si les tables de partition ne coÔncident pas avec les postes clients, la restauration echouera."
fi

echo -e "$COLINFO"
echo "Si vous savez quelle partition (sda1, sda2,...) doit Ítre restauree"
echo "sur les clients, vous pouvez le specifier ici et ainsi gagner du temps"
echo "sur les clients."

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Savez-vous quelle est la partition a restaurer"
	echo -e "sur les postes clients? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] ${COLSAISIE}\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="o"
	fi
done

if [ "$REPONSE" = "o" ]; then

	REST_HD=$(GET_DEFAULT_DISK)
	#REST_PART=$(fdisk -l /dev/${REST_HD} | grep "/dev/${REST_HD}[0-9]" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility" | cut -d" " -f1|sed -e "s|^/dev/||"|head -n 1)
	#if [ -z "$REST_PART" ]; then
	LISTE_PART ${REST_HD} avec_tableau_liste=y
	if [ -z "${liste_tmp[0]}" ]; then
		REST_PART="sda1"
	else
		REST_PART=${liste_tmp[0]}
		t=$(fdisk -s /dev/$REST_PART 2>/dev/null)
		if [ -z "$t" -o ! -e "/sys/block/$REST_HD/$REST_PART/partition" ]; then
			REST_PART="sda1"
		fi
	fi

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Partition: [${COLDEFAUT}${REST_PART}${COLTXT}] ${COLSAISIE}\c"
		read PARTITION

		if [ -z "$PARTITION" ]; then
			PARTITION=${REST_PART}
		fi

		echo -e "$COLINFO"
		echo -e "Vous avez choisi ${COLCHOIX}${PARTITION}"

		POURSUIVRE_OU_CORRIGER "1"
	done

	echo "PARTITION=$PARTITION" >> "${doss_thttpd}/parametres.txt"
fi

# PROPOSER DE LANCER LE SERVEUR TFTP
REP_TFTP=""
while [ "$REP_TFTP" != "o" -a "$REP_TFTP" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous lancer le serveur tftp pour demarrer les clients"
	echo -e "depuis le reseau (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
	read REP_TFTP

	if [ -z "$REP_TFTP" ]; then
		REP_TFTP="n"
	fi
done

if [ "$REP_TFTP" = "o" ]; then
	/bin/srv_tftp.sh 'perso'
	# Le lancement du serveur tftp provoque la redirection de la racine thttpd vers ${mnt_cdrom} pour pouvoir servir le sysrcd.dat et le sysrcd.md5
	cd ${mnt_cdrom}
	ls | while read A
	do
		ln -s ${mnt_cdrom}/$A ${doss_thttpd}/
	done
	#cd ${doss_thttpd}
fi
cd "${CHEMINBASE}/${DOSSIER}"

# Lancement du serveur thttpd avec ${doss_thttpd} pour racine pour recuperer cote client le fichier parametres.txt et le sda.out
echo -e "$COLTXT"
echo "Lancement de thttpd pour mettre le fichier de parametres a disposition des"
echo "clients."
echo -e "$COLCMD\c"
THTTPD_DOCROOT=${doss_thttpd}
#sed -i "s|ebegin \"Starting thttpd\"|ebegin \"Starting thttpd\"\nTHTTPD_DOCROOT=${THTTPD_DOCROOT}|" /etc/init.d/thttpd
#/etc/init.d/thttpd restart
#sed -i "s|^THTTPD_DOCROOT=|#THTTPD_DOCROOT=|" /etc/init.d/thttpd
cp /etc/conf.d/thttpd /etc/conf.d/thttpd.${ladate}
sed -i "s|THTTPD_DOCROOT=.*|THTTPD_DOCROOT=\"${THTTPD_DOCROOT}\"|" /etc/conf.d/thttpd
# Dans les options de demarrage, on met -nos pour suivre le lien symbolique vers les fichiers de ${mnt_cdrom} et on vire le -r pour ne pas chrooter.
#	-r
#		Do a chroot() at initialization time, restricting file access to the program's current directory. If -r is the compiled-in default, then -nor disables it. See below for details. The config-file option names for this flag are "chroot" and "nochroot", and the config.h option is ALWAYS_CHROOT. 
#	-nos
#		Don't do explicit symbolic link checking. Normally, thttpd explicitly expands any symbolic links in filenames, to check that the resulting path stays within the original document tree. If you want to turn off this check and save some CPU time, you can use the -nos flag, however this is not recommended. Note, though, that if you are using the chroot option, the symlink checking is unnecessary and is turned off, so the safe way to save those CPU cycles is to use chroot. The config-file option names for this flag are "symlinkcheck" and "nosymlinkcheck". 
sed -i "s|THTTPD_OPTS=.*|THTTPD_OPTS=\"-p 80 -nos -u root -i /var/run/thttpd.pid -l /var/log/thttpd.log\"|" /etc/conf.d/thttpd
/etc/init.d/thttpd restart
# Restauration de la conf initiale
cp /etc/conf.d/thttpd.${ladate} /etc/conf.d/thttpd

echo -e "$COLTXT"
echo -e "Sur les clients vous devrez preciser l'adresse IP du serveur."
echo -e "Notez bien l'adresse IP:"
echo -e "$COLCMD\c"
if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
	ifconfig|grep "inet addr"|grep -v "127\.0\.0\.1"
else
	ifconfig|grep "inet "|grep -v "127\.0\.0\.1"
fi
echo -e "$COLTXT"
echo "Creation de /var/log/partimage/"
echo -e "$COLCMD\c"
mkdir -p /var/log/partimage
chown partimag /var/log/partimage

REPONSE=""
while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
do
	echo -e "$COLTXT"
	echo -e "Souhaitez-vous lancer partimaged:"
	echo -e "        - en t√¢che de fond (${COLCHOIX}1${COLTXT})?"
	echo -e "        - en premier plan  (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}2${COLTXT}] \c${COLSAISIE}"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE=2
	fi
done

if [ "$mode_nossl" != "y" -a "$mode_nossl" != "o" ]; then
	if [ ! -e "/etc/partimaged/partimaged.cert" -o ! -e "/etc/partimaged/partimaged.key" ]; then
		echo -e "$COLTXT"
		echo "Creation d'un certificat..."
		echo -e "$COLCMD"
		cd /etc/partimaged
		openssl req -new -x509 -outform PEM > partimaged.csr < /dev/tty
		openssl rsa -in privkey.pem -out partimaged.key < /dev/tty
		openssl x509 -in partimaged.csr -out partimaged.cert -signkey partimaged.key
		chmod 600 partimaged.csr partimaged.key partimaged.cert privkey.pem
	fi
	chown partimag /etc/partimaged/*
else
	echo "mode_nossl=y" >> "${doss_thttpd}/parametres.txt"
fi

if [ "$REP_TFTP" = "o" ]; then
	echo -e "$COLINFO"
	echo -e "Sur les clients, vous pouvez booter sur le reseau (${COLCHOIX}F12${COLINFO})."
	#echo -e "A l'invite '${COLCHOIX}Boot:${COLINFO}', tapez '${COLCHOIX}cp${COLINFO}' ou '${COLCHOIX}cp dodhcp${COLINFO}'"
	echo -e "A l'invite '${COLCHOIX}Boot:${COLINFO}', tapez '${COLCHOIX}cp2${COLINFO}'"
	echo -e "Sinon, en bootant sur le CD, le choix sera '${COLCHOIX}cp${COLINFO}'"
	sleep 3
fi

partimaged_options=""
if [ "$mode_nologin" = "y" -o "$mode_nologin" = "o" ]; then
	partimaged_options=" -L"
else
	# Creation d'un compte pour l'acces aux sauvegardes
	chaine=$(date|md5sum)
	partimaged_user=part${chaine:0:4}
	partimaged_pass=$(date|md5sum|cut -d" " -f1)
	echo "partimaged_user=$partimaged_user" >> "${doss_thttpd}/parametres.txt"
	echo "partimaged_pass=$partimaged_pass" >> "${doss_thttpd}/parametres.txt"
	useradd ${partimaged_user} -p $(mkpasswd $partimaged_pass)
	echo $partimaged_user >> /etc/partimaged/partimagedusers
	chown partimag /etc/partimaged/*
	chmod 755 ${CHEMINBASE}/${DOSSIER}/*
fi

if [ "$mode_nossl" = "y" -o "$mode_nossl" = "o" ]; then
	partimaged_options="${partimaged_options} -n"
fi

# Comme pour IMAGE on a mis le nom de l'image sans chemin, il faut lancer partimaged en se trouvant dans le dossier contenant l'image
cd "${CHEMINBASE}/${DOSSIER}"
if [ "$REPONSE" = "1" ]; then
	echo -e "$COLTXT"
	echo "Lancement du serveur partimaged en t√¢che de fond."
	echo -e "$COLCMD"
	echo "partimaged -D ${partimaged_options}"
	partimaged -D ${partimaged_options}

	echo -e "$COLPARTIE"
	echo "Vous pouvez maintenant vous occuper des clients."
	echo -e "$COLTXT"
else
	echo -e "$COLTXT"
	echo "Lancement du serveur partimaged en premier plan."
	echo -e "$COLCMD"
	echo "partimaged ${partimaged_options}"
	partimaged ${partimaged_options}
fi

#echo ""
echo -e "$COLTITRE"
echo "Termine!"
echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour finir."
read PAUSE

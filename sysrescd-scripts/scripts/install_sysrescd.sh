#!/bin/bash

# Script d'installation de SystemRescueCD
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Et surtout tres fortement inspire des scripts de Jean-Marc Baty,
# scripts utilises dans MINAList et partimage-bootcd
# Derniere modification: 05/04/2014

# ******************************************
# Version adaptee a System Rescue CD v1.1.x
# ******************************************

source /bin/crob_fonctions.sh

source_script_sysrescd_sur_hd="/root/scripts_pour_sysresccd_sur_hd"

# J'arrive a faire fonctionner Grub...
# ... mais uniquement en faisant l'install depuis le livecd
PB_GRUB_OK="ok"
# Reste a arranger des scripts de changement de mot de passe dans le /boot/grub/menu.lst
# Voir les differentes conf de Grub: sur le secteur de boot de la partition SysRescCD? c'est ce qui arrangerait NEC?


clear
echo -e "$COLTITRE"
echo "*******************************************"
echo "* Script d'installation de SystemRescueCD *"
echo "*******************************************"
#echo ""

echo -e "$COLINFO"
echo -e "Ce script est prevu pour une installation \nsur un disque ne disposant pas deja d'un boot-loader. \nDans l'alternative, il vaut mieux proceder autrement."
echo -e "La sauvegarde sera stockee sur la meme partition \nque l'installation de SystemRescueCD pour ne pas allonger inutilement ce script."
echo -e "Par ailleurs, ce script est prevu pour la sauvegarde d'une partition Window$.\n"
echo "Si ce n'est pas le cas, il se produira une erreur lors de l'execution de LILO pour la mise en place du boot-loader."
echo ""

#echo -e "ATTENTION: Ce script ne doit pas etre lance \n           si vous avez boote avec l'option '${COLERREUR}cdcache${COLINFO}'."
#echo -e "           Desirez-vous poursuivre? (${COLCHOIX}o/n${COLINFO}) $COLSAISIE\c"
#read REPONSE

#if [ "$REPONSE" != "o" ]; then
#	echo -e "$COLERREUR"
#	echo "ABANDON !"
#	echo -e "$COLTXT"
#	exit
#fi

grep docache /proc/cmdline > /dev/null
if [ $? -eq 1 ]; then
	echo -e "$COLTXT"
	echo -e "Vous n'avez pas boote avec l'option ${COLINFO}docache${COLTXT}."
	echo -e "Le script peut se poursuivre."
	echo ""
	echo "Appuyez sur ENTREE pour poursuivre"
	read PAUSE
else
	echo -e "$COLERREUR"
	echo -e "ATTENTION: Vous avez boote avec l'option ${COLINFO}docache${COLERREUR}."
	echo -e "           Le script ne peut pas se poursuivre."
	echo -e "           Veuillez rebooter sans l'option ${COLINFO}docache${COLERREUR}."
	echo -e "$COLTXT"
	exit
fi

echo -e "$COLPARTIE"
echo "_____________________________________"
echo "ETAPE 1: LA PARTITION SYSTEME WINDOW$"
echo "_____________________________________"

BOOTDISK=""
while [ -z "$BOOTDISK" ]
do
	AFFICHHD

	DEFAULTDISK=$(GET_DEFAULT_DISK)

	echo -e "$COLTXT"
	echo "Sur quel disque s'effectue le boot?"
	echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
	echo -e "Disque de boot: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
	read BOOTDISK

	if [ -z "$BOOTDISK" ]; then
		BOOTDISK=${DEFAULTDISK}
	fi

	tst=$(sfdisk -s /dev/$BOOTDISK 2>/dev/null)
	if [ -z "$tst" -o ! -e "/sys/block/$BOOTDISK" ]; then
		echo -e "$COLERREUR"
		echo "Le disque $BOOTDISK n'existe pas."
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour corriger."
		read PAUSE
		BOOTDISK=""
	fi
done


REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$BOOTDISK:"
	#echo ""
	echo -e "$COLCMD\c"
	#fdisk -l /dev/$BOOTDISK
	LISTE_PART ${BOOTDISK} afficher_liste=y
	#echo ""


	#liste_tmp=($(fdisk -l /dev/$BOOTDISK | grep "^/dev/$BOOTDISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | egrep "(FAT|NTFS)" | cut -d" " -f1))
	LISTE_PART ${BOOTDISK} avec_tableau_liste=y type_part_cherche=windows
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")

		DEFAULT_BOOT_PART=$DEFAULTPART

		taille_part=$(fdisk -s /dev/$DEFAULTPART)
		taille_min_systeme=$((1024*1024*3))

		if [ $taille_part -lt $taille_min_systeme -a -n "${liste_tmp[1]}" ]; then
			TESTPART=$(echo ${liste_tmp[1]} | sed -e "s|^/dev/||")
			taille_part=$(fdisk -s /dev/$TESTPART)
			if [ $taille_part -gt $taille_min_systeme ]; then
				DEFAULTPART=$TESTPART
			fi
		fi
	else
		#liste_tmp=($(fdisk -l /dev/$BOOTDISK | grep "^/dev/$BOOTDISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))
		LISTE_PART ${BOOTDISK} avec_tableau_liste=y
		if [ ! -z "${liste_tmp[0]}" ]; then
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")

			DEFAULT_BOOT_PART=$DEFAULTPART

			taille_part=$(fdisk -s /dev/$DEFAULTPART)
			taille_min_systeme=$((1024*1024*3))

			if [ $taille_part -lt $taille_min_systeme -a -n "${liste_tmp[1]}" ]; then
				TESTPART=$(echo ${liste_tmp[1]} | sed -e "s|^/dev/||")
				taille_part=$(fdisk -s /dev/$TESTPART)
				if [ $taille_part -gt $taille_min_systeme ]; then
					DEFAULTPART=$TESTPART
				fi
			fi
		else
			DEFAULTPART="${BOOTDISK}1"
		fi
	fi

	echo -e "$COLERREUR"
	echo -e "ATTENTION:${COLINFO} Avec Seven, il arrive que la partition de boot et la partition"
	echo -e "           contenant le Systeme different."
	echo -e "           On peut avoir:"
	echo -e "              /dev/sda1 NTFS une petite partition de boot"
	echo -e "              /dev/sda2 NTFS la partition systeme Window$ Seven"
	echo -e "           Dans ce cas, il faut sauvegarder sda2, mais noter que le boot se fait"
	echo -e "           sur sda1"

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo "Quelle est la partition systeme de Window$ (partition a sauvegarder)?"
		echo " (probablement sda1,...)"
		echo -e "Partition systeme window$: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
		read PARDOS
		echo ""
	
		if [ -z "$PARDOS" ]; then
			PARDOS="${DEFAULTPART}"
		fi
	
		#Verification:
		#if ! fdisk -s /dev/$PARDOS > /dev/null; then
		t=$(fdisk -s /dev/$PARDOS)
		if [ -z "$t" -o ! -e "/sys/block/$BOOTDISK/$PARDOS/partition" ]; then
			echo -e "$COLERREUR"
			echo "ERREUR: La partition proposee n'existe pas!"
			#exit
			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour corriger."
			read PAUSE
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


	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo "Quelle est la partition de boot du systeme de Window\$?"
		echo " (probablement sda1,...)"
		echo -e "Partition de boot window$: [${COLDEFAUT}${DEFAULT_BOOT_PART}${COLTXT}] $COLSAISIE\c"
		read PARBOOTDOS
		echo ""
	
		if [ -z "$PARBOOTDOS" ]; then
			PARBOOTDOS="${DEFAULT_BOOT_PART}"
		fi
	
		#Verification:
		#if ! fdisk -s /dev/$PARBOOTDOS > /dev/null; then
		t=$(fdisk -s /dev/$PARBOOTDOS)
		if [ -z "$t" -o ! -e "/sys/block/$BOOTDISK/$PARBOOTDOS/partition" ]; then
			echo -e "$COLERREUR"
			echo "ERREUR: La partition proposee n'existe pas!"
			#exit
			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour corriger."
			read PAUSE
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

done

echo -e "$COLPARTIE"
echo "__________________________________________"
echo "ETAPE 2: UNE PARTITION POUR SYSTEMRESCUECD"
echo "__________________________________________"

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	AFFICHHD

	echo -e "$COLTXT"
	echo "Sur quel disque souhaitez vous effectuer l'installation?"
	echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
	#echo -e "Disque: [${COLDEFAUT}hda${COLTXT}] $COLSAISIE\c"
	echo -e "Disque: [${COLDEFAUT}${BOOTDISK}${COLTXT}] $COLSAISIE\c"
	read SYSRESCDHD
	echo ""

	if [ -z "$SYSRESCDHD" ]; then
		#SYSRESCDHD="hda"
		SYSRESCDHD=${BOOTDISK}
	fi

	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$SYSRESCDHD:"
	#echo ""
	echo -e "$COLCMD\c"
	#fdisk -l /dev/$SYSRESCDHD
	LISTE_PART ${SYSRESCDHD} afficher_liste=y
	#echo ""

	echo -e "$COLINFO"
	echo -e "Pour l'installation de SystemRescueCD, \nune partition de type ext2 est indispensable."
	echo "Seul le format ext2 est supporte pour l'installation pour le moment."

	#REPDEF=""
	#if fdisk -l /dev/$SYSRESCDHD | grep Linux | grep -v "Linux swap" > /dev/null; then
	LISTE_PART ${SYSRESCDHD} avec_tableau_liste=y type_part_cherche=linux
	if [ -n "${liste_tmp[0]}" ]; then
		REPDEF="n"
	else
		echo -e "$COLINFO"
		echo "Aucune partition de type Linux n'a ete trouvee sur $SYSRESCDHD"
		REPDEF="o"
	fi

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Souhaitez-vous modifier les partitions \n(pour par exemple redimensionner/creer une partition)? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${REPDEF}${COLTXT}] $COLSAISIE\c"
		read REPONSE
		echo ""

		if [ -z "$REPONSE" ]; then
			REPONSE=$REPDEF
		fi
	done

	if [ "$REPONSE" = "o" ]; then

		POURSUIVRE="l"

		while [ "$POURSUIVRE" = "l" ]
		do
			POURSUIVRE="EN ATTENTE"
			OUTIL=""
			while [ "$OUTIL" != "1" -a "$OUTIL" != "2" -a "$OUTIL" != "3" -a "$OUTIL" != "4" ]
			do
				echo -e "$COLTXT"
				echo "Quel outil souhaitez-vous utiliser?"

				SYSRESCDHD_CLEAN=$(echo ${SYSRESCDHD}|sed -e "s|[^0-9A-Za-z]|_|g")
				fdisk -l /dev/$SYSRESCDHD > /tmp/fdisk_l_${SYSRESCDHD_CLEAN}.txt 2>&1
				#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${SYSRESCDHD}'" /tmp/fdisk_l_${SYSRESCDHD_CLEAN}.txt|cut -d"'" -f2)

				if [ "$(IS_GPT_PARTTABLE ${SYSRESCDHD})" = "y" ]; then
					TMP_disque_en_GPT=/dev/${SYSRESCDHD}
				else
					TMP_disque_en_GPT=""
				fi

				if [ -z "$TMP_disque_en_GPT" ]; then
					echo -e "(${COLCHOIX}1${COLTXT}) fdisk, (${COLCHOIX}2${COLTXT}) cfdisk, (${COLCHOIX}3${COLTXT}) parted, (${COLCHOIX}4${COLTXT}) GParted"
				else
					echo -e "(${COLCHOIX}1${COLTXT}) gdisk, (${COLCHOIX}2${COLTXT}) cgdisk, (${COLCHOIX}3${COLTXT}) parted, (${COLCHOIX}4${COLTXT}) GParted"
				fi

				echo -e "Note: Si vous devez redimensionner une partition,\nseuls GParted (graphique)"
				echo -e "      et parted (ligne de commande) peuvent convenir ici."

				echo ""
				echo -e "      Pour le redimensionnement d'une partition NTFS, l'outil en ligne de"
				echo -e "      commande ntfs-resize peut aussi etre employe."
				echo ""
				echo -e "Votre choix: $COLSAISIE\c"
				read OUTIL
				echo ""
			done

			if [ -z "$TMP_disque_en_GPT" ]; then
				echo -e "$COLTXT"
				if [ "$OUTIL" = "1" ]; then
					/sbin/fdisk /dev/$SYSRESCDHD
				fi

				if [ "$OUTIL" = "2" ]; then
					/sbin/cfdisk /dev/$SYSRESCDHD
				fi
			else
				echo -e "$COLTXT"
				if [ "$OUTIL" = "1" ]; then
					/sbin/gdisk /dev/$SYSRESCDHD
				fi

				if [ "$OUTIL" = "2" ]; then
					/sbin/cgdisk /dev/$SYSRESCDHD
				fi
			fi

			if [ "$OUTIL" = "3" ]; then
				/usr/sbin/parted  /dev/$SYSRESCDHD
			fi

			if [ "$OUTIL" = "4" ]; then
				#/usr/sbin/run_qtparted
				if [ -z "$WMAKER_BIN_NAME" -a -z "$DESKTOP_SESSION" ]; then
#					echo '#!/bin/sh
#/usr/sbin/gparted & ' > /root/GNUstep/Library/WindowMaker/autostart
#					chmod +x /root/GNUstep/Library/WindowMaker/autostart

					sed -i "s|.*exec /root/winmgr.sh >/dev/null 2>&1|exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc
					sed -i "s|exec /root/winmgr.sh >/dev/null 2>&1|/usr/sbin/gparted \& exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc

					startx
				else
					/usr/sbin/gparted
				fi
			fi

			POURSUIVRE=""
			while [ "$POURSUIVRE" != "p" -a "$POURSUIVRE" != "r" -a "$POURSUIVRE" != "l" ]
			do
				echo -e "$COLERREUR"
				echo "ATTENTION:"
				echo -e "${COLINFO}Il arrive qu'apres une modification, \nla table de partition ne puisse pas etre relue \n(pour prendre en compte les changements)."
				echo "Il est alors necessaire de rebooter pour tenir compte des changements."
				echo "Si par exemple, vous avez obtenu de fdisk le message:"
				echo -e "${COLERREUR}Warning: Re-reading the partition failed with error 16: Device or resource busy"
				echo "The kernel will still use the old table"
				echo -e "${COLINFO}Il ne faut alors pas poursuivre, mais quitter, rebooter et relancer ce script."
				echo -e "$COLTXT"
				echo -e "${COLCHOIX}P${COLTXT}oursuivre, ${COLCHOIX}l${COLTXT}ancer un autre outil ou ${COLCHOIX}r${COLTXT}ebooter? (${COLCHOIX}p/l/r${COLTXT}) $COLSAISIE\c"
				read POURSUIVRE
				echo ""
			done

		done

		if [ "$POURSUIVRE" = "r" ]; then
			echo -e "$COLERREUR"
			echo "Tapez 'reboot' puis relancez le script."
			exit
		fi
	fi

	REPONSE=""
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


echo -e "$COLPARTIE"
echo "__________________________________________"
echo "ETAPE 3: UNE PARTITION POUR SYSTEMRESCUECD"
echo "              2eme partie"
echo "__________________________________________"

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo "Recapitulatif: Voici les partitions sur le disque /dev/$SYSRESCDHD:"
	#echo ""
	echo -e "$COLCMD\c"
	#fdisk -l /dev/$SYSRESCDHD
	LISTE_PART ${SYSRESCDHD} afficher_liste=y
	echo ""

	#liste_tmp=($(fdisk -l /dev/$SYSRESCDHD | grep "^/dev/$SYSRESCDHD" | tr "\t" " " | grep -v "^/dev/${PARDOS} " | grep -v "^/dev/${PARBOOTDOS} " | grep -v "NTFS" | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95" | grep -v "FAT" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))
	LISTE_PART ${SYSRESCDHD} avec_tableau_liste=y type_part_cherche=linux
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART="${SYSRESCDHD}5"
	fi

	echo -e "$COLTXT"
	echo "Sur quelle partition souhaitez-vous installer SystemRescueCD?"
	echo "     (ex.: hda1, hdc2,...)"
	echo -e "Partition: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read SYSRESCDPART
	echo ""

	if [ -z "$SYSRESCDPART" ]; then
		SYSRESCDPART=${DEFAULTPART}
	fi

	#Verification:
	if ! fdisk -s /dev/$SYSRESCDPART > /dev/null; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposee n'existe pas!"
		exit
	fi

	REPDEF=1
	vdispo=$(fdisk -s /dev/$SYSRESCDPART)
	if [ $vdispo -lt 860000 ]; then
		echo -e "$COLERREUR"
		echo "Il semble que la partition soit un peu petite."
		echo "La distribution SysRescCD occupe a elle seule 850Mo et il semblerait que"
		echo "l'espace disponible soit insuffisant."
		REPDEF=2
	fi

	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}${REPDEF}${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			#REPONSE="1"
			REPONSE=${REPDEF}
		fi
	done
done

FORMATEE=""
while [ "$FORMATEE" != "o" -a "$FORMATEE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "La partition est-elle formatee? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read FORMATEE

	if [ -z "$FORMATEE" ]; then
		FORMATEE="n"
	fi
done
echo ""

if [ "$FORMATEE" = "n" ]; then

	if mount | grep "/dev/$SYSRESCDPART " > /dev/null; then
		echo -e "$COLCMD\c"
		umount /dev/$SYSRESCDPART || ERREUR "La partition $SYSRESCDPART est montee et n'a pas pu etre demontee.\nLe formatage d'une partition montee n'est pas possible."
	fi

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous verifier les blocs (long mais conseille)? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE
		echo ""

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	echo -e "$COLTXT"
	echo "Formatage de la partition $SYSRESCDPART en cours..."
	echo -e "$COLCMD"
	if [ "$REPONSE" = "o" ]; then
		/sbin/mke2fs -m 0 -c /dev/$SYSRESCDPART || ERREUR "Impossible de formater /dev/$SYSRESCDPART"
	else
		/sbin/mke2fs -m 0 /dev/$SYSRESCDPART || ERREUR "Impossible de formater /dev/$SYSRESCDPART"
	fi
	echo ""
fi

echo -e "$COLPARTIE"
echo "_______________________________________"
echo "ETAPE 4: INSTALLATION DE SYSTEMRESCUECD"
echo "_______________________________________"

if mount | grep "/dev/$SYSRESCDPART " > /dev/null; then
	echo -e "$COLCMD\c"
	umount /dev/$SYSRESCDPART || ERREUR "La partition $SYSRESCDPART est deja montee et n'a pas pu etre demontee."
fi

echo -e "$COLTXT"
echo -e "Montage de la partition ${COLINFO}/dev/$SYSRESCDPART${COLTXT} en ${COLINFO}/mnt/custom${COLTXT}..."
echo -e "$COLCMD"
mount /dev/$SYSRESCDPART /mnt/custom||ERREUR "Le montage a echoue!"
#echo ""

# On contrÃŽle si la partition est vide et on supprime tout ce qui n'est ni /home, ni /oscar:
ls /mnt/custom | while read A
do
	if [ "$A" != "home" -a "$A" != "oscar" -a "$A" != "lost+found" ]; then
		rm -fr /mnt/custom/$A
	fi
done

echo -e "$COLTXT"
echo "Extraction des fichiers de SysRescCD..."
echo "Attention: Cette operation est plutot longue..."
echo -e "$COLCMD"

if [ -z "${BOOT_IMAGE}" ]; then
	BOOT_IMAGE=$(sed -e "s/ /\n/g" /proc/cmdline | grep BOOT_IMAGE | cut -d"=" -f2)
fi

if [ -z "${BOOT_IMAGE}" ]; then
	BOOT_IMAGE="rescue32"
else
	BOOT_IMAGE=$(basename $BOOT_IMAGE)
fi

mnt_cdrom_isolinux=""
if [ -e "${mnt_cdrom}/isolinux" ]; then
	mnt_cdrom_isolinux=${mnt_cdrom}/isolinux
else
	if [ -e "${mnt_cdrom}/syslinux" ]; then
		mnt_cdrom_isolinux=${mnt_cdrom}/syslinux
	else
		echo -e "$COLERREUR"
		echo "Ni le dossier isolinux ni le dossier syslinux"
		echo "n'ont ete trouves sur ${mnt_cdrom}"
		sleep 5
	fi
fi

if [ ! -e "${mnt_cdrom_isolinux}/${BOOT_IMAGE}" ]; then
	echo -e "$COLTXT"
	echo "L'image de boot va etre recuperee sur un serveur distant."
	sleep 1
	if [ -z "$netboot" ]; then
		netboot=$(sed -e "s/ /\n/g" /proc/cmdline | grep netboot | cut -d"=" -f2)
	fi
	#ip_http_server=$(echo "$boothttp" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
	#ip_http_server=$(echo "$netboot" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
	ip_http_server=$(echo "$netboot" | sed -e "s|^http://||" | cut -d"/" -f1)
	ip_chemin_http_server=$(echo "$netboot" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
	# Dans le cas d'un boot TFTP prepare sur un SysRescCD, on a: http://ip_sysresccd/sysrcd.dat
	# Dans le cas d'un boot TFTP SE3, on a: http://ip_se3/sysrescd/sysrcd.dat

	if [ -z "$ip_http_server" ]; then
		echo -e "$COLERREUR"
		echo "La source de boot n a pas ete trouvee."
		echo "Pas de 'netboot=http://XXX/sysrcd.dat' dans votre /proc/cmdline"
		echo "La suite risque d echouer."
	else
		t=$(ping -c 1 $ip_http_server)
		if [ "$?" != "0" ]; then
			echo -e "$COLERREUR"
			echo "Le serveur TFTP ($ip_http_server) n'a pas ete atteint en ping."
			echo "Veuillez controler la configuration IP..."

			# La config reseau est necessaire.
			CONFIG_RESEAU
		fi

		echo -e "$COLTXT"
		echo "Telechargement de l'image de boot et de quelques fichiers."
		echo -e "$COLCMD\c"
		sleep 1

		# Telechargement HTTP en boot PXE
		cd /tmp

		mkdir -p /livemnt/boot/isolinux

		for i in usb_inst.sh usbstick.htm version
		do
			wget http://${ip_chemin_http_server}/$i
			cp /tmp/$i /livemnt/boot/
		done

		mkdir -p /livemnt/boot/usb_inst
		for i in dialog install-mbr mkfs.vfat mtools parted syslinux syslinux.exe xorriso
		do
			wget http://${ip_chemin_http_server}/usb_inst/$i
			cp /tmp/$i /livemnt/boot/usb_inst/
		done

		for i in rescue32 rescue64 altker32 initram.igz altker64
		do
			wget http://${ip_chemin_http_server}/isolinux/$i
			cp /tmp/$i /livemnt/boot/isolinux/
		done

		mkdir -p /livemnt/boot/sysresccd
		i="memtest.bin"
		wget http://${ip_chemin_http_server}/sysresccd/$i
		cp /tmp/$i /livemnt/boot/sysresccd

		# On cree les dossiers... pour ne pas planter sur le cp -a de sysresccd-custom
		mkdir -p /livemnt/boot/bootdisk
		mkdir -p /livemnt/boot/bootprog
		mkdir -p /livemnt/boot/ntpasswd

		# On a mis en place les fichiers requis pour la suite:
		mnt_cdrom_isolinux=/livemnt/boot/isolinux
	fi
fi

sysresccd-custom extract-nosizecheck||ERREUR "L'extraction a echoue!"

echo -e "$COLTXT"
echo "Nettoyage et deplacement des fichiers..."
echo -e "$COLCMD"
rm -fr /mnt/custom/customcd/isoroot
#2003_12_13
#mv /mnt/custom/customcd/files/* /mnt/custom

#Si la partition n'etait pas vide, il faut la vider:
#for I in bin boot dev etc home initrd lib mnt opt proc root sbin tmp usr var
#for I in bin boot dev etc initrd lib mnt opt proc root sbin tmp usr var
# Avec la 1.0.0, il n'y aurait plus de dossier initrd
#for I in bin boot dev etc initrd lib lib64 make.profile mnt opt proc root sbin sys tftpboot tmp usr var
for I in bin boot dev etc initrd lib lib64 mnt opt proc root sbin sys tftpboot tmp usr var
do
	if [ -e "/mnt/custom/$I" ]; then
		rm -fr /mnt/custom/$I
	fi
done
#Je ne supprime pas /oscar
#Si des sauvegardes etaient presentes, elles sont conservees.
#(valable pour une installation effectuee apres 07/05/2005
#date a laquelle, j'ai remplace le dossier /home/sauvegarde
#par un lien vers /oscar)

mv /mnt/custom/customcd/files/* /mnt/custom/
rm -fr /mnt/custom/customcd

echo -e "$COLINFO"
echo "NB: J'ai obtenu une erreur sans consequence:"
echo -e "    ${COLERREUR}mv: cannot overwrite directory '/mnt/custom/lost+found'"
echo ""

echo -e "$COLTXT"
echo "Copie de quelques scripts..."
echo -e "$COLCMD"
cp /mnt/custom/sbin/livecd-functions.sh /mnt/custom/sbin/livecd-functions.sh.officiel
cp /sbin/livecd-functions.sh /mnt/custom/sbin/livecd-functions.sh
cp /mnt/custom/usr/sbin/net-setup /mnt/custom/usr/sbin/net-setup.officiel
cp /usr/sbin/net-setup /mnt/custom/usr/sbin/net-setup
cp /mnt/custom/usr/sbin/sysresccd-custom /mnt/custom/usr/sbin/sysresccd-custom.officiel
cp /usr/sbin/sysresccd-custom /mnt/custom/usr/sbin/sysresccd-custom
cp -f /bin/*.sh /mnt/custom/bin/
chmod +x /mnt/custom/bin/*
chmod +x /mnt/custom/sbin/*
chmod +x /mnt/custom/usr/sbin/*

cp -f /root/.Xdefaults /root/.nanorc /root/.mrxvtrc /root/liste_rom-o-matic.txt /root/liste_smtp.txt /mnt/custom/root/
#cp -f /root/.zsh/rc/autorun.rc /mnt/custom/root/.zsh/
cp -fr /root/cles_pub_ssh /mnt/custom/root/
cp -f /etc/init.d/pxebootsrv_perso /mnt/custom/etc/init.d/
chmod +x /mnt/custom/etc/init.d/pxebootsrv_perso

echo -e "$COLTXT"
echo "Copie du noyau de SystemRescueCD..."
#cp ${mnt_cdrom}/isolinux/vmlinuz1 /mnt/custom/boot
echo -e "$COLCMD"
#cp ${mnt_cdrom}/isolinux/linux/sysrescd/vmlinuz1 /mnt/custom/boot

# Creation de l'arborescence
mkdir -p /mnt/custom/boot

#if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/vmlinuz1" ]; then
#	cp ${mnt_cdrom}/isolinux/linux/sysrescd/vmlinuz1 /mnt/custom/boot/
#else
#	cp ${mnt_cdrom}/isolinux/vmlinuz1 /mnt/custom/boot/
#fi

# BOOT_IMAGE est recuperee de /proc/cmdline
#Â Apparemment, ce n'est plus le cas???
# Pas en ssh toujours...
if [ -z "${BOOT_IMAGE}" ]; then
	BOOT_IMAGE=$(sed -e "s/ /\n/g" /proc/cmdline | grep BOOT_IMAGE | cut -d"=" -f2)
fi

if [ -z "${BOOT_IMAGE}" ]; then
	BOOT_IMAGE="rescue32"
else
	BOOT_IMAGE=$(basename $BOOT_IMAGE)
fi

if [ -e "${mnt_cdrom_isolinux}/${BOOT_IMAGE}" ]; then
	cp ${mnt_cdrom_isolinux}/${BOOT_IMAGE} /mnt/custom/boot/
	cp ${mnt_cdrom_isolinux}/initram.igz /mnt/custom/boot/

	# Par precaution, comme lilo et le noyau rescuecd ne font pas bon menage...
	#if [ "${BOOT_IMAGE}" != "altker32" ]; then
		for i in rescue32 rescue64 altker32 initram.igz altker64
		do
			if [ -e ${mnt_cdrom_isolinux}/$i ]; then
				cp -f ${mnt_cdrom_isolinux}/$i /mnt/custom/boot/
			fi
		done
	#fi
else
	#La variable $boothttp contient
	#	http://192.168.1.5/sysrcd.dat
	#En fait ${mnt_cdrom} est racine du serveur web sur le serveur TFTP/PXE.

	echo -e "$COLTXT"
	echo "L'image de boot va etre recuperee sur un serveur distant."

	# La config reseau est necessaire.
	CONFIG_RESEAU

	echo -e "$COLTXT"
	echo "Telechargement de l'image de boot."
	echo -e "$COLCMD\c"

	if [ -z "$netboot" ]; then
		netboot=$(sed -e "s/ /\n/g" /proc/cmdline | grep netboot | cut -d"=" -f2)
	fi
	#ip_http_server=$(echo "$boothttp" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
	#ip_http_server=$(echo "$netboot" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
	ip_http_server=$(echo "$netboot" | sed -e "s|^http://||" | cut -d"/" -f1)
	ip_chemin_http_server=$(echo "$netboot" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
	# Dans le cas d'un boot TFTP prepare sur un SysRescCD, on a: http://ip_sysresccd/sysrcd.dat
	# Dans le cas d'un boot TFTP SE3, on a: http://ip_se3/sysrescd/sysrcd.dat


	# Telechargement HTTP en boot PXE
	cd /tmp
	#wget http://${ip_http_server}/isolinux/${BOOT_IMAGE}
	#cp /tmp/${BOOT_IMAGE} /mnt/custom/boot/
	#if [ "${BOOT_IMAGE}" != "altker32" ]; then
		for i in rescue32 rescue64 altker32 initram.igz altker64
		do
			wget http://${ip_chemin_http_server}/isolinux/$i
			cp /tmp/$i /mnt/custom/boot/
		done
	#fi
	wget http://${ip_chemin_http_server}/isolinux/initram.igz
	cp /tmp/initram.igz /mnt/custom/boot/
fi

#echo ""

echo -e "$COLTXT"
echo "Ajout de la ligne designant la partition /dev/$SYSRESCDPART au fichier /etc/fstab..."
echo "/dev/$SYSRESCDPART / ext2 errors=remount-ro 0 1" >> /mnt/custom/etc/fstab
#echo ""

echo -e "$COLTXT"
echo "Creation du dossier /oscar et du lien /home/sauvegarde vers /oscar"
echo "pour assurer une compatibilite entre mes scripts et ceux d'OSCAR."
echo -e "$COLCMD\c"
mkdir -p /mnt/custom/oscar
if [ -e /mnt/custom/home/sauvegarde ]; then
	if [ ! -h /mnt/custom/home/sauvegarde ]; then
		mv /mnt/custom/home/sauvegarde/* /mnt/custom/oscar/ && rm -fr /mnt/custom/home/sauvegarde
	fi
fi
if [ ! -e "/mnt/custom/home/sauvegarde" ]; then
	chroot /mnt/custom ln -s /oscar /home/sauvegarde
fi


echo -e "$COLTXT"
echo "Mise en place du fichier /etc/inittab avec autologin..."
echo -e "$COLCMD\c"
cp /mnt/custom/etc/inittab /mnt/custom/etc/inittab.0
cp -f /etc/inittab /mnt/custom/etc/


echo -e "$COLTXT"
echo "Mise en place du fr.ktl pour disposer du clavier fr dans LILO..."
echo -e "$COLCMD\c"
#cp ${mnt_cdrom}/sysresccd/fr.ktl /mnt/custom/boot/
#cp ${mnt_cdrom}/sysresccd/maps/fr.ktl /mnt/custom/boot/
if [ -e ${mnt_cdrom_isolinux}/maps/fr.ktl ]; then
	cp ${mnt_cdrom_isolinux}/maps/fr.ktl /mnt/custom/boot/
else
	cd /tmp
	wget http://${ip_chemin_http_server}/isolinux/maps/fr.ktl
	cp /tmp/fr.ktl /mnt/custom/boot/
fi

# Pour desactiver le choix GRUB en attendant d'avoir regle le pb...
if [ "$PB_GRUB_OK" = "ok" ]; then
	echo -e "$COLINFO"
	echo "Il va maintenant vous etre propose de choisir entre LILO et GRUB pour le"
	echo "chargeur de demarrage."
	echo "LILO est discret et permet la protection par mot de passe"
	echo "(mais en clair dans le /etc/lilo.conf)."
	echo "GRUB est moins discret, mais permet une protection par mot de passe chiffre."
	echo "(inconvenient du chiffrage: si votre memoire defaille, il ne sera pas possible"
	echo "d'aller lire le menu.lst pour y retrouver le mot de passe"
	echo "(vous pourrez neanmoins changer ce mot de passe depuis une distribution Live))"
	#echo "(autre probleme: avec Grub, on a un clavier US pour saisir le mot de passe)"
	if [ "${BOOT_IMAGE}" != "altker32" ]; then
		echo -e "${COLERREUR}ATTENTION:${COLTXT} Vous n'avez pas boote sur le noyau ${COLINFO}altker32${COLTXT}, mais sur ${COLINFO}${BOOT_IMAGE}${COLTXT}"
		echo "           Avec ce noyau, il est recommande d'utiliser GRUB."
	fi

	REP_LILO_GRUB=""
	while [ "$REP_LILO_GRUB" != "1" -a "$REP_LILO_GRUB" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous utiliser LILO (${COLCHOIX}1${COLTXT}) ou GRUB (${COLCHOIX}2${COLTXT})"
		echo -e "pour le chargeur de demarrage? [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
		read REP_LILO_GRUB

		if [ -z "$REP_LILO_GRUB" ]; then
			REP_LILO_GRUB="2"
		fi
	done
else
	REP_LILO_GRUB="1"
fi

echo -e "$COLTXT"
#echo "Mise en place du fichier de configuration de LILO..."
echo "Mise en place du fichier de configuration de LILO/GRUB..."
#cp /usr/share/sysresccd/hdinstall/lilo.conf.in /mnt/custom/etc/lilo.conf

REP_MDP_LILO_GRUB=""
while [ "$REP_MDP_LILO_GRUB" != "o" -a "$REP_MDP_LILO_GRUB" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous proteger par un mot de passe le lancement de SysRescCD? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
	read REP_MDP_LILO_GRUB

	if [ -z "$REP_MDP_LILO_GRUB" ]; then
		REP_MDP_LILO_GRUB="o"
	fi
done
#echo ""

if [ "$REP_MDP_LILO_GRUB" = "o" ]; then

	echo -e "$COLTXT"
	echo "Le clavier charge lors du boot est assez limite."
	echo "Veuillez vous limiter a un mot de passe alphanumerique."

	while [ -z "$PASSWD" -o "$PASSWD" != "$VERIF" ]
	do
		echo -e "$COLTXT"
		echo -e "${COLTXT}Mot de passe : \033[41;31m\c"
		read PASSWD
		#echo -e "\033[0;39m                                                                                "
		echo -e "\033[0;39m                                                                                                                     "
		echo -e "${COLTXT}Verification : \033[43;33m\c"
		read VERIF
		#echo -e "\033[0;39m                                                                                "
		echo -e "\033[0;39m                                                                                                                     "

		test=$(echo "$PASSWD" | sed -e "s/[0-9A-Za-z]//g")
		if [ ! -z "$test" ]; then
			echo -e "${COLERREUR}"
			echo "Des caracteres susceptibles de ne pas etre disponibles au niveau de LILO"
			#echo "ont ete saisis."
			echo "ou GRUB ont ete saisis."
			echo "Il faut se limiter aux caracteres alphanumeriques."
			PASSWD=""
		else
			if [ "$PASSWD" != "$VERIF" ]; then
				echo -e "${COLERREUR}"
				echo -e "Les deux saisies ne coÃ¯ncident pas."
			fi
		fi

		#echo -e "Mot de passe: \033[41;31m\c"
		#read PASSWD
		#echo -e "\033[0;39m\r\c"
		#echo -e "Verification: \033[43;33m\c"
		#read VERIF
		#echo -e "\033[0;39m\r\c"

		#echo -e "$COLTXT"
	done
	echo -e "$COLCMD\c"
	MD5PASSWD=$(echo -e "md5crypt\n${PASSWD}" | grub --batch 2> /dev/null | grep "Encrypted" | sed -e 's/Encrypted: //g')


	#Mot de passe pour la restauration:
	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous utiliser un autre mot de passe pour la restauration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REP
		echo ""

		if [ -z "$REP" ]; then
			REP="n"
		fi
	done

	if [ "$REP" = "o" ]; then
		while [ -z "$RESTPASSWD" -o "$RESTPASSWD" != "$VERIF" ]
		do
			echo -e "$COLTXT"

			echo -e "${COLTXT}Mot de passe : \033[41;31m\c"
			read RESTPASSWD
			#echo -e "\033[0;39m                                                                                "
			echo -e "\033[0;39m                                                                                                                     "
			echo -e "${COLTXT}Verification : \033[43;33m\c"
			read VERIF
			#echo -e "\033[0;39m                                                                                "
			echo -e "\033[0;39m                                                                                                                     "

			test=$(echo "$RESTPASSWD" | sed -e "s/[0-9A-Za-z]//g")
			if [ ! -z "$test" ]; then
				echo -e "${COLERREUR}"
				echo "Des caracteres susceptibles de ne pas etre disponibles au niveau de LILO"
				#echo "ont ete saisis."
				echo "ou GRUB ont ete saisis."
				echo "Il faut se limiter aux caracteres alphanumeriques."
				RESTPASSWD=""
			else
				if [ "$RESTPASSWD" != "$VERIF" ]; then
					echo -e "${COLERREUR}"
					echo -e "Les deux saisies ne coÃ¯ncident pas."
				fi
			fi

			#echo -e "Mot de passe: \033[41;31m\c"
			#read PASSWD
			#echo -e "\033[0;39m\r\c"
			#echo -e "Verification: \033[43;33m\c"
			#read VERIF
			#echo -e "\033[0;39m\r\c"

			#echo -e "$COLTXT"
		done

		echo -e "$COLCMD\c"
		MD5RESTPASSWD=$(echo -e "md5crypt\n${RESTPASSWD}" | grub --batch 2> /dev/null | grep "Encrypted" | sed -e 's/Encrypted: //g')
	else
		RESTPASSWD=$PASSWD
		MD5RESTPASSWD=$MD5PASSWD
	fi

	echo -e "$COLCMD"
	touch /mnt/custom/etc/lilo.conf
	#chmod 600 /mnt/custom/etc/lilo.conf
fi

echo -e "$COLINFO"
echo -e "Resolution ecran par defaut:"
echo -e "$COLTXT\c"
echo -e "  (${COLCHOIX}1${COLTXT}) Standard"
echo -e "  (${COLCHOIX}2${COLTXT}) 640x480 256 couleurs"
#vga=769
echo -e "  (${COLCHOIX}3${COLTXT}) 800x600"
#vga=788
echo -e "  (${COLCHOIX}4${COLTXT}) 1024x768"
#vga=791
echo -e "  (${COLCHOIX}5${COLTXT}) 1024x768 vesa"
#vga=791 dostartx forcevesa
echo -e "  (${COLCHOIX}6${COLTXT}) standard VGA console (no KMS)"
#nomodeset
echo -e "  (${COLCHOIX}7${COLTXT}) console en 800x600"
#video=800x600

OPT_RESOLUTION=""
REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo -e "Resolution par defaut: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
	read OPT_RESOLUTION

	echo -e "$COLTXT"
	if [ -z "$OPT_RESOLUTION" ]; then
		# On met vide, parce que par la suite, c'est la chaine ajoutee aux options de boot
		OPT_RESOLUTION=""

		echo -e "Vous avez choisi: ${COLINFO}Standard"

		POURSUIVRE_OU_CORRIGER "1"
	else
		OPT_RESOLUTION_2=$(echo "$OPT_RESOLUTION"|sed -e "s|[^0-9]||g")
		if [ "$OPT_RESOLUTION" != "$OPT_RESOLUTION_2" ]; then
			echo -e "$COLERREUR\c"
			echo -e "ERREUR de saisie"
		else
			case $OPT_RESOLUTION in
			1)
				# On met vide, parce que par la suite, c'est la chaine ajoutee aux options de boot
				OPT_RESOLUTION=""
				echo -e "Vous avez choisi: ${COLINFO}Standard"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			2)
				OPT_RESOLUTION=" vga=769"
				echo -e "Vous avez choisi: ${COLINFO}640x480 256 couleurs"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			3)
				OPT_RESOLUTION=" vga=788"
				echo -e "Vous avez choisi: ${COLINFO}800x600"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			4)
				OPT_RESOLUTION=" vga=791"
				echo -e "Vous avez choisi: ${COLINFO}1024x768"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			5)
				OPT_RESOLUTION=" vga=791 forcevesa"
				echo -e "Vous avez choisi: ${COLINFO}1024x768 vesa"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			6)
				OPT_RESOLUTION=" nomodeset"
				echo -e "Vous avez choisi: ${COLINFO}standard VGA console (no KMS)"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			7)
				OPT_RESOLUTION=" video=800x600"
				echo -e "Vous avez choisi: ${COLINFO}console en 800x600"
				POURSUIVRE_OU_CORRIGER "1"
			;;
			*)
				echo -e "$COLERREUR\c"
				echo -e "ERREUR de saisie"
			;;
			esac
		fi
	fi
done

echo -e "$COLINFO"
echo -e "Il arrive avec certaines machines qu'il faille passer des options comme '${COLCHOIX}nonet${COLINFO}'"
echo -e "ou '${COLCHOIX}nodetect${COLINFO}' pour que le boot s'effectue correctement."

REPOPTBOOT=""
while [ "$REPOPTBOOT" != "o" -a "$REPOPTBOOT" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Est-il necessaire de passer certaines options a SysRescCD"
	echo -e "pour que le boot s'effectue correctement? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPOPTBOOT

	if [ -z "$REPOPTBOOT" ]; then
		REPOPTBOOT="n"
	fi
done

if [ "$REPOPTBOOT" = "o" ]; then
	OKOPTBOOT=""
	while [ "$OKOPTBOOT" != "1" ]
	do
		OPTBOOT=""
		echo -e "$COLTXT"
		echo -e "Saisissez les options souhaitees: $COLSAISIE\c"
		read OPTBOOT

		echo -e "$COLTXT"
		echo -e "Le systeme bootera avec les options suivantes: ${COLINFO}$OPTBOOT"

		while [ "$OKOPTBOOT" != "1" -a "$OKOPTBOOT" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou preferez-vous corriger (${COLCHOIX}2${COLTXT}) ? $COLSAISIE\c"
			read OKOPTBOOT
		done
	done
else
	OPTBOOT=""
fi

#OPTBOOT="$OPTBOOT $OPT_RESOLUTION"

if ! echo "$OPTBOOT" | grep -q dodhcp; then
	echo -e "$COLINFO"
	echo "Si vous disposez d'un serveur DHCP sur le reseau, vous pouvez configurer"
	echo "SysRescCD pour prendre une IP lors du boot."

	REP_DHCP=""
	while [ -z "$REP_DHCP" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous que le SysRescCD prenne une IP en DHCP lors du boot: (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REP_DHCP

		if [ -z "$REP_DHCP" ]; then
			REP_DHCP="n"
		fi
	done

	if [ "${REP_DHCP}" = "o" ]; then
		/bin/insere_cles_pub.sh /mnt/custom/root PAS_DE_CONFIG_MAINTENANT
	fi
fi
#echo -e "$COLTXT"

echo "lba32
boot = /dev/$BOOTDISK
map = /boot/.map
#prompt
install = /boot/boot-menu.b
delay = 50
vga = normal
keytable = /boot/fr.ktl
default = win" > /mnt/custom/etc/lilo.conf



# label: L'intitule Linux est indispensable pour change_mdp_lilo.sh
echo "image = /boot/${BOOT_IMAGE}
     root = /dev/$SYSRESCDPART
     label=Linux" >> /mnt/custom/etc/lilo.conf
if [ "${REP_DHCP}" = "o" ]; then
	echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=console.sh\"" >> /mnt/custom/etc/lilo.conf
else
	echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=console.sh\"" >> /mnt/custom/etc/lilo.conf
fi

if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "     password=$PASSWD #linux" >> /mnt/custom/etc/lilo.conf
fi

echo "     read-only" >> /mnt/custom/etc/lilo.conf


if [ "${BOOT_IMAGE}" != "rescue32" -a -e /mnt/custom/boot/rescue32 ]; then
	echo "image = /boot/rescue32
     root = /dev/$SYSRESCDPART
     label=Lin_std" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #lin_std" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "altker32" -a -e /mnt/custom/boot/altker32 ]; then
	echo "image = /boot/altker32
     root = /dev/$SYSRESCDPART
     label=Lin_alt" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #lin_alt" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "rescue64" -a -e /mnt/custom/boot/rescue64 ]; then
	echo "image = /boot/rescue64
     root = /dev/$SYSRESCDPART
     label=Lin_std64" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #lin_std64" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "altker64" -a -e /mnt/custom/boot/altker64 ]; then
	echo "image = /boot/altker64
     root = /dev/$SYSRESCDPART
     label=Lin_alt64" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=console.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #lin_alt64" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi


# label:
# Espaces supprimes pour change_mdp_lilo.sh
# (de faÃ§on a utiliser le meme que pour DiglooRescueCD)
echo "image = /boot/${BOOT_IMAGE}
     root = /dev/$SYSRESCDPART
     label=sauve" >> /mnt/custom/etc/lilo.conf
if [ "${REP_DHCP}" = "o" ]; then
	echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
else
	echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
fi

if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "     password=$PASSWD #sauve" >> /mnt/custom/etc/lilo.conf
fi

echo "     read-only" >> /mnt/custom/etc/lilo.conf


if [ "${BOOT_IMAGE}" != "rescue32" -a -e /mnt/custom/boot/rescue32 ]; then
	echo "image = /boot/rescue32
     root = /dev/$SYSRESCDPART
     label=Svg_std" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #svg_std" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi


if [ "${BOOT_IMAGE}" != "altker32" -a -e /mnt/custom/boot/altker32 ]; then
	echo "image = /boot/altker32
     root = /dev/$SYSRESCDPART
     label=Svg_alt" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #svg_alt" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "rescue64" -a -e /mnt/custom/boot/rescue64 ]; then
	echo "image = /boot/rescue64
     root = /dev/$SYSRESCDPART
     label=Svg_std64" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #svg_std64" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi


if [ "${BOOT_IMAGE}" != "altker64" -a -e /mnt/custom/boot/altker64 ]; then
	echo "image = /boot/altker64
     root = /dev/$SYSRESCDPART
     label=Svg_alt64" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=sauvewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$PASSWD #svg_alt64" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi



echo "image = /boot/${BOOT_IMAGE}
     root = /dev/$SYSRESCDPART
     label=restaure" >> /mnt/custom/etc/lilo.conf
if [ "${REP_DHCP}" = "o" ]; then
	echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
else
	echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
fi

if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	#echo "     password=$PASSWD" >> /mnt/custom/etc/lilo.conf
	echo "     password=$RESTPASSWD #restaure" >> /mnt/custom/etc/lilo.conf
fi

echo "     read-only" >> /mnt/custom/etc/lilo.conf


if [ "${BOOT_IMAGE}" != "altker32" -a -e /mnt/custom/boot/altker32 ]; then
	echo "image = /boot/altker32
     root = /dev/$SYSRESCDPART
     label=Rst_alt" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$RESTPASSWD #rst_alt" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "rescue32" -a -e /mnt/custom/boot/rescue32 ]; then
	echo "image = /boot/rescue32
     root = /dev/$SYSRESCDPART
     label=Rst_std" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$RESTPASSWD #rst_std" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "rescue64" -a -e /mnt/custom/boot/rescue64 ]; then
	echo "image = /boot/rescue64
     root = /dev/$SYSRESCDPART
     label=Rst_std64" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$RESTPASSWD #rst_std64" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi

if [ "${BOOT_IMAGE}" != "altker64" -a -e /mnt/custom/boot/altker64 ]; then
	echo "image = /boot/altker64
     root = /dev/$SYSRESCDPART
     label=Rst_alt64" >> /mnt/custom/etc/lilo.conf
	if [ "${REP_DHCP}" = "o" ]; then
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION dodhcp work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	else
		echo "append = \"initrd=/boot/initram.igz $OPTBOOT $OPT_RESOLUTION work=restaurewin.sh\"" >> /mnt/custom/etc/lilo.conf
	fi

	if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
		echo "     password=$RESTPASSWD #rst_alt64" >> /mnt/custom/etc/lilo.conf
	fi

	echo "     read-only" >> /mnt/custom/etc/lilo.conf
fi



echo "other = /dev/$PARBOOTDOS
     label = win
     table = /dev/$BOOTDISK" >> /mnt/custom/etc/lilo.conf




# Le memtestp.img (2.0 a la date du 12/03/2008) est plus recent que l'autre:
#if [ -e "${mnt_cdrom}/bootdisk/memtestp.img" ]; then
#	cp ${mnt_cdrom}/bootdisk/memtestp.img /mnt/custom/boot/
#	echo "image = /boot/memtestp.img
#     label = MemTest" >> /mnt/custom/etc/lilo.conf
#else
#	if [ -e "${mnt_cdrom}/isolinux/memtest86" ]; then
#		cp ${mnt_cdrom}/isolinux/memtest86 /mnt/custom/boot/
#		echo "image = /boot/memtest86
#		label = MemTest" >> /mnt/custom/etc/lilo.conf
#	fi
#fi
# Le memtestp.img provoque lors de l'install LILO un message
#   Fatal: Setup length exceeds 31 maximum; kernel setup will overwrite boot loader
# Pas de probleme par contre avec http://www.memtest.org/download/2.01/memtest86+-2.01.bin.gz
cp ${mnt_cdrom}/sysresccd/memtest.bin /mnt/custom/boot/
echo "image = /boot/memtest.bin
	label = MemTest" >> /mnt/custom/etc/lilo.conf


# Modification des droits pour le cas oÃ¹ on met des mots de passe.
chmod 600 /mnt/custom/etc/lilo.conf


#=====================================
# Creation du fichier de conf de GRUB:
echo -e "$COLCMD\c"
mkdir -p /mnt/custom/boot/grub
if [ -e /mnt/custom/boot/grub/menu.lst ]; then
	cp /mnt/custom/boot/grub/menu.lst /mnt/custom/boot/grub/menu.lst.$(date +%Y%m%d%H%M%S)
	rm -r /mnt/custom/boot/grub/menu.lst
fi

if [ "${SYSRESCDHD}" != "${BOOTDISK}" ]; then
	# Ca ne va fonctionner que s'il n'y a que deux DD et que W$ est sur le premier.
	num_sysrcd_hd=1
else
	num_sysrcd_hd=0
fi

# Rang des partitions...
tmp_rang_win=$(echo "$PARBOOTDOS" | sed -e "s/[A-Za-z]//g")
tmp_rang_win=$(($tmp_rang_win-1))
tmp_rang_sysrcd=$(echo "$SYSRESCDPART" | sed -e "s/[A-Za-z]//g")
tmp_rang_sysrcd=$(($tmp_rang_sysrcd-1))

# Dans la suite on suppose que le W$ et le SysRescCD sont sur le premier disque dur...
# ... a ameliorer...
echo "default         0
timeout         5
hiddenmenu
keytable (hd${num_sysrcd_hd},${tmp_rang_sysrcd})/boot/fr.ktl
color cyan/blue white/blue

# Clavier Pour GRUB
setkey q a
setkey Q A
setkey a q
setkey A Q
setkey w z
setkey W Z
setkey z w
setkey Z W

setkey comma m
setkey m semicolon
setkey question M
setkey semicolon comma
setkey M colon
setkey colon period
setkey period less
setkey slash greater
setkey exclam slash

setkey dollar bracketright
setkey asterisk backslash
setkey percent doublequote

setkey ampersand 1
setkey 1 exclam
setkey tilde 2
setkey 2 at
setkey doublequote 3
setkey 3 numbersign
setkey quote 4
setkey 4 dollar
setkey parenleft 5
setkey 5 percent
setkey minus 6
setkey 6 caret
setkey backquote 7
setkey 7 ampersand
setkey underscore 8
setkey 8 asterisk
setkey caret 9
setkey 9 parenleft
setkey at 0
setkey 0 parenright

setkey parenright minus
setkey less backquote
setkey greater tilde
setkey numbersign braceright

setkey backslash question
setkey bracketright braceleft
setkey braceleft quote
setkey braceright underscore
" > /mnt/custom/boot/grub/menu.lst

if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "# Mot de passe destine a eviter une edition des entrees de Grub" >> /mnt/custom/boot/grub/menu.lst
	echo "# Ne pas modifier la ligne de commentaire ci-dessous:" >> /mnt/custom/boot/grub/menu.lst
	echo "# MDP GRUB:" >> /mnt/custom/boot/grub/menu.lst
	echo "password --md5 $MD5PASSWD #linux" >> /mnt/custom/boot/grub/menu.lst
fi

if [ "${REP_DHCP}" = "o" ]; then
	OPTBOOT="$OPTBOOT dodhcp"
fi

echo "
# Section boot Windows
title           Windows
root            (hd0,${tmp_rang_win})
savedefault
makeactive
chainloader +1" >> /mnt/custom/boot/grub/menu.lst

echo "
title           Outils de maintenance :
root
" >> /mnt/custom/boot/grub/menu.lst

echo "
title           - Linux
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/${BOOT_IMAGE} root=/dev/$SYSRESCDPART $OPTBOOT $OPT_RESOLUTION work=console.sh ro setkmap=fr
initrd          /boot/initram.igz" >> /mnt/custom/boot/grub/menu.lst
if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "password --md5 $MD5PASSWD #linux" >> /mnt/custom/boot/grub/menu.lst
fi
echo "savedefault" >> /mnt/custom/boot/grub/menu.lst

echo "
title           - Sauvegarde
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/${BOOT_IMAGE} root=/dev/$SYSRESCDPART $OPTBOOT $OPT_RESOLUTION work=sauvewin.sh ro setkmap=fr
initrd          /boot/initram.igz" >> /mnt/custom/boot/grub/menu.lst
if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "password --md5 $MD5PASSWD #sauve" >> /mnt/custom/boot/grub/menu.lst
fi
echo "savedefault" >> /mnt/custom/boot/grub/menu.lst

echo "
title           - Restauration
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/${BOOT_IMAGE} root=/dev/$SYSRESCDPART $OPTBOOT $OPT_RESOLUTION work=restaurewin.sh ro setkmap=fr
initrd          /boot/initram.igz" >> /mnt/custom/boot/grub/menu.lst
if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "password --md5 $MD5RESTPASSWD #restaure" >> /mnt/custom/boot/grub/menu.lst
fi
echo "savedefault
" >> /mnt/custom/boot/grub/menu.lst

#if [ -e "${mnt_cdrom}/bootdisk/memtestp.img" ]; then
#	echo "title           Test memoire vive
#root            (hd0,${tmp_rang_sysrcd})
#kernel          /boot/memtestp.img
#" >> /mnt/custom/boot/grub/menu.lst
#else
#	if [ -e "${mnt_cdrom}/isolinux/memtest86" ]; then
#		echo "title           Test memoire vive
#root            (hd0,${tmp_rang_sysrcd})
#kernel          /boot/memtest86
#" >> /mnt/custom/boot/grub/menu.lst
#	fi
#fi

	echo "title           - Test memoire vive
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/memtest.bin

title           Autres options de maintenance
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})" >> /mnt/custom/boot/grub/menu.lst
if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo "password --md5 $MD5PASSWD #linux" >> /mnt/custom/boot/grub/menu.lst
fi
echo "configfile      /boot/grub/menu_alt.lst" >> /mnt/custom/boot/grub/menu.lst

#=====================================
# Menu avec les options et noyaux alternatifs
echo "default         0
#timeout         15
#hiddenmenu
keytable (hd${num_sysrcd_hd},${tmp_rang_sysrcd})/boot/fr.ktl
color orange/red white/red

# Clavier Pour GRUB
setkey q a
setkey Q A
setkey a q
setkey A Q
setkey w z
setkey W Z
setkey z w
setkey Z W

setkey comma m
setkey m semicolon
setkey question M
setkey semicolon comma
setkey M colon
setkey colon period
setkey period less
setkey slash greater
setkey exclam slash

setkey dollar bracketright
setkey asterisk backslash
setkey percent doublequote

setkey ampersand 1
setkey 1 exclam
setkey tilde 2
setkey 2 at
setkey doublequote 3
setkey 3 numbersign
setkey quote 4
setkey 4 dollar
setkey parenleft 5
setkey 5 percent
setkey minus 6
setkey 6 caret
setkey backquote 7
setkey 7 ampersand
setkey underscore 8
setkey 8 asterisk
setkey caret 9
setkey 9 parenleft
setkey at 0
setkey 0 parenright

setkey parenright minus
setkey less backquote
setkey greater tilde
setkey numbersign braceright

setkey backslash question
setkey bracketright braceleft
setkey braceleft quote
setkey braceright underscore

title           Outils de maintenance :
root

title           - Linux noyau rescue32 standard
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue32 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=788
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue32 1024x768
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue32 1024x768 vesa
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791 forcevesa
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue32 standard VGA console (no KMS)
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nomodeset
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue32 console en 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr video=800x600
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue32 sans detection
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nodetect
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=788
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32 1024x768
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32 1024x768 vesa
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791 forcevesa
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32 standard VGA console (no KMS)
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nomodeset
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32 console en 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr video=800x600
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker32 sans detection
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker32 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nodetect
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=788
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64 1024x768
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64 sans detection
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nodetect
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64 1024x768 vesa
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791 forcevesa
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64 standard VGA console (no KMS)
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nomodeset
initrd          /boot/initram.igz
savedefault

title           - Linux noyau rescue64 console en 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/rescue64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr video=800x600
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=788
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64 1024x768
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64 sans detection
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nodetect
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64 1024x768 vesa
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr vga=791 forcevesa
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64 standard VGA console (no KMS)
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr nomodeset
initrd          /boot/initram.igz
savedefault

title           - Linux noyau altker64 console en 800x600
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
kernel          /boot/altker64 root=/dev/$SYSRESCDPART $OPTBOOT work=console.sh ro setkmap=fr video=800x600
initrd          /boot/initram.igz
savedefault

title           Retour au menu principal
root            (hd${num_sysrcd_hd},${tmp_rang_sysrcd})
configfile      /boot/grub/menu.lst
" >> /mnt/custom/boot/grub/menu_alt.lst

#=====================================


if [ "$REP_LILO_GRUB" = "1" ]; then
	echo -e "$COLTXT"
	echo "Nous allons maintenant installer LILO..."
	echo -e "$COLCMD"
	#mount -t devfs none /mnt/custom/dev
	#mount -t proc none /mnt/custom/proc
	chroot /mnt/custom lilo
	#umount /mnt/custom/proc
	#umount /mnt/custom/dev

	echo -e "$COLINFO"
	echo "NB: On obtient generalement un avertissement sans consequence:"
	echo -e "$COLERREUR    Warning: '/proc/partitions' doesn't exist, disk scan bypassed"
	echo -e "$COLINFO"
	echo "   En revanche, si le message ci-dessus indique quelque chose comme"
	echo "   ce qui suit, il faut refaire l'installation de LILO"
	echo -e "$COLERREUR\c"
	echo "   Device 0x0800: Inconsistent partition table, 2nd entry
	CHS address in PT:  832:0:1  -->  LBA (13366080)
	LBA address in PT:  12579840  -->  CHS (783:15:1)
Fatal: Either FIX-TABLE or IGNORE-TABLE must be specified
If not sure, first try IGNORE-TABLE (-P ignore)"
	REP=""
	while [ "$REP" != "o" -a "$REP" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Avez-vous obtenu ce deuxieme message? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REP

		if [ -z "$REP" ]; then
			REP="n"
		fi
	done

	if [ "$REP" = "o" ]; then
		echo -e "$COLTXT"
		echo "Reinstallation de LILO"
		echo -e "$COLCMD"
		chroot /mnt/custom lilo -P ignore
	fi

	if [ "$BOOTDISK" != "$SYSRESCDHD" ]; then
		echo -e "$COLINFO\c"
		echo "NB2: Lorsque le disque de boot et le disque accueillant SysRescCD sont"
		echo "     differents, on obtient l'avertissement suivant:"
		echo -e "$COLERREUR          Warning: The boot sector and map file are on different disks."
		echo -e "$COLINFO\c"
		echo "     Cet avertissement est sans consequence si lors de l'ajout d'un peripherique"
		echo "     (disque dur, lecteur CD,...) les disques de boot et de SysRescCd ne"
		echo "     changent pas de statut (maitre, esclave,...)."
		echo ""
	fi
else
	echo -e "$COLTXT"
	echo "Nous allons maintenant installer GRUB..."
	echo -e "$COLCMD"
	#mount -t devfs none /mnt/custom/dev
	#mount -t proc none /mnt/custom/proc
	#echo "chroot /mnt/custom grub-install ${SYSRESCDHD}"
	#chroot /mnt/custom grub-install ${SYSRESCDHD}
	echo "grub-install --recheck --root-directory=/mnt/custom /dev/${SYSRESCDHD}"
	grub-install --recheck --root-directory=/mnt/custom /dev/${SYSRESCDHD}

	#Â Faire des tests sur le succes...
fi

# Si des mots de passe ont ete saisis, proposer d'anonymer le lilo.conf
if [ "$REP_MDP_LILO_GRUB" = "o" ]; then
	if [ "$REP_LILO_GRUB" = "2" ]; then
		echo -e "$COLINFO"
		echo "Vous avez choisi le chargeur de demarrage GRUB,"
		echo "mais un lilo.conf a tout de meme ete genere (par precaution)."
	fi

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous cacher les mots de passe du fichier /etc/lilo.conf? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done

	if [ "$REPONSE" = "o" ]; then
		tmp_lilo_conf=/mnt/custom/etc/lilo.conf
		echo -e "${COLTXT}"
		echo -e "Securisation du /etc/lilo.conf"
		echo -e "${COLCMD}\c"
		mv ${tmp_lilo_conf} ${tmp_lilo_conf}.secu
	#	cat ${tmp_lilo_conf}.secu | while read A
	#	do
	#		if echo "$A" | grep password | grep "#linux" > /dev/null; then
	#			echo "     password=XXXXX #linux" >> ${tmp_lilo_conf}
	#		else
	#			if echo "$A" | grep password | grep "#sauve" > /dev/null; then
	#				echo "     password=XXXXX #sauve" >> ${tmp_lilo_conf}
	#			else
	#				if echo "$A" | grep password | grep "#restaure" > /dev/null; then
	#					echo "     password=XXXXX #restaure" >> ${tmp_lilo_conf}
	#				else
	#					echo "$A" >> ${tmp_lilo_conf}
	#				fi
	#			fi
	#		fi
	#	done
		sed -r 's/(password=)[A-Za-z0-9]+( #*)/password=XXXXX\2/' ${tmp_lilo_conf}.secu > ${tmp_lilo_conf}

		echo -e "${COLTXT}"
		echo "Voici le nouveau contenu des lignes password:"
		echo -e "${COLCMD}\c"
		grep password ${tmp_lilo_conf}
		rm -f ${tmp_lilo_conf}.secu
	fi
fi

# On ne fait de pause que s'il a fallu reinstaller LILO:
#if [ "$REP" = "o" ]; then
#if [ "$REP" = "o" -o "$REP_MDP_LILO_GRUB" = "o" ]; then
	echo -e "${COLTXT}"
	echo "Pause... (taper sur Entree)"
	read PAUSE
#fi
echo ""

echo -e "$COLPARTIE"
echo "_____________________________________"
echo "ETAPE 5: MISE EN PLACE DES SCRIPTS..."
echo "_____________________________________"


echo -e "$COLINFO"
echo "Les sauvegardes peuvent etre effectuees a divers formats:"
echo -e "$COLTXT\c"
#echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions, mais encore instable"
#echo -e "                si le noyau Linux utilise est en version 2.6.x"

#echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions"
#echo "                    quel que soit le noyau Linux."
#echo -e " (${COLCHOIX}2${COLTXT}) dar: pour les partitions non-NTFS quel que soit le noyau Linux."
#echo -e " (${COLCHOIX}3${COLTXT}) ntfsclone: pour les partitions NTFS quel que soit le noyau Linux."

#echo -e "$COLTXT"
#echo "Voici le noyau actuellement utilise:"
#echo -e "$COLCMD\c"
#cat /proc/version

echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions."
echo -e "                                    (sauf ext4, reiser4, btrfs)"
echo -e " (${COLCHOIX}2${COLTXT}) dar: pour les partitions non-NTFS."
echo -e " (${COLCHOIX}3${COLTXT}) ntfsclone: pour les partitions NTFS seulement."
echo -e " (${COLCHOIX}4${COLTXT}) FsArchiver: pour tous les types de partitions"

DEFAULT_FORMAT_SVG=1
DETECTED_TYPE=$(TYPE_PART $PARDOS)
if [ "$DETECTED_TYPE" = "ntfs" ]; then
	DEFAULT_FORMAT_SVG=3
elif [ "$DETECTED_TYPE" = "ext4" ]; then
	DEFAULT_FORMAT_SVG=4
fi

FORMAT_SVG=""
while [ "$FORMAT_SVG" != "1" -a "$FORMAT_SVG" != "2" -a "$FORMAT_SVG" != "3" -a "$FORMAT_SVG" != "4" ]
do
	echo -e "$COLTXT"
	echo -e "Quel est le format de sauvegarde souhaite? [${COLDEFAUT}${DEFAULT_FORMAT_SVG}${COLTXT}] $COLSAISIE\c"
	read FORMAT_SVG

	if [ -z "$FORMAT_SVG" ]; then
		FORMAT_SVG=${DEFAULT_FORMAT_SVG}
	fi
done

case ${FORMAT_SVG} in
	1)
		TYPE_SVG="partimage"
	;;
	2)
		TYPE_SVG="dar"
	;;
	3)
		TYPE_SVG="ntfsclone"
	;;
	4)
		TYPE_SVG="fsarchiver"
	;;
esac

TYPE_PARDOS_FS=""
if [ "$FORMAT_SVG" = "2" ]; then
	echo -e "$COLINFO"
	echo "La sauvegarde avec 'dar' necessite de monter la partition /dev/$PARDOS"
	echo "Le type du systeme de fichier doit donc etre precise."
	echo "Cela peut-etre: vfat, ext2 ou ext3"

	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel est le type de la partition?"
		DETECTED_TYPE=$(TYPE_PART $PARDOS)
		if [ ! -z "${DETECTED_TYPE}" ]; then
			echo -e "Type: [${COLDEFAUT}${DETECTED_TYPE}${COLTXT}] $COLSAISIE\c"
			read TYPE_FS

			if [ -z "$TYPE_FS" ]; then
				TYPE_FS=${DETECTED_TYPE}
			fi
		else
			echo -e "Type: $COLSAISIE\c"
			read TYPE_FS
		fi

		echo -e "$COLTXT"
		echo "Tentative de montage..."
		echo -e "$COLCMD"
		mkdir -p /mnt/$PARDOS
		mount -t $TYPE_FS /dev/$PARDOS /mnt/$PARDOS
		umount /mnt/$PARDOS

		echo -e "$COLTXT"
		echo -e "Si aucun message d'erreur ne s'est affiche, vous pouvez poursuivre."
		REPONSE=""
		while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? $COLSAISIE\c"
			read REPONSE
		done
	done

	TYPE_PARDOS_FS="${TYPE_FS}"

fi

echo -e "$COLTXT"
#echo -e "Les scripts ${COLINFO}sauvewin.sh${COLTXT} et ${COLINFO}restaurewin.sh${COLTXT} vont maintenant etre generes..."
echo -e "Le fichier de parametres va etre genere"
echo -e "et les scripts ${COLINFO}sauvewin.sh${COLTXT}, ${COLINFO}restaurewin.sh${COLTXT},..."
echo -e "vont etre mis en place..."
#echo -e "$COLCMD\c"
#mkdir -p /home/sauvegarde

echo -e "$COLTXT"
echo "Les questions qui viennent vont permettre de definir le comportement par defaut"
echo "du poste lors de la sauvegarde/restauration."

REP_FIN=""
while [ "$REP_FIN" != "1" -a "$REP_FIN" != "2" ]
do
	echo -e "$COLTXT"
	echo "Quelle action souhaitez-vous en fin de sauvegarde/restauration?"
	echo -e "(${COLCHOIX}1${COLTXT}) Reboot."
	echo -e "(${COLCHOIX}2${COLTXT}) Arret."
	echo -e "Choix: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
	read REP_FIN

	if [ -z "$REP_FIN" ]; then
		REP_FIN="1"
	fi
done

if [ "$REP_FIN" = "1" ]; then
	#echo "reboot" > /mnt/custom/etc/svgrest_arret_ou_reboot.txt
	svgrest_arret_ou_reboot="reboot"
else
	#echo "arret" > /mnt/custom/etc/svgrest_arret_ou_reboot.txt
	svgrest_arret_ou_reboot="arret"
fi

if [ "$FORMAT_SVG" = "2" ]; then
	echo -e "$COLINFO"
	echo -e "Un mode automatique est propose pour le choix du nom de sauvegarde."
	echo -e "Si vous choisissez le mode automatique, lors des restaurations, la partition"
	echo -e "sera automatiquement videe avant de proceder a la restauration par desarchivage."
fi
REP_CHOIX_SVG=""
while [ "$REP_CHOIX_SVG" != "1" -a "$REP_CHOIX_SVG" != "2" ]
do
	echo -e "$COLTXT"
	echo "Souhaitez-vous qu'un choix de nom de sauvegarde a effectuer"
	echo "(ou qu'un choix de sauvegarde a restaurer vous soit propose)"
	echo "ou preferez-vous qu'un nom de sauvegarde par defaut"
	echo "soit automatiquement utilise?"
	echo -e "(${COLCHOIX}1${COLTXT}) Choix du nom de l'image."
	echo -e "(${COLCHOIX}2${COLTXT}) Automatique."
	echo -e "Choix: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
	read REP_CHOIX_SVG

	if [ -z "$REP_CHOIX_SVG" ]; then
		REP_CHOIX_SVG="1"
	fi
done

if [ "$REP_CHOIX_SVG" = "2" ]; then
	#echo "L'existence de ce fichier permet d'activer le mode automatique des scripts" > /mnt/custom/etc/svgrest_automatique.txt
	#echo "de sauvegarde/restauration. Cela consiste seulement a prendre des valeurs" >> /mnt/custom/etc/svgrest_automatique.txt
	#echo "par defaut apres un delai de 5-10 secondes en l'absence d'intervention" >> /mnt/custom/etc/svgrest_automatique.txt
	#echo "de l'utilisateur." >> /mnt/custom/etc/svgrest_automatique.txt
	svgrest_auto="o"
else
	#touch /mnt/custom/etc/_svgrest_automatique.txt
	svgrest_auto="n"
fi

RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD=""
while [ "$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD" != "o" -a "$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD" != "n" ]
do
	echo -e "$COLTXT"
	echo "Souhaitez-vous aussi restaurer par defaut les premiers Mo du disque dur"
	echo "lors d'une restauration de partition?"

	if [ -n "$PARBOOTDOS" ]; then
		echo "La partition de boot W$ sera aussi restauree lors de ces restaurations."
	fi

	echo -e "Choix: [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD

	if [ -z "$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD" ]; then
		RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD="n"
	fi
done

SVG_PARBOOTDOS="n"
if [ -n $PARBOOTDOS -a "$PARDOS" != "$PARBOOTDOS" ]; then
	SVG_PARBOOTDOS=""
	while [ "$SVG_PARBOOTDOS" != "o" -a "$SVG_PARBOOTDOS" != "n" ]
	do
		echo -e "$COLTXT"
		echo "Souhaitez-vous aussi sauvegarder la partition de boot W$"
		echo "lorsque vous faites une sauvegarde de la partition systeme W$ ?"

		echo -e "Choix: [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
		read SVG_PARBOOTDOS

		if [ -z "$SVG_PARBOOTDOS" ]; then
			SVG_PARBOOTDOS="o"
		fi
	done
fi

# Chemin du fichier de parametres:
fich_param=/etc/parametres_svgrest.sh

echo '# Parametres pour un SysRescCD installe sur disque dur.

# Partition systeme a sauvegarder/restaurer:
PARDOS="'${PARDOS}'"

# Partition de boot W$ (laisser vide si c est la meme que PARDOS)
PARBOOTDOS="'${PARBOOTDOS}'"

# Partition du systeme SysRescCD:
SYSRESCDPART="'${SYSRESCDPART}'"

# Format de sauvegarde:
# - partimage
# - ntfsclone
# - dar
# - fsarchiver
TYPE_SVG="'${TYPE_SVG}'"

# Preciser le type de la partition a sauvegarder dans le cas d une sauvegarde dar
# Le type peut etre vfat, ext3,...
TYPE_PARDOS_FS="'${TYPE_PARDOS_FS}'"

# Nom de l image par defaut
NOM_IMAGE_DEFAUT="image.${TYPE_SVG}"

# Sauvegarde/restauration automatique avec le nom d image par defaut:
svgrest_auto="'${svgrest_auto}'"

# Action apres sauvegarde/restauration:
# - reboot
# ou
# - arret
svgrest_arret_ou_reboot="'${svgrest_arret_ou_reboot}'"

# Emplacement de stockage des sauvegardes:
EMPLACEMENT_SVG="/home/sauvegarde"



# ================================================
# Chemin de ntfsclone
chemin_ntfs="/usr/sbin"

# Chemin de dar
chemin_dar="/usr/bin"

# ================================================
# Adaptation de l extension au type de sauvegarde:
case ${TYPE_SVG} in
	"partimage")
		SUFFIXE_SVG="000"
	;;
	"ntfsclone")
		SUFFIXE_SVG="ntfs"
	;;
	"dar")
		SUFFIXE_SVG="1.dar"
	;;
	"fsarchiver")
		SUFFIXE_SVG="fsa"
	;;
esac

# Restaurer par defaut les premiers Mo du disque dur:
RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD="'$RESTAURATION_PAR_DEFAUT_PERMIERS_MO_HD'"

# Sauvegarder par defaut la partition de boot W$ (si elle existe) lors des sauvegardes de la partition systeme:
SVG_PARBOOTDOS="'$SVG_PARBOOTDOS'"
 ' > /mnt/custom/${fich_param}

#Â Copie des scripts sauvewin.sh, restaurewin.sh,...
cp ${source_script_sysrescd_sur_hd}/* /mnt/custom/bin/
rm /mnt/custom/bin/next.sh 2>/dev/null
chmod +x /mnt/custom/bin/*.sh



echo -e "$COLTXT"
echo "Mise en place du script permettant de lancer sauve ou restaure des LILO..."
echo -e "$COLCMD\c"
#echo -e "if [ ! -z "\$work" ]; then" > /mnt/custom/root/.zsh/rc/zework.rc
#echo -e 'if [ ! -z "$work" ]; then' > /mnt/custom/root/.zsh/rc/zework.rc

# A cause de la possibilite de sauvegarde/restauration
# automatique apres 10s lors du boot sur 'sauve/restaure',
# il ne faut pas que le script se lance sur les 6 consoles.
#echo -e 'if [ ! -z "$work" -a "$TTY" = "/dev/vc/1" ]; then' > /mnt/custom/root/.zsh/rc/zework.rc
echo -e 'if [ ! -z "$work" ]; then
	if [ "$TTY" = "/dev/vc/1" -o "$TTY" = "/dev/tty1" ]; then
		/bin/$work
	fi
fi' >> /mnt/custom/root/.zsh/rc/zework.rc

chmod +x /mnt/custom/root/.zsh/rc/zework.rc

echo -e "$COLTXT"
echo "Mise en place d'un clavier 'fr'..."
#echo "Mise en place d'un clavier 'presque fr'..."
#echo -e "Le fr.map de partimage sera charge en fin de boot, \nmais il ne permet pas d'obtenir les caracteres obtenus normalement par AltGr."
#echo "Une solution plus satisfaisante est recherchee."
echo -e "$COLCMD\c"

# Ce n'est plus utile avec SysRescCD 0.4.0
#	# J'ai place tout le necessaire directement dans /mnt/custom/customcd/files/lib/keymaps
#	# et /mnt/custom/customcd/files/sbin en modifiant le sysrcd.dat de SysRescCD.
#	mkdir /mnt/custom/lib/keymaps
#	#cp ${mnt_cdrom}/sysresccd/partimage/fr.map /mnt/custom/lib/keymaps/
#	cp ${mnt_cdrom}/sysresccd/sysresccd/fr.map /mnt/custom/lib/keymaps/
#	cp ${mnt_cdrom}/sysresccd/sysresccd/loadkmap /mnt/custom/sbin/
#	chmod +x /mnt/custom/sbin/loadkmap
#	#echo "loadkeys < /lib/keymaps/fr.map" > /mnt/custom/root/.zsh/rc/zefrclavier.rc
#	echo "loadkmap < /lib/keymaps/fr.map" > /mnt/custom/root/.zsh/rc/zefrclavier.rc
echo "loadkeys fr-latin9 > /dev/null 2>&1" > /mnt/custom/root/.zsh/rc/zefrclavier.rc
#echo ""

echo -e "$COLTXT"
echo "Suppression de l'autorun en fin de boot..."
echo -e "$COLCMD\c"
rm -f /mnt/custom/root/autorun
rm -f /mnt/custom/root/autorun.sh
rm -f /mnt/custom/root/.zsh/rc/autorun.rc

# Pour eviter un probleme avec compinit en fin de boot:
#	zsh compinit: insecure directories, run compaudit for list.
#	Ignore insecure directories and continue [y] or abort compinit [n]?
# En lancant compaudit, on a une alerte sur /root/.zsh
chmod -R 755 /root/.zsh

echo -e "$COLTXT"
echo "Sauvegarde des 5 premiers Mo de $HD avec dd..."
echo -e "$COLCMD\c"
dd if="/dev/${BOOTDISK}" of="/mnt/custom/oscar/${BOOTDISK}_premiers_MO.bin" bs=1M count=5

if [ -n $PARBOOTDOS -a "$PARDOS" != "$PARBOOTDOS" ]; then
	echo -e "$COLINFO"
	echo "La partition systeme Window$ $PARDOS et la partition de boot Window$ $PARBOOTDOS"
	echo " different."
	echo "La partition qui sera sauvegardee est $PARDOS"
	echo "Voulez-vous sauvegarder maintenant $PARBOOTDOS par precaution?"
	echo "Cela ne sera plus propose par la suite."

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous sauvegarder maintenant $PARBOOTDOS par precaution? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done

	if [ "$REPONSE" = "o" ]; then
		echo -e "$COLTXT"
		echo "Sauvegarde de $PARBOOTDOS"
		echo -e "$COLCMD\c"
		sleep 1
		mkdir -p /mnt/custom/oscar
		ladate=$(date "+%Y%m%d-%H%M%S")

		DETECTED_TYPE=$(TYPE_PART $PARBOOTDOS)
		if [ "$DETECTED_TYPE" = "ntfs" ]; then
			echo "gzip" > /mnt/custom/oscar/${PARBOOTDOS}.$ladate.type_compression.txt
			$chemin_ntfs/ntfsclone --save-image -o - /dev/${PARBOOTDOS} | gzip -c  | split -b 650m - /mnt/custom/oscar/${PARBOOTDOS}.$ladate.ntfs
			if [ "$?" = "0" ]; then
				echo -e "$COLTXT"
				echo "SUCCES de la sauvegarde"

				echo "cat /oscar/${PARBOOTDOS}.$ladate.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$PARBOOTDOS - " > /mnt/custom/oscar/restaure_$PARBOOTDOS.$ladate.sh
				chmod +x /mnt/custom/oscar/restaure_$PARBOOTDOS.$ladate.sh
			else
				echo -e "$COLERREUR"
				echo "ECHEC de la sauvegarde"
			fi
		else
			partimage -b -c -d -f3 -o -z1 save /dev/$PARBOOTDOS /mnt/custom/oscar/$PARBOOTDOS.$ladate
			if [ "$?" = "0" ]; then
				echo -e "$COLTXT"
				echo "SUCCES de la sauvegarde"

				echo "partimage -b -f3 restore /dev/$PARBOOTDOS /oscar/$PARBOOTDOS.$ladate" > /mnt/custom/oscar/restaure_$PARBOOTDOS.$ladate.sh
				chmod +x /mnt/custom/oscar/restaure_$PARBOOTDOS.$ladate.sh
			else
				echo -e "$COLERREUR"
				echo "ECHEC de la sauvegarde"
			fi
		fi
	fi
fi

echo -e "$COLTXT"
echo "Sauvegarde de la table de partitions..."
echo -e "$COLCMD\c"
if [ "$(IS_GPT_PARTTABLE ${BOOTDISK})" = "y" ]; then
	sgdisk -b /mnt/custom/oscar/gpt_${BOOTDISK}.out /dev/${BOOTDISK}
else
	sfdisk -d /dev/${BOOTDISK} > /mnt/custom/oscar/${BOOTDISK}.out
fi

echo -e "$COLTXT"
echo "Extraction d'infos materielles avec lshw, dmidecode, lspci, lsmod, lsusb..."
echo -e "$COLCMD\c"
FICHIERS_RAPPORT_CONFIG_MATERIELLE /mnt/custom/oscar

echo -e "$COLTXT"
echo "Demontage de la partition accueillant SystemRescueCD..."
echo -e "$COLCMD\c"
umount /mnt/custom

#echo ""

echo -e "$COLTITRE"
echo "L'installation est maintenant effectuee."
echo -e "$COLTXT"

echo "Appuyez sur ENTREE pour revenir au menu."
read PAUSE


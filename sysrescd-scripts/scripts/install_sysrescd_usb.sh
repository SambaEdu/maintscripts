#!/bin/bash

# Script destine a changer installer SysRescCD et l'ensemble du multiboot sur un disque dur USB ou sur une cle USB
# Le bon fonctionnement de l'ensemble des options de boot n'a pas ete teste.
# Auteur: Stephane Boireau
# Derniere modification: 28/02/2013

#Couleurs
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
# Cyan

# Alternative: Booter SysRescCD depuis un grub:
#  title    SystemRescueCd from hard-disk
#  root     (hd0,7)
#  kernel   /sysrcd/rescuecd subdir=sysrcd setkmap=fr
#  initrd   /sysrcd/initram.igz
#  boot
# cf. http://www.sysresccd.org/Sysresccd-manual-en_Easy_install_SystemRescueCd_on_harddisk#Example_for_GRUB_bootmanager
# Et dans le cas dd usb, remplacer la ligne kernel par:
#  kernel   /sysrcd/rescuecd subdir=sysrcd setkmap=fr scandelay=5 
#

echo -e "${COLTITRE}"
echo "*************************"
echo "* Script d'installation *"
echo "*    sur cle/dd USB     *"
echo "*************************"

if [ ! -e /bin/my_sysresccd-usbstick.sh ]; then
	echo -e "$COLERREUR"
	echo "Abandon: Le script /bin/my_sysresccd-usbstick.sh est absent."
	echo -e "$COLTXT"
	exit
fi

echo -e "$COLTXT"
. /bin/my_sysresccd-usbstick.sh lib
. /bin/crob_fonctions.sh

echo -e "$COLTXT"
echo "Voici la liste des peripheriques amovibles susceptibles de convenir:"
echo -e "$COLCMD"
do_listdev

echo -e "$COLINFO"
echo "Vous pourrez choisir de creer ou non une nouvelle table de partitions."
echo "Vous pourrez egalement choisir la partition a utiliser s'il y en a plusieurs."

REPONSE=""
while [ "${REPONSE}" != "1" -a "${REPONSE}" != "2" ]
do
	echo -e "$COLTXT"
	if [ -n "${DEFAULT_DISK}" ]; then
		echo -e "Quel est le disque dur USB ou cle USB a utiliser? [${COLDEFAUT}${DEFAULT_DISK}${COLTXT}] $COLSAISIE\c"
	else
		echo -e "Quel est le disque dur USB ou cle USB a utiliser? $COLSAISIE\c"
	fi
	read HD_USB

	if [ -z "${HD_USB}" -a -n "${DEFAULT_DISK}" ]; then
		HD_USB=${DEFAULT_DISK}
	fi

	t=$(sfdisk -s /dev/$HD_USB 2>/dev/null)
	if [ -z "$t" -o ! -e "/sys/block/$HD_USB" ]; then
		echo -e "$COLERREUR"
		echo "Le disque $HD_USB n'existe pas."

		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour corriger."
		read PAUSE
		HD_USB=""
	else
		echo -e "${COLINFO}"
		echo -e "Vous avez choisi le disque ${COLCHOIX}${HD_USB}"

		POURSUIVRE_OU_CORRIGER "1"
	fi
done

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Faut-il creer une nouvelle table de partition sur ${HD_USB}? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

TYPE_AUTRE_PART=""
if [ "$REPONSE" = "o" ]; then
	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" -a "$REPONSE" != "4" -a "$REPONSE" != "5" -a "$REPONSE" != "6" -a "$REPONSE" != "7" ]
	do
		echo -e "$COLTXT"
		echo -e "Faut-il creer:"
		echo -e "(${COLCHOIX}1${COLTXT}) une seule partition ${COLINFO}${HD_USB}1${COLTXT} (fat32) sur ${HD_USB},"
		echo "ou deux partitions:"
		echo -e "(${COLCHOIX}2${COLTXT}) ${COLINFO}${HD_USB}1${COLTXT} fat32 de 1Go pour SYSRESC et le reste ${COLINFO}${HD_USB}2${COLTXT} en fat32 aussi,"
		echo -e "(${COLCHOIX}3${COLTXT}) ${COLINFO}${HD_USB}1${COLTXT} fat32 de 1Go pour SYSRESC et le reste ${COLINFO}${HD_USB}2${COLTXT} en ntfs,"
		echo -e "(${COLCHOIX}4${COLTXT}) ${COLINFO}${HD_USB}1${COLTXT} fat32 de 1Go pour SYSRESC et le reste ${COLINFO}${HD_USB}2${COLTXT} en ext3,"
		echo "(suivent des choix experimentaux)"
		echo -e "(${COLCHOIX}5${COLTXT}) debut ${COLINFO}${HD_USB}1${COLTXT} en fat32 pour les DONNEES et ${COLINFO}${HD_USB}2${COLTXT} fat32 de 1Go pour SYSRESC,"
		echo -e "(${COLCHOIX}6${COLTXT}) debut ${COLINFO}${HD_USB}1${COLTXT} en ntfs pour les DONNEES et ${COLINFO}${HD_USB}2${COLTXT} fat32 de 800Mo pour SYSRESC,"
		echo -e "(${COLCHOIX}7${COLTXT}) debut ${COLINFO}${HD_USB}1${COLTXT} en ext3 pour les DONNEES et ${COLINFO}${HD_USB}2${COLTXT} fat32 de 1Go pour SYSRESC,"
		echo -e "Votre choix: $COLSAISIE\c"
		read REPONSE
	done

	case $REPONSE in
	1)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait qu'une partition..."
		echo -e "$COLCMD"
		do_writembr /dev/${HD_USB}
	;;
	2)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait deux partitions:"
		echo " - Une FAT32 de 1Go pour SYSRESC"
		echo " - Une autre FAT32 de DONNEES sur le reste du disque"
		echo -e "$COLCMD"
		PART_USB=${HD_USB}1
		do_writembr /dev/${HD_USB} partitionnement=1G_fat32_reste_fat32
		TYPE_AUTRE_PART="fat32"
		PART_DONNEES=${HD_USB}2
	;;
	3)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait deux partitions:"
		echo " - Une FAT32 de 1Go pour SYSRESC"
		echo " - Une autre partition de DONNEES en NTFS sur le reste du disque"
		echo -e "$COLCMD"
		PART_USB=${HD_USB}1
		do_writembr /dev/${HD_USB} partitionnement=1G_fat32_reste_ntfs
		TYPE_AUTRE_PART="ntfs"
		PART_DONNEES=${HD_USB}2
	;;
	4)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait deux partitions:"
		echo " - Une FAT32 de 1Go pour SYSRESC"
		echo " - Une autre partition de DONNEES en ext3 sur le reste du disque"
		echo -e "$COLCMD"
		PART_USB=${HD_USB}1
		do_writembr /dev/${HD_USB} partitionnement=1G_fat32_reste_ext3
		TYPE_AUTRE_PART="ext3"
		PART_DONNEES=${HD_USB}2
	;;
	5)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait deux partitions:"
		echo " - Une partition de DONNEES en FAT32 sur le debut du disque"
		echo " - Une autre en FAT32 de 1Go en fin de disque pour SYSRESC"
		echo -e "$COLCMD"
		do_writembr /dev/${HD_USB} partitionnement=fin_1G_fat32_debut_fat32
		TYPE_AUTRE_PART="fat32"
		PART_DONNEES=${HD_USB}1
		PART_USB=${HD_USB}2
	;;
	6)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait deux partitions:"
		echo " - Une partition de DONNEES en NTFS sur le debut du disque"
		echo " - Une autre en FAT32 de 1Go en fin de disque pour SYSRESC"
		echo -e "$COLCMD"
		#do_writembr /dev/${HD_USB} partitionnement=fin_1G_fat32_debut_ntfs
		do_writembr /dev/${HD_USB} partitionnement=fin_800M_fat32_debut_ntfs
		TYPE_AUTRE_PART="ntfs"
		PART_DONNEES=${HD_USB}1
		PART_USB=${HD_USB}2
	;;
	7)
		echo -e "$COLTXT"
		echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}"
		echo -e "${COLTXT}On cree une nouvelle table de partitions et on ne fait deux partitions:"
		echo " - Une partition de DONNEES en ext3 sur le debut du disque"
		echo " - Une autre en FAT32 de 1Go en fin de disque pour SYSRESC"
		echo -e "$COLCMD"
		do_writembr /dev/${HD_USB} partitionnement=fin_1G_fat32_debut_ext3
		TYPE_AUTRE_PART="ext3"
		PART_DONNEES=${HD_USB}1
		PART_USB=${HD_USB}2
	;;
	esac

	if [ -n "$TYPE_AUTRE_PART" ]; then
		echo -e "$COLTXT"
		echo -e "Preparation de la partition de donnees ${COLINFO}${PART_DONNEES}:"
		echo -e "$COLCMD"
		sleep 2
		mkdir -p /mnt/${PART_DONNEES}
		case $TYPE_AUTRE_PART in
		"fat32")
			mount -t vfat /dev/${PART_DONNEES} /mnt/${PART_DONNEES}
		;;
		"ntfs")
			ntfs-3g /dev/${PART_DONNEES} /mnt/${PART_DONNEES}
		;;
		"ext3")
			mount /dev/${PART_DONNEES} /mnt/${PART_DONNEES}
		;;
		esac
		mkdir -p /mnt/${PART_DONNEES}/sauvegardes
		echo "*************
Instructions:
*************
Creer dans ce dossier autant de sous-dossiers que de configurations.
Dans chaque dossier, placer:
- la(les) sauvegarde(s) a restaurer (ex.: sda1_XP.000,...),
- un fichier de partitionnement sda.out (optionnel)
- un fichier de commentaire au prefixe de la sauvegarde (ex.: sda1_XP.txt)
- un fichier de description liste_svg.csv de la liste des restaurations a effectuer au format suivant:
#
# Chaque fichier liste_svg.csv doit etre de la forme:
#    num_part;type_svg;nom_image;
# avec eventuellement plusieurs lignes de sauvegardes:
#    1;ntfsclone;dell_optiplex_330_sda1_xp
#    5;partimage;dell_optiplex_330_sda5_ubuntu_racine
#    6;fsarchiver;dell_optiplex_330_sda6_ubuntu_home
# Le fichier peut/doit aussi contenir une ligne de description entouree de la chaine ###
#    ### Dell Optiplex 330 avec XPsp3 et Ubuntu 9.10 ###
#
# Le format
#    num_part;type_svg;nom_image;
# est le minimum indispensable, mais on peut le completer avec d'autres champs, comme
#    num_part;type_svg;nom_image;taille_part;
# Si ce 4eme champ existe, la taille originale de la partition sauvegardee est affichee.
# Cela peut etre commode si on restaure sur un disque de taille differente ou avec des partitions differentes pour re-preparer les partitions avec des dimensions permettant la restauration et sans perte de place.
#
" > /mnt/${PART_DONNEES}/sauvegardes/information.txt
	umount /mnt/${PART_DONNEES}
	fi

else

	DEFAULT_PART=""
	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$HD_USB:"
	LISTE_PART ${HD_USB} afficher_liste=y avec_tableau_liste=y
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULT_PART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	fi

	REPONSE=""
	while [ "${REPONSE}" != "1" -a "${REPONSE}" != "2" ]
	do
		echo -e "$COLTXT"
		if [ -n "${DEFAULT_PART}" ]; then
			echo -e "Quelle est la partition a utiliser? [${COLDEFAUT}${DEFAULT_PART}${COLTXT}] $COLSAISIE\c"
		else
			echo -e "Quelle est la partition a utiliser? $COLSAISIE\c"
		fi
		read PART_USB

		if [ -z "${PART_USB}" -a -n "${DEFAULT_PART}" ]; then
			PART_USB=${DEFAULT_PART}
		fi

		tst=$(sfdisk -s /dev/${PART_USB} 2>/dev/null)
		if [ -z "$tst" ]; then
			echo -e "$COLERREUR"
			echo "La partition ${PART_USB} n'existe pas."

			echo -e "$COLTXT"
			echo "Appuyez sur ENTREE pour corriger."
			read PAUSE
			PART_USB=""
		else
			echo -e "${COLINFO}"
			echo -e "Vous avez choisi ${COLCHOIX}${PART_USB}"

			POURSUIVRE_OU_CORRIGER "1"
		fi
	done

	echo -e "$COLTXT"
	echo -e "Re-ecriture du MBR sur ${COLINFO}${HD_USB}${COLTXT} sans refaire la table de partition."
	echo -e "$COLCMD"
	do_writembr /dev/${HD_USB} no_new_parttable part_usb=${PART_USB}
fi

echo -e "$COLTXT"
echo "Voici l'etat maintenant:"
echo -e "$COLCMD\c"
#fdisk -l /dev/${HD_USB}
LISTE_PART ${HD_USB} afficher_liste=y

POURSUIVRE "o"

echo -e "$COLTXT"
echo -e "Formatage de ${COLINFO}${PART_USB}"
echo -e "$COLCMD"
do_format /dev/${PART_USB}

POURSUIVRE "o"

echo -e "$COLTXT"
echo -e "Copie des fichiers vers ${COLINFO}${PART_USB}"
echo -e "$COLCMD"
do_copyfiles /dev/${PART_USB}

POURSUIVRE "o"

echo -e "$COLTXT"
echo -e "Mise en place de sylinux sur ${COLINFO}${PART_USB}"
echo -e "$COLCMD"
rm -f /tmp/erreur_syslinux
do_syslinux /dev/${PART_USB}
#if [ "$?" != "0" ]; then
if [ -e "/tmp/erreur_syslinux" ]; then
	echo -e "$COLERREUR"
	echo -e "Il s'est produit une erreur lors du syslinux vers /dev/${PART_USB}"
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous reessayer en ecrasant le secteur de boot de /dev/${PART_USB}? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done
	if [ "$REPONSE" = "o" ]; then
		do_syslinux /dev/${PART_USB} -i
	fi
fi

echo -e "$COLTXT"
echo -e "On repasse install-mbr sur ${COLINFO}${HD_USB}${COLTXT} par precaution..."
echo -e "$COLCMD"
cmd="$PROG_INSTMBR /dev/${HD_USB} --force"
echo $cmd
$cmd

echo -e "$COLTITRE"
echo "Termine."
echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour quitter..."
read PAUSE


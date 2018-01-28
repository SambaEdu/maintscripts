#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Script CDRESTAURE de SystemRescueCD
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 25/05/2016

# **********************************
# Version adaptee a System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

#Partition contenant un LILO a reinstaller en fin de restauration.
PART_REINSTALL_LILOGRUB=""


# Chemin vers les programmes dar et ntfsclone
chemin_dar="/usr/bin"
chemin_ntfs="/usr/sbin"

datetemp=$(date '+%Y%m%d-%H%M%S')

option_fsarchiver="-v"

echo -e "$COLTITRE"
echo "***********************************"
echo "* Script de sauvegarde CDRESTAURE *"
echo "***********************************"

echo -e "$COLINFO"
echo "Ce script peut permettre de realiser un CD bootable de restauration."
echo -e "$COLTXT"
echo "Souhaitez-vous mettre en place"
echo -e "l'ensemble de l'arborescence du cd? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
read CDRESTAUR

if [ "$CDRESTAUR" != "o" ]; then
	CDRESTAUR="n"
fi




echo -e "$COLPARTIE"
echo "==========================="
echo "DESTINATION DES SAUVEGARDES"
echo "==========================="

DEST_SVG

if [ "$CDRESTAUR" = "o" ]; then

	echo -e "$COLPARTIE"
	echo "==========================================="
	echo "Mise en place de l'arborescence CD-restaure"
	echo "==========================================="

	#if [ -z "${boothttp}" ]; then
	if [ -z "${netboot}" ]; then
		if mount | grep ${mnt_cdrom} > /dev/null; then
			echo -e "$COLTXT"
			echo "Le CD est deja monte."
		else
			echo -e "$COLTXT"
			echo "Pour mettre en place l'arborescence du cd de restauration,"
			echo "il est necessaire de monter le CD sur lequel vous avez boote."
			echo "Veuillez reinserer le CD si vous l'avez ejecte..."
			echo "Puis appuyez sur ENTREE."

			echo "Voici la liste des lecteurs/graveurs CD/DVD-ROM presents sur votre machine:"
			echo -e "$COLCMD"
			dmesg | grep hd | grep drive | grep -v driver | grep -v Cache | grep ROM
			dmesg | grep SCSI | grep ROM

			echo -e "$COLTXT"
			echo "Dans quel lecteur se trouve le CD?"
			echo " (probablement hda, hdb, hdc, hdd,...)"
			echo -e "Lecteur de CD: [${COLDEFAUT}hdc${COLTXT}] $COLSAISIE\c"
			read CDDRIVE

			if [ -z "$CDDRIVE" ]; then
				CDDRIVE="hdc"
			fi

			echo -e "$COLTXT"
			echo "Creation du point de montage ${mnt_cdrom}..."
			echo -e "$COLCMD"
			echo "mkdir -p ${mnt_cdrom}"
			mkdir -p ${mnt_cdrom}

			echo -e "$COLTXT"
			echo "Montage du CD..."
			echo -e "$COLCMD"
			echo "mount -t iso9660 /dev/$CDDRIVE ${mnt_cdrom}"
			mount -t iso9660 /dev/$CDDRIVE ${mnt_cdrom} || ERREUR "Le montage du cd a echoue!"
		fi
	fi

	if [ ! -e "${mnt_cdrom}/isolinux/linux/prtperso/lilrd2.img" ]; then
		REPIMAGE="2"
	else
		echo -e "$COLTXT"
		echo "Plusieurs images de boot peuvent etre utilisees:"
		echo -e "   (${COLCHOIX}1${COLTXT}) Partimage-baty (mini-distribution)"
		echo "       Avec busybox mis a jour..."
		echo "       Economique en volume: Moins de 10Mo sont pris sur le CD."
		echo "       Inconvenients: Certaines operations techniques ne fonctionnent pas:"
		echo "                      - Les operations de 'chroot' depuis un script"
		echo "                        de restauration (generalement utilise lors de"
		echo "                        restauration de partitions Linux)."
		echo "                      - La restauration multi-CD ne fonctionne pas depuis"
		echo "                        un script de restauration (alors qu'elle fonctionne"
		echo "                        si on lance l'operation a la main)."
		echo -e "   (${COLCHOIX}2${COLTXT}) SysRescCD:"
		echo "       Vous disposez alors d'une distribution tres complete, mais"
		#echo "       volumineuse (~100Mo) et plus longue a booter que les precedentes."
		#echo "       volumineuse (~100Mo) et plus longue a booter que la precedente."
		echo "       volumineuse (~${volume_sysresccd}Mo) et plus longue a booter que la precedente."
		echo "       Le volume n'est pas un probleme sur un DVD,"
		echo "       mais cela peut l'etre sur un CD."
		echo "       Si plusieurs CD/DVD sont necessaires, l'option docache de SysRescCD est"
		#echo "       indispensable. Elle necessite plus de 100Mo de RAM sur la machine."
		echo "       indispensable. Elle necessite plus de 300Mo de RAM sur la machine."
		echo "       C'est le seul choix possible si vous devez utiliser dar ou ntfsclone."
		REPIMAGE=""
		while [ "$REPIMAGE" != "1" -a "$REPIMAGE" != "2" ]
		do
			echo "Quelle image souhaitez-vous utiliser?"
			echo -e "Choix: [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
			read REPIMAGE

			if [ -z "$REPIMAGE" ]; then
				REPIMAGE="2"
			fi
		done
	fi

	echo -e "$COLTXT"
	echo -e "Mise en place de l'arborescence..."

	CHEMINBASE="$DESTINATION/cdrestaure"
	CHEMINCD="$DESTINATION/cdrestaure/disk"
	DESTINATION="$DESTINATION/cdrestaure/disk/save"
	mkdir -p "$CHEMINCD/isolinux"
	mkdir -p "$CHEMINCD/partjmb"
	mkdir -p "$CHEMINCD/save"

	echo "Copie des fichiers utiles pour ISOLINUX..."
	echo -e "$COLCMD\c"
	#if [ -e ${mnt_cdrom}/isolinux/reserve/isolinux.bin.reserve ]; then
	#if [ -z "${boothttp}" ]; then
	if [ -z "${netboot}" ]; then
		cp -f ${mnt_cdrom}/isolinux/reserve/isolinux.bin.reserve "$CHEMINCD/isolinux/isolinux.bin"
		#cp -f ${mnt_cdrom}/isolinux/fr.ktl "$CHEMINCD/isolinux/"

		for i in f1boot.msg f2images.msg f3params.msg f4arun.msg f5troubl.msg f6pxe.msg f7net.msg isolinux.bin kbdmap.c32 chain.c32 pxelinux.0 ifcpu64.c32 menu.c32 reboot.c32 vesamenu.c32 memdisk netboot fr.ktl
		do
			if [ -e ${mnt_cdrom}/isolinux/$i ]; then
				cp -f ${mnt_cdrom}/isolinux/$i "$CHEMINCD/isolinux/"
			fi
		done

		mkdir -p "$CHEMINCD/isolinux/maps"
		cp -f ${mnt_cdrom}/isolinux/maps/fr.ktl "$CHEMINCD/isolinux/maps"
	else
		# ${mnt_cdrom} est racine du serveur web sur le serveur TFTP/PXE.

		echo -e "$COLTXT"
		echo "Les fichiers requis vont etre recuperes sur un serveur distant."

		# La config reseau est necessaire.
		CONFIG_RESEAU

		echo -e "$COLTXT"
		echo "Telechargement des fichiers."
		echo -e "$COLCMD\c"

		#ip_http_server=$(echo "$boothttp" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")
		ip_http_server=$(echo "$netboot" | sed -e "s|^http://||" | sed -e "s|/sysrcd.dat||")

		# Telechargement HTTP en boot PXE
		cd /tmp
		wget http://${ip_http_server}/isolinux/reserve/isolinux.bin.reserve
		cp /tmp/isolinux.bin.reserve "$CHEMINCD/isolinux/isolinux.bin"

		wget http://${ip_http_server}/isolinux/fr.ktl
		cp /tmp/fr.ktl "$CHEMINCD/isolinux/"

		for i in f1boot.msg f2images.msg f3params.msg f4arun.msg f5troubl.msg f6pxe.msg f7net.msg isolinux.bin kbdmap.c32 chain.c32 pxelinux.0 ifcpu64.c32 menu.c32 reboot.c32 vesamenu.c32 memdisk netboot fr.ktl
		do
			wget http://${ip_http_server}/isolinux/$i
			cp /tmp/fr.ktl "$CHEMINCD/isolinux/"
		done

		mkdir -p /tmp/maps
		cd /tmp/maps
		wget http://${ip_http_server}/isolinux/maps/fr.ktl
		mkdir -p "$CHEMINCD/isolinux/maps"
		cp /tmp/maps/fr.ktl "$CHEMINCD/isolinux/maps/"
	fi

	case "$REPIMAGE" in
		1)
			#if [ -z "${boothttp}" ]; then
			if [ -z "${netboot}" ]; then
				if [ -e "${mnt_cdrom}/isolinux/lilrd2.img" ]; then
					cp -f ${mnt_cdrom}/isolinux/lilrd2.img "$CHEMINCD/isolinux/"
					cp -f ${mnt_cdrom}/isolinux/vmlilo "$CHEMINCD/isolinux/"
				else
					echo -e "$COLTXT"
					echo "Utilisation du chemin alternatif pour le noyau et l'initrd..."
					echo -e "$COLCMD"
					cp -f ${mnt_cdrom}/isolinux/linux/prtperso/lilrd2.img "$CHEMINCD/isolinux/"
					cp -f ${mnt_cdrom}/isolinux/linux/prtperso/vmlilo "$CHEMINCD/isolinux/"

					echo -e "$COLINFO"
					echo "Si aucune erreur n'est affichee pour le chemin alternatif, c'est OK."
					echo "En revanche, si les fichiers n'ont pas ete trouves non plus dans"
					echo "le chemin alternatif, il faudra que vous les mettiez en place a la main,"
					echo "sans quoi le CD ne bootera pas."
					echo "Cela n'interdit pas la sauvegarde."

					echo -e "$COLTXT"
					echo -e "Peut-on poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
					read REPONSE

					if [ "$REPONSE" = "n" ]; then
						ERREUR "Vous n'avez pas souhaite poursuivre."
					fi
				fi
			else
				echo -e "$COLTXT"
				echo "Telechargement des fichiers."
				echo -e "$COLCMD\c"
				cd /tmp
				wget http://${ip_http_server}/isolinux/linux/prtperso/lilrd2.img
				wget http://${ip_http_server}/isolinux/linux/prtperso/vmlilo
				#cp /tmp/lilrd2.img "$CHEMINCD/isolinux/"
				#cp /tmp/vmlilo "$CHEMINCD/isolinux/"
				mv /tmp/lilrd2.img "$CHEMINCD/isolinux/"
				mv /tmp/vmlilo "$CHEMINCD/isolinux/"
			fi
		;;
		2)
			mkdir -p "$CHEMINCD/sysresccd"

			#if [ -z "${boothttp}" ]; then
			if [ -z "${netboot}" ]; then
				echo -e "$COLINFO"
				#echo "Un peu plus de 100Mo vont etre copies."
				echo "Pres de ${volume_sysresccd}Mo vont etre copies."
				echo "Soyez patient..."
				echo -e "$COLCMD\c"
				cp -f ${mnt_cdrom}/autorun0 "$CHEMINCD/"
				cp -f ${mnt_cdrom}/sysresccd/scripts.tar.gz "$CHEMINCD/sysresccd/"

				if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/rescue32" ]; then
					cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/rescue32 "$CHEMINCD/isolinux/"
					#cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/rescuecd.igz "$CHEMINCD/isolinux/"
				else
					cp -f ${mnt_cdrom}/isolinux/rescue32 "$CHEMINCD/isolinux/"
					#cp -f ${mnt_cdrom}/isolinux/rescuecd.igz "$CHEMINCD/isolinux/"
				fi

				#if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/vmlinuz2" ]; then
				if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/altker32" ]; then
					#cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/vmlinuz2 "$CHEMINCD/isolinux/"
					cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/altker32 "$CHEMINCD/isolinux/"
					#cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/vmlinuz2.igz "$CHEMINCD/isolinux/"
				else
					#cp -f ${mnt_cdrom}/isolinux/vmlinuz2 "$CHEMINCD/isolinux/"
					cp -f ${mnt_cdrom}/isolinux/altker32 "$CHEMINCD/isolinux/"
					#cp -f ${mnt_cdrom}/isolinux/vmlinuz2.igz "$CHEMINCD/isolinux/"
				fi

				if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/rescue64" ]; then
					cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/rescue64 "$CHEMINCD/isolinux/"
					#cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/rescue64.igz "$CHEMINCD/isolinux/"
				else
					cp -f ${mnt_cdrom}/isolinux/rescue64 "$CHEMINCD/isolinux/"
					#cp -f ${mnt_cdrom}/isolinux/rescue64.igz "$CHEMINCD/isolinux/"
				fi

				if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/altker64" ]; then
					cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/altker64 "$CHEMINCD/isolinux/"
				else
					cp -f ${mnt_cdrom}/isolinux/altker64 "$CHEMINCD/isolinux/"
				fi

				if [ -e "${mnt_cdrom}/isolinux/linux/sysrescd/initram.igz" ]; then
					cp -f ${mnt_cdrom}/isolinux/linux/sysrescd/initram.igz "$CHEMINCD/isolinux/"
				else
					cp -f ${mnt_cdrom}/isolinux/initram.igz "$CHEMINCD/isolinux/"
				fi

				cp -f ${mnt_cdrom}/sysrcd.dat "$CHEMINCD/"
				cp -f ${mnt_cdrom}/sysrcd.md5 "$CHEMINCD/"

			else
				echo -e "$COLTXT"
				echo "Telechargement des fichiers."
				echo -e "$COLCMD\c"
				cd /tmp
				#for I in rescuecd rescuecd.igz vmlinuz2 vmlinuz2.igz rescue64 rescue64.igz
				for I in rescue32 rescue64 altker32 altker64 initram.igz
				do
					wget http://${ip_http_server}/isolinux/${I}
					#cp /tmp/${I} "$CHEMINCD/isolinux/"
					mv /tmp/${I} "$CHEMINCD/isolinux/"
				done

				wget http://${ip_http_server}/autorun0
				cp /tmp/autorun0 "$CHEMINCD/autorun0"
		
				wget http://${ip_http_server}/sysresccd/scripts.tar.gz
				cp /tmp/scripts.tar.gz "$CHEMINCD/sysresccd/scripts.tar.gz"

				#wget http://${ip_http_server}/sysrcd.dat
				#wget http://${ip_http_server}/sysrcd.md5
				#cp /tmp/sysrcd.dat "$CHEMINCD/"
				#cp /tmp/sysrcd.md5 "$CHEMINCD/"
				cp ${mnt_cdrom}/sysrcd.dat "$CHEMINCD/"
				cp ${mnt_cdrom}/sysrcd.md5 "$CHEMINCD/"
			fi

			chemin_courant=$PWD
			cd $CHEMINCD/isolinux
			ln ../sysresccd/scripts.tar.gz ./
			cd $chemin_courant

		;;
		*)
			ERREUR "Le choix de l'image de boot est incorrect."
		;;
	esac

	echo -e "$COLTXT"
	echo "Copie des fichiers utiles pour mes scripts partimage..."
	echo -e "$COLCMD\c"
	#cp ${mnt_cdrom}/partjmb/jmbrd.img "$CHEMINCD/partjmb/"
	#cp ${mnt_cdrom}/partjmb/libc.so.5 "$CHEMINCD/partjmb/"
	#cp ${mnt_cdrom}/partjmb/vmljmb "$CHEMINCD/partjmb/"

	#if [ -z "${boothttp}" ]; then
	if [ -z "${netboot}" ]; then
		# Dans le cas d'un boot docache, les fichiers d'exemple peuvent etre manquants
		if [ -e ${mnt_cdrom}/partjmb/restaure.exemple1 ]; then 
			cp -f ${mnt_cdrom}/partjmb/restaure.exemple* "$CHEMINCD/save/"
		fi
	else
		cd /tmp
		for I in 1 2 3 4 5 6
		do
			wget http://${ip_http_server}/partjmb/restaure.exemple${I}
			if [ "$?" = "0" ]; then
				cp /tmp/restaure.exemple${I} "$CHEMINCD/save/"
			fi
		done
	fi
	#cp -f ${mnt_cdrom}/partjmb/restaure.exemple2 "$CHEMINCD/save/"
	#cp -f ${mnt_cdrom}/partjmb/restaure.exemple3 "$CHEMINCD/save/"


	case "$REPIMAGE" in
		1)
		echo "default 0

display bootmsg.txt
kbdmap fr.ktl

label prt2
  kernel vmlilo
  append initrd=lilrd2.img load_ramdisk=1 prompt_ramdisk=0 rw root=/dev/ram work=console

label restaure
  kernel vmlilo
  append initrd=lilrd2.img load_ramdisk=1 prompt_ramdisk=0 rw root=/dev/ram work=cdrestaure.sh

timeout 600

prompt 1

F1 bootmsg.txt

label 0
    localboot 0x80
label a
    localboot 0x00
label q
    localboot -1

label disk1
    localboot 0x80
label disk2
    localboot 0x81
label floppy
    localboot 0x00
label nextboot
    localboot -1
" > "$CHEMINCD/isolinux/isolinux.cfg"
		;;
		2)

		echo -e "$COLINFO"
		echo -e "Il arrive avec certaines machines qu'il faille passer des options comme '${COLCHOIX}nonet${COLINFO}'"
		echo -e "ou '${COLCHOIX}nodetect${COLINFO}' pour que le boot s'effectue correctement."

		#==========================================
		# BOOT_IMAGE est recuperee de /proc/cmdline
		# Apparemment, ce n'est plus le cas???
		# Pas en ssh toujours...
		if [ -z "${BOOT_IMAGE}" ]; then
			BOOT_IMAGE=$(sed -e "s/ /\n/g" /proc/cmdline | grep BOOT_IMAGE | cut -d"=" -f2)
		fi

		if [ -z "${BOOT_IMAGE}" ]; then
			BOOT_IMAGE="rescue32"
		fi
		#==========================================

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
				echo -e "Le systeme bootera avec les options suivantes:"
				echo -e "$COLCMD"
				#echo "initrd=initrd1 $OPTBOOT acpi=off root=/dev/ram0 init=/linuxrc setkmap=fr work=cdrestaure.sh"
				#echo "initrd=rescuecd.igz $OPTBOOT init=/linuxrc video=ofonly vga=5 setkmap=fr cdroot work=cdrestaure.sh"
				#echo "initrd=rescuecd.igz $OPTBOOT video=ofonly vga=5 setkmap=fr cdroot work=cdrestaure.sh"
				#echo "initrd=${BOOT_IMAGE}.igz $OPTBOOT video=ofonly vga=5 setkmap=fr cdroot work=cdrestaure.sh"
				#echo "initrd=initram.igz $OPTBOOT video=ofonly vga=0 setkmap=fr work=cdrestaure.sh"
				echo "initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr work=cdrestaure.sh autoruns=0 ar_nowait "

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

		echo "default 0

display bootmsg.txt
kbdmap maps/fr.ktl

timeout 600

prompt 1

F1 bootmsg.txt

label 0
    localboot 0x80
label a
    localboot 0x00
label q
    localboot -1

label disk1
    localboot 0x80
label disk2
    localboot 0x81
label floppy
    localboot 0x00
label nextboot
    localboot -1

label restaure
  kernel ${BOOT_IMAGE}
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr work=cdrestaure.sh autoruns=0 ar_nowait
label rescuecd
  kernel rescue32
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr autoruns=0 ar_nowait
label nofb
  kernel rescue32
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr autoruns=0 ar_nowait
label rest1
  kernel rescue32
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr work=cdrestaure.sh autoruns=0 ar_nowait
label rest2
  kernel altker32
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr work=cdrestaure.sh autoruns=0 ar_nowait
label rest64
  kernel rescue64
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr work=cdrestaure.sh autoruns=0 ar_nowait
label rstalt64
  kernel altker64
  append initrd=initram.igz $OPTBOOT scandelay=1 setkmap=fr work=cdrestaure.sh autoruns=0 ar_nowait
label altker32
  kernel altker32
  append initrd=initram.igz scandelay=1 autoruns=0 ar_nowait
label rescue64
  kernel rescue64
  append initrd=initram.igz scandelay=1 autoruns=0 ar_nowait
label altker64
  kernel altker64
  append initrd=initram.igz scandelay=1 autoruns=0 ar_nowait
label fb640
  kernel rescue32
  append initrd=initram.igz scandelay=1 vga=785 autoruns=0 ar_nowait
label fb800
  kernel rescue32
  append initrd=initram.igz scandelay=1 vga=788 autoruns=0 ar_nowait
label fb1024
  kernel rescue32
  append initrd=initram.igz scandelay=1 vga=791 autoruns=0 ar_nowait
label fb1280
  kernel rescue32
  append initrd=initram.igz scandelay=1 vga=794 autoruns=0 ar_nowait
label nokeymap
  kernel rescue32
  append initrd=initram.igz scandelay=1 setkmap=us autoruns=0 ar_nowait
label vesa
  kernel rescue32
  append initrd=initram.igz scandelay=1 vga=791 forcevesa autoruns=0 ar_nowait
label fr
  kernel rescue32
  append initrd=initram.igz scandelay=1 setkmap=fr autoruns=0 ar_nowait
label uk
  kernel rescue32
  append initrd=initram.igz scandelay=1 setkmap=uk autoruns=0 ar_nowait
label minishell
  kernel rescue32
  append initrd=initram.igz scandelay=1 setkmap=uk minishell=/bin/ash autoruns=0 ar_nowait
label boothttp
  kernel rescue32
  append initrd=initram.igz scandelay=1 boothttp=ask autoruns=0 ar_nowait

timeout 600" > "$CHEMINCD/isolinux/isolinux.cfg"
		;;
	esac

	tmplabel=$(date +"%Y%m%d")
	DEFLABEL="CDREST${tmplabel}"
	#OKLABEL=""
	REPONSE=""
	echo -e "$COLTXT"
	echo -e "Quel label souhaitez-vous donner au CD?"
	echo "Le label est limite a 16 caracteres"
	echo "(evitez les espaces, accents et caracteres speciaux)."
	#while [ "$OKLABEL" != "1" ]
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Label: [${COLDEFAUT}${DEFLABEL}${COLTXT}] $COLSAISIE\c"
		read REPLABEL

		if [ -z "$REPLABEL" ]; then
			REPLABEL="$DEFLABEL"
		fi

		LABEL=${REPLABEL:0:16}

		longueur_test=$(echo "$LABEL" | tr "-" "_" | sed -e "s/[A-Za-z0-9._]//g" | wc -m)
		if [ "$longueur_test" != "1" ]; then
			echo -e "${COLERREUR}Des caracteres non valides ont ete saisis: ${COLCHOIX}$(echo "$LABEL" | tr "-" "_" | sed -e "s/[A-Za-z0-9._]//g")"
			REPONSE=2
		else
			echo -e "${COLINFO}Vous avez choisi ${COLCHOIX}${LABEL}"

			POURSUIVRE_OU_CORRIGER
		fi
	done




#	echo "       1fÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿07
#       1f³1e       CD-Rom MultiBoot RESTAURATION        1f³07
#       1f³1e    12RUE de Bernay/Pont-Audemer (S.Boireau)11  1f³07
#       1fÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ07
#
#       Label du media: 02${LABEL}07
#
#       02a07) Premier lecteur de disquette (0x00)
#       02q07) Ignorer le CD-Rom (essaie le prochain lecteur)
#       02007)02disk107) Premier disque dur (0x80)
#       02disk207) Premier disque dur (0x81)
#" > "$CHEMINCD/isolinux/bootmsg.txt"




	echo "       1e=============================================07
       1e       CD-Rom MultiBoot RESTAURATION         07
       1e    12RUE de Bernay/Pont-Audemer (S.Boireau)11   07
       1e=============================================07

       Label du media: 02${LABEL}07

       02a07) Premier lecteur de disquette (0x00)
       02q07) Ignorer le CD-Rom (essaie le prochain lecteur)
       02007)02disk107) Premier disque dur (0x80)
       02disk207) Premier disque dur (0x81)
" > "$CHEMINCD/isolinux/bootmsg.txt"


#	echo "
#       -----------------------------------------------
#       -       CD-Rom MultiBoot RESTAURATION         -
#       -    RUE de Bernay/Pont-Audemer (S.Boireau)   -
#       -----------------------------------------------
#
#       Label du media: ${LABEL}
#
#       a) Premier lecteur de disquette (0x00)
#       q) Ignorer le CD-Rom (essaie le prochain lecteur)
#       0) Premier disque dur (0x80)" > "$CHEMINCD/isolinux/bootmsg.txt"

	case "$REPIMAGE" in
		1)
			echo "       02prt207) partimage perso d apres JM.Baty (modif busybox)" >> "$CHEMINCD/isolinux/bootmsg.txt"
#			echo "       prt2) partimage perso d apres JM.Baty (modif busybox)" >> "$CHEMINCD/isolinux/bootmsg.txt"

			echo "
       02restaure07) Restauration

       Apres 60 secondes, ou appuie sur Entree, 0 sera lance...

       Effectuez votre choix de boot..." >> "$CHEMINCD/isolinux/bootmsg.txt"
		;;
		2)
			#echo "       02fb64007)02fb80007)02fb102407)02nofb07)02nokeymap07)02i810fb80007)02i810fb102407) SysRescCD/OSCAR" >> "$CHEMINCD/isolinux/bootmsg.txt"
			echo "       02fb64007)02fb80007)02fb102407)02fb128007)02nofb07)02nofb207)02nofb307)02nokeymap07)02i810fb80007)" >> "$CHEMINCD/isolinux/bootmsg.txt"
			echo "       02i810fb102407)02intelfb64007)02intelfb80007)02intelfb102407) SysRescCD/OSCAR" >> "$CHEMINCD/isolinux/bootmsg.txt"
			#echo "       fb640)fb800)fb1024)fb1280)nofb)nokeymap)i810fb800)" >> "$CHEMINCD/isolinux/bootmsg.txt"
			#echo "       i810fb1024)intelfb640)intelfb800)intelfb1024) SysRescCD/OSCAR" >> "$CHEMINCD/isolinux/bootmsg.txt"

			echo "
       02restaure07)02rest107)02rest207)02rest6407) Restauration
       (ne choisissez autre chose que 'restaure' que si vous etes sur de vous)

       Apres 60 secondes, ou appuie sur Entree, 0 sera lance...

       Effectuez votre choix de boot..." >> "$CHEMINCD/isolinux/bootmsg.txt"

		;;
	esac


#	echo "       restaure) Restauration
#
#       Apres 60 secondes, ou appuie sur Entre, 0 sera lance...
#
#       Effectuez votre choix de boot..." >> "$CHEMINCD/isolinux/bootmsg.txt"

	echo -e "$COLTXT"
	echo "Creation du script de generation de l'image ISO bootable..."
	echo -e "$COLCMD\c"

	echo "#!/bin/sh" > "$CHEMINBASE/creeriso.sh"
	echo 'echo "ATTENTION: Le script doit etre lance en tant que root pour des questions de droits"' >> "$CHEMINBASE/creeriso.sh"
	echo 'echo "           sur l arborescence creee."' >> "$CHEMINBASE/creeriso.sh"
	echo 'echo "           Si vous souhaitez lancer ce script en tant qu utilisateur lambda,"' >> "$CHEMINBASE/creeriso.sh"
	echo 'echo "           rendez l utilisateur lambda proprietaire du dossier cdrestaure"' >> "$CHEMINBASE/creeriso.sh"
	echo 'echo "           et des sous dossiers:   chown lambda cdrestaure -R"' >> "$CHEMINBASE/creeriso.sh"
	echo 'echo -e "Peut-on poursuivre? (o/n) \c"' >> "$CHEMINBASE/creeriso.sh"
	echo 'read REPONSE' >> "$CHEMINBASE/creeriso.sh"
	echo 'if [ "$REPONSE" != "o" ]; then exit; fi' >> "$CHEMINBASE/creeriso.sh"
	#echo 'mkisofs -J -N -v -volid "'$LABEL'" -p "Stephane" -P "NU2 Productions" -A "Created Barts way using MKISOFS/CDRECORD" -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -hide isolinux.bin -hide-joliet isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -o cdrestaure.iso disk || echo -e "\033[1;31m\nERREUR LORS DE LA CREATION DE L IMAGE ISO\n\033[0;37m"' >> "$CHEMINBASE/creeriso.sh"
	#echo 'mkisofs -J -N -v -volid "'$LABEL'" -p "Stephane" -A "Created Barts way using MKISOFS/CDRECORD" -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -hide isolinux.bin -hide-joliet isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -o cdrestaure.iso disk || echo -e "\033[1;31m\nERREUR LORS DE LA CREATION DE L IMAGE ISO\n\033[0;37m"' >> "$CHEMINBASE/creeriso.sh"
	echo 'mkisofs -J -l -N -v -volid "'$LABEL'" -p "Stephane" -A "Created Barts way using MKISOFS/CDRECORD" -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -hide isolinux.bin -hide-joliet isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -o cdrestaure.iso disk || echo -e "\033[1;31m\nERREUR LORS DE LA CREATION DE L IMAGE ISO\n\033[0;37m"' >> "$CHEMINBASE/creeriso.sh"
	if [ "${TYPE_DEST_SVG}" != 'smb' -a "${TYPE_DEST_SVG}" != 'ftp' ]; then
		# Les types ${TYPE_DEST_SVG} 'ssh' et 'partition' permettent de rendre executable un script.
		if ! mount | grep ${PTMNTSTOCK} | egrep -i "(vfat|ntfs)" > /dev/null; then
			chmod +x "$CHEMINBASE/creeriso.sh"
		fi
	fi

	echo "#!/bin/sh" > "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'if [ -z "$1" ]; then echo "USAGE: Passer en parametre le nom du dossier contenant l arborescence du CD supplementaire.";exit; fi' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "ATTENTION: Le script doit etre lance en tant que root pour des questions de droits"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "           sur l arborescence creee."' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "           Si vous souhaitez lancer ce script en tant qu utilisateur lambda,"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "           rendez l utilisateur lambda proprietaire du dossier cdrestaure"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "           et des sous dossiers:   chown lambda cdrestaure -R"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "Il est de plus necessaire de passer en parametre le nom du dossier contenant"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'echo "l arborescence du cd."' >> "$CHEMINBASE/creeriso_autres_cd.sh"

	echo 'echo -e "Peut-on poursuivre? (o/n) \c"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'read REPONSE' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'if [ "$REPONSE" != "o" ]; then exit; fi' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	#echo 'mkisofs -J -N -v -volid "'$LABEL'" -p "Stephane" -P "NU2 Productions" -A "Created Barts way using MKISOFS/CDRECORD" -hide boot.catalog -hide-joliet boot.catalog -o cdrestaure_${1}.iso $1 || echo -e "\033[1;31m\nERREUR LORS DE LA CREATION DE L IMAGE ISO\n\033[0;37m"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	#echo 'mkisofs -J -N -v -volid "'$LABEL'" -p "Stephane" -A "Created Barts way using MKISOFS/CDRECORD" -hide boot.catalog -hide-joliet boot.catalog -o cdrestaure_${1}.iso $1 || echo -e "\033[1;31m\nERREUR LORS DE LA CREATION DE L IMAGE ISO\n\033[0;37m"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	echo 'mkisofs -J -l -N -v -volid "'$LABEL'" -p "Stephane" -A "Created Barts way using MKISOFS/CDRECORD" -hide boot.catalog -hide-joliet boot.catalog -o cdrestaure_${1}.iso $1 || echo -e "\033[1;31m\nERREUR LORS DE LA CREATION DE L IMAGE ISO\n\033[0;37m"' >> "$CHEMINBASE/creeriso_autres_cd.sh"
	if [ "${TYPE_DEST_SVG}" != 'smb' -a "${TYPE_DEST_SVG}" != 'ftp' ]; then
		# Les types ${TYPE_DEST_SVG} 'ssh' et 'partition' permettent de rendre executable un script.
		if ! mount | grep ${PTMNTSTOCK} | egrep -i "(vfat|ntfs)" > /dev/null; then
			chmod +x "$CHEMINBASE/creeriso_autres_cd.sh"
		fi
	fi

	if [ -e "${mnt_cdrom}/sysresccd/mkisofs" ]; then
		echo -e "$COLCMD\c"
		cp ${mnt_cdrom}/sysresccd/mkisofs/* $CHEMINBASE/
	else
		#if [ ! -z "$boothttp" ]; then
		if [ ! -z "$netboot" ]; then
			echo -e "$COLCMD\c"
			cd /tmp
			for I in creeriso.bat cygwin1.dll mkisofs.exe
			do
				wget http://${ip_http_server}/sysresccd/mkisofs/${I}
				cp /tmp/${I} $CHEMINBASE/
			done
		fi
	fi

	echo -e "${COLTXT}Demontage du CD..."
	echo -e "$COLCMD"
	umount ${mnt_cdrom}
	echo ""
	echo -e "${COLINFO}Il peut arriver que le demontage provoque l'affichage d'erreurs.\nC'est notamment le cas avec SysRescCD boote sans l'option docache.\nCe n'est pas grave.${COLTXT}"
fi

echo -e "$COLCMD\c"
echo "#Script de restauration

. /bin/crob_fonctions.sh

# Modification du chemin de montage du cdrom depuis la version 1.5.0
#mnt_cdrom=/mnt/cdrom
mnt_cdrom=/livemnt/boot
" > "$DESTINATION/restaure.sh"
if [ "${TYPE_DEST_SVG}" != 'smb' -a "${TYPE_DEST_SVG}" != 'ftp' ]; then
	# Les types ${TYPE_DEST_SVG} 'ssh' et 'partition' permettent de rendre executable un script.
	if ! mount | grep ${PTMNTSTOCK} | egrep -i "(vfat|ntfs)" > /dev/null; then
		chmod +x "$DESTINATION/restaure.sh"
	fi
fi

echo -e "$COLTXT"
echo "Extraction d'infos materielles avec lshw, dmidecode, lspci, lsmod, lsusb..."
echo -e "$COLCMD\c"
FICHIERS_RAPPORT_CONFIG_MATERIELLE ${DESTINATION}

POURSUIVRE="o"
while [ "$POURSUIVRE" = "o" ]
do
	echo -e "$COLPARTIE"
	echo "==================================="
	echo "Choix de la partition a sauvegarder"
	echo "==================================="

	AFFICHHD

	if [ ! -z "$HD" ]; then
		DEFAULTHD=$HD
	else
		if [ ! -z "$SAVEHD" ]; then
			SAVEHD_CLEAN=$(echo ${SAVEHD}|sed -e "s|[^0-9A-Za-z]|_|g")
			#fdisk -l /dev/$SAVEHD > /tmp/fdisk_l_${SAVEHD_CLEAN}.txt 2>&1
			#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${SAVEHD}'" /tmp/fdisk_l_${SAVEHD_CLEAN}.txt|cut -d"'" -f2)

			if [ "$(IS_GPT_PARTTABLE ${SAVEHD})" = "y" ]; then
				disque_en_GPT=/dev/${SAVEHD}
			else
				disque_en_GPT=""
			fi

			if [ -z "$disque_en_GPT" ]; then
				# On teste s'il y a d'autres partitions sur le disque de sauvegarde
				liste_tmp=($(fdisk -l /dev/${SAVEHD} | grep "^/dev/${SAVEHD}" | tr "\t" " " | grep -v "^/dev/${CHOIX_DEST} " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Dell Utility" | cut -d" " -f1))
				if [ ! -z "${liste_tmp[0]}" ]; then
					DEFAULTHD=$SAVEHD
				else
					DEFAULTHD=$(GET_DEFAULT_DISK)
				fi
			else
				DEFAULTHD=$(GET_DEFAULT_DISK)
			fi
		else
			DEFAULTHD=$(GET_DEFAULT_DISK)
		fi
	fi

	DISQUEOK=""
	while [ "$DISQUEOK" != "o" ]
	do
		echo -e "$COLTXT"
		echo -e "Sur quel disque se trouve la partition a sauvegarder?"
		#echo -e "Disque: [${COLDEFAUT}hda${COLTXT}] $COLSAISIE\c"
		echo -e "Disque: [${COLDEFAUT}${DEFAULTHD}${COLTXT}] $COLSAISIE\c"
		read HD

		if [ -z "$HD" ]; then
			#HD="hda"
			HD=${DEFAULTHD}
		fi

		#La presentation longue affiche hdc comme un lien vers /dev/ide/host0/bus0/target1/lun0/cd
		if ! ls -l /dev/$HD | grep "/cd$" > /dev/null 2> /dev/null; then
			HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
			#fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
			#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt|cut -d"'" -f2)

			if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
				disque_en_GPT=/dev/${HD}
			else
				disque_en_GPT=""
			fi

			#if [ -z "$disque_en_GPT" ]; then
			#	if sfdisk -s /dev/$HD > /dev/null 2> /dev/null; then
			#		# La on n'elimine pas une partition pour autant...
			#		DISQUEOK="o"
			#	fi
			#else
			#	# Est-ce aussi fiable?
			#	if [ -e "/sys/block/$HD" ]; then
			#		DISQUEOK="o"
			#	fi
			#fi

			if [ -e "/sys/block/$HD" ]; then
				if sfdisk -s /dev/$HD > /dev/null 2> /dev/null; then
					DISQUEOK="o"
				fi
			fi
		fi
	done

	#=======================================================================
	TABLE_PART_DEJA_SAUVE="n"
	#if [ -e "$DESTINATION/cdrestaure/disk/save/$HD.out" -a "$CDRESTAUR" = "o" ]; then
	#	TABLE_PART_DEJA_SAUVE="o"
	#fi
	#if [ -e "$DESTINATION/$HD.out" -a "$CDRESTAUR" = "n" ]; then
	#	TABLE_PART_DEJA_SAUVE="o"
	#fi
	##DESTINATION est .../cdrestaure/disk/save
	if [ -e "$DESTINATION/$HD.out" -o -e "$DESTINATION/gpt_$HD.out"  ]; then
		TABLE_PART_DEJA_SAUVE="o"
	fi

	if [ "$TABLE_PART_DEJA_SAUVE" = "n" ]; then
		echo -e "$COLTXT"
		echo "Sauvegarde de la table de partition de $HD..."
		echo -e "$COLCMD"

		#if [ "$CDRESTAUR" = "o" ]; then
		#	#Le chemin a ete corrige plus haut:
		#	#DESTINATION=.../cdrestaure/disk/save
		#	sfdisk -d /dev/$HD > $DESTINATION/cdrestaure/disk/save/$HD.out
		#else
			HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
			#fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
			#disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt|cut -d"'" -f2)

			if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
				disque_en_GPT=/dev/${HD}
			else
				disque_en_GPT=""
			fi

			if [ -z "$disque_en_GPT" ]; then
				sfdisk -d /dev/$HD > $DESTINATION/$HD.out

				dd if=/dev/$HD of=$DESTINATION/parttable_${HD}.bin bs=512 count=1 2> /dev/null

	 			fdisk -l /dev/$HD | grep "^/dev/$HD" | cut -d" " -f1 | sed -e "s|/dev/||" | while read TMP_PART
				do
					dd if=/dev/${TMP_PART} of=$DESTINATION/bootsector_${TMP_PART}.bin bs=512 count=1 2> /dev/null
				done
			else
				sgdisk -b $DESTINATION/gpt_$HD.out /dev/$HD
			fi
		#fi

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
# Cyan


if [ ! -z "$3" ]; then
	# En lancant le script via
	#    sh restaure.sh 1 2 $PWD
	# on peut restaurer hors dispositif cdrestaure
	# Les deux premieres variables sont bidon.
	chemin_complet="$3"
else
	if [ -z "$1" -a "$0" = "./restaure.sh" ]; then
		chemin_complet="$PWD"
	else
		if [ -z "$2" ]; then
			chemin_source="${mnt_cdrom}"
		else
			chemin_source="$2"
		fi
		chemin_complet="$chemin_source/save"
	fi
fi

' >> "$DESTINATION/restaure.sh"





		echo 'echo -e "$COLTITRE"' >> "$DESTINATION/restaure.sh"
		echo 'echo "****************"' >> "$DESTINATION/restaure.sh"
		echo 'echo "* Restauration *"' >> "$DESTINATION/restaure.sh"
		echo 'echo "****************"' >> "$DESTINATION/restaure.sh"
		#echo 'echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"

		echo '
HD='$HD'

#TEST_HD=$(sfdisk -g | cut -d":" -f1|sed -e "s|^/dev/||")
#if [ "$HD" != "$TEST_HD" ]; then

TEST_HD=$(sfdisk -g 2>/dev/null| cut -d":" -f1|sed -e "s|^/dev/||" | grep "^$HD$")

if [ -z "$TEST_HD" ]; then
	echo -e "$COLERREUR"
	echo "ATTENTION:"
	echo -e "${COLTXT}Il semble que le disque identifie lors de la sauvegarde: ${COLINFO}$HD"
	#echo -e "${COLTXT}n apparaisse pas maintenant sous le meme device:         ${COLINFO}$TEST_HD"
	echo -e "${COLTXT}n apparaisse pas maintenant sous le meme device."
	echo -e "${COLTXT}Voici la liste des disques:${COLINFO}"
	sfdisk -g 2>/dev/null

	echo -e "$COLTXT"
	echo "Il se peut que vous deviez effectuer la restauration a la main."
	echo "Ou alors, peut-etre qu en bootant sur un noyau alternatif..."

	# Pour permettre de trouver les sauvegardes dans le dossier courant...
	echo -e "$COLCMD\c"
	cd $chemin_complet

	echo -e "$COLTXT"
	echo "Appuyez sur ENTREE pour poursuivre malgre tout..."
	echo "... ou sur CTRL+C pour interrompre et proceder manuellement."
	read PAUSE
	cd /root
fi

echo -e "$COLINFO"
echo "Si les partitions ont ete modifiees,"
echo "il est necessaire de remettre les partitions dans l etat initial"
echo "pour que la restauration des images partimage soit un succes."
echo ""
echo "Certains outils comme partimage ne peuvent pas restaurer une image"
echo "vers une partition plus petite que la partition sauvegardee."

echo -e "$COLCMD"
tmp_date=$(date +%Y%m%d%H%M%S)

HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
#fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1

temoin_gpt="n"
#if grep -q "WARNING: GPT (GUID Partition Table) detected on .*/dev/${HD}.*" /tmp/fdisk_l_${HD_CLEAN}.txt; then
if parted /dev/${HD} print|grep -qi "^Partition Table: gpt"; then

	echo "sgdisk -b /tmp/gpt_$HD.${tmp_date}.out /dev/$HD"
	sgdisk -b /tmp/gpt_$HD.${tmp_date}.out /dev/$HD
	temoin_gpt="y"
else
	echo "sfdisk -d /dev/${HD} > /tmp/${HD}.${tmp_date}.out"
	sfdisk -d /dev/${HD} > /tmp/${HD}.${tmp_date}.out
fi
' >> "$DESTINATION/restaure.sh"

		if [ "$temoin_premiers_Mo_dd_sauve" != "y" ]; then
			echo -e "$COLTXT"
			echo "Sauvegarde des 5 premiers Mo de $HD avec dd..."
			echo -e "$COLCMD\c"
			dd if="/dev/${HD}" of="${DESTINATION}/${HD}_premiers_MO.bin" bs=1M count=5

			echo '
echo -e "$COLERREUR"
echo -e "EXPERIMENTAL:$COLINFO"
echo "Les premiers Mo du disque dur $HD ont ete sauvegardes."
echo ""
echo "Il semble necessaire de les restaurer dans le cas d une restauration"
echo "de Window$ Seven ou peut-etre avec un BIOS UEFI."
echo "Des choses semblent cachees entre le MBR et la premiere partition."
echo ""
echo "Si vous choisissez de restaurer ces premiers Mo, la table de partition"
echo "sera aussi refaite d apres la sauvegarde."

#echo "Dans 20 secondes, on poursuivra sans les restaurer."

REP=""
while [ "$REP" != "o" -a "$REP" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous les restaurer? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
	#read -t 20 REP
	read REP

	if [ -z "$REP" ]; then
		REP="n"
	fi
done

if [ "$REP" = "o" ]; then
	echo -e "$COLTXT"
	echo "Restauration des premiers Mo du disque."
	echo -e "$COLCMD"' >> "$DESTINATION/restaure.sh"

#			if [ "$CDRESTAUR" = "o" ]; then
				echo '
	dd if="${chemin_complet}/${HD}_premiers_MO.bin" of=/dev/${HD} bs=1M count=5' >> "$DESTINATION/restaure.sh"
#			else
#				echo '
#	dd if="${HD}_premiers_MO.bin" of=/dev/${HD} bs=1M count=5' >> "$DESTINATION/restaure.sh"
#			fi

			echo '
	sleep 2
	partprobe /dev/${HD}
	sleep 2
	restauration_debut_dd="o"
fi
' >> "$DESTINATION/restaure.sh"

			temoin_premiers_Mo_dd_sauve="y"
		fi



		if [ "$CDRESTAUR" = "o" ]; then
			echo 'if [ "$temoin_gpt" != "y" ]; then
	test_diff=$(diff -abB /tmp/${HD}.${tmp_date}.out $chemin_complet/$HD.out)
else
	test_diff=$(diff -abB /tmp/gpt_${HD}.${tmp_date}.out $chemin_complet/gpt_$HD.out)
fi' >> "$DESTINATION/restaure.sh"
		else
			echo 'if [ "$temoin_gpt" != "y" ]; then
	test_diff=$(diff -abB /tmp/${HD}.${tmp_date}.out $HD.out)
else
	test_diff=$(diff -abB /tmp/gpt_${HD}.${tmp_date}.out gpt_$HD.out)
fi' >> "$DESTINATION/restaure.sh"
		fi

		echo '
# Initialisation pour le cas ou on ne passe pas dans le if qui suit
REPONSE=""

# Si on a restaure les premiers Mo du disque, on force la recreation de la table de partitions:
if [ "$restauration_debut_dd" != "o" ]; then
	if [ ! -z "${test_diff}" ]; then
		echo -e "$COLTXT"
		echo "La table de partition semble avoir change depuis votre sauvegarde."

		if [ "$temoin_gpt" != "y" ]; then
			echo "La table de partition actuelle est:"
			echo -e "$COLCMD\c"
			cat /tmp/${HD}.${tmp_date}.out

			echo -e "$COLTXT"
			echo "Votre sauvegarde de la table de partition est:"
			echo -e "$COLCMD\c"
' >> "$DESTINATION/restaure.sh"

		if [ "$CDRESTAUR" = "o" ]; then
			echo '		cat $chemin_complet/$HD.out' >> "$DESTINATION/restaure.sh"
		else
			echo '		cat $HD.out' >> "$DESTINATION/restaure.sh"
		fi

		echo '
		fi

		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour poursuivre..."
		read PAUSE

		DEFAUT_REFAIRE_PART="o"
	else
		echo -e "$COLTXT"
		echo "La table de partitions actuelle et la table sauvegardees sont identiques."
		echo "La restauration de la table parait inutile."

		DEFAUT_REFAIRE_PART="n"
	fi

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous refaire la table de partition? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${DEFAUT_REFAIRE_PART}${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=${DEFAUT_REFAIRE_PART}
		fi
	done
fi

echo -e "$COLCMD"
if [ "$REPONSE" = "o" -o "$restauration_debut_dd" = "o" ]; then
	echo -e "$COLTXT"
	echo "Restauration de la table de partition..."
	echo -e "$COLCMD"
	sleep 1
' >> "$DESTINATION/restaure.sh"


		HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
		#fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
		temoin_gpt="n"
		#if grep -q "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt; then
		if parted /dev/${HD} print|grep -qi "^Partition Table: gpt"; then
			temoin_gpt="y"
		fi

		if [ "$CDRESTAUR" = "o" ]; then
			#echo "	sfdisk /dev/$HD < ${mnt_cdrom}/save/$HD.out" >> "$DESTINATION/restaure.sh"
			#echo "	sfdisk /dev/$HD < \$chemin_source/save/$HD.out" >> "$DESTINATION/restaure.sh"
			#echo "	sfdisk /dev/$HD < \$chemin_complet/$HD.out" >> "$DESTINATION/restaure.sh"
			if [ "$temoin_gpt" != "y" ]; then
				echo '	echo "sfdisk /dev/$HD < $chemin_complet/$HD.out"
	sfdisk /dev/$HD < $chemin_complet/$HD.out
' >> "$DESTINATION/restaure.sh"
			else
				echo '	echo "sgdisk -l $chemin_complet/gpt_$HD.out /dev/$HD"
	sgdisk -l $chemin_complet/gpt_$HD.out /dev/$HD
' >> "$DESTINATION/restaure.sh"
			fi
		else
			#echo "	sfdisk /dev/$HD < $HD.out" >> "$DESTINATION/restaure.sh"
			if [ "$temoin_gpt" != "y" ]; then
				echo '	echo "sfdisk /dev/$HD < $HD.out"
	sfdisk /dev/$HD < $HD.out' >> "$DESTINATION/restaure.sh"
			else
				echo '	echo "sgdisk -l gpt_$HD.out /dev/$HD"
	sgdisk -l gpt_$HD.out /dev/$HD' >> "$DESTINATION/restaure.sh"
			fi
		fi

		echo 'if [ "$?" != "0" ]; then
	echo -e "$COLERREUR"
	echo "Une erreur s est semble-t-il produite."
	REPONSE=""
	if [ "$restauration_debut_dd" = "o" ]; then
		REPONSE="o"
		# A FAIRE : Dans le cas GPT il va falloir revoir les choses...
	fi

	if [ "$temoin_gpt" != "y" ]; then
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous forcer le repartitionnement avec l option -f de sfdisk? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		done
	else
		echo -e "$COLERREUR"
		echo "Avec une table de partition GPT, je ne sais pas encore comment forcer..."
		echo "Peut-etre casser la table de partitions avec"
		echo "   sgdisk -z /dev/$HD"
		echo "puis"
		echo "   sgdisk -l gpt_$HD.out /dev/$HD"
		echo "??? A tester..."
	fi

	sleep 2

	echo -e "$COLCMD"
	#if [ "$REPONSE" = "o" ]; then
	if [ "$REPONSE" = "o" -a "$temoin_gpt" != "y" ]; then
	' >> "$DESTINATION/restaure.sh"

		if [ "$CDRESTAUR" = "o" ]; then
			#echo "	sfdisk -f /dev/$HD < \$chemin_complet/$HD.out" >> "$DESTINATION/restaure.sh"
			echo '		#sfdisk -f /dev/$HD < $chemin_complet/$HD.out
		ladate_repartitionnement=$(date +%Y%m%d%H%M%S)
		sfdisk -f /dev/$HD < $chemin_complet/$HD.out > /tmp/repartitionnement_${ladate_repartitionnement}.txt 2>&1
		if grep -qi "BLKRRPART: Device or resource busy" /tmp/repartitionnement_${ladate_repartitionnement}.txt; then
			echo -e "$COLERREUR"
			echo "Il semble que la relecture de la table de partitions ait echoue."
			echo "On force la relecture:"
			echo -e "$COLCMD"
			echo "hdparm -z /dev/$HD"
			hdparm -z /dev/$HD
		fi
' >> "$DESTINATION/restaure.sh"
		else
			#echo "	sfdisk -f /dev/$HD < $HD.out" >> "$DESTINATION/restaure.sh"
			echo '		#sfdisk -f /dev/$HD < $HD.out
		ladate_repartitionnement=$(date +%Y%m%d%H%M%S)
		sfdisk -f /dev/$HD < $HD.out > /tmp/repartitionnement_${ladate_repartitionnement}.txt 2>&1
		if grep -qi "BLKRRPART: Device or resource busy" /tmp/repartitionnement_${ladate_repartitionnement}.txt; then
			echo -e "$COLERREUR"
			echo "Il semble que la relecture de la table de partitions ait echoue."
			echo "On force la relecture:"
			echo -e "$COLCMD"
			echo "hdparm -z /dev/$HD"
			hdparm -z /dev/$HD
		fi
' >> "$DESTINATION/restaure.sh"
		fi

		echo '	fi
else
	echo -e "$COLTXT"
	echo "On ne modifie pas la table de partition."
fi
' >> "$DESTINATION/restaure.sh"




		echo '	#NOTE:
	#Si certaines partitions doivent etre formatees
	#parce que non restaurees via une image partimage,
	#vous pouvez ajouter des lignes comme celles-ci:
	#mkfs.vfat /dev/hda5
	#mkfs.ext2 /dev/hda6

	#A REVOIR: mke2fs est bien present sur "prt", mais n a pas l air de fonctionner...

	#On peut aussi avoir:
	#mkswap /dev/hda1
	#Cet outil fonctionne-t-il correctement avec prt?
fi

echo -e "$COLTXT"
echo "Lancement de la/des restauration(s)..."
sleep 1' >> "$DESTINATION/restaure.sh"
	fi
	#=======================================================================


	# Debug
	#echo -e "${COLINFO}temoin_gpt=${temoin_gpt}${COLTXT}"

	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$HD:"
	echo -e "$COLCMD\c"

	if [ -e "/tmp/tmp_${datetemp}/partitions_sauvees.txt" ]; then
		# Debug
		#echo -e "${COLINFO}Au moins une partition a deja ete sauvee${COLCMD}"
		if [ "$temoin_gpt" != "y" ]; then
			fdisk -l /dev/$HD > /tmp/tmp_${datetemp}/fdisk-l.txt

			#grep -B 1000 "   Device Boot" /tmp/tmp_${datetemp}/fdisk-l.txt
			grep -B 1000 "Device[ ]*Boot" /tmp/tmp_${datetemp}/fdisk-l.txt

			grep -A 1000 "Device[ ]*Boot" /tmp/tmp_${datetemp}/fdisk-l.txt | grep -v "Device[ ]*Boot" | while read A
			do
				TEST_PART=$(echo "$A" | cut -d"/" -f3 | tr "\t" " " | cut -d" " -f1)
				if grep "^${TEST_PART}$" /tmp/tmp_${datetemp}/partitions_sauvees.txt > /dev/null; then
					echo -e "${COLTXT}${A}${COLCMD}"
				else
					# CHOIX_DEST n'est renseignee que si on fait une sauvegarde locale...
					if [ "${TEST_PART}" = "${CHOIX_DEST}" ]; then
						echo -e "${COLERREUR}${A}${COLCMD}"
					else
						if ! echo "$A" | grep -i "ext" > /dev/null; then
							echo -e "${A}"
						#else
							#echo -e "${COLERREUR}${A}${COLCMD}"
						fi
					fi
				fi
			done
		else

			HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
			parted /dev/${HD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${HD_CLEAN}.txt

			parted /dev/${HD} print|grep "^Number "
			while read A
			do
				TEST_PART=$(echo "${HD}$A" | cut -d" " -f1)
				if grep "^${TEST_PART}$" /tmp/tmp_${datetemp}/partitions_sauvees.txt > /dev/null; then
					echo -e "${COLTXT}${HD}${A}${COLCMD}"
				else
					# CHOIX_DEST n'est renseignee que si on fait une sauvegarde locale...
					if [ "${TEST_PART}" = "${CHOIX_DEST}" ]; then
						echo -e "${COLERREUR}${HD}${A}${COLCMD}"
					else
						# 20150106 : Le test ne convient pas.
						#            On exclut des choses comme:
						#                 2      538MB   32.0GB  31.5GB  ext4
						#            a cause du type ext4 trouve par parted
						#if ! echo "$A" | grep -i "ext" > /dev/null; then
							echo -e "${HD}${A}"
						#else
							#echo -e "${COLERREUR}${A}${COLCMD}"
						#fi
					fi
				fi
			done < /tmp/partitions_${HD_CLEAN}.txt

		fi
	else
		if [ "$temoin_gpt" != "y" ]; then
			echo "fdisk -l /dev/$HD"
			fdisk -l /dev/$HD
		else
			HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
			parted /dev/${HD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${HD_CLEAN}.txt

			parted /dev/${HD} print|grep "^Number "
			while read A
			do
				#echo ${HD}${A}
				#B=$(echo "$A"|sed -e "s| \{2,\}| |"|tr " " "\t")
				#echo ${HD}${B}
				echo "${HD}${A}"
			done < /tmp/partitions_${HD_CLEAN}.txt
		fi
	fi


	#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd"))
	if [ ! -z "$SAVEHD" ]; then
		if [ "$temoin_gpt" != "y" ]; then

			# Dans le cas ou on fait une sauvegarde sur une partition, on exclut des propositions de sauvegarde la partition de destination des sauvegardes.
			liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | grep -v "$PARTSTOCK " | cut -d" " -f1))

			nblig=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | grep -v "$PARTSTOCK " | wc -l)

		else

			HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
			parted /dev/${HD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${HD_CLEAN}.txt
			NUM_PARTSTOCK=$(echo "${PARTSTOCK}"|sed -e "s|^/dev/${HD}||")
			# Tester si parted renvoie ces chaines:
			grep -v "^${NUM_PARTSTOCK} " /tmp/partitions_${HD_CLEAN}.txt | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" > /tmp/partitions_tmp_${HD_CLEAN}.txt

			cpt_tmp=0
			while read A
			do
				liste_tmp[${cpt_tmp}]=$(echo "${HD}${A}"|cut -d" " -f1)
				cpt_tmp=$((cpt_tmp+1))
			done < /tmp/partitions_tmp_${HD_CLEAN}.txt
			nblig=${#liste_tmp[*]}

		fi
	else
		if [ "$temoin_gpt" != "y" ]; then
			liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))

			nblig=$(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v -i "linux-swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | wc -l)
		else

			HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
			parted /dev/${HD} print|grep -A10000 "^Number "|sed -e "s|^ ||g"|grep "^[0-9]" > /tmp/partitions_${HD_CLEAN}.txt

			cpt_tmp=0
			while read A
			do
				liste_tmp[${cpt_tmp}]=$(echo "${HD}${A}"|cut -d" " -f1)
				cpt_tmp=$((cpt_tmp+1))
			done < /tmp/partitions_${HD_CLEAN}.txt
			nblig=${#liste_tmp[*]}

		fi
	fi

	if [ ! -z "${liste_tmp[0]}" ]; then
		if [ -e /tmp/tmp_${datetemp}/partitions_sauvees.txt ]; then
			cpt_test=0
			temoin_test=""
			#while [ -z "$temoin_test" -a "$cpt_test" -le ${#liste_tmp[*]} ]
			while [ -z "$temoin_test" -a "$cpt_test" -le $nblig ]
			do
				lig_part=${liste_tmp[$cpt_test]}
				tmp_part=$(echo "${liste_tmp[$cpt_test]}" | cut -d"/" -f3 | tr "\t" " " | cut -d" " -f1)
				if ! grep "^${tmp_part}$" /tmp/tmp_${datetemp}/partitions_sauvees.txt > /dev/null; then
					temoin_test=$cpt_test
				#else
				#	cpt_test=$(($cpt_test+1))
				fi
				cpt_test=$(($cpt_test+1))
			done

			if [ ! -z "$temoin_test" ]; then
				#DEFAULTPART=$(echo ${liste_tmp[$cpt_test]} | sed -e "s|^/dev/||")
				DEFAULTPART=$(echo ${liste_tmp[$temoin_test]} | sed -e "s|^/dev/||")
			else
				DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
			fi
		else
			DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		fi
	else
		DEFAULTPART="hda1"
	fi


	REPONSE=""
	REP="o"
	while [ "$REPONSE" = "" -a "$REP" = "o" ]
	do
		#REP="o"

		if [ -z "$DEFAULTPART" ]; then
			echo -e "$COLINFO"
			echo "Aucune partition ne semble avoir ete automatiquement trouvee."
			echo "S'il n'y a pas d'autre partition a sauvegarder, validez ci-dessous"
			echo "sans saisir de partition."

			echo -e "$COLTXT"
			echo -e "Quelle partition souhaitez-vous sauvegarder? ${COLSAISIE}\c"
			read REPONSE
		else
			echo -e "$COLTXT"
			#echo -e "Quelle partition souhaitez-vous sauvegarder? [${COLDEFAUT}hda1${COLTXT}] ${COLSAISIE}\c"
			echo -e "Quelle partition souhaitez-vous sauvegarder? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] ${COLSAISIE}\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				#REPONSE="hda1"
				REPONSE=${DEFAULTPART}
			fi
		fi

		#Tester l'existence de la partition
		#if ! fdisk -l /dev/$HD | grep "$REPONSE " > /dev/null; then
		if [ ! -e "/sys/block/$HD/$REPONSE/partition" ]; then
			echo -e "${COLERREUR}La partition /dev/$REPONSE n'existe pas.${COLTXT}"
			REPONSE=""
		fi

		if [ "$REPONSE " = "${CHOIX_DEST}" ]; then
			echo -e "${COLERREUR}La partition /dev/$REPONSE est la partition qui reçoit les sauvegardes.${COLTXT}"
			REPONSE=""
		fi

		if [ "$REPONSE" = "" ]; then
			echo -e "${COLTXT}Voulez-vous sauvegarder une autre partition? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
			read REP

			if [ "$REP" != "n" ]; then
				REP="o"
			fi

			#Pour ne pas repartir dans la boucle sur la valeur saisie au tour perecedent:
			POURSUIVRE=""
		fi
	done

	PARTTMP="${REPONSE}"


	mkdir -p /tmp/tmp_${datetemp}
	if [ ! -e "/tmp/tmp_${datetemp}/partitions_sauvees.txt" ]; then
		touch /tmp/tmp_${datetemp}/partitions_sauvees.txt
	fi
	#echo "$PARTTMP" >> /tmp/tmp_${datetemp}/partitions_sauvees.txt
	# Si on renonce a sauvegarder cette partition par la suite... eventuellement parce que l'on veut changer le nom de sauvegarde, il ne faut pas la considerer comme sauvegardee avant la confirmation.

	TYPE_TMP=$(TYPE_PART ${PARTTMP})

	#�Pour ne pas proposer ntfsclone sur la 2e partition sauvegardee si ce n'est pas une partition ntfs.
	if [ "$TYPE_TMP" != "ntfs" -a "$DEFAULT_FORMAT_SVG" = "3" ]; then
		DEFAULT_FORMAT_SVG="1"
	fi

	if [ "${TYPE_TMP}" = "vfat" -o "${TYPE_TMP}" = "ntfs" ]; then
		REPLILOGRUB=""
	else
		# On va chercher s'il y a un dossier boot de Grub ou Lilo
		mkdir -p /mnt/${PARTTMP}
		mount /dev/${PARTTMP} /mnt/${PARTTMP} 2>/dev/null
		if [ "$?" = "0" ]; then
			if [ -e "/mnt/${PARTTMP}/boot" ]; then
				echo -e "$COLINFO"
				echo "NOTE: Si vous sauvegardez plusieurs partitions et que l'une d'elle est une"
				echo "      partition Linux chargee a l'aide de LILO/GRUB, il est possible que,"
				echo "      lors de la restauration de vos sauvegardes vers un autre poste,"
				echo "      LILO/GRUB doive etre reinstalle."
				echo -e "      Il est pour cela necessaire de savoir si la partition proposee ${COLERREUR}${PARTTMP}${COLINFO}"
				echo "      est une partition systeme Linux."

				#echo -e "$COLERREUR"
				#echo "ATTENTION: SysRescCD ne permet pas avec ce script de restaurer un Grub>=1.97"
				#echo "           (cas des distributions *Ubuntu 9.10)"
	
				t=$(head /dev/$HD | strings | egrep "(^LILO $|^LILO$)")
				if [ -n "$t" ]; then
					DEF_REPLILOGRUB="1"
				else
					t=$(head /dev/$HD | strings | egrep "(^GRUB $|^GRUB$)")
					if [ -n "$t" ]; then
						DEF_REPLILOGRUB="2"
					else
						DEF_REPLILOGRUB="3"
					fi
				fi
				REPLILOGRUB=""
				while [ "$REPLILOGRUB" != "1" -a "$REPLILOGRUB" != "2"  -a "$REPLILOGRUB" != "3" ]
				do
					echo -e "$COLTXT"
					echo -e "La partition ${COLCHOIX}${PARTTMP}${COLTXT} contient-elle:"
					echo -e " (${COLCHOIX}1${COLTXT}) un LILO devant etre reinstalle en fin de restauration"
					echo -e " (${COLCHOIX}2${COLTXT}) un GRUB devant etre reinstalle en fin de restauration"
					echo -e " (${COLCHOIX}3${COLTXT}) aucun chargeur de demarrage qu'il faille reinstaller"
					echo -e "Votre choix: [${COLDEFAUT}${DEF_REPLILOGRUB}${COLTXT}] $COLSAISIE\c"
					read REPLILOGRUB
	
					if [ -z "$REPLILOGRUB" ]; then
						REPLILOGRUB=${DEF_REPLILOGRUB}
					fi
				done
			fi
			umount /mnt/${PARTTMP}
		fi
	fi

	if [ "$REPLILOGRUB" = "1" -o "$REPLILOGRUB" = "2" ]; then
		PART_REINSTALL_LILOGRUB="${PARTTMP}"
	fi

	if [ "$REP" = "o" ]; then

		SUFFPARTSAVE="$REPONSE"
		PARTSAVE="/dev/$REPONSE"

		#if fdisk -l /dev/$HD | grep $PARTTMP | grep Linux > /dev/null; then

			#parted /dev/sda print | grep "^ 1" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f7
			num_part=$(echo $PARTTMP | sed -e "s|^$HD||")
			#type_fs=$(parted /dev/$HD print | grep "^ 1" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f7)
			type_fs=$(parted /dev/$HD print | sed -e "s/ \{2,\}/ /g" | grep "^ ${num_part} " | cut -d" " -f7)

			if [ "$type_fs" = "ext2" -o "$type_fs" = "ext3" ]; then

				fsck="fsck.$type_fs"

				echo -e "$COLTXT"
				echo "Il peut arriver sur des partitions Linux qu'un scan soit necessaire pour que"
				echo "la sauvegarde s'effectue correctement."

				REP_FSCK=""
				while [ "$REP_FSCK" != "o" -a "$REP_FSCK" != "n" ]
				do
					echo -e "$COLTXT"
					echo -e "Voulez-vous contrôler la partition avec $fsck? [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
					read REP_FSCK

					if [ -z "$REP_FSCK" ]; then
						REP_FSCK="o"
					fi
				done

				if [ "$REP_FSCK" = "o" ]; then

					if mount | grep "/dev/$PARTTMP " > /dev/null; then
						umount /dev/$PARTTMP
						if [ "$?" = "0" ]; then
							echo -e "$COLTXT"
							echo "Lancement du 'scan'..."
							echo -e "$COLCMD\c"
							$fsck /dev/$PARTTMP
						else
							echo -e "$COLERREUR"
							echo "Il semble que la partition /dev/$PARTTMP soit montee"
							echo "et qu'elle ne puisse pas etre demontee."
							echo "Il n'est pas possible de scanner la partition dans ces conditions..."
							echo "... et probablement pas possible non plus de sauvegarder la partition"
							echo "tant qu'elle sera montee."
							echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de regler"
							echo "le probleme (demonter et scanner ($fsck /dev/$PARTTMP))"
							echo "avant de poursuivre."
						fi
					else
						echo -e "$COLTXT"
						echo "Lancement du 'scan'..."
						echo -e "$COLCMD\c"
						$fsck /dev/$PARTTMP
					fi

					POURSUIVRE
				fi
			fi
		#fi


		#========================================================================
		#========================================================================
		#========================================================================

		if [ "$REPIMAGE" = "1" ]; then
			echo -e "$COLINFO"
			echo "Vous pouvez effectuer une sauvegarde classique partimage."
			echo "Inconvenient: La partition de restauration doit etre de taille"
			echo "(superieure ou) egale a la partition actuelle de sauvegarde."
			echo "Si vous ignorez dans quelles circonstances vous aurez a restaurer l'image,"
			echo "une archive TAR convient tout a fait pour une restauration sur une partition"
			echo "non NTFS (je n'ai teste que la restauration d'un W98 vers une partition FAT32)."
			echo "Mais l'archive TAR ne sera pas compressee... donc aussi volumineuse que la partition a sauvegarder."

			echo -e "$COLTXT"
			echo "Voulez-vous effectuer:"
			echo -e "   (${COLCHOIX}1${COLTXT}) une sauvegarde partimage,"
			echo -e "   (${COLCHOIX}6${COLTXT}) ou une archive TAR?"
			TYPESVG=""
			while [ "$TYPESVG" != "1" -a "$TYPESVG" != "6" ]
			do
				echo -e "$COLTXT"
				echo -e "Votre choix: (${COLCHOIX}1/6${COLTXT}) [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
				read TYPESVG

				if [ -z "$TYPESVG" ]; then
					TYPESVG="1"
				fi
			done

			FORMAT_SVG=$TYPESVG

			case $FORMAT_SVG in
				1)
					NOM_IMAGE_DEFAUT="${SUFFPARTSAVE}.image.partimage"
					SUFFIXE_SVG="000"
					type_svg='partimage'
				;;
				6)
					NOM_IMAGE_DEFAUT="${SUFFPARTSAVE}.image_tar"
					SUFFIXE_SVG="tar"
					type_svg='tar'
				;;
			esac
		else
			echo -e "$COLINFO"
			echo "Les sauvegardes peuvent etre effectuees a divers formats:"
			echo -e "$COLTXT\c"
			#echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions, mais encore instable"
			#echo -e "                si le noyau Linux utilise est en version 2.6.x"
			echo -e " (${COLCHOIX}1${COLTXT}) partimage: valable pour tous types de partitions."
			echo -e "                  (mais sauvegarde ext4 non supporte)"
			#echo -e " (${COLCHOIX}2${COLTXT}) dar: pour les partitions non-NTFS quel que soit le noyau Linux."
			#echo -e " (${COLCHOIX}3${COLTXT}) ntfsclone: pour les partitions NTFS quel que soit le noyau Linux."
			echo -e " (${COLCHOIX}2${COLTXT}) dar: pour les partitions non-NTFS."
			echo -e " (${COLCHOIX}3${COLTXT}) ntfsclone: pour les partitions NTFS."
			echo -e " (${COLCHOIX}4${COLTXT}) FsArchiver: pour toutes les partitions"
			echo -e "                  (support NTFS:"
			echo -e "                   http://www.fsarchiver.org/Cloning-ntfs"
			echo -e "                   fsarchiver permet de restaurer vers"
			echo -e "                   une partition plus petite que l'originale)."
			echo -e " (${COLCHOIX}5${COLTXT}) dd (experimental)"

			echo -e "$COLTXT"
			echo "Voici le noyau actuellement utilise:"
			echo -e "$COLCMD\c"
			cat /proc/version

			if [ -z "$DEFAULT_FORMAT_SVG" ]; then
				DEFAULT_FORMAT_SVG=1
			fi

			DETECTED_TYPE=$(TYPE_PART $SUFFPARTSAVE)
			if [ "$DETECTED_TYPE" = "ntfs" ]; then
				DEFAULT_FORMAT_SVG=3
			elif [ "$DETECTED_TYPE" = "ext4" ]; then
				DEFAULT_FORMAT_SVG=4
			fi

			FORMAT_SVG=""
			while [ "$FORMAT_SVG" != "1" -a "$FORMAT_SVG" != "2" -a "$FORMAT_SVG" != "3" -a "$FORMAT_SVG" != "4" -a "$FORMAT_SVG" != "5" ]
			do
				echo -e "$COLTXT"
				echo -e "Quel est le format de sauvegarde souhaite? [${COLDEFAUT}${DEFAULT_FORMAT_SVG}${COLTXT}] $COLSAISIE\c"
				read FORMAT_SVG

				if [ -z "$FORMAT_SVG" ]; then
					FORMAT_SVG=${DEFAULT_FORMAT_SVG}
				fi
			done

			DEFAULT_FORMAT_SVG=$FORMAT_SVG

			case $FORMAT_SVG in
				1)
					NOM_IMAGE_DEFAUT="${SUFFPARTSAVE}.image.partimage"
					SUFFIXE_SVG="000"
					type_svg='partimage'
				;;
				2)
					NOM_IMAGE_DEFAUT="${SUFFPARTSAVE}.image_dar"
					#SUFFIXE_SVG="dar"
					SUFFIXE_SVG="1.dar"
					type_svg='dar'
				;;
				3)
					NOM_IMAGE_DEFAUT="${SUFFPARTSAVE}.image"
					SUFFIXE_SVG="ntfs"
					type_svg='ntfsclone'
				;;
				4)
					NOM_IMAGE_DEFAUT="image.FsArchiver"
					SUFFIXE_SVG="fsa"
					type_svg='fsarchiver'
				;;
				5)
					NOM_IMAGE_DEFAUT="image.dd"
					SUFFIXE_SVG="bin"
					type_svg='dd'
				;;
			esac

			TYPESVG="$FORMAT_SVG"
		fi


		#if [ "$FORMAT_SVG" = "2" -o "$FORMAT_SVG" = "5" ]; then
		if [ "$FORMAT_SVG" = "2" -o "$FORMAT_SVG" = "6" ]; then
			echo -e "$COLINFO"
			echo "La sauvegarde avec 'dar' ou 'tar' necessite de monter la partition /dev/$SUFFPARTSAVE"
			echo "Le type du systeme de fichier doit donc etre precise."
			echo "Cela peut-etre: vfat, ext2 ou ext3"

			REPONSE=""
			while [ "$REPONSE" != "1" ]
			do
				echo -e "$COLTXT"
				echo -e "Quel est le type de la partition?"
				#if fdisk -l /dev/$HD | tr "\t" " " | grep "$PARTSAVE " | egrep "(W95 FAT32|Win95 FAT32)" > /dev/null; then
				DETECTED_TYPE=$(TYPE_PART $PARTSAVE)
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
				mkdir -p /mnt/$SUFFPARTSAVE
				if [ ! -z "$TYPE_FS" ]; then
					mount -t $TYPE_FS /dev/$SUFFPARTSAVE /mnt/$SUFFPARTSAVE
				else
					mount /dev/$SUFFPARTSAVE /mnt/$SUFFPARTSAVE
				fi
				umount /mnt/$SUFFPARTSAVE

				echo -e "$COLTXT"
				echo "Si aucune erreur n'est affichee, le type doit convenir..."

				REPONSE=""
				while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
				do
					echo -e "$COLTXT"
					echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? $COLSAISIE\c"
					read REPONSE
				done
			done

		else
			if mount | grep "/dev/$SUFFPARTSAVE " > /dev/null; then
				umount /dev/$SUFFPARTSAVE
				if [ "$?" != "0" ]; then
					echo -e "$COLERREUR"
					echo "Il semble que la partition /dev/$SUFFPARTSAVE soit montee"
					echo "et qu'elle ne puisse pas etre demontee."
					echo "Il n'est pas possible de sauvegarder la partition avec partimage ou ntfsclone"
					echo "dans ces conditions..."
					echo "Vous devriez passer dans une autre console (ALT+F2) et tenter de regler"
					echo "le probleme (demonter la partition /dev/$SUFFPARTSAVE)"
					echo "avant de poursuivre."
				fi
			fi
		fi


		#========================================================================
		#========================================================================
		#========================================================================


		echo -e "$COLPARTIE"
		echo "====================="
		echo "Niveau de compression "
		echo "====================="

		if [ "$FORMAT_SVG" != "4" ]; then
			#if [ "$TYPESVG" = "5" -a "$REPIMAGE" = "1" ]; then
			if [ "$TYPESVG" = "6" -a "$REPIMAGE" = "1" ]; then
				# prt n'accepte pas les tar.bz2
				echo -e "$COLTXT"
				echo -e "Quel niveau de compression souhaitez-vous?"
				echo -e " - ${COLCHOIX}0${COLTXT} Aucune compression"
				echo -e " - ${COLCHOIX}1${COLTXT} Compression gzip"
				COMPRESS=""
				while [ "$COMPRESS" != "0" -a "$COMPRESS" != "1" ]
				do
					echo -e "$COLTXT\c"
					echo -e "Niveau de compression: [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
					read COMPRESS
	
					if [ -z "$COMPRESS" ]; then
						COMPRESS=1
					fi
				done
			else
				echo -e "$COLTXT"
				echo -e "Quel niveau de compression souhaitez-vous?"
				echo -e " - ${COLCHOIX}0${COLTXT} Aucune compression"
				echo -e " - ${COLCHOIX}1${COLTXT} Compression gzip"
				echo -e " - ${COLCHOIX}2${COLTXT} Compression bzip2"
				COMPRESS=""
				while [ "$COMPRESS" != "0" -a "$COMPRESS" != "1" -a "$COMPRESS" != "2" ]
				do
					echo -e "$COLTXT\c"
					echo -e "Niveau de compression: [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
					read COMPRESS
	
					if [ -z "$COMPRESS" ]; then
						COMPRESS=1
					fi
				done
			fi

			NIVEAU=$COMPRESS
		else
			NIVEAU=""
			while [ -z "$NIVEAU" ]
			do
				echo -e "$COLTXT"
				echo "Quel est le niveau de compression souhaite?"
				echo "Du moins efficace au plus efficace (mais plus gourmand en ressources cpu)"
				echo -e " - ${COLCHOIX}1${COLTXT} Compression avec lzop (rapide mais gain faible)"
				echo -e " - ${COLCHOIX}2${COLTXT} Compression avec gzip niveau 3"
				echo -e " - ${COLCHOIX}3${COLTXT} Compression avec gzip niveau 6"
				echo -e " - ${COLCHOIX}4${COLTXT} Compression avec gzip niveau 9"
				echo -e " - ${COLCHOIX}5${COLTXT} Compression avec bzip2 niveau 2"
				echo -e " - ${COLCHOIX}6${COLTXT} Compression avec bzip2 niveau 5"
				echo -e " - ${COLCHOIX}7${COLTXT} Compression avec lzma niveau 1"
				echo -e " - ${COLCHOIX}8${COLTXT} Compression avec lzma niveau 6"
				echo -e " - ${COLCHOIX}9${COLTXT} Compression avec lzma niveau 9"
				echo -e "Niveau: [${COLDEFAUT}3${COLTXT}] $COLSAISIE\c"
				read NIVEAU
		
				if [ "$NIVEAU" = "" ]; then
					NIVEAU=3
				fi
		
				t=$(echo "$NIVEAU"|wc -m)
				if [ "$t" != "2" ]; then
					echo -e "${COLERREUR}Niveau incorrect."
					NIVEAU=""
				else
					t=$(echo "$NIVEAU"|sed -e "s|[1-9]||g")
					if [ -n "$t" ]; then
						echo -e "${COLERREUR}Niveau incorrect."
						NIVEAU=""
					fi
				fi
			done

		fi

		#NIVEAU=$COMPRESS

		VOLUME=0
		#if [ "$CDRESTAUR" = "o" ]; then
		if [ "$CDRESTAUR" = "o" -a "$TYPESVG" != "5" ]; then
			echo -e "$COLPARTIE"
			echo "====================="
			echo "Volume des 'morceaux'"
			echo "====================="

			echo -e "$COLINFO"
			echo "Pour tenir sur un CD, l'image doit etre scindee en morceaux"
			echo "ne depassant pas 700Mo."
			echo "Sur le premier CD, on place aussi tout le necessaire pour rendre le CD bootable."
			echo "La valeur proposee est donc 690."

			#VOLUME=0
			echo -e "$COLTXT"
			echo -e "Tapez un volume en Mega-Octets: [${COLDEFAUT}690${COLTXT}] $COLSAISIE\c"
			read VOLUME
			if [ -z "$VOLUME" ]; then
				VOLUME=690
			fi

			test=$(echo "$VOLUME" | sed -e "s/[0-9]//g")
			if [ ! -z "$test" ]; then
				VOLUME=690
			fi

			if [ "$FORMAT_SVG" = "1" ]; then
				if partimage -v | grep 0.6.1 > /dev/null; then
					VOLUME=$(echo ${VOLUME}*1024 | bc)
				fi
			fi
		fi

		echo -e "$COLPARTIE"
		echo "============================="
		echo " Nom de l'image et lancement "
		echo "      de la sauvegarde       "
		echo "============================="

		IMAGE=""
		while [ -z "$IMAGE" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel est le nom de l'image a creer? [${COLDEFAUT}${NOM_IMAGE_DEFAUT}${COLTXT}] $COLSAISIE\c"
			read IMAGE
			if [ -z "$IMAGE" ]; then
				IMAGE="${NOM_IMAGE_DEFAUT}"
			fi

			longueur_test=$(echo "$IMAGE" | tr "-" "_" | sed -e "s/[A-Za-z0-9._]//g" | wc -m)
			if [ "$longueur_test" != "1" ]; then
				tmp_chaine=$(echo "$IMAGE" | tr "-" "_" | sed -e "s/[A-Za-z0-9._]//g")
				echo -e "${COLERREUR}Des caracteres non valides ont ete saisis: ${COLCHOIX}$tmp_chaine"
				IMAGE=""
			fi
		done

		echo -e "$COLINFO"
		echo "RECAPITULATIF:"
		echo -e "${COLTXT}Partition source  :      ${COLINFO}${PARTSAVE}"
		echo -e "${COLTXT}Partition destination  : ${COLINFO}${PARTSTOCK}"
		echo -e "${COLTXT}Chemin de sauvegarde :   ${COLINFO}${DESTINATION}"
		echo -e "${COLTXT}Nom de l'image :         ${COLINFO}${IMAGE}"
		echo -e "${COLTXT}Niveau de compression :  ${COLINFO}${COMPRESS}"
		#if [ "$CDRESTAUR" = "o" ]; then
		if [ "$CDRESTAUR" = "o" -a "$TYPESVG" = "1" ]; then
			echo -e "${COLTXT}Scinder en morceaux de : ${COLINFO}${VOLUME} Mo"
		fi
		echo -e "$COLTXT"

		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Peut-on continuer ? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		done

		echo -e "$COLTXT"
		if [ "$REPONSE" = "o" ]; then


			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous creer un fichier de commentaires? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}o${COLTXT}] $COLSAISIE\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="o"
				fi
			done

			if [ "$REPONSE" = "o" ]; then
				echo -e "$COLTXT"
				echo "Tapez vos commentaires, eventuellement sur plusieurs lignes"
				echo "et pour finir, tapez une ligne ne contenant que le mot 'FIN'."
				if [ -e "$DESTINATION/${IMAGE}.txt" ]; then
					rm -f $DESTINATION/${IMAGE}.txt
				fi
				touch $DESTINATION/${IMAGE}.txt
				LIGNE=""
				echo -e "$COLSAISIE"
				while [ "$LIGNE" != "FIN" ]
				do
					read LIGNE
					echo "$LIGNE" >> $DESTINATION/${IMAGE}.txt
				done

				cat $DESTINATION/${IMAGE}.txt | sed -e "s/^FIN$//g" > $DESTINATION/${IMAGE}.txt.tmp
				cp -f $DESTINATION/${IMAGE}.txt.tmp $DESTINATION/${IMAGE}.txt
				rm -f $DESTINATION/${IMAGE}.txt.tmp

				echo -e "$COLTXT"
				echo "Vous avez saisi:"
				echo -e "$COLCMD"
				cat $DESTINATION/${IMAGE}.txt

				echo -e "$COLTXT"
				echo "Appuyez sur ENTREE pour poursuivre."
				read PAUSE
			fi


			type_fs=$(TYPE_PART ${PARTSAVE})
			if [ "$type_fs" = "ntfs" ]; then
				echo -e "$COLINFO"
				echo "Par precaution, on sauvegarde le debut des partitions avec dd."
				echo "Il semble cependant que cette sauvegarde ne presente pas d'interet,"
				echo "contrairement a celle des premiers Mo du disque dur."

				echo -e "$COLTXT"
				echo "Sauvegarde des 5 premiers Mo de $PARTSAVE avec dd..."
				echo -e "$COLCMD\c"
				dd if=$PARTSAVE of="${DESTINATION}/${IMAGE}_premiers_MO.bin" bs=1M count=5

				echo '
echo -e "$COLERREUR"
echo -e "EXPERIMENTAL:$COLINFO"
echo "Les premiers Mo de la partition ont ete sauvegardes."
echo "Leur restauration n est normalement pas necessaire."
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
	dd if="${chemin_complet}/'${IMAGE}'_premiers_MO.bin" of='${PARTSAVE}' bs=1M count=5
fi
' >> "$DESTINATION/restaure.sh"

				COMPTE_A_REBOURS "Suite dans " 5 " secondes."
			fi


			echo 'echo -e "$COLINFO"
echo -e "Restauration de '$SUFFPARTSAVE'..."' >> "$DESTINATION/restaure.sh"
			if [ -e "$DESTINATION/${IMAGE}.txt" ]; then
				echo 'echo -e "$COLTXT"
echo -e "Commentaire saisi:"
echo -e "$COLINFO"' >> "$DESTINATION/restaure.sh"
				if [ "$CDRESTAUR" = "o" ]; then
					#echo 'cat "$chemin_source/save/'${IMAGE}'.txt"' >> "$DESTINATION/restaure.sh"
					echo 'cat "$chemin_complet/'${IMAGE}'.txt"' >> "$DESTINATION/restaure.sh"
				else
					echo 'cat "'${IMAGE}'.txt"' >> "$DESTINATION/restaure.sh"
				fi
				echo 'echo -e "$COLTXT"
cpt=9
while [ "$cpt" -ge 0 ]
do
	echo -en "\rLe script va se poursuivre dans $cpt seconde(s). "
	cpt=$(($cpt-1))
	sleep 1
done
echo ""
echo -e "$COLCMD\c"' >> "$DESTINATION/restaure.sh"
			else
				echo 'echo -e "$COLCMD\c"
sleep 3' >> "$DESTINATION/restaure.sh"
			fi

			echo 't1=$(date +%s)' >> "$DESTINATION/restaure.sh"

			echo -e "$COLINFO"
			echo -e "Lancement de la sauvegarde..."
			echo -e "$COLCMD"
			t1=$(date +%s)
			t2=""
			case $FORMAT_SVG in
				1)
					echo 'echo -e "$COLINFO"
echo -e "Lancement de la restauration"
echo -e "$COLCMD\c"
sleep 2' >> "$DESTINATION/restaure.sh"

					if [ "$CDRESTAUR" = "o" ]; then
						if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
							partimage -f0 -z$NIVEAU -c -d -o -b -V${VOLUME} save $PARTSAVE $DESTINATION/$IMAGE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							#echo "partimage -b -f3 -w restore $PARTSAVE \$chemin_source/save/$IMAGE.000" >> "$DESTINATION/restaure.sh"
							echo "partimage -b -f3 -w restore $PARTSAVE \$chemin_complet/$IMAGE.000" >> "$DESTINATION/restaure.sh"
						else
							partimage -f0 -z$NIVEAU -c -d -o -b save $PARTSAVE $DESTINATION/$IMAGE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							#echo "partimage -b -f3 restore $PARTSAVE \$chemin_source/save/$IMAGE.000" >> "$DESTINATION/restaure.sh"
							echo "partimage -b -f3 restore $PARTSAVE \$chemin_complet/$IMAGE.000" >> "$DESTINATION/restaure.sh"
						fi
					else
						if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
							partimage -f0 -z$NIVEAU -c -d -o -b -V${VOLUME} save $PARTSAVE $DESTINATION/$IMAGE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							echo "partimage -b -f3 -w restore $PARTSAVE $IMAGE.000" >> "$DESTINATION/restaure.sh"
						else
							partimage -f0 -z$NIVEAU -c -d -o -b save $PARTSAVE $DESTINATION/$IMAGE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							echo "partimage -b -f3 restore $PARTSAVE $IMAGE.000" >> "$DESTINATION/restaure.sh"
						fi
					fi
				;;
				2)
					mkdir -p /mnt/$SUFFPARTSAVE
					#echo "mkdir -p /mnt/$SUFFPARTSAVE" >> "$DESTINATION/restaure.sh"
					if [ ! -z "$TYPE_FS" ]; then
						mount -t $TYPE_FS $PARTSAVE /mnt/$SUFFPARTSAVE
					else
						mount $PARTSAVE /mnt/$SUFFPARTSAVE
					fi
					#echo "mount -t $TYPE_FS $PARTSAVE /mnt/$SUFFPARTSAVE" >> "$DESTINATION/restaure.sh"

					echo 'REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous vider la partition avant de lancer la restauration? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

echo -e "$COLTXT"
echo -e "Montage de la partition..."
echo -e "$COLCMD\c"
mkdir -p /mnt/'$SUFFPARTSAVE >> "$DESTINATION/restaure.sh"

if [ ! -z "$TYPE_FS" ]; then
	echo 'mount -t '$TYPE_FS' '$PARTSAVE' /mnt/'$SUFFPARTSAVE >> "$DESTINATION/restaure.sh"
else
	echo 'mount '$PARTSAVE' /mnt/'$SUFFPARTSAVE >> "$DESTINATION/restaure.sh"
fi

echo 'if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo -e "Suppression du contenu de la partition avant restauration..."
	echo -e "$COLCMD\c"
	rm -fr /mnt/'$SUFFPARTSAVE'/*
fi

echo -e "$COLINFO"
echo -e "Lancement de la restauration"
echo -e "$COLCMD\c"
sleep 2' >> "$DESTINATION/restaure.sh"

					case $NIVEAU in
						0)
							OPT_COMPRESS=""
						;;
						1)
							OPT_COMPRESS="-z2"
						;;
						2)
							OPT_COMPRESS="-y2"
						;;
					esac
					if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
						$chemin_dar/dar -c $DESTINATION/$IMAGE -s ${VOLUME}M $OPT_COMPRESS -v -R /mnt/$SUFFPARTSAVE
						#echo "/usr/local/bin/dar -x $PTMNTSTOCK/$PREFIMAGE -R /mnt/$SUFFPARTSAVE -b -wa -v" >> "$DESTINATION/restaure.sh"
					else
						$chemin_dar/dar -c $DESTINATION/$IMAGE $OPT_COMPRESS -v -R /mnt/$SUFFPARTSAVE
						#echo "" >> "$DESTINATION/restaure.sh"
					fi

					if [ "$?" != "0" ]; then
						echo -e "${COLERREUR}"
						echo "Il semble qu'une erreur se soit produite."
						echo "La sauvegarde effectuee n'est peut-etre pas integre."

						echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
						ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
						date >> $DESTINATION/$IMAGE.ECHEC.txt
						df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

						POURSUIVRE
					else
						t2=$(date +%s)
						echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
						ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
						date >> $DESTINATION/$IMAGE.SUCCES.txt
						df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
					fi

					#echo 'echo -e "$COLCMD"' >> "$DESTINATION/restaure.sh"
					if [ "$CDRESTAUR" = "o" ]; then
						#echo "$chemin_dar/dar -x \$chemin_source/save/$IMAGE -R /mnt/$SUFFPARTSAVE -b -wa -v" >> "$DESTINATION/restaure.sh"
						echo "$chemin_dar/dar -x \$chemin_complet/$IMAGE -R /mnt/$SUFFPARTSAVE -b -wa -v" >> "$DESTINATION/restaure.sh"
					else
						echo "$chemin_dar/dar -x $IMAGE -R /mnt/$SUFFPARTSAVE -b -wa -v" >> "$DESTINATION/restaure.sh"
					fi
				;;
				3)
					echo 'echo -e "$COLINFO"
echo -e "Lancement de la restauration"
echo -e "$COLCMD\c"
sleep 2' >> "$DESTINATION/restaure.sh"

					# Il faudrait tester si la partition est OK.
					# ERROR: Volume '/dev/sda4' is sheduled for a check or it was shutdown uncleanly. Please boot Windows or use the --force option to progress.
					echo -e "$COLTXT"
					echo "Controle de la partition..."
					echo -e "$COLCMD\c"
					$chemin_ntfs/ntfsfix -d /dev/$SUFFPARTSAVE

					if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
						case $NIVEAU in
							0)
								echo "" > $DESTINATION/$IMAGE.type_compression.txt
								$chemin_ntfs/ntfsclone --save-image -o - /dev/$SUFFPARTSAVE | split -b ${VOLUME}m - $DESTINATION/$IMAGE.ntfs

								# Il semble qu'il n'y ait pas un retour d'erreur dans le cas 
								# ERROR: Volume '/dev/sda4' is sheduled for a check or it was shutdown uncleanly. Please boot Windows or use the --force option to progress.
								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									#echo "cat \$chemin_source/save/$IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
									echo "cat \$chemin_complet/$IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								fi
							;;
							1)
								echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
								$chemin_ntfs/ntfsclone --save-image -o - /dev/$SUFFPARTSAVE | gzip -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.ntfs

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									# Si l'erreur est due au remplissage de la partition, ce qui suiv va aussi provoquer des erreurs
									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									#echo "cat \$chemin_source/save/$IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
									echo "cat \$chemin_complet/$IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								fi
							;;
							2)
								echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
								$chemin_ntfs/ntfsclone --save-image -o - /dev/$SUFFPARTSAVE | bzip2 -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.ntfs

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									#echo "cat \$chemin_source/save/$IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
									echo "cat \$chemin_complet/$IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								fi
							;;
						esac
					else
						# Probleme: Est-ce qu'il scinde tout seul a 2Go?
						# Si ce n'est pas le cas, la sauvegarde a travers le reseau va planter...
						case $NIVEAU in
							0)
								echo "" > $DESTINATION/$IMAGE.type_compression.txt
								$chemin_ntfs/ntfsclone --save-image -o $DESTINATION/$IMAGE.ntfs /dev/$SUFFPARTSAVE

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									#echo "cat \$chemin_source/save/$IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
									echo "cat \$chemin_complet/$IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.ntfs* | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								fi
							;;
							1)
								echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
								$chemin_ntfs/ntfsclone --save-image -o - /dev/$SUFFPARTSAVE | gzip -c > $DESTINATION/$IMAGE.ntfs

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									#echo "cat \$chemin_source/save/$IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
									echo "cat \$chemin_complet/$IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.ntfs* | gunzip -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								fi
							;;
							2)
								echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
								$chemin_ntfs/ntfsclone --save-image -o - /dev/$SUFFPARTSAVE | bzip2 -c > $DESTINATION/$IMAGE.ntfs

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									#echo "cat \$chemin_source/save/$IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
									echo "cat \$chemin_complet/$IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.ntfs* | bzip2 -d -c | $chemin_ntfs/ntfsclone --restore-image --overwrite /dev/$SUFFPARTSAVE -" >> "$DESTINATION/restaure.sh"
								fi
							;;
						esac
					fi
				;;



				5)
					echo 'echo -e "$COLINFO"
echo -e "Lancement de la restauration"
echo -e "$COLCMD\c"
sleep 2' >> "$DESTINATION/restaure.sh"
					if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
						case $NIVEAU in
							0)
								echo "" > $DESTINATION/$IMAGE.type_compression.txt
								echo "dd if=/dev/$SUFFPARTSAVE ${opt_dd}| split -b ${VOLUME}m - $DESTINATION/$IMAGE.${SUFFIXE_SVG}"
								dd if=/dev/$SUFFPARTSAVE ${opt_dd}| split -b ${VOLUME}m - $DESTINATION/$IMAGE.${SUFFIXE_SVG}

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									echo "cat \$chemin_complet/$IMAGE.${SUFFIXE_SVG}* | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.${SUFFIXE_SVG}* | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								fi
							;;
							1)
								echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
								echo "dd if=/dev/$SUFFPARTSAVE ${opt_dd}| gzip -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.${SUFFIXE_SVG}"
								dd if=/dev/$SUFFPARTSAVE ${opt_dd}| gzip -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.${SUFFIXE_SVG}

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									# Si l'erreur est due au remplissage de la partition, ce qui suiv va aussi provoquer des erreurs
									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									echo "cat \$chemin_complet/$IMAGE.${SUFFIXE_SVG}* | gunzip -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.${SUFFIXE_SVG}* | gunzip -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								fi
							;;
							2)
								echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
								echo "dd if=/dev/$SUFFPARTSAVE ${opt_dd}| bzip2 -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.${SUFFIXE_SVG}"
								dd if=/dev/$SUFFPARTSAVE ${opt_dd}| bzip2 -c | split -b ${VOLUME}m - $DESTINATION/$IMAGE.${SUFFIXE_SVG}

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									echo "cat \$chemin_complet/$IMAGE.${SUFFIXE_SVG}* | bzip2 -d -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.${SUFFIXE_SVG}* | bzip2 -d -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								fi
							;;
						esac
					else
						# Probleme: Est-ce qu'il scinde tout seul a 2Go?
						# Si ce n'est pas le cas, la sauvegarde a travers le reseau va planter...
						case $NIVEAU in
							0)
								echo "" > $DESTINATION/$IMAGE.type_compression.txt
								echo "dd if=/dev/$SUFFPARTSAVE of=$DESTINATION/$IMAGE.${SUFFIXE_SVG} ${opt_dd}"
								dd if=/dev/$SUFFPARTSAVE of=$DESTINATION/$IMAGE.${SUFFIXE_SVG} ${opt_dd}

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									echo "cat \$chemin_complet/$IMAGE.${SUFFIXE_SVG}* | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.${SUFFIXE_SVG}* | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								fi
							;;
							1)
								echo "gzip" > $DESTINATION/$IMAGE.type_compression.txt
								echo "dd if=/dev/$SUFFPARTSAVE ${opt_dd}| gzip -c > $DESTINATION/$IMAGE.${SUFFIXE_SVG}"
								dd if=/dev/$SUFFPARTSAVE ${opt_dd}| gzip -c > $DESTINATION/$IMAGE.${SUFFIXE_SVG}

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									echo "cat \$chemin_complet/$IMAGE.${SUFFIXE_SVG}* | gunzip -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.${SUFFIXE_SVG}* | gunzip -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								fi
							;;
							2)
								echo "bzip2" > $DESTINATION/$IMAGE.type_compression.txt
								echo "dd if=/dev/$SUFFPARTSAVE ${opt_dd}| bzip2 -c > $DESTINATION/$IMAGE.${SUFFIXE_SVG}"
								dd if=/dev/$SUFFPARTSAVE ${opt_dd}| bzip2 -c > $DESTINATION/$IMAGE.${SUFFIXE_SVG}

								if [ "$?" != "0" ]; then
									echo -e "${COLERREUR}"
									echo "Il semble qu'une erreur se soit produite."
									echo "La sauvegarde effectuee n'est peut-etre pas integre."

									echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
									date >> $DESTINATION/$IMAGE.ECHEC.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

									POURSUIVRE
								else
									t2=$(date +%s)
									echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
									ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
									date >> $DESTINATION/$IMAGE.SUCCES.txt
									df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
								fi

								if [ "$CDRESTAUR" = "o" ]; then
									echo "cat \$chemin_complet/$IMAGE.${SUFFIXE_SVG}* | bzip2 -d -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								else
									echo "cat $IMAGE.${SUFFIXE_SVG}* | bzip2 -d -c | dd of=/dev/$SUFFPARTSAVE ${opt_dd}" >> "$DESTINATION/restaure.sh"
								fi
							;;
						esac
					fi
				;;


				6)
					mkdir -p /mnt/$SUFFPARTSAVE
					if [ ! -z "$TYPE_FS" ]; then
						mount -t $TYPE_FS $PARTSAVE /mnt/$SUFFPARTSAVE
					else
						mount $PARTSAVE /mnt/$SUFFPARTSAVE
					fi

					echo 'REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous vider la partition avant de lancer la restauration? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

echo -e "$COLTXT"
echo -e "Montage de la partition..."
echo -e "$COLCMD\c"
mkdir -p /mnt/'$SUFFPARTSAVE >> "$DESTINATION/restaure.sh"

if [ ! -z "$TYPE_FS" ]; then
	echo 'mount -t '$TYPE_FS' '$PARTSAVE' /mnt/'$SUFFPARTSAVE >> "$DESTINATION/restaure.sh"
else
	echo 'mount '$PARTSAVE' /mnt/'$SUFFPARTSAVE >> "$DESTINATION/restaure.sh"
fi

echo 'if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo -e "Suppression du contenu de la partition avant restauration..."
	echo -e "$COLCMD\c"
	rm -fr /mnt/'$SUFFPARTSAVE'/*
fi

echo -e "$COLINFO"
echo -e "Lancement de la restauration"
echo -e "$COLCMD\c"
sleep 2
' >> "$DESTINATION/restaure.sh"
					cd /
					#AJOUTER UN TEST: SI ERREUR AU MONTAGE POUR LA RESTAURATION, ABANDONNER!!!
					echo "cd /" >> "$DESTINATION/restaure.sh"

					if [ "$CDRESTAUR" = "o" ]; then
						TAROPTIONS=""
						TARRESTAUROPTIONS=""
						EXTENSION=""
						if [ "$COMPRESS" = "0" ]; then
							TAROPTIONS="cvf"
							TARRESTAUROPTIONS="xvf"
							EXTENSION="tar"
						else
							if [ "$COMPRESS" = "1" ]; then
								TAROPTIONS="cvzf"
								TARRESTAUROPTIONS="xvzf"
								EXTENSION="tar.gz"
							else
								TAROPTIONS="cvjf"
								TARRESTAUROPTIONS="xvjf"
								EXTENSION="tar.bz2"
							fi
						fi

						#tar -${TAROPTIONS} $DESTINATION/${IMAGE}.${EXTENSION} /mnt/part_restauration/*
						#echo "tar -${TARRESTAUROPTIONS} \$chemin_source/save/${IMAGE}.${EXTENSION}" >> "$DESTINATION/restaure.sh"
						tar -${TAROPTIONS} $DESTINATION/${IMAGE}.${EXTENSION} /mnt/$SUFFPARTSAVE/*

						if [ "$?" != "0" ]; then
							echo -e "${COLERREUR}"
							echo "Il semble qu'une erreur se soit produite."
							echo "La sauvegarde effectuee n'est peut-etre pas integre."

							echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
							ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
							date >> $DESTINATION/$IMAGE.ECHEC.txt
							df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

							POURSUIVRE
						else
							t2=$(date +%s)
							echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
							ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
							date >> $DESTINATION/$IMAGE.SUCCES.txt
							df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
						fi

						#echo "tar -${TARRESTAUROPTIONS} \$chemin_source/save/${IMAGE}.${EXTENSION}" >> "$DESTINATION/restaure.sh"
						echo "tar -${TARRESTAUROPTIONS} \$chemin_complet/${IMAGE}.${EXTENSION}" >> "$DESTINATION/restaure.sh"
					else
						#tar -${TAROPTIONS} $DESTINATION/${IMAGE}.${EXTENSION} /mnt/part_restauration/*
						#echo "tar -${TARRESTAUROPTIONS} ${IMAGE}.${EXTENSION}" >> "$DESTINATION/restaure.sh"
						tar -${TAROPTIONS} $DESTINATION/${IMAGE}.${EXTENSION} /mnt/$SUFFPARTSAVE/*

						if [ "$?" != "0" ]; then
							echo -e "${COLERREUR}"
							echo "Il semble qu'une erreur se soit produite."
							echo "La sauvegarde effectuee n'est peut-etre pas integre."

							echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
							ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
							date >> $DESTINATION/$IMAGE.ECHEC.txt
							df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

							POURSUIVRE
						else
							t2=$(date +%s)
							echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
							ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
							date >> $DESTINATION/$IMAGE.SUCCES.txt
							df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
						fi

						echo "tar -${TARRESTAUROPTIONS} ${IMAGE}.${EXTENSION}" >> "$DESTINATION/restaure.sh"
					fi
					#umount /mnt/part_restauration
					#echo "umount /mnt/part_restauration" >> "$DESTINATION/restaure.sh"
					# Demontage reporte plus bas pour les formats 2 et 4 de sauvegarde.
				;;
				4)
					echo 'echo -e "$COLINFO"
echo -e "Lancement de la restauration"
echo -e "$COLCMD\c"
sleep 2' >> "$DESTINATION/restaure.sh"

					#echo -e "$COLINFO"
					#echo "La sauvegarde n'est pas verbeuse."
					#echo "En apparence, rien ne se passe, soyez patient."
					#echo -e "$COLCMD\c"

					if [ "$CDRESTAUR" = "o" ]; then
						if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
							echo "fsarchiver -o -z$NIVEAU -s ${VOLUME} ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE"
							fsarchiver -o -z$NIVEAU -s ${VOLUME} ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							#echo "partimage -b -f3 -w restore $PARTSAVE \$chemin_source/save/$IMAGE.000" >> "$DESTINATION/restaure.sh"
							echo "fsarchiver -v restfs \$chemin_complet/$IMAGE.fsa id=0,dest=$PARTSAVE" >> "$DESTINATION/restaure.sh"
						else
							echo "fsarchiver -o -z$NIVEAU ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE"
							fsarchiver -o -z$NIVEAU ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							#echo "partimage -b -f3 restore $PARTSAVE \$chemin_source/save/$IMAGE.000" >> "$DESTINATION/restaure.sh"
							echo "fsarchiver -v restfs \$chemin_complet/$IMAGE.fsa id=0,dest=$PARTSAVE" >> "$DESTINATION/restaure.sh"
						fi
					else
						if [ "$VOLUME" != "0" -a ! -z "$VOLUME" ]; then
							echo "fsarchiver -o -z$NIVEAU -s ${VOLUME} ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE"
							fsarchiver -o -z$NIVEAU -s ${VOLUME} ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							echo "fsarchiver -v restfs $IMAGE.fsa id=0,dest=$PARTSAVE" >> "$DESTINATION/restaure.sh" >> "$DESTINATION/restaure.sh"
						else
							echo "fsarchiver -o -z$NIVEAU ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE"
							fsarchiver -o -z$NIVEAU ${option_fsarchiver} savefs $DESTINATION/$IMAGE $PARTSAVE

							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Il semble qu'une erreur se soit produite."
								echo "La sauvegarde effectuee n'est peut-etre pas integre."

								echo "ECHEC" > $DESTINATION/$IMAGE.ECHEC.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.ECHEC.txt
								date >> $DESTINATION/$IMAGE.ECHEC.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.ECHEC.txt

								POURSUIVRE
							else
								t2=$(date +%s)
								echo "SUCCES" > $DESTINATION/$IMAGE.SUCCES.txt
								ls -lh $DESTINATION/$IMAGE.* >> $DESTINATION/$IMAGE.SUCCES.txt
								date >> $DESTINATION/$IMAGE.SUCCES.txt
								df -h | egrep "(^Filesystem|${PTMNTSTOCK})" >> $DESTINATION/$IMAGE.SUCCES.txt
							fi

							echo "fsarchiver -v restfs $IMAGE.fsa id=0,dest=$PARTSAVE" >> "$DESTINATION/restaure.sh" >> "$DESTINATION/restaure.sh"
						fi
					fi
				;;
			esac

			# A revoir: Le test $? pour tar porte sur le demontage, pas sur la restauration.
			echo 'if [ "$?" = "0" ]; then' >> "$DESTINATION/restaure.sh"
			echo '	echo -e "$COLINFO"' >> "$DESTINATION/restaure.sh"
			echo '	echo "Restauration: OK"' >> "$DESTINATION/restaure.sh"
			echo '	t2=$(date +%s)' >> "$DESTINATION/restaure.sh"
			echo '	duree_rest_part=$(CALCULE_DUREE $t1 $t2)' >> "$DESTINATION/restaure.sh"
			echo '	echo -e "${COLTXT}Duree: ${COLINFO}${duree_rest_part}${COLTXT}"' >> "$DESTINATION/restaure.sh"

			if [ "$FORMAT_SVG" = "2" -o "$FORMAT_SVG" = "4" ]; then
				umount /mnt/$SUFFPARTSAVE
				echo "umount /mnt/$SUFFPARTSAVE" >> "$DESTINATION/restaure.sh"
			fi

			echo '	echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"
			echo 'else' >> "$DESTINATION/restaure.sh"
			echo '	echo -e "$COLERREUR"' >> "$DESTINATION/restaure.sh"
			echo '	echo "ERREUR lors de la restauration."' >> "$DESTINATION/restaure.sh"
			echo '	read PAUSE' >> "$DESTINATION/restaure.sh"
			echo '	echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"
			echo 'fi' >> "$DESTINATION/restaure.sh"

			echo -e "${COLTXT}"
			echo "Volume de la sauvegarde:"
			echo -e "${COLCMD}\c"
			#Le 'du' donne des resultats bizarres a travers SMB
			#du -h $DESTINATION/$IMAGE.*
			#VOLSVG=$(ls -lh $DESTINATION/$IMAGE.* | sed -e "s/ \{2,\}/ /g" | cut -d" " -f5)
			ls $DESTINATION/$IMAGE.* | sed -e "s/*//g" | while read A
			do
				VOLSVG=$(ls -lh "$A" | sed -e "s/ \{2,\}/ /g" | cut -d" " -f5)
				echo -e "${COLCMD}$A${COLTXT} : ${COLINFO}$VOLSVG${COLTXT}"
			done
			echo -e "${COLTITRE}"
			echo "Sauvegarde terminee!"

			echo "$PARTTMP" >> /tmp/tmp_${datetemp}/partitions_sauvees.txt

			if [ -e "$DESTINATION/$IMAGE.001" -o -e "$DESTINATION/$IMAGE.2.dar" ]; then
				#echo -e "$COLTXT"
				echo "La sauvegarde/restauration necessite plusieurs CD." > "$DESTINATION/plusieurs_cd.txt"
			fi



			#=============================================================
			# Ajout pour le script restaure_svg_hdusb.sh
			# echo ${PART_SOURCE} | sed -e "s|.*/||g"
			# Cas du HP Proliant ML350 avec disque raid: /dev/cciss/c0d0p1

			#num_part=$(echo ${CHOIX_SOURCE} | sed -e "s|[A-Za-z]||g")

			#/sys/block/sda/sda1/partition

			duree_svg=""
			if [ -n "$t2" ]; then
				duree_svg=$(CALCULE_DUREE $t1 $t2)
				echo -e "${COLTXT}"
				echo -e "Duree de sauvegarde: ${COLINFO}${duree_svg}${COLTXT}"
			fi

			num_part=$(cat /sys/block/${HD}/${SUFFPARTSAVE}/partition)

			taille_part=$(fdisk -s /dev/${SUFFPARTSAVE})
			if [ -e "$DESTINATION/liste_svg.csv" ]; then
				if ! grep -q "^${num_part};" $DESTINATION/liste_svg.csv; then
					echo "${num_part};${type_svg};${IMAGE};${taille_part};${duree_svg};" >> $DESTINATION/liste_svg.csv
				else
					echo -e "${COLERREUR}ATTENTION:${COLTXT} Il existe deja une sauvegarde de partition n�${num_part}"
					echo "           Le fichier liste_svg.csv genere n'est pas directement utilisable pour"
					echo "           le script restaure_svg_hdusb.sh"
					read -t 5 PAUSE
				fi
			else
				echo "${num_part};${type_svg};${IMAGE};${taille_part};${duree_svg};" > $DESTINATION/liste_svg.csv
			fi
			#=============================================================


		fi

		POURSUIVRE=""
		while [ "$POURSUIVRE" != "o" -a "$POURSUIVRE" != "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Avez-vous une autre partition a sauvegarder? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read POURSUIVRE
		done
	fi
done

#echo 'if [ "$?" = "0" ]; then' >> "$DESTINATION/restaure.sh"
#echo '	echo -e "$COLINFO"' >> "$DESTINATION/restaure.sh"
#echo '	echo "Restauration: OK"' >> "$DESTINATION/restaure.sh"
#echo '	echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"
#echo 'else' >> "$DESTINATION/restaure.sh"
#echo '	echo -e "$COLERREUR"' >> "$DESTINATION/restaure.sh"
#echo '	echo "ERREUR lors de la restauration."' >> "$DESTINATION/restaure.sh"
#echo '	read PAUSE' >> "$DESTINATION/restaure.sh"
#echo '	echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"
#echo 'fi' >> "$DESTINATION/restaure.sh"


echo 'echo -e "$COLTITRE"' >> "$DESTINATION/restaure.sh"
echo 'echo "Restauration achevee!"' >> "$DESTINATION/restaure.sh"
#echo 'echo "Il faut peut-etre monter la partition racine\n et effectuer \'chroot /mnt/disk lilo\' pour reinstaller LILO."' >> $DESTINATION/restaure.sh
echo 'echo -e "$COLINFO"' >> "$DESTINATION/restaure.sh"
echo 'echo "Il faut peut-etre monter la partition racine"' >> "$DESTINATION/restaure.sh"
echo 'echo "et effectuer:"' >> "$DESTINATION/restaure.sh"
echo 'echo "              chroot /mnt/disk lilo"' >> "$DESTINATION/restaure.sh"
echo 'echo "pour reinstaller LILO (si LILO etait installe)."' >> "$DESTINATION/restaure.sh"

echo 'echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"
echo 'echo "Demontage du cdrom..."' >> "$DESTINATION/restaure.sh"
echo 'echo -e "$COLCMD\c"' >> "$DESTINATION/restaure.sh"
#echo 'umount ${mnt_cdrom}' >> "$DESTINATION/restaure.sh"
echo '# Si on lance manuellement la restauration depuis le dossier contenant les sauvegardes, avec:
#    ./restaure.sh bidon bidon $PWD
# la variable chemin_complet est renseignee, mais pas chemin_source
if [ ! -z "${chemin_source}" ]; then
	umount ${chemin_source}
fi' >> "$DESTINATION/restaure.sh"





if [ ! -z "$PART_REINSTALL_LILOGRUB" ]; then
	echo "" >> "$DESTINATION/restaure.sh"

	if [ "$REPLILOGRUB" = "1" ]; then
		echo 'REPLILO=""
while [ "$REPLILO" != "o" -a "$REPLILO" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous reinstaller LILO? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPLILO
done

if [ "$REPLILO" = "o" ]; then

	echo -e "$COLCMD\c"
	mkdir -p /mnt/tmplilo
	mount /dev/'$PART_REINSTALL_LILOGRUB' /mnt/tmplilo

	if [ -e "/mnt/tmplilo/bin/change_mdp_lilo.sh" ]; then
		REPMDP=""
		while [ "$REPMDP" != "o" -a "$REPMDP" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Souhaitez-vous changer le(s) mot(s) de passe LILO? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPMDP
		done

		if [ $REPMDP = "o" ]; then
			chroot /mnt/tmplilo /bin/change_mdp_lilo.sh
		else
			echo -e "$COLTXT"
			echo "Reinstallation de LILO:"
			echo -e "$COLCMD"
			chroot /mnt/tmplilo lilo
		fi
	else
		echo -e "$COLTXT"
		echo "Reinstallation de LILO:"
		echo -e "$COLCMD"
		chroot /mnt/tmplilo lilo
	fi
	umount /mnt/tmplilo

	echo -e "$COLTXT"
	echo "Fin de la reinstallation de LILO"
fi' >> "$DESTINATION/restaure.sh"
	else
		echo 'REPGRUB=""
while [ "$REPGRUB" != "o" -a "$REPGRUB" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous reinstaller GRUB? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPGRUB
done

if [ "$REPGRUB" = "o" ]; then
	/bin/reinstall_grub.sh
fi' >> "$DESTINATION/restaure.sh"
	fi
else
	echo 'echo -e "$COLINFO"
echo "Si le secteur de boot comportait un chargeur de demarrage LILO et que le Linux"
echo "n est plus present, il faut penser a nettoyer le secteur de boot."
REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Faut-il nettoyer le secteur de boot? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo "Nettoyage du secteur de boot."
	echo -e "$COLCMD\c"
	install-mbr /dev/$HD
fi
' >> "$DESTINATION/restaure.sh"
fi



echo 'NUM_PART=$(parted -s /dev/${HD} print | grep "boot$" | sed -e "s|^ ||g"|cut -d" " -f1)
if [ -z "$NUM_PART" ]; then
	echo -e "${COLERREUR}"
	echo -e "ATTENTION: Aucune partition n a l air bootable."
	echo -e "           Cela peut empecher le boot du systeme."
	echo -e "${COLCMD}"
	#fdisk -l /dev/${HD}
	parted -s /dev/${HD} print

	#echo -e "${COLTXT}"
	#echo -e "Lancez ${COLCMD}fdisk /dev/${HD}${COLTXT} pour rendre une partition active/bootable."
	#echo ""

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous rendre une partition bootable? (${COLCHOIX}o/n${COLTXT}) ${COLSAISIE}\c"
		read REPONSE
	done

	if [ "$REPONSE" = "o" ]; then
		NUM_PART=""
		while [ -z "$NUM_PART" ]
		do
			echo -e "${COLTXT}"
			echo -e "Quel est le numero de la partition a rendre active? [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
			read NUM_PART

			if [ -z "$NUM_PART" ]; then
				NUM_PART="1"
			fi

			#t=$(fdisk -l /dev/${HD} | tr "\t" " " | grep "^/dev/${HD}${NUM_PART} ")
			#if [ -z "$t" ]; then
			if [ ! -e "/sys/block/${HD}/${HD}${NUM_PART}/partition" -o "$(cat /sys/block/${HD}/${HD}${NUM_PART}/partition)" =! "1" ]; then
				echo -e "${COLERREUR}"
				echo "Partition /dev/${HD}${NUM_PART} invalide."
				NUM_PART=""
			fi
		done

		echo -e "$COLTXT"
		echo -e "Positionnement du drapeau Bootable sur la partition ${COLINFO}${HD}${NUM_PART}"
		echo -e "$COLCMD\c"
		parted -s /dev/${HD} toggle ${NUM_PART} boot
		echo -e "$COLTXT"
		echo "Nouvel etat:"
		echo -e "$COLCMD\c"
		parted -s /dev/${HD} print
	fi

	#echo -e "Appuyez sur ENTREE pour quitter..."
	#read PAUSE
fi' >> "$DESTINATION/restaure.sh"


echo 'echo -e "$COLTITRE"' >> "$DESTINATION/restaure.sh"
echo 'echo "Termine!"' >> "$DESTINATION/restaure.sh"
#echo 'echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"

echo 'echo -e "$COLINFO"' >> "$DESTINATION/restaure.sh"
echo 'echo -e "Pour rebooter, tapez ${COLTXT}reboot${COLINFO}"' >> "$DESTINATION/restaure.sh"
echo 'echo -e "Pour arreter, tapez ${COLTXT}halt${COLINFO}"' >> "$DESTINATION/restaure.sh"
echo 'echo -e "$COLTXT"' >> "$DESTINATION/restaure.sh"

echo '' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"
echo '#Vous pouvez decommenter les 4 lignes ci-dessous si vous souhaitez automatiser le reboot.' >> "$DESTINATION/restaure.sh"
echo '#echo "**********"' >> "$DESTINATION/restaure.sh"
echo '#echo "* REBOOT *"' >> "$DESTINATION/restaure.sh"
echo '#echo "**********"' >> "$DESTINATION/restaure.sh"
echo '#reboot' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"

echo '' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"
echo '# NOTE 1: Si vous conservez ce script sans utiliser ce qui est indique en ANNEXE plus bas,' >> "$DESTINATION/restaure.sh"
echo '#         Et si vous devez utiliser plusieurs CD, veillez a creer un fichier' >> "$DESTINATION/restaure.sh"
echo '#         "plusieurs_cd.txt" dans le dossier save.' >> "$DESTINATION/restaure.sh"
echo '#         Vous devez de plus recreer une arborescence de CD pour les CD 2, 3,...' >> "$DESTINATION/restaure.sh"
echo '#         Elle ne se compose que d un dossier "save" contenant la ou les images partimage.' >> "$DESTINATION/restaure.sh"
echo '#         Vous utiliserez alors le script "creeriso_autres_cd.sh" pour creer les images ISO' >> "$DESTINATION/restaure.sh"
echo '#         des CD 2, 3,...' >> "$DESTINATION/restaure.sh"
echo '#         Vous lui passerez en parametre le nom du dossier dans lequel se trouve l arborescence du CD.' >> "$DESTINATION/restaure.sh"
echo '#         Exemple: Vous pourrez mettre en place une arborescence du type:' >> "$DESTINATION/restaure.sh"
echo '#                  ' >> "$DESTINATION/restaure.sh"
echo '#                  -- cdrestaure' >> "$DESTINATION/restaure.sh"
echo '#                      |-- creeriso.sh' >> "$DESTINATION/restaure.sh"
echo '#                      |-- creeriso_autres_cd.sh' >> "$DESTINATION/restaure.sh"
echo '#                      |-- disk' >> "$DESTINATION/restaure.sh"
echo '#                      |   |-- isolinux' >> "$DESTINATION/restaure.sh"
echo '#                      |   |   |-- bootmsg.txt' >> "$DESTINATION/restaure.sh"
echo '#                      |   |   |-- fr.ktl' >> "$DESTINATION/restaure.sh"
echo '#                      |   |   |-- isolinux.bin' >> "$DESTINATION/restaure.sh"
echo '#                      |   |   |-- isolinux.cfg' >> "$DESTINATION/restaure.sh"
echo '#                      |   |   |-- lilrd.img' >> "$DESTINATION/restaure.sh"
echo '#                      |   |   `-- vmlilo' >> "$DESTINATION/restaure.sh"
echo '#                      |   |-- partjmb' >> "$DESTINATION/restaure.sh"
#echo '#                      |   |   |-- jmbrd.img' >> "$DESTINATION/restaure.sh"
#echo '#                      |   |   |-- libc.so.5' >> "$DESTINATION/restaure.sh"
#echo '#                      |   |   `-- vmljmb' >> "$DESTINATION/restaure.sh"
echo '#                      |   `-- save' >> "$DESTINATION/restaure.sh"
echo '#                      |       |-- hda5.000' >> "$DESTINATION/restaure.sh"
echo '#                      |       |-- hda8.000' >> "$DESTINATION/restaure.sh"
echo '#                      |       |-- hda9.000' >> "$DESTINATION/restaure.sh"
echo '#                      |       |-- plusieurs_cd.txt' >> "$DESTINATION/restaure.sh"
echo '#                      |       |-- restaure.sh' >> "$DESTINATION/restaure.sh"
echo '#                      `-- disk2' >> "$DESTINATION/restaure.sh"
echo '#                          `-- save' >> "$DESTINATION/restaure.sh"
echo '#                              `-- hda7.000' >> "$DESTINATION/restaure.sh"
echo '#                  Pour creer la deuxieme image ISO, vous lancerez alors depuis le dossier "cdrestaure":' >> "$DESTINATION/restaure.sh"
echo '#                    ./creeriso_autres_cd.sh disk2' >> "$DESTINATION/restaure.sh"
echo '#                  Le nom du dossier "dik2" contenant l arborescence du deuxieme CD est passe en parametre.' >> "$DESTINATION/restaure.sh"
echo '#' >> "$DESTINATION/restaure.sh"
echo '#                  NOTEZ que le fichier "plusieurs_cd.txt" a ete cree a la main ci-dessus, aucune image' >> "$DESTINATION/restaure.sh"
echo '#                  n etant scindee, il n avait pas ete cree automatiquement.' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"

echo '' >> "$DESTINATION/restaure.sh"
echo '# NOTE 2: Vous pouvez vous inspirer des fichiers restaure.exemple1 et restaure.exemple2' >> "$DESTINATION/restaure.sh"
echo '#         pour adapter le script restaure.sh' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"

#echo '' >> "$DESTINATION/restaure.sh"
#echo '# ATTENTION:' >> "$DESTINATION/restaure.sh"
#echo '# Si l image necessite plusieurs CDs, il ne faut pas laisser l option -b a partimage' >> "$DESTINATION/restaure.sh"
#echo '# partimage n attendrait pas le changement de CD et echouerait.' >> "$DESTINATION/restaure.sh"

echo '' >> "$DESTINATION/restaure.sh"
echo '# ANNEXE:' >> "$DESTINATION/restaure.sh"
echo '# Si vous devez utiliser plusieurs CD, il est possible de rendre' >> "$DESTINATION/restaure.sh"
echo '# la restauration encore plus automatisee:' >> "$DESTINATION/restaure.sh"
echo '# Modifiez l ordre des restaurations pour optimiser le remplissage des CD.' >> "$DESTINATION/restaure.sh"
echo '# Entre les CDS inserez/intercalez les lignes suivantes (sans oublier de les decommenter):' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"
#echo '#umount ${mnt_cdrom}' >> "$DESTINATION/restaure.sh"
echo '#umount $chemin_source' >> "$DESTINATION/restaure.sh"
echo '#echo "Inserez le CDROM suivant et appuyez sur ENTREE..."' >> "$DESTINATION/restaure.sh"
echo '#read PAUSE' >> "$DESTINATION/restaure.sh"
#echo '#mount -t iso9660 /dev/$1 ${mnt_cdrom}' >> "$DESTINATION/restaure.sh"
echo '#mount -t iso9660 /dev/$1 $chemin_source' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"
echo '# Et enfin supprimez le fichier save/plusieurs_cd.txt s il existe.' >> "$DESTINATION/restaure.sh"
echo '' >> "$DESTINATION/restaure.sh"




echo -e "$COLTXT"
echo "Si la sauvegarde necessite plusieurs CD, un fichier temoin sera cree."
echo "Il conviendra de le laisser sur le cd de boot."

if [ ! -z "$CHEMINCD" ]; then
	echo -e "$COLTXT"
	echo "Voici le volume occupe par l'ensemble de l'arborescence du CD/DVD."
	echo "A vous de voir s'il convient de repartir l'ensemble sur plusieurs CD/DVD."
	echo -e "$COLCMD"
	du -sh "$CHEMINCD"
fi

echo -e "$COLTXT"
#if ls "$DESTINATION/*.001"; then
#if [ -e "$DESTINATION/$IMAGE.001" -o -e "$DESTINATION/$IMAGE.2.dar" ]; then
#	echo -e "$COLTXT"
#	echo "La sauvegarde/restauration necessite plusieurs CD." > "$DESTINATION/plusieurs_cd.txt"
#fi

if [ -e "$DESTINATION/plusieurs_cd.txt" ]; then
	##Lorsque l'image est sur plusieurs CD, il ne faut pas laisser l'option '-b' de partimage
	#FAUX: Ca ne change rien!
	#cat "$DESTINATION/restaure.sh" | sed -e "s/partimage -b /partimage /g" > "$DESTINATION/restaure.sh.tmp"
	#mv "$DESTINATION/restaure.sh" "$DESTINATION/restaure0.sh"
	#mv "$DESTINATION/restaure.sh.tmp" "$DESTINATION/restaure.sh"

	echo "ATTENTION: Si la somme des images .000, .001,... ne tient pas sur un seul CD"
	echo "           ou DVD, il convient d'utiliser la methode 1."
	echo "           Il faut en effet conserver le fichier plusieurs_cd.txt"
	echo "           et lancer la restauration apres avoir accede a une console pour"
	echo "           pouvoir ensuite basculer vers une deuxieme console et taper"
	echo "           next.sh pour demonter le cd et inserer/monter le suivant."
	echo ""

	POURSUIVRE

	echo -e "${COLINFO}"
	echo "Si vos sauvegardes necessitent plusieurs CD et si editer un fichier texte"
	echo "pour effectuer quelques menues modifications (commentees) ne vous effraye"
	echo "pas, editez le fichier save/restaure.sh pour rendre la restauration plus"
	echo "conviviale encore."
	echo ""
	echo "Si vos sauvegardes necessitent plusieurs CD, il faudra recreer une"
	echo "arborescence disk2/save, disk3/save,... et y placer les images correspondantes"
	echo "dans l'ordre de restauration (qui est par defaut l'ordre de sauvegarde)."

	#if [ "$REPIMAGE" != "3" ]; then
	#	echo -e "${COLERREUR}"
	#	echo "PROBLEME: Il semble que partimage ne prenne pas en compte l'option -w quand"
	#	echo "          la commande est executee depuis le script restaure.sh via la mini-"
	#	echo "          distrib partimage-baty (prt)."
	#	echo "          Ce doit etre lie a busybox."
	#	echo "          Le probleme ne se pose pas en lançant le script depuis SysRescCD"
	#	echo "          boote avec l'option cdcache."

	##FAUX! JE VIENS DE FAIRE UN TEST EN VMWARE
	##      PAR CONTRE LE MONTAGE DU 2eme CD DOIT PARFOIS SE FAIRE A LA MAIN.

	#fi

	echo -e "${COLCMD}"
	#if [ "$REPIMAGE" -eq 3 ]; then
	if [ "$REPIMAGE" = "3" ]; then
		cp "$CHEMINCD/isolinux/isolinux.cfg" "$CHEMINCD/isolinux/isolinux.cfg.reserve"
		cat "$CHEMINCD/isolinux/isolinux.cfg" | sed -e "s%work=cdrestaure.sh%work=cdrestaure.sh docache%g" > /tmp/isolinux.cfg.temp
		cat /tmp/isolinux.cfg.temp > "$CHEMINCD/isolinux/isolinux.cfg"
	fi
else
	echo -e "$COLTXT"
	echo "Il semble qu'aucune image ne soit scindee en plusieurs fractions"
	echo ".000, .001, .002,... pour des sauvegardes partimage,"
	echo ".2.dar, .3.dar,... pour des sauvegardes dar,"
	echo ".ntfsaa, .ntfsab, .ntfsac,... pour des sauvegardes ntfsclone,"
	echo "Si vous devez neanmoins utiliser plusieurs CD, creez un fichier "
	echo -e "${COLINFO}plusieurs_cd.txt${COLTXT} dans le dossier save de l'arborescence"
	echo "du CD de restauration."
fi

if [ -e "$DESTINATION/plusieurs_cd.txt" ]; then
	echo -e "$COLINFO"
	echo -e "Si vous comptez placer toutes les images sur un unique DVD, il convient"
	echo -e "de supprimer le fichier plusieurs_cd.txt genere lors des sauvegardes."

	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous que le fichier ${COLINFO}plusieurs_cd.txt${COLTXT} soit supprime? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		echo -e "$COLTXT"
		echo -e "Suppression du fichier ${COLINFO}plusieurs_cd.txt${COLTXT}"
		echo -e "$COLCMD\c"
		rm -f "$DESTINATION/plusieurs_cd.txt"
	fi
fi

echo -e "${COLCMD}\c"
if [ ! -z "$CHEMINBASE" ]; then
	if [ "${TYPE_DEST_SVG}" != 'smb' -a "${TYPE_DEST_SVG}" != 'ftp' ]; then
		# Les types ${TYPE_DEST_SVG} 'ssh' et 'partition' permettent de rendre executable un script.
		if ! mount | grep ${PTMNTSTOCK} | egrep -i "(vfat|ntfs)" > /dev/null; then
			chmod u+w "$CHEMINBASE" -R
		fi
	fi
fi

if [ "$CDRESTAUR" = "o" ]; then
	echo -e "${COLTXT}"
	echo "Voici l'espace encore disponible:"
	echo -e "${COLCMD}"
	df -h | egrep "(^Filesystem|${PTMNTSTOCK})"

	echo -e "${COLINFO}"
	echo "Si vous n'envisagez qu'un CD/DVD de restauration"
	echo "(c'est-a-dire sans repartir la sauvegarde sur plusieurs CD/DVD),"
	echo "et s'il y a assez de place, vous pouvez generer l'image ISO des maintenant."
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Souhaitez-vous generer l'image ISO des maintenant? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done
	if [ "$REPONSE" = "o" ]; then
		echo -e "${COLCMD}"
		cd "$CHEMINBASE"
		./creeriso.sh
	fi
fi

echo -e "${COLTXT}"
echo -e "Demontage de la partition ${COLINFO}${PARTSTOCK}"
echo -e "${COLCMD}\c"
cd /
umount ${PTMNTSTOCK}
echo -e "${COLTITRE}"
echo "Fin des sauvegardes!"
echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour quitter..."
read PAUSE


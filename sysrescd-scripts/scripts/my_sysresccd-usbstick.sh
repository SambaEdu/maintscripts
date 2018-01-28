#!/bin/bash
# Project page: http://www.sysresccd.org/
# (C) 2010 Francois Dupoux
# This scipt is available under the GPL-2 license

# it may also be interesting to reset the MBR
# dd if=/usr/lib/syslinux/mbr.bin of=/dev/sdf

## HELP AND BASIC ARGUMENT PROCESSING
#####################################

# Derniere modif: 19/10/2013

logfile="/var/tmp/usb_inst.log"
TMPDIR="/var/tmp/usb_inst.tmp"
# minimal size required for sysresccd in mega-bytes
#MINSIZEMB=512
# Pour faire tenir tout le CD multiboot:
MINSIZEMB=700
#PROG="${0}"

rescuecd_kernel="rescue32"

PROGIMG="${0}"
PROGLOC="$(dirname ${0})"
CDFILES=('sysrcd.dat' 'sysrcd.md5' 'version' '???linux/initram.igz' 
	'???linux/'${rescuecd_kernel} '???linux/rescue64' '???linux/f1boot.msg'
	'???linux/???linux.bin' '???linux/???linux.cfg')

#mnt_cdrom=/mnt/cdrom
mnt_cdrom=/livemnt/boot

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

usage()
{
	cat <<EOF
${PROGIMG}: SystemRescueCd installation script for USB-sticks
Syntax: ${PROGIMG} <command> ...

Please, read the manual for help about how to use this script.
http://www.sysresccd.org/Online-Manual-EN

You can either run all sub-commands in the appropriate order, or you
can just use the semi-graphical menu which requires less effort:

A) Semi-graphical installation (easy to use):
   Just run "${PROGIMG} dialog" and select the USB device

B) Sub-commands for manual installation (execute in that order):
   1) listdev               Show the list of removable media
   2) writembr <devname>    Recreate the MBR + partition table on the stick
   3) format <partname>     Format the USB-stick device (overwrites its data)
   4) copyfiles <partname>  Copy all the files from the cdrom to the USB-stick
   5) syslinux <partname>   Make the device bootable

C) Extra sub-commands:
   -h|--help	            Display these instructions

Distributed under the GNU Public License version 2 - http://www.sysresccd.org
EOF
}

#cdfiles=('sysrcd.dat' 'sysrcd.md5' 'version' 'isolinux/initram.igz' 
#	'isolinux/rescuecd' 'isolinux/rescue64' 'isolinux/f1boot.msg'
#	'isolinux/isolinux.bin' 'isolinux/isolinux.cfg')
#cdfiles=('sysrcd.dat' 'sysrcd.md5' 'version' '???linux/initram.igz' 
#	'???linux/rescuecd' '???linux/rescue64' '???linux/f1boot.msg'
#	'???linux/???linux.bin' '???linux/???linux.cfg')

## MISC FUNCTIONS: Many utilities functions
###########################################

# show the error message ($1 = first line of the message)
help_readman()
{
	echo "$1"
	echo "Merci de lire le manuel pour une aide a propso de ce script."
	echo "Web: http://www.sysresccd.org"
	exit 1
}

cleanup_tmpdir()
{
	if [ -d "${TMPDIR}" ]
	then
		#rm -rf ${TMPDIR}/{parted,install-mbr,mkfs.vfat,syslinux,dialog,mtools,mcopy,mattrib,mmove}
		rm -rf ${TMPDIR}/{parted,install-mbr,mkfs.vfat,syslinux,syslinux.exe,dialog,mtools,mcopy,mattrib,mmove,xorriso}
		rmdir ${TMPDIR}
	fi
}

## ERROR HANDLING
#####################################

die()
{
	echo -e "$COLERREUR\c"
	if [ -n "$1" ]
	then
		echo "$(basename ${PROGIMG}): Erreur: $1"
	else
		echo "$(basename ${PROGIMG}): Abandon."
	fi
	cleanup_tmpdir
	echo -e "$COLTXT"
	sleep 5
	exit 1
}

## MISC FUNCTIONS: Many utilities functions
###########################################

# check that there is one partition and one only on block-device $1
find_first_partition()
{
	devname="$1"
	if [ -z "${devname}" ] || [ ! -d "/sys/block/$(basename ${devname})" ]
	then
		die "${devname} n'est pas un peripherique valide (1)."
	fi
	
	partcnt=0
	firstpart=0
	for i in $(seq 1 4)
	do
		partname="${devname}${i}"
		if [ -b "${partname}" ]
		then
			[ "${firstpart}" = '0' ] && firstpart="$i"
			partcnt=$((partcnt+1))
		fi
	done

	if [ "${partcnt}" = '1' ]
	then
		return ${partcnt}
	else
		return 0
	fi
}

find_partitions()
{
	devname="$1"
	if [ -z "${devname}" ] || [ ! -d "/sys/block/$(basename ${devname})" ]
	then
		die "${devname} n'est pas un peripherique valide."
	fi

	tmp_curdev=$(echo $devname|sed -e "s|^/dev/||")
	liste_part=""
	for i in $(seq 1 4)
	do
		if [ -e "/sys/block/${tmp_curdev}/${tmp_curdev}${i}/partition" ]; then
			liste_part="${liste_part} /dev/${tmp_curdev}${i}"
		fi
	done

	echo ${liste_part} | sed -e "s/^ //"
}

# check $1 is a valid partition name
check_valid_partname()
{
	if [ -z "${partname}" ]
	then
		die "Vous devez choisir un nom de partition device-name comme argument a cette commande."
	fi

	if [ -z "${partname}" ] || [ ! -b "${partname}" ]
	then
		die "${partname} n'est pas un nom de partition valide."
	fi
	
	if ! echo "${partname}" | grep -qE '^/dev/[a-z]*[1-4]+$'
	then
		die "Le peripherique [${partname}] n'est pas une partition valide. Quelque chose comme [/dev/sdf1] est attendu."
	fi

	if is_dev_mounted "${partname}"
	then
		die "${partname} est deja monte. Abandon."
	fi
	
	return 0
}

# check $1 is a valid block device name
check_valid_blkdevname()
{
	if [ -z "${devname}" ]
	then
		die "Vous devez fournir un nom de peripherique valide comme argument a cette commande."
	fi
	
	if [ ! -b "${devname}" ] || [ ! -d "/sys/block/$(basename ${devname})" ]
	then
		die "${devname} n'est pas un peripherique valide (2)."
	fi
	
	if is_dev_mounted "${devname}"
	then
		die "${devname} est deja monte. Abandon."
	fi
	
	return 0
}

check_sysresccd_files()
{
	rootdir="$1"
	#[ -z "${rootdir}" ] && rootdir="${mnt_cdrom}"
    [ -z "${rootdir}" ] && die "invalid rootdir"
	for curfile in ${CDFILES[*]}
	do
		curcheck="${rootdir}/${curfile}"
		#if [ ! -f ${curcheck} ]
		if ! ls ${curcheck} >/dev/null 2>&1
		then
			die "Le fichier ${curcheck} ne peut pas etre trouve. Abandon."
		fi
	done
	return 0
}

# returns 0 if the device is big enough
check_sizeof_dev()
{
	devname="$1"

	if [ -z "${devname}" ]
	then
		die "check_sizeof_dev(): Le nom de peripherique fourni est vide."
	fi

	if [ -z "$(which blockdev)" ]
	then
		echo "Le programme blockdev n'a pas ete trouve. On suppose que l'espace disponible est suffisant."
		return 0
	fi
	
	secsizeofdev="$(blockdev --getsz ${devname})"
	mbsizeofdev="$((secsizeofdev/2048))"
	if [ "${mbsizeofdev}" -lt "${MINSIZEMB}" ]
	then
		die "Le peripherique [${devname}] n'est que de ${mbsizeofdev} MB. C'est trop peu pour copier tous les fichiers, une cle USB d'au moins ${MINSIZEMB}MB est recommandee."
	else
		echo "Le peripherique [${devname}] semble etre assez grand: ${mbsizeofdev} MB."
		return 0
	fi
}

# say how much freespace there is on a mounted device
check_disk_freespace()
{
	# Bizarres ces \df et \du, mais cela a l'air de fonctionner...
	freespace=$(\df -m -P ${1} | grep " ${1}$" | tail -n 1 | awk '{print $4}')
	#echo "Free space on ${1} is ${freespace}MB"
	sysrcdspc=$(\du -csm ${1}/{sysrcd.dat,bootdisk,bootprog,isolinux,ntpasswd,usb_inst} 2>/dev/null | grep total$ | awk '{print $1}')
	realfreespace=$((freespace+sysrcdspc))
	echo "DEBUG: diskspace($1): freespace=${freespace}, sysrcdspc=${sysrcdspc}, realfreespace=${realfreespace}"
	echo "Free space on ${1} is ${realfreespace}MB"
	#if [ "${freespace}" -lt "${MINSIZEMB}" ]
	if [ "${realfreespace}" -lt "${MINSIZEMB}" ]
	then
		die "Il n'y a pas assez de place sur la cle USB pour copier les fichiers de SystemRescuecd."
	fi
	return 0
}

# check that device $1 is an USB-stick
is_dev_usb_stick()
{
	curdev="$1"
	
	remfile="/sys/block/${curdev}/removable"
	if [ -f "${remfile}" ] && cat ${remfile} 2>/dev/null | grep -qF '1' \
		&& cat /sys/block/${curdev}/device/uevent 2>/dev/null | grep -qF 'DRIVER=sd'
	then
		#vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
		#model="$(cat /sys/block/${curdev}/device/model 2>/dev/null)"
		#return 0
		echo 0
	else
		#return 1
		echo 1
	fi
}

# check that device $1 is an USB-HD
is_dev_usb_hd()
{
	curdev="$1"

	#remfile="/sys/block/${curdev}/removable"

	t=$(readlink /sys/block/${curdev}|grep "/usb")
	#t2=$(find /sys/block/${TEST_DRIVE}/ -name partition)

	if [ -n "$t" -a -n "$(cat /sys/block/${curdev}/device/uevent 2>/dev/null | grep -F 'DRIVER=sd')" ]
	then
		#vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
		#model="$(cat /sys/block/${curdev}/device/model 2>/dev/null)"
		#return 0
		echo 0
	else
		#return 1
		echo 1
	fi
}

do_writembr()
{
	devname="$1"
	shortname="$(echo ${devname} | sed -e 's!/dev/!!g')"

	check_valid_blkdevname "${devname}"
	#if ! is_dev_usb_stick "${shortname}"
	if [ "$(is_dev_usb_stick ${shortname})" != "0" -a "$(is_dev_usb_hd ${shortname})" != "0" ]
	then
		die "Le peripherique [${devname}] ne semble pas etre une cle/dd USB. Abandon."
	fi
	
	check_sizeof_dev "${devname}"
	
	#if [ -z "$(which install-mbr)" ] || [ -z "$(which parted)" ]
	if [ ! -x "${PROG_INSTMBR}" ] || [ ! -x "${PROG_PARTED}" ]
	then
		die "install-mbr et parted doivent etre installes, verifier la presence de ces programmes d'abord."
	fi

	echo -e "$COLTXT"
	echo -e "Installation de MBR sur ${COLINFO}${devname}"
	echo -e "$COLCMD\c"
	#cmd="install-mbr ${devname} --force"
	cmd="${PROG_INSTMBR} ${devname} --force"
	echo "--> ${cmd}"
	if ! ${cmd}
	then
		die "${cmd} --> echec"
	fi

	if ! echo "$*" | grep -q "no_new_parttable"; then
		# On cree une nouvelle table de partitions

		echo -e "$COLTXT"
		echo "Creation d'une nouvelle table de partitions:"
		echo -e "$COLCMD\c"
		#cmd="parted -s ${devname} mklabel msdos"
		cmd="${PROG_PARTED} -s ${devname} mklabel msdos"
		echo "--> ${cmd}"
		if ! ${cmd} 2>/dev/null
		then
			die "${cmd} --> echec"
		fi

		# A ce stade, il n'y a aucune partition

		partprobe ${devname}

		# On passe au partitionnement
		if ! echo "$*" | grep -q "partitionnement="; then
			# Une seule partition
			echo -e "$COLTXT"
			echo "Creation d'une unique partition:"
			echo -e "$COLCMD\c"
			#cmd="parted -s ${devname} mkpartfs primary fat32 0 100%"
			cmd="${PROG_PARTED} -s ${devname} mkpart primary fat32 0 100%"
			echo "--> ${cmd}"
			if ! ${cmd} 2>/dev/null
			then
				echo -e "$COLERREUR"
				echo "Echec de la creation de partition avec ${PROG_PARTED}"
				echo -e "$COLTXT\c"
				echo "Nouvelle tentative avec fdisk..."
				fich_repartitionnement=/tmp/repartitionnement_$(date +%Y%m%d%H%M%S).txt

				echo "n
p
1


a

w
" > $fich_repartitionnement
				echo -e "$COLCMD\c"
				${PROG_FDISK} ${devname} < $fich_repartitionnement

				if ! fdisk -s ${devname} > /dev/null 2>&1; then
					die "${cmd} --> echec"
				fi

			fi
		else
			fich_repartitionnement=/tmp/repartitionnement_$(date +%Y%m%d%H%M%S).txt

			t=$(echo "$*" | tr " " "\n" | grep "partitionnement=" | cut -d"=" -f2)

			if [ ${t:0:4} = "fin_" ]; then
				echo -e "$COLTXT"
				echo "On va placer SYSRESC a la fin du disque..."

				part_usb=${devname}2

				# Format fin_${size_part2}_${fs_part2}_debut_${fs_part1}
				t=${t:4}
				size_part2=$(echo "$t"|cut -d"_" -f1)
				t2=$(echo "$size_part2"|grep "G$")
				if [ -n "$t2" ]; then
					size_part2=$(($(echo ${size_part2}|sed -e "s|G$||")*1024))
				else
					size_part2=$(echo ${size_part2}|sed -e "s|M$||")
				fi
				fs_part2=$(echo "$t"|cut -d"_" -f2)
				fs_part1=$(echo "$t"|cut -d"_" -f4)
				if [ "$fs_part1" = "fat32" ]; then
					fdisk_fs_part1="b"
				elif [ "$fs_part1" = "ntfs" ]; then
					fdisk_fs_part1="7"
				else
					fdisk_fs_part1="83"
				fi

				# Taille totale en Mo
				taille=$(($(fdisk -s ${devname})/1024))
				size_part1=$(($taille-${size_part2}))
				size_part1=$(echo $size_part1|cut -d"." -f1)

				if [ -e "/tmp/debug" ]; then
					echo -e "$COLTXT"
					echo "Etat initial: fdisk -l ${devname}"
					echo -e "$COLCMD\c"
					fdisk -l ${devname}
					echo ""
				fi

				echo -e "$COLTXT"
				echo "On commence par creer la partition de DONNEES de ${size_part1}MB"
				echo -e "$COLCMD\c"
				#cmd="${PROG_PARTED} -s ${devname} mkpart primary $fs_part1 0 ${size_part1}MB"
				cmd="${PROG_PARTED} -a optimal -s ${devname} mkpart primary $fs_part1 0 ${size_part1}MB"
				echo $cmd|tee -a /tmp/log_partitionnement.txt
				$cmd|tee -a /tmp/log_partitionnement.txt
				if [ "$?" = "0" ]; then
					echo -e "$COLTXT"
					echo "La partition de donnees a ete creee avec succes avec parted"

					partprobe ${devname}

					if [ -e "/tmp/debug" ]; then
						echo "Etat courant: fdisk -l ${devname}"
						echo -e "$COLCMD\c"
						fdisk -l ${devname}
						echo ""
					fi
				else
					echo -e "$COLERREUR"
					echo "La creation avec ${PROG_PARTED} semble avoir echoue..."

					t=$(fdisk -l ${devname}|grep "^/dev/")
					if [ -n "$t" ]; then
						echo -e "$COLTXT"
						echo "Il semble qu'il existe au moins une partition sur ${devname}"
						echo "On va faire le menage."
						echo -e "$COLCMD\c"
						cmd="${PROG_PARTED} -s ${devname} mklabel msdos"
						echo "--> ${cmd}"
						if ! ${cmd} 2>/dev/null
						then
							echo -e "$COLERREUR"
							echo "Echec de la creation d'une nouvelle table de partitions."
							echo -e "$COLTXT"
							echo "Nouvel essai en supprimant les partitions primaires avec fdisk..."
							echo "d
1
d
2
d
3
d
4

w
" > $fich_repartitionnement
							${PROG_FDISK} ${devname} < $fich_repartitionnement >/dev/null 2>&1

							partprobe ${devname}

							t=$(fdisk -l ${devname}|grep "^/dev/")
							if [ -n "$t" ]; then
								echo -e "$COLERREUR"
								echo "Il semble que des partitions soient toujours presentes???"
							fi
						fi
					
					fi

					echo -e "$COLTXT"
					echo "Nouvelle tentative de creation de partition de DONNEES avec fdisk"
					echo "n
p
1

+${size_part1}

t
${fdisk_fs_part1}

w
" > $fich_repartitionnement
					echo -e "$COLCMD\c"
					#cat $fich_repartitionnement
					#sleep 3
					cmd="${PROG_FDISK} ${devname} < $fich_repartitionnement"
					echo $cmd
					$cmd > /dev/null 2>&1
					sleep 2
					partprobe ${devname}
					sleep 1
				fi

				if [ -e "/tmp/debug" ]; then
					echo -e "$COLTXT"
					echo "Etat courant: fdisk -l ${devname}"
					echo -e "$COLCMD\c"
					fdisk -l ${devname}
					echo ""
					sleep 2
				fi

				partprobe ${devname}

				# Formatage
				echo -e "$COLTXT"
				echo "Formatage de ${devname}1"
				echo -e "$COLCMD\c"
				case $fs_part1 in 
				"fat32")
					cmd="${PROG_MKVFATFS} -F 32 -n DONNEES ${devname}1"
				;;
				"ntfs")
					cmd="${PROG_MKNTFS} -L DONNEES -f ${devname}1"
				;;
				*)
					cmd="${PROG_MKEXT3} -L DONNEES ${devname}1"
				;;
				esac
				echo $cmd
				$cmd


				echo -e "$COLTXT"
				echo "Creation de la deuxieme partition pour SYSRESC avec fdisk"
				echo "n
p
2



t
2
b

a
2

w
" > $fich_repartitionnement
					echo -e "$COLCMD\c"
					#cat $fich_repartitionnement
					#sleep 3
					echo "${PROG_FDISK} ${devname} < $fich_repartitionnement > /dev/null 2>&1"
					${PROG_FDISK} ${devname} < $fich_repartitionnement > /dev/null 2>&1

					if [ -e "/tmp/debug" ]; then
						echo -e "$COLTXT"
						echo "Etat courant: fdisk -l ${devname}"
						echo -e "$COLCMD\c"
						fdisk -l ${devname}
						echo ""
						sleep 2
					fi

					partprobe ${devname}
					sleep 2

					# Formatage
					echo -e "$COLTXT"
					echo "Formatage vfat de ${devname}2"
					echo -e "$COLCMD\c"
					echo ${PROG_MKVFATFS} -F 32 -n SYSRESC ${devname}2
					${PROG_MKVFATFS} -F 32 -n SYSRESC ${devname}2
					#mkfs.vfat ${devname}2

			else
				# Choix historique:
				# La partition SYSRESC va etre en debut de disque
				size_part1=$(echo "$t"|cut -d"_" -f1)
				fs_part1=$(echo "$t"|cut -d"_" -f2)
				fs_part2=$(echo "$t"|cut -d"_" -f4)

				if [ -e "/tmp/debug" ]; then
					echo -e "$COLTXT"
					echo "Partitionnement demandee: 2 partitions"
					echo "- Partition 1 : SYSRESC : $size_part1 en $fs_part1"
					echo "- Partition 2 : DONNEES : Le reste en $fs_part2"
				fi

#			echo "p
#n
#p
#1
#
#+${size_part1}
#
#t
#b
#
#a
#
#n
#p
#2
#
#
#" > $fich_repartitionnement

				#parted -s ${devname} mkpartfs primary fat32 0 ${size_part1}B
				#parted -s ${devname} mkpartfs primary fat32 0 $(($(echo ${size_part1}|sed -e "s|G$||")*1000))MB
				#parted -s ${devname} mkpartfs primary fat32 0 $(($(echo ${size_part1}|sed -e "s|G$||")*1024))MB

				if [ -e "/tmp/debug" ]; then
					echo -e "$COLTXT"
					echo "Etat initial: fdisk -l ${devname}"
					echo -e "$COLCMD\c"
					fdisk -l ${devname}
					echo ""
				fi

				echo -e "$COLTXT"
				echo "Creation de la partition SYSRESC"
				echo -e "$COLCMD\c"
				echo ${PROG_PARTED} -s ${devname} mkpart primary fat32 0 $(($(echo ${size_part1}|sed -e "s|G$||")*1024))MB
				${PROG_PARTED} -s ${devname} mkpart primary fat32 0 $(($(echo ${size_part1}|sed -e "s|G$||")*1024))MB

				sleep 2

				if [ -e "/tmp/debug" ]; then
					echo -e "$COLTXT"
					echo "Nouvel etat: fdisk -l ${devname}"
					echo -e "$COLCMD\c"
					fdisk -l ${devname}
					echo "Apuyez sur ENTREE pour poursuivre..."
					read PAUSE
				fi

				if ! fdisk -s ${devname}1 > /dev/null 2>&1; then
					echo -e "$COLERREUR"
					echo "La creation avec ${PROG_PARTED} semble avoir echoue..."

					t=$(fdisk -l ${devname}|grep "^/dev/")
					if [ -n "$t" ]; then
						echo -e "$COLTXT"
						echo "Il semble qu'il existe au moins une partition sur ${devname}"
						echo "On va faire le menage."
						echo -e "$COLCMD\c"
						cmd="${PROG_PARTED} -s ${devname} mklabel msdos"
						echo "--> ${cmd}"
						if ! ${cmd} 2>/dev/null
						then
							echo -e "$COLERREUR"
							echo "Echec de la creation d'une nouvelle table de partitions."
							echo -e "$COLTXT"
							echo "Nouvel essai en supprimant les partitions primaires avec fdisk..."
							echo "d
1
d
2
d
3
d
4

w
" > $fich_repartitionnement
							echo -e "$COLCMD\c"
							echo "${PROG_FDISK} ${devname} < $fich_repartitionnement >/dev/null 2>&1"
							${PROG_FDISK} ${devname} < $fich_repartitionnement >/dev/null 2>&1

							t=$(fdisk -l ${devname}|grep "^/dev/")
							if [ -n "$t" ]; then
								echo -e "$COLERREUR"
								echo "Il semble que des partitions soient toujours presentes???"
							fi
						fi
					
					fi

					echo -e "$COLTXT"
					echo "Tentative de creation de partition avec fdisk"
					echo "n
p
1

+${size_part1}

t
b

a
1

w
" > $fich_repartitionnement
					echo -e "$COLCMD\c"
					echo "${PROG_FDISK} ${devname} < $fich_repartitionnement > /dev/null 2>&1"
					${PROG_FDISK} ${devname} < $fich_repartitionnement > /dev/null 2>&1

					if [ -e "/tmp/debug" ]; then
						echo -e "$COLTXT"
						echo "Apuyez sur ENTREE pour poursuivre..."
						read PAUSE
					else
						sleep 2
					fi

					echo -e "$COLTXT"
					echo "Formatage vfat de ${devname}1"
					echo -e "$COLCMD\c"
					mkfs.vfat ${devname}1

					if [ -e "/tmp/debug" ]; then
						echo -e "$COLTXT"
						echo "Apuyez sur ENTREE pour poursuivre..."
						read PAUSE
					else
						sleep 2
					fi
				fi

				# Creation de la deuxieme partition:
				echo -e "$COLTXT"
				echo "Creation de la deuxieme partition pour les DONNEES"
				echo "n
p
2


" > $fich_repartitionnement

				case $fs_part2 in 
				"fat32")
					echo "t
2
c
" >> $fich_repartitionnement
				;;
				"ntfs")
					echo "t
2
7
" >> $fich_repartitionnement
				;;
				esac

				echo "p
w
" >> $fich_repartitionnement

				echo -e "$COLCMD\c"
				echo "${PROG_FDISK} ${devname} < $fich_repartitionnement > /dev/null 2>&1"
				${PROG_FDISK} ${devname} < $fich_repartitionnement > /dev/null 2>&1

				# Pause pour ne pas lancer trop vite le formatage avant la relecture de la table de partitions
				sleep 2

				if ! fdisk -s ${devname}2 > /dev/null 2>&1; then
					echo -e "$COLERREUR"
					echo "Il semble qu'il se soit produit une erreur lors de la creation de la deuxieme partition..."

					echo -e "$COLTXT"
					echo "Nouvel etat: fdisk -l ${devname}"
					echo -e "$COLCMD\c"
					fdisk -l ${devname}

					echo "Apuyez sur ENTREE pour poursuivre malgre tout..."
					read PAUSE
				fi

				echo -e "$COLTXT"
				echo "Formatage de ${devname}1"
				echo -e "$COLCMD\c"
				${PROG_MKVFATFS} -F 32 -n SYSRESC ${devname}1

				echo -e "$COLTXT"
				echo "Formatage de ${devname}2"
				echo -e "$COLCMD\c"
				case $fs_part2 in 
				"fat32")
					cmd="${PROG_MKVFATFS} -F 32 -n DONNEES ${devname}2"
				;;
				"ntfs")
					cmd="${PROG_MKNTFS} -L DONNEES -f ${devname}2"
				;;
				*)
					cmd="${PROG_MKEXT3} -L DONNEES ${devname}2"
				;;
				esac
				echo $cmd
				$cmd
			fi
		fi
	else
		# On change pas la table de partitions
		echo -e "$COLTXT"
		echo "On change pas la table de partitions."
		if echo "$*" | grep -q " part_usb="; then
			# On se contente de formater la partition de boot
			echo -e "$COLTXT"
			echo "Formatage de la partition SYSRESC..."
			echo -e "$COLCMD\c"
			part_usb=$(echo "$*" | sed -e "s|.* part_usb=||" | cut -d" " -f1)
			#cmd="parted -s ${part_usb} mkfs fat32"
			cmd="${PROG_MKVFATFS} /dev/${part_usb}"
			echo "--> ${cmd}"
			if ! ${cmd} 2>/dev/null
			then
				die "${cmd} --> echec"
			fi
		else
			# On ne devrait pas arriver la...

			#cmd="parted -s ${devname} mkpartfs primary fat32 0 100%"
			#cmd="${PROG_PARTED} -s ${devname} mkpartfs primary fat32 0 100%"
			cmd="${PROG_PARTED} -s ${devname} mkpart primary fat32 0 100%"
			echo "--> ${cmd}"
			if ! ${cmd} 2>/dev/null
			then
				die "${cmd} --> echec"
			fi
		fi

	fi

	echo -e "$COLTXT"
	echo "On rend la partition SYSRESC bootable..."
	echo -e "$COLCMD\c"
	NUM_PART_BOOT=$(echo "${part_usb}"|sed -e "s|[^0-9]||g")
	if [ -z "$NUM_PART_BOOT" ]; then
		#cmd="parted -s ${devname} set 1 boot on"
		cmd="${PROG_PARTED} -s ${devname} set 1 boot on"
	else
		cmd="${PROG_PARTED} -s ${devname} set $NUM_PART_BOOT boot on"
	fi
	echo "--> ${cmd}"
	if ! ${cmd} 2>/dev/null
	then
		die "${cmd} --> echec"
	fi

}

do_format()
{
	partname="$1"
	check_valid_partname "${partname}"

	check_sizeof_dev "${partname}"

	#if [ -z "$(which mkfs.vfat)" ]
	if [ ! -x "${PROG_MKVFATFS}" ]
	then
		die "mkfs.vfat non trouve sur votre systeme, merci d'installer dosfstools d'abord."
	fi
	
	#if mkfs.vfat -F 32 -n SYSRESC ${partname}
	if ${PROG_MKVFATFS} -F 32 -n SYSRESC ${partname}
	then
		echo "La partition ${partname} a ete formatee avec succes."
		return 0
	else
		echo "La partition ${partname} ne peut pas etre formatee."
		return 1
	fi
}

do_copyfiles()
{
	partname="$1"
	check_valid_partname "${partname}"
	
	# check the important files are available in ${mnt_cdrom}
	# check the important files are available in ${LOCATION}
	#check_sysresccd_files "${mnt_cdrom}"
	check_sysresccd_files "${LOCATION}"
	
	check_sizeof_dev "${partname}"

	mkdir -p /mnt/usbstick 2>/dev/null
	if ! mount -t vfat ${partname} /mnt/usbstick
	then
		die "Impossible de monter ${partname} en /mnt/usbstick"
	fi
	echo "${partname} a ete montee avec succes en /mnt/usbstick"
	
	check_disk_freespace "/mnt/usbstick"
	
	#if cp -r --remove-destination ${mnt_cdrom}/* /mnt/usbstick/ && sync
	echo "cp -v -r --remove-destination ${LOCATION}/* /mnt/usbstick/"
	if cp -v -r --remove-destination ${LOCATION}/* /mnt/usbstick/ && sync
	then
		echo "Les fichiers ont ete copies avec succes vers ${partname}"
	else
		echo "Impossible de copier les fichiers vers ${partname}"
	fi
	
	#for curfile in '/mnt/usbstick/isolinux/isolinux.cfg'
	#do
	#	if [ ! -f "${curfile}" ]
	#	then
	#		umount /mnt/usbstick
	#		die "${curfile} non trouve. Abandon."
	#	fi
	#done
	if ! ls -l /mnt/usbstick/???linux/???linux.cfg >/dev/null 2>&1
	then
		umount /mnt/usbstick
		die "Fichier de configuration isolinux/syslinux non trouve. Abandon."
	fi
	# check the important files have been copied
	check_sysresccd_files "/mnt/usbstick"
	
	# move isolinux files to syslinux files
	if [ -e /mnt/usbstick/isolinux ]; then
		# On a boote sur un CD.
		# Dans le cas d'un boot sur cle usb, on a deja syslinux au lieu de isolinux.
		echo "Suppression prealable de /mnt/usbstick/syslinux..."
		rm -rf /mnt/usbstick/syslinux

# On n'utilise plus isolinux_dd_usb.cfg avec les nouveaux menus
#	if [ -e /mnt/usbstick/isolinux/isolinux_dd_usb.cfg ]; then
#		if ! mv -f /mnt/usbstick/isolinux/isolinux.cfg /mnt/usbstick/isolinux/isolinux_cdrom.cfg \
#		|| ! cp -f /mnt/usbstick/isolinux/isolinux_dd_usb.cfg /mnt/usbstick/isolinux/syslinux.cfg \
#		|| ! mv /mnt/usbstick/isolinux /mnt/usbstick/syslinux
#		then
#			umount /mnt/usbstick
#			die "Impossible de renommer le dossier isolinux en syslinux, echec."
#		fi
#		sed -i -e 's!/isolinux/!/syslinux/!g' /mnt/usbstick/boot/grub/grub*.cfg
#	else

		echo "On renomme isolinux.cfg en syslinux.cfg et le dossier isolinux en syslinux..."
		if ! mv /mnt/usbstick/isolinux/isolinux.cfg /mnt/usbstick/isolinux/syslinux.cfg \
			|| ! mv /mnt/usbstick/isolinux /mnt/usbstick/syslinux
		then
			umount /mnt/usbstick
			die "Impossible de renommer le dossier isolinux en syslinux, echec."
		fi
	fi

#		# remove the last lines which produces error messages 'bad keyword' with syslinux
#		sed -i -e '/label disk[1-2]$/d' -e '/label floppy$/d' -e '/label nextboot$/d' -e '/localboot/d' /mnt/usbstick/syslinux/syslinux.cfg
		
#		# add scandelay option which allows the usb devices to be detected
#		sed -i -e 's!initrd=initram.igz!initrd=initram.igz scandelay=5!g' /mnt/usbstick/syslinux/syslinux.cfg

		# add scandelay option which allows the usb devices to be detected
		sed -i -e 's!scandelay=.!scandelay=5!g' /mnt/usbstick/syslinux/syslinux.cfg

		if grep -q "/isolinux/clonezilla.cfg" /mnt/usbstick/syslinux/syslinux.cfg; then
			sed -i "s|/isolinux/clonezilla.cfg|/syslinux/clonezilla.cfg|" /mnt/usbstick/syslinux/syslinux.cfg
		fi

		if grep -q "/isolinux/konboot/fdkb.img" /mnt/usbstick/syslinux/syslinux.cfg; then
			sed -i "s|/isolinux/konboot/fdkb.img|/syslinux/konboot/fdkb.img|" /mnt/usbstick/syslinux/syslinux.cfg
		fi

		sed -i -e 's!/isolinux/!/syslinux/!g' /mnt/usbstick/boot/grub/grub*.cfg
		if [ -e "/mnt/usbstick/EFI/boot/grub.cfg" ]; then
			# Le grub.cfg de CloneZilla
			sed -i -e 's!/isolinux/!/syslinux/!g' /mnt/usbstick/EFI/boot/grub.cfg
		fi
#	fi

	umount /mnt/usbstick
}

do_syslinux()
{
	partname="$1"
	#option_syslinux="$2"
	check_valid_partname "${partname}"
	
	#if [ -z "$(which syslinux)" ]
	if [ ! -x "${PROG_SYSLINUX}" ]
	then
		die "syslinux non trouve sur votre systeme, merci d'installer syslinux d'abord."
	fi

	if [ -e /tmp/erreur_syslinux ]; then
		rm -f /tmp/erreur_syslinux
	fi

	#if syslinux ${partname} && sync
	#if ${PROG_SYSLINUX} ${partname} && sync
	#echo ${PROG_SYSLINUX} ${option_syslinux} ${partname}
	#${PROG_SYSLINUX} ${option_syslinux} ${partname}
	echo ${PROG_SYSLINUX} --install --directory syslinux ${partname}
	${PROG_SYSLINUX} --install --directory syslinux ${partname}
	res=$?
	sync
	if [ ${res} -eq 0 ]
	then
		echo "syslinux a prepare avec succes ${partname}"
	else
		echo "syslinux n'a pas reussi a preparer ${partname}"
		echo "erreur" > /tmp/erreur_syslinux
	fi
}

is_dev_mounted()
{
	curdev="$1"
	
	if cat /proc/mounts | grep -q "^${curdev}"
	then
		return 0
	else
		return 1
	fi
}

do_dialog_old()
{
    if [ ! -x ${PROG_DIALOG} ]
    then
        die "Program dialog not found, cannot run the semi-graphical installation program"
    fi
	lwselection="`mktemp /tmp/lwselection.XXXX`"
	#selection='dialog --backtitle "Select USB-Stick" --checklist "Select USB-Stick" 20 61 5'
	# A VERIFIER
	#selection='${PROG_DIALOG} --backtitle "Select USB-Stick" --checklist "Select USB-Stick (current data will be lost)" 20 70 5'
	selection=${PROG_DIALOG}' --backtitle "Select USB-Stick" --checklist "Select USB-Stick (current data will be lost)" 20 70 5'
	devcnt=0
	for curpath in /sys/block/*
	do
		curdev="$(basename ${curpath})"
		devname="/dev/${curdev}"
		#if is_dev_usb_stick ${curdev}
		if [ "$(is_dev_usb_stick ${curdev})" = "0" -o "$(is_dev_usb_hd ${curdev})" = "0" ]
		then
			if [ -n "$(which blockdev)" ]
			then
				secsizeofdev="$(blockdev --getsz /dev/${curdev})"
				mbsizeofdev="$((secsizeofdev/2048))"
				sizemsg=" and size=${mbsizeofdev}MB"
			fi	
			echo "Device [${devname}] detected as [${vendor} ${model}] is removable${sizemsg}"
			if is_dev_mounted "${devname}"
			then
				echo "Device [${devname}] is mounted: cannot use it"
			else
				echo "Device [${devname}] is not mounted"
				selection="$selection \"${devname}\" \"[${vendor} ${model}] ${sizemsg}\" off"
				devcnt=$((devcnt+1))
			fi
			#find_first_partition ${devname}
			#firstpart="$?"
			#if [ "${firstpart}" != '0' ]
			#then
			#	echo "Device [${devname}] has one partition: ${devname}${firstpart}"
			#	selection="$selection \"${devname}\" \"\" off"
			#else
			#	echo "Cannot identify which partition to use on ${devname}"
			#fi
			#devcnt=$((devcnt+1))
		fi
	done
	if [ "${devcnt}" = '0' ]
	then
		echo "No valid USB-stick has been detected."
	else
		eval $selection 2>$lwselection
		if test -s $lwselection
		then
			#for devname2 in `cat $lwselection  | tr -d \" | sort`; do
			for devname2 in $(cat $lwselection  | tr -d \" | sort)
			do
				do_writembr ${devname2}
				sleep 5
				find_first_partition ${devname2}
				devname2="${devname2}$?"
				do_format ${devname2}
				do_copyfiles ${devname2}
				do_syslinux ${devname2}
			done
		fi
	fi
	rm -f $lwselection
}


do_dialog()
{
    if [ ! -x ${PROG_DIALOG} ]
    then
        die "Program dialog not found, cannot run the semi-graphical installation program"
    fi
	devsallcnt=0
	devsmntcnt=0
	devsokcnt=0
	for curpath in /sys/block/*
	do
		curdev="$(basename ${curpath})"
		devname="/dev/${curdev}"
		if is_dev_usb_stick ${curdev}
		then
			if [ -n "$(which blockdev)" ]
			then
				secsizeofdev="$(blockdev --getsz /dev/${curdev})"
				mbsizeofdev="$((secsizeofdev/2048))"
				sizemsg=" and size=${mbsizeofdev}MB"
			fi
			echo "Device [${devname}] detected as [${vendor} ${model}] is removable${sizemsg}"
			if is_dev_mounted "${devname}"
			then
				echo "* Device [${devname}] is mounted: cannot use it"
				devsmnttxt="${devsmnttxt} * Device [${devname}] is mounted: cannot use it"
				devsmntcnt=$((devsmntcnt+1))
				devsallcnt=$((devsallcnt+1))
			else
				echo "* Device [${devname}] is not mounted"
				devsoktxt="${devsoktxt} \"${devname}\" \"[${vendor} ${model}] ${sizemsg}\" off"
				devsokcnt=$((devsokcnt+1))
				devsallcnt=$((devsallcnt+1))
			fi
		fi
	done
	if [ ${devsallcnt} -eq 0 ]
	then
		echo "No valid USB/Removable device has been detected on your system"
		return 1	
	fi
	if [ ${devsokcnt} -eq 0 ]
	then
		echo "All valid USB/Removable devices are currently mounted, unmount these devices first"
		return 1
	fi

	if [ ${devsmntcnt} -gt 0 ]
        then
		message="${message}The following USB/Removable devices cannot be used:\n"
		message="${message}${devsmnttxt}\n\n"
	fi
	message="${message}Select the USB/Removable devices where you want to install it.\n"
	message="${message}Files on these devices will be lost if you continue.\n"

	lwselection="/tmp/usb_inst_$$.tmp"
	[ ! -d /tmp ] && mkdir -p /tmp
	[ -f ${lwselection} ] && rm -f ${lwselection}
	selection='${PROG_DIALOG} --backtitle "Select USB/Removable device" --checklist "${message}" 20 70 5'
	eval "${selection} ${devsoktxt}" 2>$lwselection
	if [ -s $lwselection ]
	then
		status=""
		output=""
		echo "" > ${logfile}
		for devname2 in $(cat $lwselection | tr -d \" | sort)
		do
			echo "Installation on ${devname2} at $(date +%Y-%m-%d_%H:%M)" >> ${logfile}
			status="${status}Installation on ${devname2} in progress\n\n"
			status="${status}details will be written in ${logfile}\n"
			dialog_status "${status}"
			status="${status}* Writing MBR on ${devname2}\n"
			dialog_status "${status}"
			do_writembr ${devname2} >> ${logfile} 2>&1
			[ $? -ne 0 ] && dialog_die "Failed to write the MBR on ${devname2}"
			sleep 1
			output="$(find_first_partition ${devname2})\n"
			devname2="${devname2}$?"
			dialog_status "${status}"
			sleep 5
			status="${status}* Creating filesystem on ${devname2}...\n"
			dialog_status "${status}"
			do_format ${devname2} >> ${logfile} 2>&1
			[ $? -ne 0 ] && dialog_die "Failed to create the filesystem on ${devname2}"
			status="${status}* Copying files (please wait)...\n"
			dialog_status "${status}"
			do_copyfiles ${devname2} >> ${logfile} 2>&1
			[ $? -ne 0 ] && dialog_die "Failed to copy files on ${devname2}"
			status="${status}* Installing the boot loader on ${devname2}...\n"
			dialog_status "${status}"
			do_syslinux ${devname2} >> ${logfile} 2>&1
			[ $? -ne 0 ] && dialog_die "Failed to install the boot loader ${devname2}"
			status="${status}* Installation on ${devname2} successfully completed\n"
			dialog_status "${status}"
			sleep 5
		done
		${PROG_DIALOG} --title "Success" --msgbox "Installation successfully completed" 10 50
	fi
	rm -f $lwselection
}

dialog_status()
{
	${PROG_DIALOG} --infobox "$1" 20 75
}

dialog_die()
{
	readlog="Read the logfile (${logfile}) for more details"
	${PROG_DIALOG} --title "Error" --msgbox "$1\n${readlog}" 20 70
	cleanup_tmpdir
	exit 1
}

do_listdev()
{
	devcnt=0
	for curpath in /sys/block/*
	do
		curdev="$(basename ${curpath})"
		devname="/dev/${curdev}"
		nom_dev_courant=$curdev
		#echo "curdev=$curdev"
		if [ "$(is_dev_usb_stick ${curdev})" = "0" -o  "$(is_dev_usb_hd ${curdev})" = "0" ]
		then
			if [ -n "$(which blockdev)" ]
			then
				secsizeofdev="$(blockdev --getsz /dev/${curdev})"
				mbsizeofdev="$((secsizeofdev/2048))"
				sizemsg=" et taille=${mbsizeofdev}MB"
			fi	

			vendor="$(cat /sys/block/${curdev}/device/vendor 2>/dev/null)"
			model="$(cat /sys/block/${curdev}/device/model 2>/dev/null | tr "\t" " " | sed -e 's/ $//g')"

			#echo "Le peripherique [${devname}] detecte comme [${vendor} ${model}] est amovible${sizemsg}"
			chaine_tmp=$(echo "${vendor} ${model}" | sed -e "s|^ ||g" | sed -e "s| \{2,\}| |g")
			echo "Le peripherique [${devname}] detecte comme [${chaine_tmp}] est amovible${sizemsg}"
			if is_dev_mounted "${devname}"
			then
				echo "Le peripherique [${devname}] est monte."
				temoin_est_monte="y"
			else
				echo "Le peripherique [${devname}] n'est pas monte."
				temoin_est_monte="n"
			fi

#			find_first_partition ${devname}
#			firstpart="$?"
#			if [ "${firstpart}" != '0' ]
#			then
#				echo "Le peripherique [${devname}] a une partition: ${devname}${firstpart}"
#			else
#				echo "Impossible d'identifier la partition a utiliser sur ${devname}"
#			fi

			if [ -z "$DEFAULT_DISK" -a "$temoin_est_monte" = "n" ]; then
				# Le curdev passe de sdb a /dev/sdb en cours de traitement
				#DEFAULT_DISK=${curdev}
				DEFAULT_DISK=${nom_dev_courant}
				#echo "DEFAULT_DISK=${curdev}"
			fi

			liste_part=$(find_partitions ${devname})
			if [ -n "${liste_part}" ]
			then
				echo "Le peripherique [${devname}] a une ou des partitions: ${liste_part}"
				DEFAULT_PART=$(echo ${liste_part}|sed -e "s/^ //g"|cut -d" " -f1|sed -e "s|^/dev/||g")
			else
				echo "Impossible d'identifier la partition a utiliser sur ${devname}"
			fi

			devcnt=$((devcnt+1))
		fi
	done
	if [ "${devcnt}" = '0' ]
	then
		echo "Aucune cle/dd USB n'a ete detecte."
	fi
}


## Main
###############################################################################

export TERMINFO_DIRS=$TERMINFO_DIRS:/lib/terminfo:/etc/terminfo:/usr/share/terminfo

if [ "$(basename $0)" = 'usb_inst.sh' ] && [ -d "${PROGLOC}/usb_inst" ]
then
	RUN_FROM_ISOROOT='1'

	echo "Lance via usb_inst.sh"
	echo "Utilisation des programmes copies vers ${TMPDIR}"

	# copy programs to a temp dir on the disk since exec from cdrom may fail
	cleanup_tmpdir
	mkdir -p ${TMPDIR} || die "Impossible de creer le dossier temporaire: ${TMPDIR}"
	if ! cp -r ${PROGLOC}/usb_inst/* ${TMPDIR}/
	then
		rm -rf ${TMPDIR} 2>/dev/null
		die "Impossible de copier les programmes vers le dossier temporaire: ${TMPDIR}"
	else
		chmod 777 ${TMPDIR}/*
	fi
	LOCATION="${PROGLOC}"
	# programs directly used by this script
	PROG_PARTED="${TMPDIR}/parted"
	PROG_INSTMBR="${TMPDIR}/install-mbr"
	PROG_MKVFATFS="${TMPDIR}/mkfs.vfat"
    #======================
    # A voir: a quoi le usb_inst correspond-il?
	# Ca ne peut pas fonctionner... dans usb_inst, on a des programmes statiques il me semble...
    PROG_MKNTFS="${LOCATION}/usb_inst/mkfs.ntfs"
    PROG_MKEXT3="${LOCATION}/usb_inst/mkfs.ext3"
    PROG_FDISK="${LOCATION}/usb_inst/fdisk"
	# Les progs ci-dessus n'y sont pas
    PROG_MKNTFS="$(which mkfs.ntfs)"
    PROG_MKEXT3="$(which mkfs.ext3)"
    PROG_FDISK="$(which fdisk)"
    #======================
	PROG_SYSLINUX="${TMPDIR}/syslinux"
	PROG_DIALOG="${TMPDIR}/dialog"
	# syslinux requires mtools
	ln -s mtools ${TMPDIR}/mcopy
	ln -s mtools ${TMPDIR}/mmove
	ln -s mtools ${TMPDIR}/mattrib
	export PATH=${TMPDIR}:${PATH}
else
	echo "Initialisation des chemins par defaut des programmes via 'which TEL_PROG'"

	LOCATION="/livemnt/boot"
	PROG_PARTED="$(which parted)"
	PROG_INSTMBR="$(which install-mbr)"
	PROG_MKVFATFS="$(which mkfs.vfat)"
    PROG_MKNTFS="$(which mkfs.ntfs)"
    PROG_MKEXT3="$(which mkfs.ext3)"
    PROG_FDISK="$(which fdisk)"
	PROG_SYSLINUX="$(which syslinux)"
	PROG_DIALOG="$(which dialog)"

	#echo "\$0=$0"
	if [ "$0" = "/bin/install_sysrescd_usb.sh" ]; then
		#echo "Lance depuis /bin/install_sysrescd_usb.sh"
		if [ -e "$LOCATION/usb_inst" ]; then
			echo "$LOCATION/usb_inst existe"

			PROGLOC=$LOCATION

			RUN_FROM_ISOROOT='1'

			echo "Utilisation des programmes copies vers ${TMPDIR}"

			# copy programs to a temp dir on the disk since exec from cdrom may fail
			cleanup_tmpdir
			mkdir -p ${TMPDIR} || die "Impossible de creer le dossier temporaire: ${TMPDIR}"
			if ! cp -r ${PROGLOC}/usb_inst/* ${TMPDIR}/
			then
				rm -rf ${TMPDIR} 2>/dev/null
				die "Impossible de copier les programmes vers le dossier temporaire: ${TMPDIR}"
			else
				chmod 777 ${TMPDIR}/*
			fi
			LOCATION="${PROGLOC}"
			# programs directly used by this script
			PROG_PARTED="${TMPDIR}/parted"
			PROG_INSTMBR="${TMPDIR}/install-mbr"
			PROG_MKVFATFS="${TMPDIR}/mkfs.vfat"
			#======================
			# A voir: a quoi le usb_inst correspond-il?
			# Ca ne peut pas fonctionner... dans usb_inst, on a des programmes statiques il me semble...
			#PROG_MKNTFS="${LOCATION}/usb_inst/mkfs.ntfs"
			#PROG_MKEXT3="${LOCATION}/usb_inst/mkfs.ext3"
			#PROG_FDISK="${LOCATION}/usb_inst/fdisk"
			# Les progs ci-dessus n'y sont pas
			#PROG_MKNTFS="$(which mkfs.ntfs)"
			#PROG_MKEXT3="$(which mkfs.ext3)"
			#PROG_FDISK="$(which fdisk)"
			#======================
			PROG_SYSLINUX="${TMPDIR}/syslinux"
			PROG_DIALOG="${TMPDIR}/dialog"
			# syslinux requires mtools
			ln -s mtools ${TMPDIR}/mcopy
			ln -s mtools ${TMPDIR}/mmove
			ln -s mtools ${TMPDIR}/mattrib
			export PATH=${TMPDIR}:${PATH}

		else
			echo "ANOMALIE ?"
			echo "usb_inst non trouve dans $LOCATION"
		fi
	fi
fi

#sleep 5

if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
	usage
	exit 1
fi

if [ "$(whoami)" != "root" ]
then
	help_readman "$0: Ce script necessite des droits root pour fonctionner."
fi

if [ -z "${RUN_FROM_ISOROOT}" ] && ! cat /proc/mounts | awk '{print $2}' | grep -q -F '/memory'
then
	help_readman "$0: Ce script doit etre ececute depuis SystemRescueCd."
	exit 1
fi

if [ -n "${RUN_FROM_ISOROOT}" ] && [ -z "${1}" ]
then
    COMMAND='dialog'
else
    COMMAND="${1}"
    shift
fi

## MAIN SHELL FUNCTION
########################################################

#COMMAND="${1}"
#shift
case "${COMMAND}" in
	listdev)
		do_listdev
		exit 0
		;;
	writembr)
		do_writembr "$@"
		exit 0
		;;
	format)
		do_format "$@"
		exit 0
		;;
	copyfiles)
		do_copyfiles "$@"
		exit 0
		;;
	syslinux)
		do_syslinux "$@"
		exit 0
		;;
	dialog)
		do_dialog "$@"
		;;
	lib)
		#echo "Chargement de '$0'"
		# On n'obtient pas la bonne info
		# C'est le progamme appelant my_sysresccd-usbstick.sh qui apparait
		echo -e "${COLTXT}Chargement de '${COLINFO}/bin/my_sysresccd-usbstick.sh${COLTXT}'"
		;;
	*)
		usage 
		exit 1
		;;
esac
#exit 0

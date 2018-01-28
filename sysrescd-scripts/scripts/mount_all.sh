#!/bin/bash

# Script de montage de toutes les partitions trouvées
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 26/02/2013

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "************************************"
echo "* Montage de toutes les partitions *"
echo "************************************"
#echo ""

echo -e "$COLCMD"
sfdisk -g|cut -d":" -f1|while read A
do
	#fdisk -l $A|grep "^$A" | tr "\t" " " | sed -e "s/ \{2,\}/ /g" | sed -e "s|^/dev/||" | cut -d" " -f1 | while read part

	if [ -e "/tmp/debug.txt" ]; then
		echo "Disque courant: $A"
	fi

	LISTE_PART ${A} avec_tableau_liste=y

	if [ -e "/tmp/debug.txt" ]; then
		cat /tmp/liste_part_extraite_par_LISTE_PART.txt
	fi

	cat /tmp/liste_part_extraite_par_LISTE_PART.txt | while read tmp_part
	do
		part=$(echo $tmp_part|sed -e "s|^/dev/||")

		if [ -e "/tmp/debug.txt" ]; then
			echo "part=$part"
		fi

		type_part=$(TYPE_PART /dev/$part)
		if [ -e "/tmp/debug.txt" ]; then
			echo "type_part=$type_part"
		fi

		if ! mount | grep -q "^/mnt/$part "; then
			case $type_part in
				"vfat")
					echo -e "$COLTXT"
					echo "Montage de la partition /dev/$part (vfat)"
					echo -e "$COLCMD\c"
					mkdir -p /mnt/$part
					mount -t vfat /dev/$part /mnt/$part
				;;
				"ntfs")
					echo -e "$COLTXT"
					echo "Montage de la partition /dev/$part (ntfs)"
					echo -e "$COLCMD\c"
					mkdir -p /mnt/$part
					ntfs-3g /dev/$part /mnt/$part
				;;
				"ext2")
					echo -e "$COLTXT"
					echo "Montage de la partition /dev/$part (ext2)"
					echo -e "$COLCMD\c"
					mkdir -p /mnt/$part
					mount /dev/$part /mnt/$part
				;;
				"ext3")
					echo -e "$COLTXT"
					echo "Montage de la partition /dev/$part (ext3)"
					echo -e "$COLCMD\c"
					mkdir -p /mnt/$part
					mount /dev/$part /mnt/$part
				;;
				"xfs")
					echo -e "$COLTXT"
					echo "Montage de la partition /dev/$part (xfs)"
					echo -e "$COLCMD\c"
					mkdir -p /mnt/$part
					mount -t xfs /dev/$part /mnt/$part
				;;
				*)
				;;
			esac
		fi
		if [ -e "/tmp/debug.txt" ]; then
			echo "================================"
		fi
	done
done

echo -e "$COLTXT"
echo "Liste des partitions montees:"
echo -e "$COLCMD\c"
mount | grep /mnt | egrep -v "(${mnt_cdrom}|/mnt/livecd|/mnt/memory)"

echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour quitter..."
read PAUSE

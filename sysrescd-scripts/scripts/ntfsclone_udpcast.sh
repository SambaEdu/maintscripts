#!/bin/bash

# Auteur: Stephane Boireau
# Derniere modification: 22/09/2017

source /bin/crob_fonctions.sh

doss_web="/livemnt/tftpmem"

# A FAIRE: Permettre de lancer le script sans que tous les parametres viennent de /proc/cmdline

echo -e "$COLTITRE"
echo "*******************************************************"
echo "* Clonage de partition NTFS avec Ntfsclone et Udpcast *"
echo "*******************************************************"

ECHO_DEBUG() {
	if [ "$debug" = "y" ]; then
		echo "$1"
	fi
}

rapport=/tmp/rapport_clonage_$(date +%Y%m%d_%H%M%S).txt

echo -e "$COLCMD\c"
if mount | grep ${mnt_cdrom} > /dev/null; then
	grep docache /proc/cmdline > /dev/null
	if [ $? -eq 1 ]; then
		# Il n'est pas possible d'ejecter le CD.
		ejection_cd="n"
	else
		echo -e "$COLTXT"
		echo "Demontage et ejection du CD."
		echo -e "$COLCMD\c"
		umount ${mnt_cdrom}
		eject
	fi
fi

# Pour des tests, il est possible de modifier un fichier de parametres sur le modele de celui obtenu normalement via /proc/cmdline
fich_cmdline=$(echo "$*"|sed -e "s| |\n|g"|grep "cmdline="|cut -d"=" -f2)
if [ -z "$fich_cmdline" ]; then
	# Pour eliminer les options ar_nowait,... qui ne permettent pas de définir des variables
	cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
	#source /tmp/tmp_proc_cmdline.txt
	#. /tmp/tmp_proc_cmdline.txt
	fich_cmdline=/tmp/tmp_proc_cmdline.txt
fi
. ${fich_cmdline}

# Pour relancer le script en modifiant des parametres, par exemple le nombre min_receivers
# Copier, editer et modifier:
#     cp /tmp/tmp_proc_cmdline.txt /tmp/param.txt
#     vi /tmp/param.txt
#     ntfsclone_udpcast.sh param=/tmp/param.txt
if echo "$*"|grep -q " param="; then
	fich_param=$(echo "$*"|sed -e "s| |\n|g"|grep "param="|cut -d"=" -f2)
	if [ -n "$fich_param" -a -e "$fich_param" ]; then
		chmod +x $fich_param
		. $fich_param
	fi
fi

if [ -n "$url_authorized_keys" ]; then
	echo -e "$COLTXT"
	echo "Telechargement de $url_authorized_keys"
	echo -e "$COLCMD"
	cd /tmp
	wget --tries=3 -O authorized_keys $url_authorized_keys
	if [ "$?" = "0" ]; then
		mkdir -p /root/.ssh
		chmod 700 /root/.ssh
		mv authorized_keys /root/.ssh/
		#/etc/init.d/sshd start
		/etc/init.d/sshd_crob start
	fi
fi

# Pour relever la duree de clonage et la remonter vers remontee_udpcast.php
date "+%s" > /tmp/debut_udpcast
# Pour afficher a l'ecran:
datedebut=`date "+%Y-%m-%d %H:%M:%S"`
echo "Debut: $datedebut" > /tmp/dates_udpcast.txt

# Decommenter pour afficher des messages de debug
#debug="y"
# Sinon, la variable peut etre recuperee de /proc/cmdline


#================================================
# Notes sur le dispositif SE3 action_clone
#append initrd=udprd root=01:00 persoparams=oui lang=FR kbmap=FR dhcp=yes compr=$compr port=$port umode=rcv disk=$disk auto_reboot=$auto_reboot enableDiskmodule=$enableDiskmodule diskmodule=$diskmodule netmodule=$netmodule remontee_info=y page_remontee=${urlse3}/tftp/remontee_udpcast.php mac=$mac num_op=${num_op} udpcparam=$udpcparam
#udpcparam=--min-receivers=1

# $udpcparam="--max-wait=".$sec_max_wait." --min-receivers=".$min_receivers;

#$resultat=exec("/usr/bin/sudo $chemin/pxe_gen_cfg.sh 'udpcast_recepteur' '$corrige_mac' '$ip_machine' '$nom_machine' '$compr' '$port' '$enableDiskmodule' '$diskmodule' '$netmodule' '$disk' '$auto_reboot' '$udpcparam' '$urlse3' '$num_op' '$dhcp' '$dhcp_iface'", $retour);
#$udpcparam="--start-timeout=".$sec_start_timeout;

#$resultat.=exec("/usr/bin/sudo $chemin/pxe_gen_cfg.sh 'udpcast_emetteur' '$corrige_mac' '$ip_machine' '$nom_machine' '$compr' '$port' '$enableDiskmodule' '$diskmodule' '$netmodule' '$disk' '$auto_reboot' '$udpcparam' '$urlse3' '$num_op' '$dhcp' '$dhcp_iface'", $retour);
#================================================

############################################"
############################################"
# A FAIRE: Si on a passe 
#append initrd=udprd root=01:00 persoparams=oui lang=FR kbmap=FR dhcp=no ip=$ip netmask=$netmask compr=$compr port=$port umode=snd disk=$disk auto_reboot=$auto_reboot enableDiskmodule=$enableDiskmodule diskmodule=$diskmodule netmodule=$netmodule remontee_info=y page_remontee=${urlse3}/tftp/remontee_udpcast.php mac=$mac num_op=${num_op} udpcparam=\"$udpcparam\"
# on a ip et netmask... pour faire la config reseau? si la connexion n'est pas franche en mode dhcp? tentative de renouveler l'ip pendant le clonage?
############################################"
############################################"

#================================================
# Emetteur ou recepteur
if [ "$umode" = "rcv" ]; then
	MODE=2
else
	if [ "$umode" = "snd" ]; then
		MODE=1
	else
		MODE=""
	fi
fi

while [ "$MODE" != "1" -a "$MODE" != "2" ]
do
	echo -e "$COLTXT"
	echo -e "Le poste est-il le modele (emetteur) (${COLCHOIX}1${COLTXT})"
	echo -e "ou un clone (recepteur) (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
	read MODE

	if [ -z "$MODE" ]; then
		MODE="2"
	fi
done
#================================================
# Port
PORT=""
if [ -n "$port" ]; then
	t=$(echo "$port" | sed -e "s|[0-9]||g")
	if [ -z "$t" ]; then
		PORT=$port
	fi
fi

if [ -z "$PORT" ]; then
	#PORT=""
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel port souhaitez-vous utiliser? [${COLDEFAUT}9002${COLTXT}] $COLSAISIE\c"
		read PORT

		if [ -z "$PORT" ]; then
			PORT=9002
		fi

		echo -e "${COLTXT}"
		echo -e "Vous avez choisi le port ${COLINFO}${PORT}"

		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done
fi
#================================================
# Interface
# La recuperation de l'interface a utiliser risque de planter dans le cas du reseau wifi
# A VERIFIER: Dans la ligne de commande /proc/cmdline, on pourrait passer l'ip du poste puisque genere par pxe_gen_cfg.sh qui recoit l'info pour generer un /tftpboot/pxelinux.cfg/01-<MAC> avec des infos precises (destinees au menage sur le serveur une fois le boot effectue, l'option pxe servie)

GET_INTERFACE_DEFAUT
if [ -e /tmp/iface.txt ]; then
	INTERFACE=$(cat /tmp/iface.txt)
else
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		INTERFACE=""
		echo -e "$COLTXT"
		echo -e "Quelle interface souhaitez-vous utiliser? [${COLDEFAUT}eth0${COLTXT}] $COLSAISIE\c"
		read INTERFACE

		if [ -z "$INTERFACE" ]; then
			INTERFACE="eth0"
		fi

		echo -e "${COLTXT}"
		echo -e "Vous avez choisi l'interface ${COLINFO}${INTERFACE}"

		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done
fi

#================================================
# On peut passer ip et netmask par /proc/cmdline
if [ -n "$ip" -a -n "$netmask" ]; then
	IP=$ip
	MASK=$netmask
fi

if [ -n "$IP" -a -n "$MASK" ]; then
	NETWORK=$(calcule_reseau $IP $MASK)
	BROADCAST=$(calcule_broadcast $IP $MASK)

	/etc/init.d/NetworkManager stop
	sleep 1

	$ifconfig ${iface} ${IP} broadcast ${BROADCAST} netmask ${MASK}
	echo "iface_eth0=\"${IP} broadcast ${BROADCAST} netmask ${MASK}\"" >> /etc/conf.d/net

	if [ -n "$GW" ]; then
		if [ -e /sbin/route ]; then
			/sbin/route add default gw ${GW} dev ${iface} netmask 0.0.0.0 metric 1
		else
			/bin/route add default gw ${GW} dev ${iface} netmask 0.0.0.0 metric 1
		fi
	    echo "gateway=\"${iface}/${GW}\"" >> /etc/conf.d/net
	fi

	if [ -n "$DNS" ]; then
		echo "nameserver $DNS" > /etc/resolv.conf
		echo "# Free
#nameserver 212.27.54.252
#nameserver 212.27.53.252

# Wanadoo:
#nameserver 193.252.19.3
#nameserver 193.252.19.4
" >> /etc/resolv.conf
	fi
fi

echo -e "$COLTXT"
echo "La config reseau est faite."

#================================================
# Compression
if [ "$compr" = "lzop" -o "$compr" = "gzip" -o "$compr" = "none" -o "$compr" = "pbzip2" ]; then
	COMPRESSION=$compr
else
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		COMPRESSION=""
		COMPR=""
		while [ "$COMPR" != "1" -a "$COMPR" != "2" -a "$COMPR" != "3" ]
		do
			COMPR=""
			echo -e "$COLINFO"
			echo -e "Vous pouvez compresser avant d'emettre et"
			echo -e "decompresser sur le recepteur pour reduire le trafic reseau."
			echo -e "$COLTXT"
			echo -e "Les modes sont les suivants:"
			echo -e " (${COLCHOIX}1${COLTXT}) lzop (1 processeur ou + si gigabit)"
			echo -e " (${COLCHOIX}2${COLTXT}) gzip (2 processeurs mini, 100M) "
			echo -e " (${COLCHOIX}3${COLTXT}) bzip2 (4 processeurs mini, ou reseau lent) "
			echo -e " (${COLCHOIX}4${COLTXT}) aucune compression (deconseille sauf SSD et gigabit)"
	
			echo -e "$COLTXT"
			echo -e "Quel mode de compression souhaitez-vous? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
			read COMPR
	
			if [ -z "$COMPR" ]; then
				COMPR="1"
			fi
		done

		case $COMPR in 
			"1")
				COMPRESSION="lzop"
				echo -e "${COLTXT}Vous avez choisi la compression ${COLINFO}${COMPRESSION}"
				;;
			"2")
				COMPRESSION="gzip"
				echo -e "${COLTXT}Vous avez choisi la compression ${COLINFO}${COMPRESSION}"
				;;
			"3")
				COMPRESSION="pbzip2"
				echo -e "${COLTXT}Vous avez choisi la compression ${COLINFO}${COMPRESSION}"
				;;
			"4")
				COMPRESSION="none"
				echo -e "${COLTXT}Vous avez choisi de ne pas compresser"
				;;
		esac

		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done
fi

echo -e "$COLTXT"
echo "Le format de compression est defini: $COMPRESSION."

#================================================

#append initrd=udprd root=01:00 persoparams=oui lang=FR kbmap=FR dhcp=yes compr=$compr port=$port umode=rcv disk=$disk auto_reboot=$auto_reboot enableDiskmodule=$enableDiskmodule diskmodule=$diskmodule netmodule=$netmodule remontee_info=y page_remontee=${urlse3}/tftp/remontee_udpcast.php mac=$mac num_op=${num_op} udpcparam=$udpcparam
#udpcparam=--min-receivers=1
#================================================
#================================================

POURSUIVRE_CLONAGE="y"

instant_0=$(date +%s)
ECHO_DEBUG "instant_0=$instant_0"

# Parametres pour l'emetteur
min_wait=$(echo $udpcparam | sed -e "s| |\n|g"|grep '\-\-min\-wait' | cut -d"=" -f2)
max_wait=$(echo $udpcparam | sed -e "s| |\n|g"|grep '\-\-max\-wait' | cut -d"=" -f2)
min_receivers=$(echo $udpcparam | sed -e "s| |\n|g"|grep '\-\-min\-receivers' | cut -d"=" -f2)

# Parametres pour le recepteur
start_timeout=$(echo $udpcparam | sed -e "s| |\n|g"|grep '\-\-start\-timeout' | cut -d"=" -f2)

start_timeout=$(echo $udpcparam | sed -e "s| |\n|g"|grep '\-\-start\-timeout' | cut -d"=" -f2)

# 20130213
seven_test_taille_part=$(echo $udpcparam | sed -e "s| |\n|g"|grep 'seven_test_taille_part' | cut -d"=" -f2)
if [ -z "$seven_test_taille_part" ]; then
	seven_test_taille_part=3000
fi

date > $rapport
if [ -n "$pc" ]; then
	echo "pc=$pc">>$rapport
fi
cat /proc/cmdline>>$rapport
echo "MODE=$MODE">>$rapport

# Preparation
if [ "$MODE" = "1" ]; then
	# Serveur
	echo -e "$COLTXT"
	echo "Poste emetteur..."

	#================================================
	# Disque ou partition a cloner
	if [ "$disk" = "auto" -o -z "$disk" ]; then
		disk=$(GET_DEFAULT_DISK)
		#liste_tmp=($(fdisk -l /dev/$disk | grep "^/dev/$disk" | tr "\t" " " | egrep "(HPFS/NTFS$|HPFS/NTFS/exFAT$)" | cut -d" " -f1))
		LISTE_PART ${disk} avec_tableau_liste=y type_part_cherche=ntfs
		if [ ! -z "${liste_tmp[0]}" ]; then
			disk=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
		else
			# Il faudra choisir manuellement la partition
			disk=""
		fi
	fi

	# Pour restaurer le début du disque, meme s'il n'y a pas de modification de la table de partitions
	restaurer_5Mo_debut_disque="n"
	plusieurs_part_a_cloner="n"
	if [ -n "$disk" ]; then
		# Tester si on a plusieurs partitions a cloner...
		t=$(echo "$disk" | grep "_")
		if [ -n "$t" -a "$disk" != "seven64_linux" ]; then
			plusieurs_part_a_cloner="y"

			DISK=$(echo "$disk" | sed -e "s/_.*//")
			# 20130903
			# Est-ce qu'il ne faudrait pas:
			#DISK=$(echo "$disk" | sed -e "s/[0-9]*_.*//")
			# Non, on fait plus loin:HD=$(echo "$DISK" | sed -e "s|[0-9]||g")
			FICHIER="/dev/$DISK"

			#PART=$DISK
			PART=$disk

		elif [ "$disk" = "seven64" ]; then
			# On ne clone que les partitions ntfs
			# PROBLEME: Si la partition de boot est une partition vfat, elle ne va pas etre clonee
			plusieurs_part_a_cloner="y"
			DISK="sda"
			FICHIER="/dev/sda"
			# 20130903
			LISTE_PART ${DISK} avec_tableau_liste=y type_part_cherche=ntfs
			if [ ! -z "${liste_tmp[0]}" ]; then
				if [ -n "$chaine_liste_tmp_part" ]; then
					PART=$(echo "$chaine_liste_tmp_part"|sed -e "s|/dev/||g")
				else
					PART="sda1_sda2"
				fi
			else
				PART="sda1_sda2"
			fi

			restaurer_5Mo_debut_disque="y"
		elif [ "$disk" = "seven64_linux" ]; then
			# On ne clone pas que les partitions systeme et boot seven, mais aussi la ou les partitions linux, vfat,... supplementaires
			plusieurs_part_a_cloner="y"
			DISK="sda"
			FICHIER="/dev/sda"
			LISTE_PART ${DISK} avec_tableau_liste=y
			if [ ! -z "${liste_tmp[0]}" ]; then
				if [ -n "$chaine_liste_tmp_part" ]; then
					PART=$(echo "$chaine_liste_tmp_part"|sed -e "s|/dev/||g")
				else
					PART="sda1_sda2"
				fi
			else
				PART="sda1_sda2"
			fi

			restaurer_5Mo_debut_disque="y"
		else
			t=$(sfdisk -g 2>/dev/null|grep "^/dev/$disk:")
			if [ -n "$t" ]; then
				# On a un disque et non une partition
				# Il faut recuperer la partition...
				#liste_tmp=($(fdisk -l /dev/$disk | grep "^/dev/$disk" | tr "\t" " " | egrep "(HPFS/NTFS$|HPFS/NTFS/exFAT$)" | cut -d" " -f1))
				LISTE_PART ${disk} avec_tableau_liste=y type_part_cherche=ntfs
				if [ ! -z "${liste_tmp[0]}" ]; then
					disk=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")


					# Taille $seven_test_taille_part en MB destinee a ne pas cloner la petite partition presente en debut de disque avec certaines install seven
					if [ -n "$seven_test_taille_part" ]; then
						taille_part=$(fdisk -s /dev/$disk)
						taille_part=$(($taille_part/1024))
						if [ $taille_part -lt $seven_test_taille_part ]; then
							#liste_tmp=($(fdisk -l /dev/$disk | grep "^/dev/$disk" | tr "\t" " " | egrep "(HPFS/NTFS$|HPFS/NTFS/exFAT$)" | cut -d" " -f1))
							LISTE_PART ${disk} avec_tableau_liste=y type_part_cherche=ntfs
							cpt=0
							disk=""
							while [ $cpt -lt ${#liste_tmp[*]} ]
							do
								taille_part=$(fdisk -s ${liste_tmp[$cpt]})
								taille_part=$(($taille_part/1024))
								if [ $taille_part -ge $seven_test_taille_part ]; then
									disk=$(echo ${liste_tmp[$cpt]} | sed -e "s|^/dev/||")
									break
								fi
								cpt=$((cpt+1))
							done
						fi
					fi


				else
					# Il faudra choisir manuellement la partition
					disk=""
				fi
			fi

			DISK=$disk
			FICHIER="/dev/$DISK"

			PART=$DISK
		fi
	else
		DISK=$disk
		FICHIER="/dev/$DISK"

		PART=$DISK
	fi

	#DISK=$disk
	#FICHIER="/dev/$DISK"

	#PART=$DISK

	echo "DISK=$DISK">>$rapport
	echo "PART=$PART">>$rapport

	if ! fdisk -s /dev/$DISK > /dev/null 2>&1; then
		echo -e "$COLERREUR\c"
		echo "ERREUR: Le disque propose n'existe pas!"
	
		echo -e "$COLTXT"
		echo "Vous allez devoir indiquer manuellement la partition a cloner:"
		echo " 'hda', 'sda1',..."
		
		AFFICHHD
		
		DEFAULTDISK=$(GET_DEFAULT_DISK)
		
		DISK=""
		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do
			echo -e "$COLTXT"
			echo -e "Sur quel disque se trouve la partition a cloner? [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
			read DISK
		
			if [ -z "$DISK" ]; then
				DISK=${DEFAULTDISK}
			fi
		
			if ! fdisk -s /dev/$DISK > /dev/null 2>&1; then
				echo -e "$COLERREUR\c"
				echo "ERREUR: Le disque propose n'existe pas!"
				REPONSE="2"
			else
				echo -e "$COLTXT"
				echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
				read REPONSE
		
				if [ -z "$REPONSE" ]; then
					REPONSE="1"
				fi
			fi
		done

		echo -e "$COLTXT"
		echo "Voici les partitions presentes sur le disque /dev/$DISK"
		echo -e "$COLCMD\c"
		#fdisk -l /dev/$DISK
		LISTE_PART ${DISK} afficher_liste=y

		REPONSE=""
		while [ "$REPONSE" != "1" ]
		do

			#liste_tmp=($(fdisk -l /dev/$DISK | grep "^/dev/$DISK" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | grep -v "Hidden" | grep -v "Dell Utility" | cut -d" " -f1))
			LISTE_PART ${DISK} avec_tableau_liste=y
			if [ ! -z "${liste_tmp[0]}" ]; then
				DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
			else
				DEFAULTPART="${DISK}1"
			fi

			PART=""
			echo -e "$COLTXT"
			echo -e "Quelle partition souhaitez-vous cloner? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
			read PART

			if [ -z "$PART" ]; then
				PART=$DEFAULTPART
			fi

			echo -e "${COLTXT}"
			echo -e "Vous avez choisi /dev/${COLINFO}${PART}"

			if ! fdisk -s /dev/$PART > /dev/null 2>&1; then
				echo -e "$COLERREUR\c"
				echo "ERREUR: La partition proposee n'existe pas!"
				REPONSE="2"
			else
				echo -e "$COLTXT"
				echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}) ou voulez-vous corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
				read REPONSE

				if [ -z "$REPONSE" ]; then
					REPONSE="1"
				fi
			fi
		done

		#FICHIER=$PART
		FICHIER="/dev/$PART"
	fi

	# PB: Si la machine a cloner est en RAID,...
	echo -e "$COLTXT"
	echo -e "Mise a disposition de la table de partition de ${COLINFO}$DISK"
	echo -e "$COLCMD"
	HD=$(echo "$DISK" | sed -e "s|[0-9]||g")

	echo "HD=$HD">>$rapport

	fdisk -l /dev/$HD > /tmp/fdisk_l_${HD}.txt 2>&1
	#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD}.txt|cut -d"'" -f2)

	if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
		TMP_disque_en_GPT=/dev/${HD}
	else
		TMP_disque_en_GPT=""
	fi

	if [ -z "$TMP_disque_en_GPT" ]; then
		sfdisk -d /dev/$HD > ${doss_web}/$HD.out
	else
		sgdisk -b ${doss_web}/gpt_$HD.out /dev/$HD
	fi

	if [ "$?" != "0" ]; then
		rm -f ${doss_web}/$HD.out ${doss_web}/gpt_$HD.out
		echo -e "$COLERREUR"
		echo "Il s'est produit une erreur lors du dump de la table de partitions."|tee -a $rapport
		echo "On ne poursuit pas."|tee -a $rapport

		POURSUIVRE_CLONAGE="n"

		# VOIR COMMENT signaler le pb... via remontee_udpcast.php

	else
		#dd if="/dev/${HD}" of="${doss_web}/${HD}.bin" bs=1M count=5
		echo -e "dd if=/dev/${HD} of=${doss_web}/${HD}.bin bs=5M count=1"|tee -a $rapport
		dd if="/dev/${HD}" of="${doss_web}/${HD}.bin" bs=5M count=1
		if [ "$?" != "0" ]; then
			rm ${doss_web}/$HD.bin
			echo -e "$COLERREUR"
			echo "Il s'est produit une erreur lors du dump des 5 premiers Mo du disque."|tee -a $rapport
			echo "On ne poursuit pas."|tee -a $rapport

			POURSUIVRE_CLONAGE="n"

			# VOIR COMMENT signaler le pb... via remontee_udpcast.php

		else
			#echo $PART > ${doss_web}/partition_a_cloner.txt
			#echo $PART | sed -e "s/_/\n/g" > ${doss_web}/partition_a_cloner.txt

			echo -e "Dump du debut des partitions de ${COLINFO}$DISK"|tee -a $rapport

			rm -f ${doss_web}/partition_a_cloner.txt
			echo $PART | sed -e "s/_/\n/g" | while read PARTITION
			do
				echo -e "Dump de ${PARTITION}"|tee -a $rapport
				#dd if="/dev/${PARTITION}" of="${doss_web}/${PARTITION}.bin" bs=1M count=5
				echo -e "dd if=/dev/${PARTITION} of=${doss_web}/${PARTITION}.bin bs=5M count=1"|tee -a $rapport
				dd if=/dev/${PARTITION} of=${doss_web}/${PARTITION}.bin bs=5M count=1

				echo "${PARTITION};$(TYPE_PART ${PARTITION})" >> ${doss_web}/partition_a_cloner.txt
			done

			echo "Les partitions a cloner seront:"|tee -a $rapport
			cat ${doss_web}/partition_a_cloner.txt|tee -a $rapport
			sleep 3

			# Test de reinstallation requise de GRUB ou LILO
			echo "aucun">${doss_web}/reinstallation_bootloader.txt
			t=$(head /dev/$HD | strings | grep "GRUB")
			if [ -n "$t" ]; then
				echo "grub">${doss_web}/reinstallation_bootloader.txt
			else
				t=$(head /dev/sda | strings | grep "LILO")
				if [ -n "$t" ]; then
					echo "lilo">${doss_web}/reinstallation_bootloader.txt
				fi
			fi

			echo "$restaurer_5Mo_debut_disque">${doss_web}/restaurer_5Mo_debut_disque.txt
		fi
	fi

	if [ "$POURSUIVRE_CLONAGE" = "y" ]; then
		liste_clients=/tmp/liste_clients.txt
		#wget -O ${liste_clients} http://${se3ip}/clonage/liste_clients_ntfsclone_udpcast_${num_op}.txt
		wget -O ${liste_clients} http://${se3ip}/clonage/liste_clients_ntfsclone_udpcast_${num_op}_${id_microtime}.txt > /dev/null 2>&1
		if [ "$?" != "0" ]; then
	
			# Signaler l'echec
			echo -e "$COLERREUR"
			echo -e "Erreur lors de la recuperation sur le serveur ${COLINFO}$se3ip${COLERREUR} de la liste des clients."
			#echo "wget ${page_remontee}?debut=${debut}\&fin=${fin}\&succes=${succes}\&mac=${mac}\&num_op=${num_op}\&umode=${umode}"
			#wget ${page_remontee}?debut=${debut}\&fin=${fin}\&succes=${succes}\&mac=${mac}\&num_op=${num_op}\&umode=${umode}
	
			POURSUIVRE_CLONAGE="n"

			# VOIR COMMENT signaler le pb... via remontee_udpcast.php

			echo -e "$COLTXT"
			#exit
		fi

		if [ "$POURSUIVRE_CLONAGE" = "y" ]; then
			mv $liste_clients $liste_clients.tmp
			sort $liste_clients.tmp | uniq > $liste_clients
		
			echo -e "${COLTXT}"
			echo -e "Lancement de thttpd pour permettre une recuperation des fichiers temoin, sda.out,..."
			echo -e "${COLCMD}"
			/etc/init.d/thttpd start
		
			nb_clients=$(egrep -v "(^#|^$)" ${liste_clients} | wc -l)
	
			# Boucle test de presence des clients
			ABANDON="n"
			SUITE="n"
			while [ "$SUITE" != "y" -a "$ABANDON" != "y" ]
			do
				echo -e "$COLTXT"
				echo "Recherche des clients devant etre clones pour l'action numero ${num_op}..."
				#echo -e "$COLCMD"
				while read IP
				do
					#echo -e "$COLTXT"
					echo -e "${COLTXT}Client $IP : \c"
					#echo -e "$COLCMD"
					#wget --spider --tries=3 http://$IP/client_${num_op}_pret.txt
					wget --tries=1 http://$IP/client_${num_op}_pret.txt > /dev/null 2>&1
					if [ "$?" = "0" ]; then
						echo "OK" > /tmp/client_${num_op}_${IP}_pret.txt
						echo -e "${COLINFO}Present"
						t=$(grep "^$IP$" /tmp/liste_clients_pret_${num_op}.txt 2> /dev/null)
						if [ -z "$t" ]; then
							echo "$IP" >> /tmp/liste_clients_pret_${num_op}.txt
							echo "Client $IP pret.">>$rapport
						fi
					else
						echo -e "${COLERREUR}Absent"
					fi
				done < ${liste_clients}
		
				nb_clients_prets=$(ls /tmp/client_${num_op}_*_pret.txt 2> /dev/null | wc -l)
				echo -e "$COLTXT"
				echo "$nb_clients_prets client(s) pret(s)."
		
				if [ "$nb_clients_prets" = "$nb_clients" ]; then
					SUITE="y"
				else
					# A FAIRE: Renseigner la variable ABANDON d'apres le temps maxi autorise pour l'operation
					if [ -n "$max_wait" ]; then
						instant_courant=$(date +%s)
	
						ECHO_DEBUG "instant_courant=$instant_courant"

						t=$((${instant_courant}-${instant_0}))
	
						ECHO_DEBUG "t=\$((${instant_courant}-${instant_0}))=$t"
						ECHO_DEBUG "max_wait=$max_wait"

						echo "$t sec (ecoulees) / $max_wait sec (max_wait)"

						if [ $t -ge $max_wait ]; then
							if [ $nb_clients_prets -lt $min_receivers ]; then
								echo -e "${COLERREUR}ABANDON: Duree max d'attente ecoulee: $max_wait"
								echo -e "         et on n'a que $nb_clients_prets recepteurs prets"
								echo -e "         alors que le min demande est $min_receivers"
								ABANDON="y"
		
								ECHO_DEBUG "ABANDON=$ABANDON"
		
								POURSUIVRE_CLONAGE="n"
	
								# VOIR COMMENT signaler le pb... via remontee_udpcast.php
								succes="n"
							else
								# Le nombre min de recepteurs est atteint... on va cloner
								echo -e "${COLINFO}PIS-ALLER: Duree max d'attente ecoulee: $max_wait"
								echo -e "           mais le nombre min ($min_receivers) de recepteurs"
								echo -e "           est atteint ($nb_clients_prets), on va poursuivre le clonage."
								SUITE="y"
							fi
						else
							# On laisse tourner : Pas de duree max definie (lancement manuel?)
							echo ""
						fi
					fi
				fi
				echo "======================================="

				#sleep 3
				echo -e "$COLTXT"
				echo -e "Si un client fait defection, vous pouvez reduire la valeur de ${COLINFO}min_receivers${COLTXT}"
				echo -e "${COLTXT}qui actuellement vaut ${COLINFO}${min_receivers}${COLTXT}"
				echo -e "Vous avez ${COLINFO}5s${COLTXT} pour saisir une nouvelle valeur et valider."
				echo -e "Nombre minimum de clients: [${COLDEFAUT}${min_receivers}${COLTXT}] \c$COLSAISIE"
				read -t 5 tmp_min_receivers
				if [ -n "$tmp_min_receivers" ]; then
					t=$(echo "$tmp_min_receivers"|sed -e "s|[0-9]||g")
					if [ -z "$t" ]; then
						min_receivers=$tmp_min_receivers
						echo -e "Reduction du nombre de clients a attendre a: ${COLINFO}${min_receivers}${COLTXT}"
					fi
				fi
			done
		fi
	fi
else
	# Client
	timestamp_timeout=$(($instant_0+$start_timeout))

	echo -e "${COLTXT}"
	echo -e "Recherche de l'adresse du serveur ntfsclone/udp-sender...\n$instant_0 -> ..."
	echo -e "${COLCMD}"
	SUITE="n"
	while [ "$SUITE" != "y" -a "$ABANDON" != "y" ]
	do
		wget -O /tmp/serveur_ntfsclone_udpcast_${num_op}.txt http://${se3ip}/clonage/serveur_ntfsclone_udpcast_${num_op}_${id_microtime}.txt > /dev/null 2>&1
		if [ "$?" = "0" ]; then
			IP_SERVEUR=$(cat /tmp/serveur_ntfsclone_udpcast_${num_op}.txt)
			echo -e "$COLTXT"
			echo "Serveur trouve en $IP_SERVEUR"

			SUITE="y"

			echo "IP_SERVEUR=$IP_SERVEUR">>$rapport
		fi

		if [ -n "$start_timeout" ]; then
			instant_courant=$(date +%s)

			#echo -en "\r${instant_courant} / $timestamp_timeout"

			ECHO_DEBUG "instant_courant=$instant_courant"

			t=$((${instant_courant}-${instant_0}))

			ECHO_DEBUG "t=\$((${instant_courant}-${instant_0}))=$t"
			ECHO_DEBUG "start_timeout=$start_timeout"

			if [ $t -ge $start_timeout ]; then
				echo -e "$COLERREUR"
				echo "Abandon : Delais $start_timeout ecoule : Serveur non trouve."

				ABANDON="y"

				ECHO_DEBUG "ABANDON=$ABANDON"

				POURSUIVRE_CLONAGE="n"

				# VOIR COMMENT signaler le pb... via remontee_udpcast.php

				succes="n"
			else
				echo -en "\r${t} sec (ecoulees) / $start_timeout sec (start_timeout)"
			fi
		fi

		sleep 5
	done

	IP_SERVEUR=$(cat /tmp/serveur_ntfsclone_udpcast_${num_op}.txt)
	SUITE="n"
	while [ "$SUITE" != "y" -a "$ABANDON" != "y" ]
	do
		wget -O /tmp/partition_a_cloner.txt http://$IP_SERVEUR/partition_a_cloner.txt
		if [ "$?" = "0" ]; then
			SUITE="y"
			echo "Partitions a cloner:">>$rapport
			cat /tmp/partition_a_cloner.txt>>$rapport
		else
			# A FAIRE: Renseigner la variable ABANDON d'apres le temps maxi autorise pour l'operation
			if [ -n "$start_timeout" ]; then
				instant_courant=$(date +%s)

				ECHO_DEBUG "instant_courant=$instant_courant"

				t=$((${instant_courant}-${instant_0}))

				ECHO_DEBUG "t=\$((${instant_courant}-${instant_0}))=$t"
				ECHO_DEBUG "start_timeout=$start_timeout"

				if [ $t -ge $start_timeout ]; then
					ABANDON="y"

					ECHO_DEBUG "ABANDON=$ABANDON"

					POURSUIVRE_CLONAGE="n"
	
					# VOIR COMMENT signaler le pb... via remontee_udpcast.php

					succes="n"
				fi
			fi
		fi

		sleep 5
	done


	if [ "$ABANDON" != "y" ]; then
		#HD=$(cat /tmp/partition_a_cloner.txt | sed -e "s|[0-9]||g")
		#HD=$(cat /tmp/partition_a_cloner.txt | sed -e "s|[0-9]||g"|head -n1)
		HD=$(cat /tmp/partition_a_cloner.txt |head -n1|cut -d";" -f1| sed -e "s|[0-9]||g")

		echo "HD=$HD">>$rapport

		SUITE="n"
		while [ "$SUITE" != "y" -a "$ABANDON" != "y" ]
		do
			echo "Recuperation de la table de partitions..."|tee -a $rapport
			#wget -O /tmp/$HD.out http://$IP_SERVEUR/$HD.out > /dev/null 2>&1

			wget -O /tmp/${HD}.out http://$IP_SERVEUR/$HD.out > /dev/null 2>&1
			if [ -e /tmp/${HD}.out ]; then
				echo "/tmp/${HD}.out recupere"|tee -a $rapport
			fi

			wget -O /tmp/gpt_${HD}.out http://$IP_SERVEUR/gpt_$HD.out > /dev/null 2>&1
			if [ -e /tmp/gpt_${HD}.out ]; then
				echo "/tmp/gpt_${HD}.out recupere"|tee -a $rapport
			fi

			wget -O /tmp/${HD}.bin http://$IP_SERVEUR/$HD.bin > /dev/null 2>&1
			if [ -e /tmp/${HD}.bin ]; then
				echo "/tmp/${HD}.bin recupere"|tee -a $rapport
			fi

			wget -O /tmp/reinstallation_bootloader.txt http://$IP_SERVEUR/reinstallation_bootloader.txt > /dev/null 2>&1
			if [ -e /tmp/reinstallation_bootloader.txt ]; then
				echo -e "/tmp/reinstallation_bootloader.txt recupere avec pour bootloader a reinstaller:\c"|tee -a $rapport
				cat /tmp/reinstallation_bootloader.txt|tee -a $rapport
			fi

			wget -O /tmp/restaurer_5Mo_debut_disque.txt http://$IP_SERVEUR/restaurer_5Mo_debut_disque.txt > /dev/null 2>&1
			if [ -e /tmp/restaurer_5Mo_debut_disque.txt ]; then
				echo -e "/tmp/restaurer_5Mo_debut_disque.txt recupere avec contenu:\c"|tee -a $rapport
				cat /tmp/restaurer_5Mo_debut_disque.txt|tee -a $rapport
			fi

			while read LIGNE
			do
				PARTITION=$(echo "$LIGNE"|cut -d";" -f1)
				wget -O /tmp/$PARTITION.bin http://$IP_SERVEUR/$PARTITION.bin > /dev/null 2>&1
				if [ -e /tmp/$PARTITION.bin ]; then
					echo "/tmp/$PARTITION.bin recupere"|tee -a $rapport
				else
					echo "/tmp/$PARTITION.bin non trouve"|tee -a $rapport
				fi
			done < /tmp/partition_a_cloner.txt

			if [ "$?" = "0" ]; then
				# A REVOIR... on ne teste plus que le succes du dernier telechargement
				SUITE="y"
				echo "Contenu de /tmp">>$rapport
				ls /tmp/>>$rapport
			else
				# A FAIRE: Renseigner la variable ABANDON d'apres le temps maxi autorise pour l'operation
				if [ -n "$start_timeout" ]; then
					instant_courant=$(date +%s)

					ECHO_DEBUG "instant_courant=$instant_courant"

					t=$((${instant_courant}-${instant_0}))
	
					ECHO_DEBUG "t=\$((${instant_courant}-${instant_0}))=$t"
					ECHO_DEBUG "start_timeout=$start_timeout"
	
					if [ $t -ge $start_timeout ]; then
						ABANDON="y"

						ECHO_DEBUG "ABANDON=$ABANDON"
	
						POURSUIVRE_CLONAGE="n"

						# VOIR COMMENT signaler le pb... via remontee_udpcast.php

						succes="n"
					fi
				fi
			fi
	
			sleep 5
		done

		#FICHIER=/dev/$(cat /tmp/partition_a_cloner.txt)

		if [ "$ABANDON" != "y" ]; then

			restaurer_5Mo_debut_disque="n"
			if [ -e /tmp/restaurer_5Mo_debut_disque.txt ]; then
				restaurer_5Mo_debut_disque=$(cat /tmp/restaurer_5Mo_debut_disque.txt)
			fi
			echo "restaurer_5Mo_debut_disque=$restaurer_5Mo_debut_disque"|tee -a $rapport


			fdisk -l /dev/$HD > /tmp/fdisk_l_${HD}.txt 2>&1
			#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD}.txt|cut -d"'" -f2)

			#if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
			# Modif pour ne pas considerer qu'on est en GPT seulement si le recepteur est en GPT, mais seulement si l'emetteur est lui aussi en GPT
			if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
				if [ -e /tmp/gpt_${HD}.out ]; then
					TMP_disque_en_GPT=/dev/${HD}
				else
					TMP_disque_en_GPT=""
					# Le recepteur est en GPT, mais l'emetteur est en MSDOS
					echo -e "${COLTXT}"
					echo -e "On change la table de partition de gpt en msdos sur le disque $HD..."|tee -a $rapport
					echo -e "${COLCMD}"
					parted -s /dev/${HD} -- mklabel msdos
					#dd if=/dev/zero of=/dev/$HD bs=10M count=100
					sleep 3
					partprobe /dev/$HD
					sleep 3
				fi
			else
				TMP_disque_en_GPT=""
			fi

			if [ -z "$TMP_disque_en_GPT" ]; then
				sfdisk -d /dev/$HD > /tmp/${HD}_client.out
				t=$(diff /tmp/${HD}_client.out /tmp/${HD}.out)
			else
				sgdisk -b /tmp/gpt_${HD}_client.out /dev/$HD
				t=$(diff /tmp/gpt_${HD}_client.out /tmp/gpt_${HD}.out)
			fi

			if [ -n "$t" ]; then
				#echo -e "${COLTXT}"
				#echo -e "On refait la table de partition d'apres celle de l'emetteur..."
				#echo -e "${COLCMD}"
				#sfdisk /dev/$HD < /tmp/${HD}.out

				echo -e "${COLTXT}"
				echo -e "On ecrase le debut du disque $HD..."|tee -a $rapport
				echo -e "${COLCMD}"
				# A quoi sert ce premier dump?
				if [ -z "$TMP_disque_en_GPT" ]; then
					sfdisk -d /dev/$HD > /tmp/${HD}_client0.out
				else 
					sgdisk -b /tmp/${HD}_client0.out /dev/$HD
				fi
				#dd if="/tmp/${HD}.bin" of="/dev/${HD}" bs=1M count=5 
				echo "dd if=/tmp/${HD}.bin of=/dev/${HD} count=1">>$rapport
				dd if=/tmp/${HD}.bin of=/dev/${HD} count=1
				partprobe /dev/$HD
				if [ -z "$TMP_disque_en_GPT" ]; then
					sfdisk -d /dev/$HD > /tmp/${HD}_client.out
					t=$(diff /tmp/${HD}_client.out /tmp/${HD}.out)
				else 
					sgdisk -b /tmp/${HD}_client.out /dev/$HD
					t=$(diff /tmp/gpt_${HD}_client.out /tmp/gpt_${HD}.out)
				fi
				if [ -n "$t" ]; then
					if [ -z "$TMP_disque_en_GPT" ]; then
						sfdisk /dev/$HD < /tmp/${HD}.out

						if [ "$?" != "0" ]; then
							echo -e "${COLERREUR}"
							echo "Il s'est produit une erreur."
		
							echo -e "${COLTXT}"
							echo -e "Nouvelle tentative pour refaire la table de partition d'apres celle de l'emetteur..."
							echo -e "${COLCMD}"
							sfdisk -f /dev/$HD < /tmp/${HD}.out
		
							if [ "$?" != "0" ]; then
								echo -e "${COLERREUR}"
								echo "Pas moyen de refaire la table de partitions."
		
								POURSUIVRE_CLONAGE="n"

								# VOIR COMMENT signaler le pb... via remontee_udpcast.php

								succes="n"
		
								#exit
							fi
		
							echo -e "${COLTXT}"
							echo "PAUSE..."
							sleep 5
						fi
					else
						sgdisk -l /tmp/${HD}.out /dev/$HD

						if [ "$?" != "0" ]; then
							echo -e "${COLERREUR}"
							echo "Il s'est produit une erreur."
							echo "Pas moyen de refaire la table de partitions."
	
							POURSUIVRE_CLONAGE="n"
							# VOIR COMMENT signaler le pb... via remontee_udpcast.php
							succes="n"
							#exit
		
							echo -e "${COLTXT}"
							echo "PAUSE..."
							sleep 5
						fi
					fi
				fi

				echo -e "${COLTXT}"
				echo -e "On ecrase le debut de chaque partition..."|tee -a $rapport
				while read LIGNE
				do
					PARTITION=$(echo "$LIGNE"|cut -d";" -f1)
					if [ -e "/tmp/${PARTITION}.bin" ]; then
						echo -e "${COLTXT}\c"
						echo -e "Restauration du debut de $PARTITION"
						echo -e "${COLCMD}\c"
						#dd "if=/tmp/${PARTITION}.bin" of="/dev/${PARTITION}" bs=1M count=5
						echo "dd if=/tmp/${PARTITION}.bin of=/dev/${PARTITION} bs=5M count=1">>$rapport
						dd if=/tmp/${PARTITION}.bin of=/dev/${PARTITION} bs=5M count=1
					else
						echo -e "${COLINFO}\c"
						echo "Pas de ${PARTITION}.bin a restaurer."
					fi
				done < /tmp/partition_a_cloner.txt

			elif [ "$restaurer_5Mo_debut_disque" = "y" ]; then

				if [ ! -e "/tmp/${HD}.bin" ]; then
					echo -e "${COLERREUR}"
					echo -e "Le fichier /tmp/${HD}.bin est absent. On ne peut pas ecraser le debut du disque $HD..."|tee -a $rapport
					echo -e "${COLTXT}"
				else
					echo -e "${COLTXT}"
					echo -e "On ecrase le debut du disque $HD..."|tee -a $rapport
					echo -e "${COLCMD}"
					# A quoi sert ce premier dump?
					if [ -z "$TMP_disque_en_GPT" ]; then
						sfdisk -d /dev/$HD > /tmp/${HD}_client0.out
					else 
						sgdisk -b /tmp/${HD}_client0.out /dev/$HD
					fi
					#dd if="/tmp/${HD}.bin" of="/dev/${HD}" bs=1M count=5 
					echo "dd if=/tmp/${HD}.bin of=/dev/${HD} count=1">>$rapport
					dd if=/tmp/${HD}.bin of=/dev/${HD} count=1
					partprobe /dev/$HD
				fi
			fi
		fi
	fi

	if [ "$POURSUIVRE_CLONAGE" = "y" ]; then
		echo "Pret" > ${doss_web}/client_${num_op}_pret.txt
	fi

	echo -e "${COLTXT}"
	echo -e "Lancement de thttpd pour permettre une recuperation des fichiers temoin,..."|tee -a $rapport
	echo -e "${COLCMD}"
	/etc/init.d/thttpd start
fi





datedebut=`date "+%Y-%m-%d %H:%M:%S"`
echo "Debut: $datedebut" > /tmp/dates.txt

date "+%s" > /tmp/debut_udpcast.txt

if [ "$POURSUIVRE_CLONAGE" = "y" ]; then

	if [ "$MODE" = "1" ]; then
		echo -e "$COLINFO"
		echo "Emetteur:"
	
		#echo -e "$COLCMD\c"

		echo "Pret a emettre" > ${doss_web}/pret_a_emettre.txt
		echo -e "$COLTXT"
		echo "Emetteur pret a emettre"|tee -a $rapport
		if [ -n "$min_wait" ]; then
			instant_courant=$(date +%s)

			ECHO_DEBUG "instant_courant=$instant_courant"


			echo -e "$COLTXT"
			echo -e "Les clients sont prets.
Un temps minimum d'attente est defini: ${COLINFO}$min_wait${COLTXT}
Apres ce delai, le clonage va demarrer."
			echo -e "Vous avez ${COLINFO}5s${COLTXT} pour saisir une nouvelle valeur et valider."
			echo -e "Patienter (en secondes): [${COLDEFAUT}${min_wait}${COLTXT}] \c$COLSAISIE"
			read -t 5 tmp_min_wait
			if [ -n "$tmp_min_wait" ]; then
				t=$(echo "$tmp_min_wait"|sed -e "s|[0-9]||g")
				if [ -z "$t" ]; then
					min_wait=$tmp_min_wait
					echo -e "Reduction de la pause a: ${COLINFO}${min_wait}${COLTXT} secondes."
				fi
			fi


			t=$(($min_wait-$((${instant_courant}-${instant_0}))))

			ECHO_DEBUG "t=\$(($min_wait-\$((${instant_courant}-${instant_0}))))=$t"
			ECHO_DEBUG "min_wait=$min_wait"

			if [ $t -gt 0 ]; then
				COMPTE_A_REBOURS "Demarrage de l'emission dans " $t " secondes."
			else
				COMPTE_A_REBOURS "Demarrage de l'emission dans " 20 " secondes."
			fi
		else
			COMPTE_A_REBOURS "Demarrage de l'emission dans " 20 " secondes."
		fi

		port_courant=$PORT

		compteur_partitions=1
		#while read PART
		while read LIGNE
		do
			PART=$(echo "$LIGNE"|cut -d";" -f1)
			TYPE_PART=$(echo "$LIGNE"|cut -d";" -f2)
			FICHIER=/dev/$PART



			# 20140409 : Le clonage de la deuxieme partition a l'air de planter avec "No participant found"
			# Il faudrait relancer une boucle sur le test de presence des clients.

			# Pour le premier tour, la presence des clients a ete testee
			#if [ "$compteur_partitions" -gt 1 ]; then
				instant_0_partition_courante=$(date +%s)
				echo -e "$COLTXT"
				date >> $rapport
				echo "Verification, avant le clonage de $PART, de la presence des clients..."|tee -a $rapport

				instant_courant=$(date +%s)
				temps_ecoule_entre_partitions=$((${instant_courant}-${instant_0_partition_courante}))
				max_wait_entre_partitions=300
				nb_clients_prets=0
				while [ $nb_clients_prets -lt $nb_clients -a ${temps_ecoule_entre_partitions} -lt ${max_wait_entre_partitions} ]
				do

					while read IP
					do

						t=$(grep "^$IP$" /tmp/liste_clients_pret_${num_op}_partition_${PART}.txt 2> /dev/null)
						if [ -z "$t" ]; then
							echo -e "${COLTXT}Client $IP : \c"

							#wget --tries=1 http://$IP/client_${num_op}_pret.txt > /dev/null 2>&1
							ping -c1 -W1 $IP > /dev/null 2>&1
							if [ "$?" = "0" ]; then
								echo "OK" > /tmp/client_${num_op}_${IP}_pret_pour_clonage_partition_${PART}.txt
								echo -e "${COLINFO}Present"
								echo "$IP" >> /tmp/liste_clients_pret_${num_op}_partition_${PART}.txt
								echo "Client $IP pret.">>$rapport
							else
								echo -e "${COLERREUR}Absent"
							fi
						fi
					done < ${liste_clients}

					nb_clients_prets=$(ls /tmp/client_${num_op}_*_pret_pour_clonage_partition_${PART}.txt 2> /dev/null | wc -l)
					echo -e "$COLTXT"
					echo "$nb_clients_prets client(s) pret(s)."|tee -a $rapport

					instant_courant=$(date +%s)
					temps_ecoule_entre_partitions=$((${instant_courant}-${instant_0_partition_courante}))
				done
			#fi

			if [ -e "/tmp/udpsender.log" ]; then
				rm /tmp/udpsender.log
			fi

			if [ "$TYPE_PART" = "ntfs" ]; then
				if [ "$COMPRESSION" = "lzop" ]; then
					commande="ntfsclone --save-image -o - $FICHIER | udp-sender --portbase ${port_courant} --interface $INTERFACE --autostart 5 --pipe 'lzop -c -f -'"
				elif [ "$COMPRESSION" = "gzip" ]; then
					commande="ntfsclone --save-image -o - $FICHIER | udp-sender --portbase ${port_courant} --interface $INTERFACE --autostart 5 --pipe 'pigz -c -f -'"
				elif [ "$COMPRESSION" = "pbzip2" ]; then
					commande="ntfsclone --save-image -o - $FICHIER | udp-sender --portbase ${port_courant} --interface $INTERFACE --autostart 5 --pipe 'pbzip2 -1 -c -f -'"
				else 
					commande="ntfsclone --save-image -o - $FICHIER | udp-sender --portbase ${port_courant} --interface $INTERFACE --autostart 5"
				fi

				echo -e "$COLTXT"
				echo $commande|tee -a $rapport
				fichier_courant=/tmp/${cpt_boucle}_commande_emission_$(date "+%Y%m%d_%H%M%S").sh
				echo $commande>$fichier_courant
				chmod +x $fichier_courant
				echo -e "$COLCMD\c"
				#$commande|tee -a $rapport
				$fichier_courant|tee -a $rapport
			else

				#delai_autostart=30
				delai_autostart=120
				min_wait=60

				#--min-wait 20 --max-wait 80
				#--start-timeout
				#parametres_demarrage="--autostart ${delai_autostart}"
				#parametres_demarrage="--min-wait ${min_wait} --max-wait 3600 --start-timeout ${delai_autostart}"

				cpt_boucle=1
				REUSSI=""
				while [ -z "$REUSSI" ]
				do
					if [ "$COMPRESSION" = "lzop" ]; then
						commande="udp-sender --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --min-wait ${min_wait} --max-wait 3600 --start-timeout ${delai_autostart} --log /tmp/udpsender.log --pipe 'lzop -c -f -'"
					elif [ "$COMPRESSION" = "gzip" ]; then
						commande="udp-sender --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --min-wait ${min_wait} --max-wait 3600 --start-timeout ${delai_autostart} --log /tmp/udpsender.log --pipe 'gzip -c -f -'"
					elif [ "$COMPRESSION" = "pbzip2" ]; then
						commande="udp-sender --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --min-wait ${min_wait} --max-wait 3600 --start-timeout ${delai_autostart} --log /tmp/udpsender.log --pipe 'pbzip2 -1 -c -f -'"
					else
						echo "udp-sender --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --min-wait ${min_wait} --max-wait 3600 --start-timeout ${delai_autostart} --log /tmp/udpsender.log"
					fi

					echo -e "$COLTXT"
					echo $commande|tee -a $rapport
					fichier_courant=/tmp/${cpt_boucle}_commande_emission_$(date "+%Y%m%d_%H%M%S").sh
					echo $commande>$fichier_courant
					chmod +x $fichier_courant
					echo -e "$COLCMD\c"
					#$commande|tee -a $rapport
					$fichier_courant|tee -a $rapport

					if [ -e "/tmp/udpsender.log" ]; then
						t=$(grep "Transfer complete" /tmp/udpsender.log)
						if [ -n "$t" ]; then
							REUSSI="y"
						else
							echo -e "$COLERREUR"
							echo "Pas de chaine 'Transfer complete' trouvee dans le fichier de log genere."|tee -a $rapport
							echo "... nouvel essai dans 5s..."|tee -a $rapport
							sleep 5
						fi
					else
						echo -e "$COLERREUR"
						echo "Pas de fichier de log genere... nouvel essai dans 5s..."|tee -a $rapport
						sleep 5
					fi

					cpt_boucle=$((${cpt_boucle}+1))
				done
			fi

			if [ -e "/tmp/udpsender.log" ]; then
				echo "Rapport de l emission effectuee:">>$rapport
				cat /tmp/udpsender.log>>$rapport
			fi

			# Ce test ne correspond plus a rien... A REVOIR
			if [ "$?" != "0" ]; then
				echo -e "$COLERREUR"
				echo "Il semble qu'un probleme se soit produit."|tee -a $rapport
				echo "Le clonage pourrait bien avoir echoue pour une machine au moins."
				echo -e "$COLTXT"
				succes="n"
				read PAUSE
				#exit
			else
				succes="y"
			fi

			compteur_partitions=$((compteur_partitions+1))

			# Pause avant de lancer un eventuel clonage suivant
			echo -e "$COLTXT"
			echo "On patiente 20 secondes avant de poursuivre..."
			sleep 20
			#port_courant=$((port_courant+2))

		done < ${doss_web}/partition_a_cloner.txt
	else
		if [ "$MODE" = "2" ]; then
			echo -e "$COLINFO"
			echo "Recepteur:"

			# Boucle test de presence des clients
			ABANDON="n"
			SUITE="n"
			while [ "$SUITE" != "y" -a "$ABANDON" != "y" ]
			do
				echo -e "$COLTXT"
				echo "L'emetteur est-il pret ?"
				#echo ""
				#echo -e "$COLCMD"
				wget --tries=1 http://$IP_SERVEUR/pret_a_emettre.txt > /dev/null 2>&1
				if [ "$?" = "0" ]; then
					echo -e "$COLTXT"
					echo "Emetteur : pret pour emission..."|tee -a $rapport
					SUITE="y"
				else
					echo -e "$COLERREUR"
					echo "L'emetteur n'est pas encore pret..."
					echo "(il manque peut-etre des clients,"
					echo "ou le temps minimal d'attente n'est pas encore atteint)"

					instant_courant=$(date +%s)
	
					ECHO_DEBUG "instant_courant=$instant_courant"
	
					t=$((${instant_courant}-${instant_0}))
	
					ECHO_DEBUG "t=\$((${instant_courant}-${instant_0}))=$t"
					ECHO_DEBUG "start_timeout=$start_timeout"
	
					echo -e "\r${COLTXT}$t sec (ecoulees) / $start_timeout sec (start_timeout)"

					if [ -n "$start_timeout" ]; then
						if [ $t -ge $start_timeout ]; then
							ABANDON="y"
	
							ECHO_DEBUG "ABANDON=$ABANDON"
	
							POURSUIVRE_CLONAGE="n"
	
							# VOIR COMMENT signaler le pb... via remontee_udpcast.php
	
							succes="n"
						else
							echo "... reste $(($start_timeout-$t)) secondes avant abandon..."
						fi
					else
						# On donne 20 min de delais
						echo "On attend au maximum 20min l'emetteur..."
						if [ $t -ge 1200 ]; then
							ABANDON="y"
	
							ECHO_DEBUG "ABANDON=$ABANDON"
	
							POURSUIVRE_CLONAGE="n"
	
							# VOIR COMMENT signaler le pb... via remontee_udpcast.php
	
							succes="n"
						else
							echo "... reste $((1200-$t)) secondes avant abandon..."
						fi
					fi
				fi
				sleep 3
			done

			if [ "$ABANDON" != "y" ]; then

				port_courant=$PORT

				while read LIGNE
				do
					PART=$(echo "$LIGNE"|cut -d";" -f1)
					TYPE_PART=$(echo "$LIGNE"|cut -d";" -f2)
					FICHIER=/dev/$PART

					PING_PATIENTER $IP_SERVEUR|tee -a $rapport

					# A FAIRE: Dans le cas non NTFS, ajouter un temoin cote serveur comme quoi l'emission est lancee et ne lancer qu'alors le receiver... qui va etre alors vu par l emetteur.
					# Recuperer le temoin par wget.

					if [ "$TYPE_PART" = "ntfs" ]; then
						if [ "$COMPRESSION" = "lzop" ]; then
							commande="udp-receiver --portbase ${port_courant} --interface $INTERFACE -p 'lzop -d -c -f -' --nokbd | ntfsclone -r -O $FICHIER -"
						elif [ "$COMPRESSION" = "gzip" ]; then
							commande="udp-receiver --portbase ${port_courant} --interface $INTERFACE -p 'pigz -d -c -f -' --nokbd | ntfsclone -r -O $FICHIER -"
						elif [ "$COMPRESSION" = "pbzip2" ]; then
							commande="udp-receiver --portbase ${port_courant} --interface $INTERFACE -p 'pbzip2 -d -c -f -' --nokbd | ntfsclone -r -O $FICHIER -"
						else
							commande="udp-receiver --portbase ${port_courant} --interface $INTERFACE --nokbd | ntfsclone -r -O $FICHIER -"
						fi
					else
						if [ "$COMPRESSION" = "lzop" ]; then
							commande="udp-receiver --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --nokbd --pipe 'lzop -d -c -f -'"
						elif [ "$COMPRESSION" = "gzip" ]; then
							commande="udp-receiver --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --nokbd --pipe 'gzip -d -c -f -'"
						elif [ "$COMPRESSION" = "pbzip2" ]; then
							commande="udp-receiver --file $FICHIER --portbase ${port_courant} --interface $INTERFACE -p 'pbzip2 -d -c -f -' --nokbd"
						else
							commande="udp-receiver --file $FICHIER --portbase ${port_courant} --interface $INTERFACE --nokbd"
						fi

						# Dans le cas ou le type de la partition est Linux, il faudrait pouvoir reinstaller GRUB... et donc avoir pointe la presence de GRUB sur l emetteur.
					fi

					echo -e "$COLTXT"
					echo $commande|tee -a $rapport
					fichier_courant=/tmp/commande_reception_$(date "+%Y%m%d_%H%M%S").sh
					echo $commande>$fichier_courant
					chmod +x $fichier_courant
					echo -e "$COLCMD\c"
					#$commande|tee -a $rapport
					$fichier_courant|tee -a $rapport

					if [ "$?" != "0" ]; then
						echo -e "$COLERREUR"
						echo "Il semble qu'un probleme se soit produit."|tee -a $rapport
						echo "Le clonage pourrait bien avoir echoue."
						echo -e "$COLTXT"
						succes="n"
						read PAUSE
						#exit
					else
						succes="y"
					fi
		
					if [ "$TYPE_PART" = "ntfs" ]; then
						echo -e "$COLTXT"
						echo "Re-ecriture du secteur de 'demarrage' (?) (start sector) de $FICHIER"|tee -a $rapport
						echo -e "$COLCMD\c"
						echo "ntfsreloc -w $FICHIER"|tee -a $rapport
						ntfsreloc -w $FICHIER
					fi

					#port_courant=$((port_courant+2))
				done < /tmp/partition_a_cloner.txt

				LISTE_PART ${HD} afficher_liste=n avec_tableau_liste=y type_part_cherche=linux
				if [ -n "${liste_tmp[0]}" ]; then
					echo -e "$COLTXT"
					echo "Recherche d un fichier temoin de la reinstallation GRUB demandee ou non..."
					echo -e "$COLCMD\c"
					# En attendant un autre moyen de choisir si on veut reinstaller grub ou non

					# Faire un test sur la presence de GRUB sur le poste modele?

					fichier_temoin_reinstall_grub=/tmp/fichier_temoin_reinstall_grub.txt
					wget -O ${fichier_temoin_reinstall_grub} http://${se3ip}/clonage/fichier_temoin_reinstall_grub.txt > /dev/null 2>&1
					if [ "$?" != "0" ]; then
						echo -e "$COLTXT"
						echo "Reinstallation automatique de GRUB..."|tee -a $rapport
						echo -e "$COLCMD\c"
						/bin/reinstall_grub.sh reinstall_grub=auto
						sleep 3
					elif [ -e /tmp/reinstallation_bootloader.txt ]; then
						if grep -qi grub /tmp/reinstallation_bootloader.txt; then
							echo "/bin/reinstall_grub.sh reinstall_grub=auto"|tee -a $rapport
							/bin/reinstall_grub.sh reinstall_grub=auto
							sleep 3
						elif grep -qi lilo /tmp/reinstallation_bootloader.txt; then
							echo "/bin/reinstall_lilo.sh reinstall_lilo_auto=y HD=${HD}"|tee -a $rapport
							/bin/reinstall_lilo.sh reinstall_lilo_auto=y HD=${HD}
							sleep 3
						fi
					fi
				fi
			fi
		else
			echo -e "$COLERREUR"
			echo "Le mode choisi n'existe pas."
			succes="n"
			read PAUSE
		fi
	fi
fi

if [ "$remontee_info" = "y" ]; then
	echo -e "$COLTXT"
	echo "Remontee du statut vers le serveur..."
	echo -e "$COLCMD"

	if [ "$ABANDON" = "y" ]; then
		succes="n"
	fi

	# L heure de fin depend aussi du fait que l horloge BIOS soit a l heure
	#echo "wget ${page_remontee}?fin=${date_fin}\&succes=${succes}\&mac=${mac}"
	#wget ${page_remontee}?fin=${date_fin}\&succes=${succes}\&mac=${mac}
	debut=`cat /tmp/debut_udpcast.txt`

	date "+%s" > /tmp/fin_udpcast.txt
	fin=`cat /tmp/fin_udpcast.txt`
	echo "wget ${page_remontee}?debut=${debut}\&fin=${fin}\&succes=${succes}\&mac=${mac}\&num_op=${num_op}\&umode=${umode}"|tee -a $rapport
	wget ${page_remontee}?debut=${debut}\&fin=${fin}\&succes=${succes}\&mac=${mac}\&num_op=${num_op}\&umode=${umode}
fi


echo -e "$COLTITRE"
echo "*****************"
echo "* Duree ecoulee *"
echo "*****************"

echo -e "$COLTXT"
echo "Voici les dates relevees..."
echo -e "$COLCMD"
datefin=`date "+%Y-%m-%d %H:%M:%S"`
echo "Fin:   $datefin" >> /tmp/dates_udpcast.txt
cat /tmp/dates_udpcast.txt|tee -a $rapport
echo -e "$COLINFO"
echo "Ces dates peuvent etre incorrectes si les machines n'etaient pas a l'heure.
Mais la difference entre les heures de debut et de fin donne le temps de
clonage."|tee -a $rapport

echo -e "$COLTITRE"
echo "***********"
echo "* Termine *"
echo "***********"
echo -e "$COLTXT"

if grep -q rapport_local /proc/cmdline; then
	LISTE_PART ${HD} afficher_liste=n avec_tableau_liste=y type_part_cherche=linux
	if [ -n "${liste_tmp[0]}" ]; then
		tmp_mnt=/mnt/partition_linux_$(date +%Y%m%d%H%M%S)
		mkdir -p $tmp_mnt
		mount ${liste_tmp[0]} $tmp_mnt && cp $rapport /$tmp_mnt/&& umount $tmp_mnt
	else
		echo "Pas de partition Linux trouvee..."|tee -a $rapport
	fi
fi

delais_reboot=5
if grep "auto_reboot=always" /proc/cmdline > /dev/null; then
	echo -e "$COLTXT"
	COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes."
	reboot
else
	if grep "auto_reboot=success" /proc/cmdline > /dev/null; then
		if [ "$succes" = "y" ]; then
			echo -e "$COLTXT"
			COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes."
			reboot
		else
			echo -e "$COLERREUR"
			echo "Un probleme s est produit lors du clonage."
			read PAUSE
		fi
	else
		echo -e "$COLTXT"
		echo "Vous pouvez rebooter..."
		read PAUSE
	fi
fi


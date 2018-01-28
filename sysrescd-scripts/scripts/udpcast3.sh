#!/bin/sh

# Auteur: Stephane Boireau
# Derniere modification: 25/06/2013

source /bin/crob_fonctions.sh

echo -e "$COLTITRE"
echo "************************"
echo "* Clonage avec Udpcast *"
echo "************************"

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

# Pour eliminer les options ar_nowait,... qui ne permettent pas de definir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

# Pour relever la duree de clonage et la remonter vers remontee_udpcast.php
date "+%s" > /tmp/debut_udpcast
# Pour afficher a l'ecran:
datedebut=`date "+%Y-%m-%d %H:%M:%S"`
echo "Debut: $datedebut" > /tmp/dates_udpcast.txt

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
# Disque ou partition a cloner
if [ "$disk" = "auto" -o -z "$disk" ]; then
	disk=$(GET_DEFAULT_DISK)
fi

DISK=$disk
FICHIER="/dev/$DISK"

if ! fdisk -s /dev/$DISK > /dev/null 2>&1; then
	echo -e "$COLERREUR\c"
	echo "ERREUR: Le disque propose n'existe pas!"

	echo -e "$COLTXT"
	echo "Vous allez devoir indiquer manuellement ce qui doit etre copie:"
	echo " 'hda', 'hda1',... 'sda', 'sda1',..."
	
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	DISK=""
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel disque souhaitez-vous cloner,"
		echo -e "ou sur quel disque se trouve la partition a cloner? [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
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


	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous cloner:"
		echo -e "   (${COLCHOIX}1${COLTXT}) tout le disque"
		echo -e "   (${COLCHOIX}2${COLTXT}) seulement une partition?"
		echo -e "Votre choix: [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done

	if [ "$REPONSE" = "1" ]; then
		#FICHIER=$DISK
		FICHIER="/dev/$DISK"
	else
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
fi
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
#================================================
# Compression
if [ "$compr" = "lzop" -o "$compr" = "gzip" -o "$compr" = "none" ]; then
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
			echo -e " (${COLCHOIX}1${COLTXT}) lzop (recommande)"
			echo -e " (${COLCHOIX}2${COLTXT}) gzip"
			echo -e " (${COLCHOIX}3${COLTXT}) aucune compression"
	
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
#================================================

#append initrd=udprd root=01:00 persoparams=oui lang=FR kbmap=FR dhcp=yes compr=$compr port=$port umode=rcv disk=$disk auto_reboot=$auto_reboot enableDiskmodule=$enableDiskmodule diskmodule=$diskmodule netmodule=$netmodule remontee_info=y page_remontee=${urlse3}/tftp/remontee_udpcast.php mac=$mac num_op=${num_op} udpcparam=$udpcparam
#udpcparam=--min-receivers=1
#================================================
#================================================










datedebut=`date "+%Y-%m-%d %H:%M:%S"`
echo "Debut: $datedebut" > /tmp/dates.txt

date "+%s" > /tmp/debut_udpcast.txt

if [ "$MODE" = "1" ]; then
	echo -e "$COLINFO"
	echo "Emetteur:"
	if [ "$COMPRESSION" = "lzop" ]; then
		echo -e "$COLTXT"
		echo "udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE $udpcparam --pipe 'lzop -c -f -'"
		echo -e "$COLCMD\c"
		udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE $udpcparam --pipe 'lzop -c -f -'
	else
		if [ "$COMPRESSION" = "gzip" ]; then
			echo -e "$COLTXT"
			echo "udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE $udpcparam --pipe 'gzip -c -f -'"
			echo -e "$COLCMD\c"
			udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE $udpcparam --pipe 'gzip -c -f -'
		else
			echo -e "$COLTXT"
			echo "udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE $udpcparam"
			echo -e "$COLCMD\c"
			udp-sender --file $FICHIER --portbase $PORT --interface $INTERFACE $udpcparam
		fi
	fi

	if [ "$?" != "0" ]; then
		echo -e "$COLERREUR"
		echo "Il semble qu'un probleme se soit produit."
		echo "Le clonage pourrait bien avoir echoue pour une machine au moins."
		echo -e "$COLTXT"
		succes="n"
		read PAUSE
		#exit
	else
		succes="y"
	fi
else
	if [ "$MODE" = "2" ]; then
		echo -e "$COLINFO"
		echo "Recepteur:"
		if [ "$COMPRESSION" = "lzop" ]; then
			echo -e "$COLTXT"
			echo "udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd $udpcparam --pipe 'lzop -d -c -f -'"
			echo -e "$COLCMD\c"
			udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd $udpcparam --pipe 'lzop -d -c -f -'
		else
			if [ "$COMPRESSION" = "gzip" ]; then
				echo -e "$COLTXT"
				echo "udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd $udpcparam --pipe 'gzip -d -c -f -'"
				echo -e "$COLCMD\c"
				udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd $udpcparam --pipe 'gzip -d -c -f -'
			else
				echo -e "$COLTXT"
				echo "udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd $udpcparam"
				echo -e "$COLCMD\c"
				udp-receiver --file $FICHIER --portbase $PORT --interface $INTERFACE --nokbd $udpcparam
			fi
		fi

		if [ "$?" != "0" ]; then
			echo -e "$COLERREUR"
			echo "Il semble qu'un probleme se soit produit."
			echo "Le clonage pourrait bien avoir echoue."
			echo -e "$COLTXT"
			succes="n"
			read PAUSE
			#exit
		else
			succes="y"
		fi
	else
		echo -e "$COLERREUR"
		echo "Le mode choisi n'existe pas."
		succes="n"
		read PAUSE
	fi
fi

if [ "$remontee_info" = "y" ]; then
	echo -e "$COLTXT"
	echo "Remontee du statut vers le serveur..."
	echo -e "$COLCMD"

	# L heure de fin depend aussi du fait que l horloge BIOS soit a l heure
	#echo "wget ${page_remontee}?fin=${date_fin}\&succes=${succes}\&mac=${mac}"
	#wget ${page_remontee}?fin=${date_fin}\&succes=${succes}\&mac=${mac}
	debut=`cat /tmp/debut_udpcast.txt`

	date "+%s" > /tmp/fin_udpcast.txt
	fin=`cat /tmp/fin_udpcast.txt`
	echo "wget ${page_remontee}?debut=${debut}\&fin=${fin}\&succes=${succes}\&mac=${mac}\&num_op=${num_op}\&umode=${umode}"
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
cat /tmp/dates_udpcast.txt
echo -e "$COLINFO"
echo "Ces dates peuvent etre incorrectes si les machines n'etaient pas a l'heure."
echo "Mais la difference entre les heures de debut et de fin donne le temps de"
echo "clonage."

echo -e "$COLTITRE"
echo "***********"
echo "* Termine *"
echo "***********"
echo -e "$COLTXT"

if grep "auto_reboot=always" /proc/cmdline > /dev/null; then
	echo -e "$COLTXT"
	echo "Reboot dans 5 secondes..."
	sleep 5
	reboot
else
	if grep "auto_reboot=success" /proc/cmdline > /dev/null; then
		if [ "$succes" = "y" ]; then
			echo -e "$COLTXT"
			echo "Reboot dans 5 secondes..."
			sleep 5
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

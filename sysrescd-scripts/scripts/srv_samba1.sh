#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read
# Dernière modification: 26/02/2013

source /bin/crob_fonctions.sh

ladate=$(date +"%Y.%m.%d-%H.%M.%S");
tmp=/tmp/$ladate
mkdir $tmp


echo -e "$COLTITRE"
echo "********************************************"
echo "* Script de mise en place du serveur Samba *"
echo "********************************************"

echo -e "$COLINFO"
echo "Ce script permet de mettre en place un serveur Samba pour partager une"
echo "partition/un dossier/un lecteur CD/DVD,..."
echo "Les étapes sont les suivantes:"
echo " - Configuration IP du serveur."
echo " - Saisie des paramètres globaux du serveur (nom netbios, domaine,...)."
echo " - Définition (si nécessaire) d'utilisateurs."
echo " - Montage de la ressource (partition, lecteur,...)."
echo " - Définition des partages."
# Mise en place du smb.conf
# Création effective des utilisateurs
echo " - Démarrage du serveur Samba."

POURSUIVRE




echo -e "$COLPARTIE"
echo "==========================="
echo "Configuration IP du serveur"
echo "==========================="

CONFIG_RESEAU

echo -e "$COLPARTIE"
echo "============================="
echo "Paramètres globaux du serveur"
echo "============================="

echo -e "$COLINFO"
echo "Vous allez devoir répondre à quelques questions correspondant à des paramètres"
echo "de la section [global] du fichier de configuration du serveur Samba."

echo -e "${COLPARTIE}"
echo "======================="
echo -e "Paramètre ${COLCHOIX}netbios name${COLPARTIE}"
echo "======================="

DEFAUT_NETBIOS="smbsysrcd"
REPONSE=""
while [ "$REPONSE" != "n" ]
do
	#Pour réinitialiser la variable après une proposition erronée:
	REPONSE=""

	echo -e "$COLTXT"
	echo "Le nom du serveur ne doit comporter que des caractères alphanumériques"
	echo "(pas de caractères spéciaux, ni accents) avec un maximum de 12 caractères."
	echo "(15 est la limite théorique)"
	echo -e  "Veuillez saisir le nom souhaité pour le serveur: [${COLDEFAUT}${DEFAUT_NETBIOS}${COLTXT}] $COLSAISIE\c"
	read NOM_NETBIOS

	if [ -z "$NOM_NETBIOS" ]; then
		NOM_NETBIOS="$DEFAUT_NETBIOS"
	fi

	CORRECTION=$(echo "$NOM_NETBIOS" | sed -e "s|[A-Za-z0-9_]||g" | wc -m)
	CORRECT2=$(echo "$NOM_NETBIOS" | wc -m)
	if [ $CORRECTION -ge 2 -o $CORRECT2 -ge 14 ]; then
	#if [ $CORRECTION -ge 2 ]; then
		REPONSE="o"
	else
		echo -e "$COLTXT"
		echo -e "Vous avez choisi le nom netbios suivant: '${COLINFO}${NOM_NETBIOS}${COLTXT}'"
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous corriger? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="n"
			fi
		done
	fi
done

if [ -z "$iface" ]; then
	iface="$eth0"
fi

if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
	IP=$(ifconfig ${iface} | grep "inet " | cut -d":" -f2 | cut -d" " -f1)
else
	IP=$(ifconfig ${iface} | grep "inet "|sed -e "s|^ *||g"| cut -d" " -f2)
fi

#Pour éviter des problèmes de résolution de nom:
cat /etc/hosts | grep -v "^$IP " > /tmp/hosts_elague
cat /tmp/hosts_elague > /etc/hosts
#echo "$IP cdimage smbsysrcd" >> /etc/hosts
echo "$IP sysresccd smbsysrcd" >> /etc/hosts

mkdir -p /var/log/samba
mkdir -p /var/run/samba
mkdir -p /var/cache/samba
mkdir -p /etc/samba/private

echo -e "${COLPARTIE}"
echo "===================="
echo -e "Paramètre ${COLCHOIX}workgroup${COLPARTIE}"
echo "===================="

DEFAUT_DOMAINE="sysrcdomain"
REPONSE=""
while [ "$REPONSE" != "n" ]
do
	#Pour réinitialiser la variable après une proposition erronée:
	REPONSE=""

	echo -e "$COLTXT"
	echo "Le nom du domaine/workgroup ne doit comporter que des caractères alphanumériques"
	echo "(pas de caractères spéciaux, ni accents) avec un maximum de 12 caractères."
	echo "(15 est la limite théorique)"
	echo -e  "Veuillez saisir le nom souhaité pour le domaine: [${COLDEFAUT}${DEFAUT_DOMAINE}${COLTXT}] $COLSAISIE\c"
	read DOMAINE

	if [ -z "$DOMAINE" ]; then
		DOMAINE="$DEFAUT_DOMAINE"
	fi

	CORRECTION=$(echo "$DOMAINE" | sed -e "s|[A-Za-z0-9_]||g" | wc -m)
	if [ "$CORRECTION" -ge 2 -o $(echo "$DOMAINE" | wc -m) -ge 14 ]; then
		REPONSE="o"
		DOMAINE=""
	else
		echo -e "$COLTXT"
		echo -e "Vous avez choisi le nom de domaine suivant: '${COLINFO}$DOMAINE${COLTXT}'"
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous corriger? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="n"
			fi
		done
	fi
done

echo -e "${COLPARTIE}"
echo "======================="
echo -e "Paramètre: ${COLCHOIX}hosts allow${COLPARTIE}"
echo "======================="

DEFAUT_HOSTS_ALLOW="127. "
#CALCULER LE RESTE DU $DEFAUT_HOSTS_ALLOW D'APRES L'IP/MASQUE
HOSTS_ALLOW=""
REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous limiter les accès au serveur"
	echo -e "à une classe IP particulière? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	while [ "$REPONSE" = "o" ]
	do
		echo -e "$COLTXT"
		echo -e "Donnez la liste des classes autorisées sous la forme suivante:"
		echo -e "   ${COLINFO}192.168.1. 192.168.2.${COLTXT} pour ${COLINFO}192.168.1.*${COLTXT} et ${COLINFO}192.168.2.*${COLTXT}"
		echo -e "ou ${COLINFO}10.127.${COLTXT} pour ${COLINFO}10.127.*.*${COLTXT}"

		echo -e "$COLTXT"
		echo -e "A la liste que vous proposerez,"
		echo -e "sera ajouté ${COLINFO}127.${COLTXT} pour les besoins du serveur Samba."

		echo -e "$COLTXT"
		echo -e "Liste: $COLSAISIE\c"
		read HOSTS_ALLOW

		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Vous avez choisi ${COLINFO}$HOSTS_ALLOW${COLTXT}"

			echo -e "$COLTXT"
			echo -e "Voulez-vous corriger? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="n"
			fi
		done
	done
fi

echo "#======================= Global Settings =====================================
[global]

   workgroup = $DOMAINE
   netbios name = $NOM_NETBIOS
   server string = %h server (Samba %v)

# The following parameter is useful only if you have the linpopup package
# installed. The samba maintainer and the linpopup maintainer are
# working to ease installation and configuration of linpopup and samba.
;   message command = /bin/sh -c '/usr/bin/linpopup \"%f\" \"%m\" %s; rm %s' &

   log file = /var/log/samba/log.%m
   max log size = 1000
# Set the log (verbosity) level (0 <= log level <= 10)
;   log level = 3

# We want Samba to log a minimum amount of information to syslog. Everything
# should go to /var/log/samba/log.{smbd,nmbd} instead. If you want to log
# through syslog you should set the following parameter to something higher.
   syslog = 0



# 4. Security and Domain Membership Options:
# This option is important for security. It allows you to restrict
# connections to machines which are on your local network. The
# following example restricts access to two C class networks and
# the \"loopback\" interface. For more examples of the syntax see
# the smb.conf man page. Do not enable this if (tcp/ip) name resolution does
# not work for all the hosts in your network." >> $tmp/smb.conf

if [ "$HOSTS_ALLOW" != "" ]; then
	echo "   hosts allow = $HOSTS_ALLOW 127." >> $tmp/smb.conf
else
	echo ";   hosts allow = 192.168.1. 192.168.2. 127." >> $tmp/smb.conf
	#OU:
	#echo ";   hosts allow = $DEFAUT_HOSTS_ALLOW 127." >> $tmp/smb.conf
fi

echo "   security = user
   encrypt passwords = true

   passdb backend = tdbsam
   map to guest = Bad User

# Most people will find that this option gives better performance.
# See smb.conf(5) and /usr/share/doc/samba-doc/htmldocs/speed.html
# for details
# You may want to add the following on a Linux system:
#         SO_RCVBUF=8192 SO_SNDBUF=8192
   socket options = TCP_NODELAY



# This boolean parameter controls whether Samba attempts to sync the Unix
# password with the SMB password when the encrypted SMB password in the
# passdb is changed.
;   unix password sync = no

# For Unix password sync to work on a Debian GNU/Linux system, the following
# parameters must be set (thanks to Ian Kahan <<kahan@informatik.tu-muenchen.de> for
# sending the correct chat script for the passwd program in Debian Sarge).
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\sUNIX\spassword:* %n\n *Retype\snew\sUNIX\spassword:* %n\n *password\supdated\ssuccessfully* .


# Configure Samba to use multiple interfaces
# If you have multiple network interfaces then you must list them
# here. See the man page for details.
;   interfaces = 192.168.12.2/24 192.168.13.2/24

   local master = yes
   os level = 65
   domain master = yes
   preferred master = yes
   domain logons = yes
   ;logon script = %U.bat
   ;logon script = %G.bat
   logon script = commun.bat

# Where to store roaming profiles for WinNT and Win2k
#        %L substitutes for this servers netbios name, %U is username
#        You must uncomment the [Profiles] share below
;   logon path = \\%L\Profiles\%U

# Where to store roaming profiles for Win9x. Be careful with this as it also
# impacts where Win2k finds it's /HOME share
; logon home = \\%L\%U\.profile



# The following setting only takes effect if 'domain logons' is set
# It specifies the location of a user's home directory (from the client
# point of view)
;   logon drive = H:
;   logon home = \\%N\%U



#==========
#Pour désactiver les profiles au niveau Samba:
logon home =
logon path =
#==========




# This allows Unix users to be created on the domain controller via the SAMR
# RPC pipe.  The example command creates a user account with a disabled Unix
# password; please adapt to your needs
; add user script = /usr/sbin/adduser --quiet --disabled-password --gecos "" %u


   dns proxy = no

   ; Apparemment, ces paramètres ne sont pas acceptés:
   ;dos charset = 850
   ;unix charset = ISO8859-1
" >> $tmp/smb.conf


echo -e "$COLPARTIE"
echo "======"
echo "Divers"
echo "======"

#Pb jonction au domaine:
#"L'erreur suivante s'est produite lors de la tentative de jonction au domaine "sysrcdomain":
#Le nom d'utilisateur est introuvable."

#root@cdimage /root % cat /var/log/samba/log.xpbof
#useradd: unknown group machines
#root@cdimage /root %

echo -e "$COLTXT"
echo "Création du groupe 'machines' pour permettre l'intégration de machines NT/2K/XP."
echo -e "$COLCMD\c"
if ! cat /etc/group | grep "^machines:" > /dev/null; then
	groupadd machines
fi


echo -e "$COLPARTIE"
echo "======================="
echo "Création d'utilisateurs"
echo "======================="

echo -e "$COLINFO"
echo "Si vous comptez faire joindre des machines NT/2K/XP au domaine,"
echo "pensez à créer le compte 'root' pour Samba."

REPONSE=""
while [ "$REPONSE" != "1" -a  "$REPONSE" != "2" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous créer des utilisateurs et leur affecter des mots de passe (${COLCHOIX}1${COLTXT}),"
	echo -e "ou préférez-vous effectuer des accès 'guest' (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="2"
	fi
done

if [ "$REPONSE" = "1" ]; then
	echo -e "$COLINFO"
	echo "Vous allez devoir préciser le nom du compte et son mot de passe."
	echo "N'utilisez pour le nom du compte que des caractères alphanumériques"
	echo "en minuscules (sans chiffre pour le premier caractère)"
	echo "et limitez-vous à 8 caractères."

	REPONSE=""
	while [ "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Nom du compte: $COLSAISIE\c"
		read COMPTE

		CORRECTION=$(echo "$COMPTE" | sed -e "s|[A-Za-z0-9]||g" | wc -m)
		CORRECT2=$(echo "$COMPTE" | wc -m)
		if [ $CORRECTION -ge 2 -o $CORRECT2 -ge 10 ]; then
			REPONSE=""
		else
			echo -e "$COLCMD\c"
			if [ "$COMPTE" != "root" ]; then
				useradd $COMPTE -d /home/$COMPTE -m -k /etc/skel
			fi

			echo -e "$COLTXT"
			echo "Vous allez devoir saisir le mot de passe à deux reprises:"
			echo -e "$COLCMD\c"
			#echo $MDP | passwd $COMPTE --stdin
			#smbpasswd -a $COMPTE $MDP
			smbpasswd -a $COMPTE

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous créer un autre utilisateur? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
				read REPONSE
			done
		fi
	done
fi


echo -e "$COLPARTIE"
echo "======================="
echo "Définition des partages"
echo "======================="


echo "#============================ Share Definitions ==============================
[homes]
   comment = Home Directories
   browseable = no
   writable = yes
   create mask = 0700

[netlogon]
   comment = Network Logon Service
   path = /var/lib/samba/netlogon
   guest ok = yes
   writable = no
   share modes = no

# Un-comment the following and create the profiles directory to store
# users profiles (see the "logon path" option above)
# (you need to configure Samba to act as a domain controller too.)
# The path below should be writable by all users so that their
# profile directory may be created the first time they log on
;[profiles]
;   comment = Users profiles
;   path = /home/samba/profiles
;   guest ok = no
;   browseable = no
;   create mask = 0600
;   directory mask = 0700

#A voir pour des pb avec le SP1... dans [Profiles]:
#nt acl support = yes
" >> $tmp/smb.conf

echo -e "$COLTXT"
echo "Les partages [homes] et [netlogon] ont déjà été définis."
#Voir où le Home est créé et quelle place est disponible.

COMPTEUR=1
REPONSE="o"
while [ "$REPONSE" = "o" ]
do
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Devez-vous monter un lecteur"
		echo -e "ou une partition avant de définir un partage? (${COLCHOIX}o/n${COLTXT})? $COLSAISIE\c"
		read REPONSE
	done

	if [ "$REPONSE" = "o" ]; then
		#PTMNT="/mnt/partage_${COMPTEUR}"
		#mkdir $PTMNT
		#Pour effectuer le démontage, il faudrait stocker les points de montage dans un tableau.
		#PTMNT[$COMPTEUR]="/mnt/partage_${COMPTEUR}"
		PTMNT[$COMPTEUR]="/mnt/part_${COMPTEUR}"
		mkdir -p ${PTMNT[$COMPTEUR]}

		echo -e "$COLTXT"
		echo -e "Voulez-vous partager un dossier sur une partition locale (${COLCHOIX}1${COLTXT})"
		echo -e "ou monter un lecteur CD/DVD (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi

		if [ "$REPONSE" = "1" ]; then

			#Montage de la partition:

			SMBHD=""
			while [ -z "$SMBHD" ]
			do
				AFFICHHD
	
				DEFAULTDISK=$(GET_DEFAULT_DISK)
	
				echo -e "$COLTXT"
				echo "Sur quel disque se trouve la partition à monter?"
				echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
				echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
				read SMBHD
	
				if [ -z "$SMBHD" ]; then
					SMBHD=${DEFAULTDISK}
				fi

				tst=$(sfdisk -s /dev/$SMBHD 2>/dev/null)
				if [ -z "$tst" -o ! -e "/sys/block/$SMBHD" ]; then
					echo -e "$COLERREUR"
					echo "Le disque $SMBHD n'existe pas."
					echo -e "$COLTXT"
					echo "Appuyez sur ENTREE pour corriger."
					read PAUSE
					SMBHD=""
				fi
			done


			REPONSE=""
			while [ "$REPONSE" != "1" ]
			do
				echo -e "$COLTXT"
				echo "Voici les partitions disponibles:"
				echo -e "$COLCMD"
				#fdisk -l /dev/$SMBHD | grep "/dev/${SMBHD}[0-9]" | grep -v "Linux swap"
				LISTE_PART ${SMBHD} afficher_liste=y

				#liste_tmp=($(fdisk -l /dev/$SMBHD | grep "^/dev/$SMBHD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | cut -d" " -f1))
				LISTE_PART ${SMBHD} avec_tableau_liste=y
				if [ ! -z "${liste_tmp[0]}" ]; then
					DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
				else
					DEFAULTPART="${SMBHD}1"
				fi
	
	
				echo -e "$COLTXT"
				echo -e "Quelle est la partition à monter? [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
				read CHOIX_PARTITION
	
				if [ -z "$CHOIX_PARTITION" ]; then
					CHOIX_PARTITION=${DEFAULTPART}
				fi

				#if ! fdisk -s /dev/$CHOIX_PARTITION > /dev/null; then
				t=$(fdisk -s /dev/$PARTITION)
				if [ -z "$t" -o ! -e "/sys/block/$SMBHD/$PARTITION" ]; then
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

			PARTSMB[$COMPTEUR]="/dev/$CHOIX_PARTITION"

			#if ! fdisk -l /dev/$SMBHD | grep ${PARTSMB[$COMPTEUR]} > /dev/null; then
			t=$(fdisk -s /dev/${PARTSMB[$COMPTEUR]})
			if [ -z "$t" -o ! -e "/sys/block/$SMBHD/${PARTSMB[$COMPTEUR]}" ]; then
				echo -e "$COLERREUR"
				echo "ERREUR: La partition proposée n'existe pas!"
				echo -e "$COLTXT"
				read PAUSE
				exit 1
			fi

			echo -e "$COLTXT"
			echo "Quel est le type de la partition ${PARTSMB[$COMPTEUR]}?"
			echo "(vfat (pour FAT32), ntfs, ext2, ext3,...)"
			DETECTED_TYPE=$(TYPE_PART ${PARTSMB[$COMPTEUR]})
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
			if mount | grep "${PARTSMB[$COMPTEUR]} " > /dev/null; then
				umount ${PARTSMB[$COMPTEUR]}
				sleep 1
			fi

			if mount | grep ${PTMNT[$COMPTEUR]} > /dev/null; then
				umount ${PTMNT[$COMPTEUR]}
				sleep 1
			fi

			echo -e "$COLTXT"
			echo "Montage de la partition ${PARTSMB[$COMPTEUR]} en ${PTMNT[$COMPTEUR]}:"
			if [ -z "$TYPE" ]; then
				echo -e "${COLCMD}mount ${PARTSMB[$COMPTEUR]} ${PTMNT[$COMPTEUR]}"
				mount ${PARTSMB[$COMPTEUR]} "${PTMNT[$COMPTEUR]}"||ERREUR "Le montage de ${PARTSMB[$COMPTEUR]} a échoué!"
			else
				if [ "$TYPE" = "ntfs" ]; then
					echo -e "${COLCMD}ntfs-3g ${PARTSMB[$COMPTEUR]} ${PTMNT[$COMPTEUR]} -o ${OPT_LOCALE_NTFS3G}"
					ntfs-3g ${PARTSMB[$COMPTEUR]} ${PTMNT[$COMPTEUR]} -o ${OPT_LOCALE_NTFS3G} || ERREUR "Le montage a échoué!"
					sleep 1
				else
					#if [ "$TYPE" = "vfat" -o "$TYPE" = "ntfs" ]; then
					if [ "$TYPE" = "vfat" ]; then
						#Pour avoir un accès en lecture/écriture
						OPTIONS="-o umask=0"
					else
						OPTIONS=""
					fi
	
					echo -e "${COLCMD}mount -t $TYPE ${PARTSMB[$COMPTEUR]} ${PTMNT[$COMPTEUR]} $OPTIONS"
					mount -t $TYPE ${PARTSMB[$COMPTEUR]} "${PTMNT[$COMPTEUR]}" $OPTIONS ||ERREUR "Le montage de ${PARTSMB[$COMPTEUR]} a échoué!"
				fi
			fi
		else
			#=======
			#=======
			#=======
			#A FAIRE: montage lecteur CD/DVD
			#=======
			#=======
			#=======
			A_FAIRE=""

			echo -e "$COLTXT"
			echo "Le montage de CD/DVD n'est pas encore implémenté."
			echo "Basculez dans un autre terminal (ALT+F2) et effectuez"
			echo "le montage à la main, puis revenez dans ce terminal."
			echo "Une fois le montage effectué, appuez sur ENTREE pour poursuivre."
			read PAUSE
		fi
		COMPTEUR=$(($COMPTEUR+1))
	fi

	#Dossier à partager
	echo -e "${COLPARTIE}"
	echo "================================="
	echo -e "Dossier à partager: ${COLCHOIX}path = XXXXX${COLPARTIE}"
	echo "================================="
	echo -e "$COLINFO"
	echo "Vous allez pouvoir choisir le dossier à partager."
	echo "Il pourra être créé d'après vos saisies s'il n'existe pas."
	echo ""
	echo -e "Les partitions montées dans ce script le sont en ${COLCHOIX}/mnt/part_X${COLINFO}"
	echo -e "où ${COLCHOIX}X${COLINFO} est un nombre incrémenté de 1 pour chaque nouveau montage."

	VARTEST="n"
	while [ "$VARTEST" = "n" ]
	do

		#Afficher les dossiers?
		#Comment les parcourir?
		DOSS="/"
		LS=""
		while [ "$LS" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voici les fichiers/dossiers à la racine de: ${COLINFO}$DOSS${COLTXT}"
			echo -e "$COLCMD"
			ls $DOSS

			LS=""
			while [ "$LS" != "o" -a  "$LS" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous parcourir d'autres dossiers? (${COLCHOIX}o/n${COLTXT})? $COLSAISIE\c"
				read LS
			done

			if [ "$LS" = "o" ]; then
				echo -e "$COLTXT"
				echo -e "Quel dossier voulez-vous parcourir? $COLSAISIE\c"
				cd /
				read -e DOSS
			fi
		done

		echo -e "$COLTXT"
		echo -e "Quel dossier voulez-vous partager? $COLSAISIE\c"
		cd /
		read -e DOSSTMP

		if [ ! -e "$DOSSTMP" ]; then
			echo -e "$COLTXT"
			echo "Le dossier proposé n'existe pas:"
			echo -e "\t${COLINFO}$DOSSTMP"

			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous le créer? (${COLCHOIX}o/n${COLTXT})? $COLSAISIE\c"
				read REPONSE
			done

			if [ "$REPONSE" = "n" ]; then
				VARTEST="n"
			else
				mkdir -p "$DOSSTMP"
				VARTEST="o"
			fi
		else
			VARTEST="o"
		fi
	done

	#Virer le / de fin.
	DOSSIER=$(echo "$DOSSTMP" | sed -e "s|/$||")


	#Nom du partage
	echo -e "${COLPARTIE}"
	echo "========================"
	echo -e "Nom du partage: ${COLCHOIX}[XXXXX]${COLPARTIE}"
	echo "========================"

	echo -e "$COLINFO"
	echo "Pour le nom du partage veillez à n'utiliser que des caractères alphanumériques"
	echo "non accentués et à rester sous les 12 caractères (15 est la limite théorique)."

	PARTAGE=""
	while [ -z "$PARTAGE" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel nom voulez-vous donner au partage? $COLSAISIE\c"
		read PARTAGE

		CORRECTION=$(echo "$PARTAGE" | sed -e "s|[A-Za-z0-9_]||g" | wc -m)
		CORRECT2=$(echo "$PARTAGE" | wc -m)
		if [ $CORRECTION -ge 2 -o $CORRECT2 -ge 17 ]; then
			PARTAGE=""
		fi
	done

	echo -e "${COLPARTIE}"
	echo "=================="
	echo -e "Paramètre ${COLCHOIX}comment${COLPARTIE}"
	echo "=================="

	COMMENTAIRE=""
	while [ -z "$COMMENTAIRE" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel commentaire/descriptif voulez-vous donner au partage?"
		echo -e "Commentaire: [${COLDEFAUT}Partage $PARTAGE${COLTXT}] $COLSAISIE\c"
		read COMMENTAIRE

		if [ -z "$COMMENTAIRE" ]; then
			COMMENTAIRE="Partage $PARTAGE"
		fi
	done


	echo -e "${COLPARTIE}"
	echo "================="
	echo -e "Paramètre ${COLCHOIX}public${COLPARTIE}"
	echo "================="

	#public = $PUBLIC
	REPONSE=""
	while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Le partage doit-il être accessible (au moins en lecture) à tous? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		PUBLIC="yes"
	else
		PUBLIC="no"
	fi

	echo -e "${COLPARTIE}"
	echo "====================="
	echo -e "Paramètre ${COLCHOIX}browseable${COLPARTIE}"
	echo "====================="
	#browseable
	REPONSE=""
	while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Le partage doit-il être visible dans le 'Voisinage Réseau'? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		BROWSEABLE="yes"
	else
		BROWSEABLE="no"
	fi

	#===================================================================================
	#Restrictions:
	# - write list = ...
	# - writable = yes/no
	# - valid users = ...

	echo -e "${COLPARTIE}"
	echo "======================"
	echo -e "Paramètre ${COLCHOIX}valid users${COLPARTIE}"
	echo "======================"
	# valid users = ...
	if [ "$PUBLIC" = "no" ]; then
		REPONSE=""
		while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Voulez-vous spécifier une liste d'utilisateurs"
			echo -e "autorisés à accéder au partage? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="n"
			fi
		done

		if [ "$REPONSE" = "o" ]; then
			echo -e "$COLTXT"
			echo -e "Donnez la liste des utilisateurs sous la forme: ${COLCHOIX}toto,titi${COLTXT}"
			echo -e "Liste: $COLSAISIE\c"
			read VALIDUSERS
		else
			VALIDUSERS="NON"
		fi
	else
		VALIDUSERS="NON"
	fi

	echo -e "${COLPARTIE}"
	echo "==================="
	echo -e "Paramètre ${COLCHOIX}writable${COLPARTIE}"
	echo "==================="
	# writable = ...
	REPONSE=""
	while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
	do
		echo -e "$COLINFO"
		echo "L'accès en écriture au partage peut déjà être limité par une partition"
		echo "de type NTFS (en lecture seule)."
		echo "Il peut aussi déjà être limité par le fait que seuls certains utilisateurs"
		echo "y aient accès."
		echo "La réponse à la question suivante ne pourra pas outrepasser"
		echo "les points ci-dessus."

		echo -e "$COLTXT"
		echo -e "Le partage doit-il être accessible en écriture"
		echo -e "pour tous les utilisateurs autorisés à accéder au partage? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done

	if [ "$REPONSE" = "o" ]; then
		WRITABLE="yes"
		WRITELIST="NON"
	else
		WRITABLE="no"

		echo -e "${COLPARTIE}"
		echo "====================="
		echo -e "Paramètre ${COLCHOIX}write list${COLPARTIE}"
		echo "====================="
		# write list = ...
		REPONSE=""
		while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
		do
			echo -e "$COLTXT"
			echo -e "Le partage doit-il accessible en écriture"
			echo -e "pour certains utilisateurs? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REPONSE

			if [ -z "$REPONSE" ]; then
				REPONSE="n"
			fi
		done

		if [ "$REPONSE" = "o" ]; then
			echo -e "$COLTXT"
			echo -e "Donnez la liste des utilisateurs sous la forme: ${COLCHOIX}toto,titi${COLTXT}"
			echo -e "Liste: $COLSAISIE\c"
			read WRITELIST
		else
			WRITELIST="NON"
		fi
	fi


	#===================================================================================




	echo "" >> $tmp/smb.conf
	echo "[$PARTAGE]
	comment = $COMMENTAIRE
	path = $DOSSIER
	browseable = $BROWSEABLE
	public = $PUBLIC
	writable = $WRITABLE" >> $tmp/smb.conf

	if [ "$VALIDUSERS" != "NON" ]; then
		echo "	valid users = $VALIDUSERS" >> $tmp/smb.conf
	fi

	if [ "$WRITELIST" != "NON" ]; then
		echo "	write list = $WRITELIST" >> $tmp/smb.conf
	fi

	#if [ "$..." != "NON" ]; then
	#	echo "	... = $..." >> $tmp/smb.conf
	#fi


	REPONSE=""
	while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous créer un autre partage? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		#COMPTEUR=$(($COMPTEUR+1))

		if [ -z "$REPONSE" ]; then
			REPONSE="n"
		fi
	done
done




#Script de login:
echo -e "$COLTXT"
echo "Création d'un script de login."
echo 'if "%OS%"=="Windows_NT" goto xp' > /var/lib/samba/netlogon/commun.tmp
echo "net use H: /home" >> /var/lib/samba/netlogon/commun.tmp
echo "goto suite" >> /var/lib/samba/netlogon/commun.tmp
echo ":xp" >> /var/lib/samba/netlogon/commun.tmp
echo 'net use H: \\'$NOM_NETBIOS'\%USERNAME%' >> /var/lib/samba/netlogon/commun.tmp
echo ":suite" >> /var/lib/samba/netlogon/commun.tmp
if cat $tmp/smb.conf | grep "\[public\]" > /dev/null; then
	#echo 'net use P: \\\\'$NOM_NETBIOS'\\public' >> /var/lib/samba/netlogon/commun.tmp
	echo 'net use P: \\'$NOM_NETBIOS'\public' >> /var/lib/samba/netlogon/commun.tmp
fi
echo "" >> /var/lib/samba/netlogon/commun.tmp
#Fins de lignes DOS:
sed 's/$'"/`echo \\\r`/" "/var/lib/samba/netlogon/commun.tmp" > /var/lib/samba/netlogon/commun.bat

#Comme j'ai mis "logon home =", W2k/... ne trouve pas son 'home':
#C:\Documents and Settings\toto>net use H: /home
#Le répertoire de base de l'utilisateur n'a pas été spécifié.
#Vous obtiendrez une aide supplémentaire en entrant NET HELPMSG 3916.
#Pour monter le home, un montage classique est effectué.


echo -e "$COLPARTIE"
echo "=========================="
echo "Démarrage du serveur Samba"
echo "=========================="

echo -e "$COLTXT"
echo "Mise en place du fichier smb.conf"
echo -e "$COLCMD\c"
cp -f $tmp/smb.conf /etc/samba/smb.conf

REPONSE=""
while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous contrôler la configuration avec testparm? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo "Contrôle de la configuration:"
	echo -e "$COLCMD"
	testparm
fi

REPONSE=""
while [ "$REPONSE" != "o" -a  "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous maintenant démarrer le service Samba? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo "Démarrage du service Samba:"
	echo -e "$COLCMD"
	/etc/init.d/samba start
fi

echo -e "${COLINFO}"
echo "Les machines WNT/2K/XP peuvent joindre le domaine,"
echo "mais les profiles ne sont pas gérés."
echo "De plus, j'ignore si, lors de l'arrêt de SysRescCD, le secrets.tdb est conservé."
echo "   (à contrôler...)"
echo "Dans ces conditions, le serveur de fichiers, en mode contrôleur de domaine,"
echo "est un peu gadget;o)."

echo -e "${COLTITRE}"
echo "***********"
echo "* Terminé *"
echo "***********"
echo -e "${COLTXT}"
read PAUSE


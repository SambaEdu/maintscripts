#!/bin/bash

# Script de lancement auto du CD-ROM
# Adapte par S.Boireau d'apres le script de Franck Molle
# Script qui etait lui-meme adapte de celui du cd Stonehenge
# Derniere modification: 04/12/2014

# **********************************
# Version adaptee √† System Rescue CD
# **********************************

# Pour eviter la mise en veille ecran:
echo -e '\033[9;0]'

# Nom du script autorun:
script_autorun="autorun.sh"
# Ce script lorsqu'il est nomme autorun est normalement lance automatiquement
# mais avec la version 0.3.5 de SysRescCD, cela se bloque...

source /bin/crob_fonctions.sh

# On modifie les couleurs du terminal dans l'interface graphique
/bin/config_Terminal_terminalrc.sh

# Creation d'un lanceur SSHD sans NetworkManager requis:
cp -a /etc/init.d/sshd /etc/init.d/sshd_crob
sed -i "s/need net/#need net\necho ''/g" /etc/init.d/sshd_crob
sed -i "s/need net/#need net\necho ''/g" /etc/init.d/sshd

# Suppression de la dependance NetworkManager dans plusieurs scripts:
sed -i "s/need net/#need net\necho ''/g" /etc/init.d/dhcpd
sed -i "s/need net/#need net\necho ''/g" /etc/init.d/in.tftpd
sed -i "s/need net/#need net\necho ''/g" /etc/init.d/thttpd
sed -i "s/need net/#need net\necho ''/g" /etc/init.d/pxebootsrv

sed -i 's|cp --remove-destination ${bootdir}/???linux/???linux.cfg /tftpboot/pxelinux.cfg/default|if [ -e ${bootdir}/isolinux/isolinux.cfg ]; then cp --remove-destination ${bootdir}/isolinux/isolinux.cfg /tftpboot/pxelinux.cfg/default; elif [ -e ${bootdir}/isolinux/syslinux.cfg ]; then cp --remove-destination ${bootdir}/isolinux/syslinux.cfg /tftpboot/pxelinux.cfg/default; elif [ -e ${bootdir}/syslinux/isolinux.cfg ]; then cp --remove-destination ${bootdir}/syslinux/isolinux.cfg /tftpboot/pxelinux.cfg/default; elif [ -e ${bootdir}/syslinux/syslinux.cfg ]; then cp --remove-destination ${bootdir}/syslinux/syslinux.cfg /tftpboot/pxelinux.cfg/default;fi|' /etc/init.d/pxebootsrv

# Ajout pour prÈvenir un manque dans la version 1.5.2
mkdir -p /tftpboot/pxelinux.cfg

#†On supprime le lancement d'un autre terminal que celui lancant autorun.sh:
sed -i "s|^/usr/bin/terminal >/dev/null 2>&1 &|#/usr/bin/terminal >/dev/null 2>\&1 \&|g" /root/.xinitrc

t=$(grep "cle_ssh=" /proc/cmdline)
if [ -n "$t" -a ! -e /tmp/cle_ssh_done.txt ]; then
	/bin/wget_cle_pub.sh
	echo "Fait." > /tmp/cle_ssh_done.txt
fi

# On vide le $work apres le premier lancement.
if [ -e /tmp/temoin_autorun.txt ]; then
	work=""
fi
echo "Autorun lance une fois." > /tmp/temoin_autorun.txt

if [ "$work" = "cdrestaure.sh" ]; then
	/bin/cdrestaure.sh
else

	if [ "$work" = "gparted" ]; then
		if [ -z "$WMAKER_BIN_NAME" -a -z "$DESKTOP_SESSION" ]; then
#			echo '#!/bin/sh
#/usr/sbin/gparted & ' > /root/GNUstep/Library/WindowMaker/autostart
#			chmod +x /root/GNUstep/Library/WindowMaker/autostart

			sed -i "s|.*exec /root/winmgr.sh >/dev/null 2>&1|exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc
			sed -i "s|exec /root/winmgr.sh >/dev/null 2>&1|/usr/sbin/gparted \& exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc

			#CONFXORG

			startx || echo "Plusieurs causes peuvent expliquer un plantage:
- Un probleme de pilote (essayez les differentes options de boot:
	. fb800
	. i810fb800
	. intelfb800)
- Un probleme de resolution trop elevee
  (essayez fb800 si vous aviez tente fb1024)
- Un probleme de carte video mal supportee
  (essayez de passer l'option forcevesa lors du boot.
  Ex.: fb800 forcevesa)
- Un fichier de configuration /etc/X11/xorg.conf non rempli ou mal rempli
  (lancez /usr/sbin/mkxf86config.sh)."
		else
			/usr/sbin/gparted
		fi
		exit
	else
		if grep dostartx /proc/cmdline > /dev/null; then
#			echo '#!/bin/sh
#/usr/bin/xterm -bg black -fg white -e /root/'$script_autorun' & ' > /root/GNUstep/Library/WindowMaker/autostart
#			chmod +x /root/GNUstep/Library/WindowMaker/autostart

			sed -i "s|.*exec /root/winmgr.sh >/dev/null 2>&1|exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc

			sed -i "s|exec /root/winmgr.sh >/dev/null 2>&1|/usr/bin/mrxvt -e /root/autorun.sh \& exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc

			#CONFXORG

			startx || echo "Plusieurs causes peuvent expliquer un plantage:
- Un probleme de pilote (essayez les differentes options de boot:
	. fb800
	. i810fb800
	. intelfb800)
- Un probleme de resolution trop elevee
  (essayez fb800 si vous aviez tente fb1024)
- Un probleme de carte video mal supportee
  (essayez de passer l'option forcevesa lors du boot.
  Ex.: fb800 forcevesa)
- Un fichier de configuration /etc/X11/xorg.conf non rempli ou mal rempli
  (lancez /usr/sbin/mkxf86config.sh)."
			exit
		fi
	fi

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

	ssh_started="n"
	t=$(grep url_authorized_keys /proc/cmdline)
	if [ ! -z "$work" -o -n "$t" ]; then
		#oldifs="$IFS"
		#IFS=" "
		#for I in $(cat /proc/cmdline)
		#do
		#	if [ ${I:0:5} = "disk=" ]; then
		#		disk=$(echo $I | cut -d"=" -f2)
		#		#echo $disk
		#	fi
		#done
		#IFS="$oldifs"

		# Pour eliminer les options ar_nowait,... qui ne permettent pas de dÈfinir des variables
		cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
		source /tmp/tmp_proc_cmdline.txt

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
				ssh_started="y"
			fi
		fi
	fi

	#†A FAIRE: Tester aussi dans /var/run...
	t=$(grep "autoruns=2" /proc/cmdline)
	if [ -n "$t" -a "$ssh_started" = "n" ]; then
		/etc/init.d/sshd_crob start
		echo "Demarrage sshd_crob via le test autoruns=2">/tmp/mode_demarrage_sshd_crob.txt
		ssh_started="y"
	fi

	if [ "$work" = "u1" ]; then
		if grep docache /proc/cmdline > /dev/null; then
			echo -e "${COLINFO}"
			echo "Ejection du CD..."
			echo -e "${COLCMD}"
			eject
		fi

		if [ -z "$disk" ]; then
			/bin/udpcast2.sh "emetteur" "sda"
		else
			/bin/udpcast2.sh "emetteur" "$disk"
		fi
	else
		if [ "$work" = "u2" ]; then
			if grep docache /proc/cmdline > /dev/null; then
				echo -e "${COLINFO}"
				echo "Ejection du CD..."
				echo -e "${COLCMD}"
				eject
			fi

			if [ -z "$disk" ]; then
				/bin/udpcast2.sh "recepteur" "sda"
			else
				/bin/udpcast2.sh "recepteur" "$disk"
			fi
		else
			if [ ! -z "$work" ]; then
				if [ -e $work ]; then
					#sh $work
					chmod +x $work
					$work
				else
					for dossier_work in /root/bin /sbin /bin /usr/sbin /usr/bin
					do
						if [ -e $dossier_work/$work ]; then
							#sh $dossier_work/$work
							chmod +x $dossier_work/$work
							$dossier_work/$work
							break
						fi
					done
				fi
			fi

			echo -e "$COLTXT"
			echo "Pause de 1min avant de poursuivre..."
			echo "... pressez ENTREE pour accelerer le mouvement."
			read -t 60 PAUSE
		fi
	fi


	num_page=1
	nb_pages=3

	while [ "1" = "1" ]
	do

		if [ $num_page -gt $nb_pages ]; then
			num_page=1
		fi

		clear
		echo -e "${COLTITRE}\c"
		echo -e "-------------------------------------------------------------------"
		echo -e "                            BIENVENUE ($num_page/$nb_pages)                  "
		echo -e "${COLTITRE}\c"
		echo "-------------------------------------------------------------------"
		echo -e "${COLCMD}\c"

		case "$num_page" in
		1)
			echo -e "   - ${COLCHOIX}a${COLCMD} Lancer une sauvegarde locale, SMB ou SSHFS d'${COLERREUR}une seule${COLCMD} partition"
			echo -e "   - ${COLCHOIX}b${COLCMD} Lancer une restauration depuis une partition,"
			echo -e "       un CD/DVD, un partage SMB/Win ou un serveur SSH"
			echo -e "   - ${COLCHOIX}c${COLCMD} Sauvegarde en boucle de partitions, ${COLERREUR}eventuellement plusieurs${COLCMD},"
			echo -e "   -   avec possibilite de creer un ISO CDRESTAURE"
			echo -e "   - ${COLCHOIX}ru${COLCMD} Restauration depuis un disque USB"
			echo -e ""
			echo -e "   - ${COLCHOIX}i${COLCMD} Installer SysRescCD sur disque dur"
			echo -e "   - ${COLCHOIX}iu${COLCMD} Installer SysRescCD sur disque dur USB"
			echo -e ""
			echo -e "   - ${COLCHOIX}cp${COLCMD}/${COLCHOIX}cp2${COLCMD} Lancer le script client d'un serveur partimaged"
			echo -e "   - ${COLCHOIX}sp${COLCMD}/${COLCHOIX}sp2${COLCMD} Configurer la station en serveur partimaged"
			echo -e ""
			echo -e "   - ${COLCHOIX}u${COLCMD} Lancement de Udpcast"
			echo -e "   - ${COLCHOIX}u1${COLCMD}/${COLCHOIX}u2${COLCMD} Emetteur/Recepteur Udpcast sur tout 'sda'"
			;;
		2)
			echo -e "   - ${COLCHOIX}1${COLCMD} Reinstaller LILO."
			echo -e "   - ${COLCHOIX}2${COLCMD} Rechercher un/des mot(s) de passe LILO."
			echo -e "   - ${COLCHOIX}3${COLCMD} Reinstaller GRUB."
			echo -e "   - ${COLCHOIX}mdp${COLCMD} Virer un mot de passe W\$XP (experimental)"
			echo -e "   - ${COLCHOIX}ntfs${COLCMD} Reduire une partition NTFS (experimental)"
			echo -e ""
			echo -e "   - ${COLCHOIX}n${COLCMD} Monter une partition NTFS en lecture/ecriture"
			echo -e "   - ${COLCHOIX}mp${COLCMD} Monter toutes les partitions d'un disque"
			#if ! egrep "( vga=0 | vga=4 | vga=6 )" /proc/cmdline > /dev/null; then
				echo "-------------------------------------------------------------------"
				echo -e "${COLCMD}\c"
				echo -e "   - ${COLCHOIX}gp${COLCMD} Lancer GParted pour repartitionner"
				echo -e "${COLCMD}\c"
				#if [ -z "$WMAKER_BIN_NAME" ]; then
				if [ -z "$WMAKER_BIN_NAME" -a -z "$DESKTOP_SESSION" ]; then
					echo -e "   - ${COLCHOIX}X${COLCMD} Re-Lancer le menu dans une interface graphique"
					echo -e "   - ${COLCHOIX}rX${COLCMD} Reduire la resolution maximale pour X"
					echo -e "        de fa√ßon √† eviter un message 'Out of range'"
				fi
			#fi
			echo -e ""
			echo -e "   - ${COLCHOIX}conf${COLCMD} Generer un rapport de la configuration materielle"
			;;
		3)
			echo -e "   - ${COLCHOIX}9xdom${COLCMD} Griser/degriser le champ domaine du login sur W98SE (experimental)"
			echo -e ""
			echo -e "   - ${COLCHOIX}h${COLCMD} Lancer une sauvegarde de donnees"
			echo -e "   - ${COLCHOIX}z${COLCMD} Remplissage des vides par des zeros"
			echo "-------------------------------------------------------------------"
			echo -e "${COLCMD}\c"
			echo -e "   - ${COLCHOIX}s${COLCMD} Configurer et lancer le serveur de fichiers Samba"
			echo -e "   - ${COLCHOIX}t${COLCMD} Configurer et lancer le serveur TFTP"
			echo "-------------------------------------------------------------------"
			echo -e "${COLCMD}\c"
			echo -e "   - ${COLCHOIX}m${COLCMD} Lancement d'un script de preparation de SysRescCD"
			echo -e "       pour en faire une distribution de mirroring SSH"
			echo -e "       d'un serveur SambaEdu3"
			echo "-------------------------------------------------------------------"
			echo -e "${COLCMD}\c"
			echo -e "   - ${COLCHOIX}MAJ${COLCMD} Mise √† jour des scripts sur un SysRescCD"
			echo -e "         installe sur disque dur."
			echo "-------------------------------------------------------------------"
			#echo -e "   - ${COLCHOIX}conf${COLCMD} Generer un rapport de la configuration materielle"
			echo -e "   - ${COLCHOIX}d${COLCMD} Lire la doc HTML"
			;;
		esac

		echo "-------------------------------------------------------------------"
		echo -e "     - ${COLCHOIX}q${COLCMD} Quitter le programme     - ${COLCHOIX}r${COLCMD} Rebooter la machine"
		echo "-------------------------------------------------------------------"
		echo -e "    ${COLINFO}Appuyez simplement sur ENTREE pour passer au menu suivant${COLCMD}"
		echo "-------------------------------------------------------------------"
		echo -e "   Votre choix ? ${COLSAISIE}\c"
		read CHOIX < /dev/tty
	
		echo -e "${COLCMD}"

		. /root/choix.sh

	done
fi

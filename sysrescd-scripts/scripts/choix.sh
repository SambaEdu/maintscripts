
# Portion de code appelee dans /root/autorun.sh pour effectuer le traitement choisi
# Derniere modification: 17/05/2012

if [ -z "$CHOIX" ]; then
	# On passe a la suite
	num_page=$(($num_page+1))
else
	case "$CHOIX" in

	a) clear
	echo "Lancement d'une sauvegarde !"
	echo
	echo
	sleep 1
	/bin/save-hda1_papa4.sh
	echo
	echo
	cd /root

	;;

	b) clear
	echo "Lancement d'une restauration !"
	echo
	echo
	sleep 1
	/bin/restore-hda1_papa4.sh
	echo
	echo
	cd /root

	;;

	c) clear
	echo "Lancement d'une sauvegarde: CDRESTAURE!"
	echo
	echo
	sleep 1
	/bin/sauve_cdrestaure.sh
	echo
	echo
	cd /root

	;;

	#c2) clear
	#echo "Lancement d'une sauvegarde: CDRESTAURE!"
	#echo
	#echo
	#sleep 1
	#/bin/sauve_cdrestaure_test.sh
	#echo
	#echo
	#cd /root
	#./$script_autorun
	#;;

#	d) clear
#	echo "Acces a la documentation HTML!"
#	echo
#	echo
#	sleep 1
#	/bin/liredoc.sh
#	echo
#	echo
#	cd /root
#
#	;;

	h) clear
	echo "Lancement d'une sauvegarde de donnees (HOME,...) !"
	echo
	echo
	sleep 1
	/bin/savehome3.sh
	echo
	echo
	cd /root

	;;


	i) clear
	echo "Installation de SysRescCD sur le disque dur !"
	echo
	echo
	sleep 1
	/bin/install_sysrescd.sh
	echo
	echo
	cd /root

	;;


	iu) clear
	echo "Installation de SysRescCD sur le disque dur USB !"
	echo
	echo
	sleep 1
	/bin/install_sysrescd_usb.sh
	echo
	echo
	cd /root

	;;


	#r) clear
	#echo "Configuration de l'interface eth0 !"
	#echo
	#echo
	#sleep 1
	#/bin/net_setup.sh eth0
	#echo
	#echo
	#cd /root
	#./$script_autorun
	#;;


	z) clear
	echo "Remplissage de l'espace libre d'une partition par des zeros!"
	echo
	echo
	sleep 1
	/bin/zero2.sh
	echo
	echo
	cd /root

	;;

	gp) clear
	echo "Lancement de l'interface graphique..."
	echo "... puis de gparted."
	echo
	echo -e "${COLERREUR}"
	echo -e "ATTENTION:${COLCMD} Si vous redimensionnez une partition NTFS, il est indispensable"
	echo "           de laisser ensuite Windows effectuer son 'scandisk'."
	echo
	echo "Appuyez sur ENTREE pour poursuivre..."
	#sleep 1
	read PAUSE
	#run_qtparted
	#if [ -z "$WMAKER_BIN_NAME" ]; then
	if [ -z "$WMAKER_BIN_NAME" -a -z "$DESKTOP_SESSION" ]; then
#		echo '#!/bin/sh
#/usr/sbin/gparted & ' > /root/GNUstep/Library/WindowMaker/autostart
#		chmod +x /root/GNUstep/Library/WindowMaker/autostart

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
	echo
	echo
	cd /root

	;;

	X) clear
	echo "Lancement de l'interface graphique !"
	echo
	echo
	sleep 1
#	echo '#!/bin/sh
#/usr/bin/xterm -bg black -fg white -e /root/'$script_autorun' & ' > /root/GNUstep/Library/WindowMaker/autostart
#	chmod +x /root/GNUstep/Library/WindowMaker/autostart

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
	echo
	echo
	cd /root

	;;


	rX) clear
	echo "Reduction de la resolution maximale a 800x600 !"
	echo
	echo
	sleep 1
	#CONFXORG
	ladate=$(date '+%Y%m%d-%H%M%S')
	mv /etc/X11/xorg.conf /etc/X11/xorg.conf.${ladate}
	echo "Correction du fichier /etc/X11/xorg.conf"
	sed -e 's/Modes "1024x768" "800x600" "640x480"/Modes "800x600" "640x480"/g' /etc/X11/xorg.conf.${ladate} > /etc/X11/xorg.conf
	echo "Termine."
	sleep 1
	echo
	echo
	cd /root

	;;



	#7) clear
	#echo "Telechargement des signatures de virus pour clamav !"
	#echo
	#echo
	#sleep 1
	##/bin/telclam2.sh
	#echo
	#echo
	#cd /root
	#./$script_autorun
	#;;


	n) clear
	echo "Montage d'une partition NTFS en lecture/ecriture !"
	echo
	echo
	sleep 1
	/bin/ntfs2.sh
	echo
	echo
	cd /root
	;;

	mp) clear
	echo "Montage de toutes les partitions d'un disque !"
	echo
	echo
	sleep 1
	/bin/monter_toutes_les_partitions_d_un_disque.sh
	echo
	echo
	cd /root
	;;


	cp) clear
	echo "Lancement du script client d'un serveur partimaged !"
	echo
	echo
	sleep 1
	/bin/client_partimaged.sh
	echo
	echo
	cd /root
	;;

	sp) clear
	echo "Configuration de la station en serveur partimaged !"
	echo
	echo
	sleep 1
	/bin/serveur_partimaged.sh
	echo
	echo
	cd /root

	;;


	sp2) clear
	echo "Lancement du script serveur partimaged !"
	echo
	echo
	sleep 1
	/bin/srv_partimaged.sh
	echo
	echo
	cd /root

	;;


	cp2) clear
	echo "Lancement du script client d'un serveur partimaged !"
	echo
	echo
	sleep 1
	/bin/cli_partimaged.sh
	echo
	echo
	cd /root

	;;


	u) clear
	echo "Lancement de UDPcast !"
	echo
	echo
	sleep 1
	/bin/udpcast2.sh
	echo
	echo
	cd /root

	;;


	u1) clear
	echo "Emetteur UDPcast !"
	echo
	echo
	sleep 1
	#/bin/udpcast.sh "emetteur" "sda"
	/bin/udpcast2.sh "emetteur" "sda"
	echo
	echo
	cd /root

	;;


	u2) clear
	echo "Recepteur UDPcast !"
	echo
	echo
	sleep 1
	#/bin/udpcast.sh "recepteur" "sda"
	/bin/udpcast2.sh "recepteur" "sda"
	echo
	echo
	cd /root

	;;

	conf) clear
	echo "Lancement d'un script de generation de rapport sur la configuration materielle."
	echo
	echo
	sleep 1
	generer_rapport_machine.sh
	echo
	echo
	cd /root

	;;

	q) clear
	echo "Bye bye !"
	echo
	echo
	sleep 1
	echo
	exit 1
	;;

	r) clear
	echo -e "$COLERREUR"
	echo "Vous avez demande a rebooter la machine !"
	echo -e "$COLCMD"
	echo -e "Etes-vous sÃ»r ??? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
	if [ "$REPONSE" = "o" ]; then
		echo -e "$COLERREUR"
		echo "Reboot lance !! "
		echo -e "$COLCMD"
		reboot
	fi
	echo
	echo
	;;

	s) clear
	echo "Configuration et lancement du serveur de fichiers Samba !"
	echo
	echo
	sleep 1
	srv_samba1.sh
	echo
	echo
	cd /root
	;;
	
	t) clear
	echo "Configuration et lancement du serveur TFTP !"
	echo
	echo
	sleep 1
	srv_tftp.sh
	echo
	echo
	cd /root

	;;
	
	m) clear
	echo "Lancement d'un script de préparation de SysRescCD"
	echo "pour en faire une distribution de mirroring SSH d'un serveur SambaEdu3"
	echo
	echo
	sleep 1
	passwdgroupmin.sh
	echo
	echo
	cd /root

	;;
	
	ntfs) clear
	echo "Lancement d'un script de réduction de partition NTFS"
	echo "en ligne de commande"
	echo
	echo
	sleep 1
	ntfs_resize.sh
	echo
	echo
	cd /root

	;;
	
	mdp) clear
	echo "Lancement de chntpw..."
	echo
	echo
	sleep 1
	virer_mdp_xp.sh
	echo
	echo
	cd /root

	;;
	
	
	9xdom) clear
	echo "Lancement d'un script de remplacement du fichier"
	echo "   C:\WINDOWS\SYSTEM\mprserv.dll "
	echo "contrôlant la possibilité de modification"
	echo "du champ domaine de la fenêtre de login."
	echo
	echo
	sleep 1
	w9x_domaine_grise.sh
	echo
	echo
	cd /root

	;;
	
	#conf) clear
	#echo "Lancement d'un script de génération de rapport sur la configuration matérielle."
	#echo
	#echo
	#sleep 1
	#generer_rapport_machine.sh
	#echo
	#echo
	#cd /root
	#./$script_autorun
	#;;
	
	MAJ) clear
	echo -e "$COLTXT"
	echo -e "Lancement d'un script de mise a jour des scripts ${COLINFO}sauvewin.sh${COLTXT},"
	echo -e "${COLINFO}restaurewin.sh${COLTXT},... d'un SysRescCD installé sur disque dur."
	echo
	echo
	sleep 1
	maj_sauvewin_restaurewin2.sh
	echo
	echo
	cd /root

	;;
	
	1) clear
	echo "Réinstallation d'un LILO !"
	echo
	echo
	sleep 1
	reinstall_lilo.sh
	echo
	echo
	cd /root

	;;
	
	2) clear
	echo "Recherche d'un/de mot(s) de passe LILO. !"
	echo
	echo
	sleep 1
	recherche_mdp_lilo.sh
	echo
	echo
	cd /root

	;;
	
	3) clear
	echo "Réinstallation d'un GRUB !"
	echo
	echo
	sleep 1
	reinstall_grub.sh
	echo
	echo
	cd /root

	;;
	
	d) clear
	echo "Accès a la documentation HTML!"
	echo
	echo
	sleep 1
	/bin/liredoc.sh
	echo
	echo
	cd /root

	;;

	ru) clear
	echo "Lancement d'une restauration depuis un disque USB !"
	echo
	echo
	sleep 1
	/bin/restaure_svg_hdusb.sh
	echo
	echo
	sleep 2
	cd /root
	;;

	*) clear
	echo -e "${COLERREUR}Entree erronee!${COLTXT} Merci de recommencer."
	echo ""
	echo "Appuyez sur une touche pour continuer..."
	read PAUSE
	cd /root

	;;

	esac
fi

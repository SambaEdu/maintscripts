#!/bin/bash

# Script de mise a jour des scripts distants:
# Version du: 05/10/2012

COLPARTIE="\033[1;34m"
COLINFO="\033[0;33m"
COLTITRE="\033[1;35m"
COLTXT="\033[0;37m"
COLCMD="\033[1;37m"
COLSAISIE="\033[1;32m"
COLERREUR="\033[1;31m"
COLCHOIX="\033[1;33m"
COLDEFAUT="\033[0;33m"

echo -e "$COLPARTIE"
echo "************************************"
echo "* Mise a jour des scripts distants *"
echo "************************************"

. /bin/crob_fonctions.sh

# Pour eliminer les options ar_nowait,... qui ne permettent pas de definir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

if [ -z "$ar_source" ]; then
	ar_source=http://wawadeb.crdp.ac-caen.fr/iso/sysresccd
fi

if [ "${ar_source:0:7}" = "http://" ]; then
	echo -e "$COLTXT"
	echo "Telechargement de l'archive scripts.tar.gz depuis ${ar_source}/"
	echo -e "$COLCMD\c"
	tmp=/tmp/telech_scripts_$(date +%Y%m%d%H%M%S)
	mkdir -p $tmp
	cd $tmp
	echo "wget --tries=3 ${ar_source}/scripts.tar.gz"
	wget --tries=3 ${ar_source}/scripts.tar.gz

	if [ "$?" != "0" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR lors du telechargement."
		echo -e "$COLTXT"
		exit
	fi

	echo -e "$COLTXT"
	echo "Extraction de l'archive scripts.tar.gz"
	echo -e "$COLCMD\c"
	cd $tmp
	tar -xzf scripts.tar.gz&&rm -f scripts.tar.gz

	echo -e "$COLTXT"
	echo "Copie de mes fichiers"
	echo -e "$COLCMD\c"
	cp /sbin/livecd-functions.sh /sbin/livecd-functions.sh.officiel
	cp livecd-functions.sh /sbin/livecd-functions.sh
	
	cp /usr/sbin/net-setup /usr/sbin/net-setup.officiel
	cp net-setup /usr/sbin/net-setup
	
	cp /usr/sbin/sysresccd-custom /usr/sbin/sysresccd-custom.officiel
	cp sysresccd-custom /usr/sbin/sysresccd-custom
	
	chmod +x /sbin/*
	chmod +x /usr/sbin/*
	
	cp scripts/*.sh /bin/ -f
	chmod +x /bin/*.sh
	
	mkdir -p /root/scripts_pour_sysresccd_sur_hd
	cp scripts/scripts_pour_sysresccd_sur_hd/*.sh /root/scripts_pour_sysresccd_sur_hd/ -f
	
	mkdir -p /root/cles_pub_ssh
	cp scripts/cles_pub_ssh/*.pub /root/cles_pub_ssh/ -f

	if [ -n "$script_autorun" ]; then
		cp scripts/$script_autorun /root/ -f
		chmod +x /root/$script_autorun
	fi

	cp scripts/choix.sh /root/ -f
	chmod +x /root/choix.sh
	
	cp scripts/autorun.rc /root/.zsh/rc/ -f
	#chmod +x /root/.zsh/rc/autorun.rc
	
	#cp ./disk1/sysresccd/scripts/page2_autorun /root/ -f
	cp scripts/page2_autorun /root/ -f
	chmod +x /root/page2_autorun
	
	cp etc/init.d/pxebootsrv_perso /etc/init.d/
	chmod +x /etc/init.d/pxebootsrv_perso
	
	cp scripts/liste_rom-o-matic.txt /root/ -f
	cp scripts/liste_smtp.txt /root/ -f
	
	echo -e "$COLTXT"
	echo "Renseignement de quelques fichiers de parametrage..."
	echo -e "$COLCMD\c"
	if [ -e "/root/.Xdefaults" ]; then
		echo -e "$COLTXT"
		echo "Un fichier /root/.Xdefaults existait:"
		echo -e "$COLCMD\c"
		cat /root/.Xdefaults
	
		echo -e "$COLTXT"
		echo -e "Il va etre ecrase par:
${COLCMD}URxvt*scrollBar_right: True
URxvt*saveLines: 32767
xterm*foreground:    White
xterm*background:    Black"
	fi
	
	echo "URxvt*scrollBar_right: True
URxvt*saveLines: 32767
xterm*foreground:    White
xterm*background:    Black" > /root/.Xdefaults
	
	if ! grep "Mrxvt.background: Black" /root/.mrxvtrc > /dev/null; then
		echo "Mrxvt.background: Black" >> /root/.mrxvtrc
	fi
	
	if ! grep "Mrxvt.foreground: White" /root/.mrxvtrc > /dev/null; then
		echo "Mrxvt.foreground: White" >> /root/.mrxvtrc
	fi
	
	echo -e "$COLTXT"
	echo "Ajout de la colorisation syntaxique dans nano"
	echo -e "$COLCMD\c"
	if [ ! -e "/root/.nanorc" ]; then
		for fnano in css.nanorc debian.nanorc html.nanorc nanorc.nanorc perl.nanorc php.nanorc python.nanorc ruby.nanorc sh.nanorc xml.nanorc
		do
			if [ -e "/usr/share/nano/$fnano" ]; then
				echo "include \"/usr/share/nano/$fnano\"" >> /root/.nanorc
			fi
		done
	fi
else
	echo -e "$COLERREUR"
	echo "Les scripts n'ont pas ete recuperes depuis un site distant en http."
	echo -e "$COLTXT"
fi

echo -e "$COLTITRE"
echo "Termine."
echo -e "$COLTXT"


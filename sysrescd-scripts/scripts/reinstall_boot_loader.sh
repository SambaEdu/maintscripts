#!/bin/bash

# Script de reinstallation duboot loader GRUB ou LILO:
# Version du: 08/04/2014

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
echo "*********************************"
echo "* Reinstallation du Boot Loader *"
echo "*********************************"

. /bin/crob_fonctions.sh

# Pour eliminer les options ar_nowait,... qui ne permettent pas de définir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

t=$(head /dev/sda | strings | grep "GRUB")
if [ -n "$t" ]; then
	/bin/reinstall_grub.sh
else
	t=$(head /dev/sda | strings | grep "LILO")
	if [ -n "$t" ]; then
		/bin/reinstall_lilo.sh
	else
		echo -e "$COLERREUR"
		echo "Le chargeur de demarrage installe n'a pas ete identifie."
		
		REP=""
		while [ -z "${REP}" ]
		do
			echo -e "${COLTXT}"
			echo -e "Voulez-vous:"
			echo -e " (${COLCHOIX}1${COLTXT}) Reinstaller LILO"
			echo -e " (${COLCHOIX}2${COLTXT}) Reinstaller GRUB"
			echo -e " (${COLCHOIX}3${COLTXT}) Abandonner"
			echo -e "Votre choix: [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
			read REP
		
			if [ -z "$REP" ]; then
				REP=2
			fi
		
			if [ "$REP" != "1" -a "$REP" != "2" -a "$REP" != "3" ]; then
				REP=""
			fi
		done
		
		if [ "$REP" = "1" ]; then
			/bin/reinstall_lilo.sh
		else
			if [ "$REP" = "2" ]; then
				/bin//bin/reinstall_grub.sh
			else
				echo -e "$COLERREUR"
				echo "ABANDON"
			fi
		fi
	fi
fi

if [ -z "$delais_reboot" ]; then
	# Pour etre sur que le nettoyage de tache ait le temps de passer
	delais_reboot=120
fi

t=$(grep "auto_reboot=y" /proc/cmdline)
if [ -n "$t" ]; then
	echo -e "$COLTXT"
	#echo "Reboot dans $delais_reboot secondes..."
	#sleep $delais_reboot
	COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes..."
	reboot
fi

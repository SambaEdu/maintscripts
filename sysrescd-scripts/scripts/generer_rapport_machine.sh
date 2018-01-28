#!/bin/bash

# J'ai mis /bin/bash pour l'option -e de la commande read

# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derniere modification: 26/02/2013

# **********************************
# Version adaptee à System Rescue CD
# **********************************

source /bin/crob_fonctions.sh

clear
echo -e "$COLTITRE"
echo "*************************************************"
echo "*      Ce script doit vous aider à generer      *"
echo "*    un rapport sur la config de la machine     *"
echo "*************************************************"


echo -e "$COLPARTIE"
echo "====================="
echo "Generation du rapport"
echo "====================="

echo -e "$COLTXT"
echo "Extraction des informations..."
echo -e "$COLCMD\c"

ladate=$(date +%Y%m%d%H%M%S)

dest_locale=/root
fichier="${dest_locale}/rapport_config_materielle_${ladate}.txt"

echo "********" >> $fichier
echo "* lshw *" >> $fichier
echo "********" >> $fichier
lshw >> $fichier
echo "" >> $fichier

echo "*********" >> $fichier
echo "* lspci *" >> $fichier
echo "*********" >> $fichier
lspci >> $fichier
echo "" >> $fichier

echo "************" >> $fichier
echo "* lspci -n *" >> $fichier
echo "************" >> $fichier
lspci -n >> $fichier
echo "" >> $fichier

echo "*********" >> $fichier
echo "* lsmod *" >> $fichier
echo "*********" >> $fichier
lsmod >> $fichier
echo "" >> $fichier

echo "************" >> $fichier
echo "* uname -a *" >> $fichier
echo "************" >> $fichier
uname -a >> $fichier
echo "" >> $fichier

echo "*********************" >> $fichier
echo "* cat /proc/version *" >> $fichier
echo "*********************" >> $fichier
cat /proc/version >> $fichier
echo "" >> $fichier

echo "*********************" >> $fichier
echo "* cat /proc/cmdline *" >> $fichier
echo "*********************" >> $fichier
cat /proc/cmdline >> $fichier
echo "" >> $fichier

echo "*********" >> $fichier
echo "* dmesg *" >> $fichier
echo "*********" >> $fichier
dmesg >> $fichier
echo "" >> $fichier

echo "*******" >> $fichier
echo "* NET *" >> $fichier
echo "*******" >> $fichier
LISTE_INTERFACES_RESEAU "liste_sans_couleur" >> $fichier
echo "" >> $fichier
echo "Configuration actuelle:" >> $fichier
ifconfig -a >> $fichier
echo "" >> $fichier

POURSUIVRE "o"



echo -e "$COLPARTIE"
echo "===================="
echo "RENOMMAGE DU FICHIER"
echo "===================="

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Voulez-vous ajouter un prefixe pour le nom du rapport? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	REPONSE=""
	PREF=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Prefixe: $COLSAISIE\c"
		read PREF

		PREF=$(echo "$PREF" | tr " " "_" | tr "ÂÄàâäÊËéèêëÎÏîïÔÖôöÛÜùûü" "AAaaaEEeeeeIIiiOOooUUuuu")
		VERIF=$(echo "$PREF" | sed -e "s/[A-Za-z0-9._-]//g")
		if [ -z "$PREF" -o ! -z "$VERIF" ]; then
			echo -e "$COLERREUR"
			echo -e "ERREUR: Des caracteres non valides ont ete proposes:"
			echo -e "   ${COLINFO}${VERIF}"
			REPONSE="2"
		else
			echo -e "$COLTXT"
			echo -e "Vous proposez: ${COLINFO}${PREF}"

			POURSUIVRE_OU_CORRIGER "1"
		fi
	done

	tmp_fich=$(echo "$fichier" | sed -e "s|^${dest_locale}/||")
	mv "$fichier" "${dest_locale}/${PREF}${tmp_fich}"
	fichier=${dest_locale}/${PREF}${tmp_fich}
fi

echo -e "$COLPARTIE"
echo "======================"
echo "DESTINATION DU FICHIER"
echo "======================"

echo -e "$COLINFO"
echo -e "Le fichier ${COLCHOIX}${fichier}${COLINFO}"
echo -e "a ete genere."
echo "Il est actuellement en memoire vive et disparaitra donc à l'extinction du poste."
echo -e "Vous pouvez envoyer le fichier ${COLCHOIX}${fichier}${COLINFO} en webmail"
echo "en vous connectant dans l'interface graphique et en lançant le navigateur."
echo "Sinon, vous pouvez copier le rapport vers une partition locale,"
echo "vers un partage Window$/Samba ou vers un serveur SSH."

REPONSE=""
#while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" -a "$REPONSE" != "4" ]
while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
do
	echo -e "$COLTXT"
	echo -e "Souhaitez-vous:"
	echo -e "${COLCHOIX}1${COLTXT} copier le rapport sur un peripherique"
	echo -e "${COLCHOIX}2${COLTXT} envoyer le rapport par mail"
	echo -e "${COLCHOIX}3${COLTXT} envoyer le rapport par webmail"

	echo -e "Votre choix [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE=1
	fi
done

case "$REPONSE" in
1)
	DEST_SVG

	echo -e "${COLTXT}"
	echo "Copie du fichier..."
	echo -e "${COLCMD}\c"
	cp $fichier $DESTINATION/
	if [ "$?" = "0" ]; then
		echo -e "${COLINFO}... succes!"
	else
		echo -e "${COLERREUR}... erreur!"
	fi

	echo -e "$COLTXT"
	echo -e "Demontage de $PTMNTSTOCK"
	echo -e "$COLCMD"
	umount $PTMNTSTOCK
;;
2)
	CONFIG_RESEAU

	ENVOI_MAIL $fichier
;;
3)
	echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
	<title>Webmail</title>
	<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
	<meta name="author" content="Stephane Boireau, A.S. RUE de Bernay/Pont-Audemer">
	<!--link href="styles.css" type="text/css" rel="stylesheet"-->
	<style type="text/css">
		body {
			background-color: #FFFF85;
		}

		a {
			color: #7C420B;
		}

		a:hover {
			color: #C66912;
		}

		b a {
			color: #542D08;
		}

		.content {
			border: 1px solid #000000;
			padding: 1em 1%;
			background-color: white;
		}
	</style>
</head>
<body>
	<div class="content">
		<h1 align="center">Webmail</h1>

		<div align="center">
			<p><a href="http://webmail.ac-rouen.fr">http://webmail.ac-rouen.fr</a></p>
			<p><a href="http://www.laposte.net/">http://www.laposte.net/</a></p>
			<p><a href="http://imp.free.fr/">http://imp.free.fr/</a></p>
			<p><br></p>
			<p><i>NOTE:</i> Si vous devez passer par un proxy, il se peut qu il faille le renseigner dans le navigateur (<i>menu Edit/Preferences/Onglet Advanced/Network/Settings</i>).</p>
		</div>
	</div>
</body>
</html>' > /tmp/webmail.html

	REPONSE=""
	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" -a "$REPONSE" != "3" ]
	do
		echo -e "$COLTXT"
		echo "Il est donc necessaire d'effectuer la configuration reseau."
		CHOIX=2
		if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
			if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:" > /dev/null; then
				echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
				ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 addr:"
				CHOIX=1
			fi
		else
			if ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 " > /dev/null; then
				echo -e "${COLTXT}Une interface autre que 'lo' est configurée, voici sa config:${COLCMD}"
				ifconfig | grep inet | grep -v 127.0.0.1 | grep -v "inet6 "
				CHOIX=1
			fi
		fi

		echo -e "${COLTXT}\n"
		echo -e "Si le reseau est OK, tapez       ${COLCHOIX}1${COLTXT}"
		echo -e "Pour configurer le reseau, tapez ${COLCHOIX}2${COLTXT}"
		echo -e "Pour abandonner, tapez           ${COLCHOIX}3${COLTXT}"
		echo -e "Votre choix: [${COLDEFAUT}${CHOIX}${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE=${CHOIX}
		fi
	done

	if [ "$REPONSE" = "3" ]; then
		echo -e "$COLERREUR"
		echo "ABANDON!"
		echo -e "$COLTXT"
		read PAUSE
		exit
	fi

	if [ "$REPONSE" = "2" ]; then
		echo -e "$COLINFO"
		echo "Le script net-setup de SystemRescueCD (depuis la version 0.3.1) pose des"
		echo "problemes lorsqu'il est lance sans être passe par une console avant le lancement"
		echo "(cas du lancement via l'autorun)."
		echo "Un script alternatif est propose, mais il ne permet pas, contrairement au script"
		echo "net-setup officiel, de configurer une interface wifi."
		REPNET=""
		while [ "$REPNET" != "1" -a "$REPNET" != "2" ]
		do
			echo -e "$COLTXT"
			echo -e "Quel script souhaitez-vous utiliser? (${COLCHOIX}1/2${COLTXT}) [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
			read REPNET

			if [ -z "$REPNET" ]; then
				REPNET=2
			fi
		done

		REP="o"
		while [ "$REP" = "o" ]
		do
			echo -e "$COLCMD"
			#SysRescCD:
			if [ "$REPNET" = "1" ]; then
				net-setup eth0
				iface=eth0
			else
				/bin/net_setup.sh
				iface=$(cat /tmp/iface.txt)
			fi
			#Puppy:
			#net-setup.sh

			echo -e "$COLTXT"
			echo "Patientez..."
			sleep 2

			echo -e "$COLTXT"
			echo "Voici la config IP:"
			echo -e "$COLCMD\c"
			if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
				echo "ifconfig $iface | grep inet | grep -v \"inet6 addr:\""
				ifconfig $iface | grep inet | grep -v "inet6 addr:"
			else
				echo "ifconfig $iface | grep inet | grep -v \"inet6 \""
				ifconfig $iface | grep inet | grep -v "inet6 "
			fi

			echo -e "$COLTXT"
			echo -e "Voulez-vous corriger/modifier cette configuration? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
			read REP

			if [ -z "$REP" ]; then
				REP="n"
			fi
		done
	fi


	echo -e "$COLTXT"
	echo "Lancement du navigateur $web_browser apres lancement eventuel de l'interface graphique."
	echo -e "$COLCMD\c"


	#if [ -z "$WMAKER_BIN_NAME" ]; then
	if [ -z "$WMAKER_BIN_NAME" -a -z "$DESKTOP_SESSION" ]; then
	#echo '#!/bin/sh
#'$web_browser_avec_chemin' /tmp/webmail.html & ' > /root/GNUstep/Library/WindowMaker/autostart
	#chmod +x /root/GNUstep/Library/WindowMaker/autostart

	#CONFXORG

	sed -i "s|.*exec /root/winmgr.sh >/dev/null 2>&1|exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc
	sed -i "s|exec /root/winmgr.sh >/dev/null 2>&1|${web_browser_avec_chemin} /tmp/webmail.html \& exec /root/winmgr.sh >/dev/null 2>\&1|" /root/.xinitrc

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
		$web_browser_avec_chemin /tmp/webmail.html
	fi
;;
esac

echo -e "$COLTITRE"
echo "********"
echo "Termine!"
echo "********"
echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour finir."
read PAUSE
exit 0


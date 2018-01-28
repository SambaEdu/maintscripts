#!/bin/sh

#Script de téléchargement des signatures pour clamav
# Humblement réalisé par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 13/01/2007

BLEU="\033[1;34m"
BROWN="\033[0;33m"
ROSE="\033[1;35m"
GRIS="\033[0;37m"
BLANC="\033[1;37m"
VERT="\033[1;32m"
ROUGE="\033[1;31m"

clear
echo -e "$BLEU"
echo "*********************************************"
echo "*  Ce script doit vous aider a telecharger  *"
echo "*     les dernières signatures de virus     *"
echo "*               pour clamav                 *"
echo "*     (freshclam semble poser probleme)     *"
echo "*********************************************"

CONFIG_RESEAU

#echo ""
echo -e "$GRIS"
echo "Etes-vous situe derriere un proxy (SLIS)?"
echo "Si oui, il est necessaire de renseigner une variable d'environnement pour pouvoir effectuer le telechargement."
echo -e "Reponse: (o/n) $VERT\c"
read REPONSE

while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	#echo ""
	echo -e "$GRIS"
	echo -e "Etes-vous situe derriere un proxy (SLIS)? (o/n) $VERT\c"
	read REPONSE
done

if [ "$REPONSE" == "o" ]; then
	echo -e "$GRIS"
	echo -e "Quelle est l'IP de ce proxy? [10.127.164.1] $VERT\c"
	read IP
	#echo ""

	if [ -z "$IP" ]; then
		IP=10.127.164.1
	fi

	echo -e "$GRIS"
	echo -e "Quel est le port de ce proxy? [3128] $VERT\c"
	read PORT
	#echo ""

	if [ -z "$PORT" ]; then
		PORT=3128
	fi

	echo -e "$GRIS"
	echo "La commande exécutée est: export http_proxy=\"$IP:$PORT\""
	echo -e "$BLANC"
	export http_proxy="$IP:$PORT"
fi

echo -e "$BLANC"
cd /tmp
echo -e "$GRIS"
echo "Telechargement des signatures vers /tmp:"
echo -e "$BLANC"
wget http://clamav.sourceforge.net/database/viruses.db
wget http://clamav.sourceforge.net/database/viruses.db2
#echo ""
echo -e "$GRIS"
echo "Si aucune erreur n'est signalee, vous pouvez scanner un dossier, une partition en tapant:"
echo "     clamscan -r -d /tmp /dossier_a_scanner"
echo "-r pour recursivement;"
echo "-d pour preciser l'emplacement des signatures de virus (ici /tmp)."

echo -e "${GRIS}PAUSE... (taper sur ENTREE)"
read PAUSE

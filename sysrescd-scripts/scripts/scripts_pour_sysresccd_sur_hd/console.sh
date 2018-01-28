#!/bin/sh

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
echo "************************"
echo "*     INFORMATIONS...  *"
echo "************************"
echo -e "$COLTXT"
echo "Pause... (taper sur Entree)"
read PAUSE

echo -e "$COLTXT"
echo "Les scripts ajoutes sont:"
echo -e "$COLCMD"
ls /bin/*.sh

echo -e "$COLTITRE"
echo "Vous pouvez rafficher cette page en lancant console.sh"
echo -e "$COLTXT"

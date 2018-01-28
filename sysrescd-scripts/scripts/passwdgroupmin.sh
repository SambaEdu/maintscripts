#!/bin/bash

# 20130625

# J'ai mis /bin/bash pour l'option -e de la commande read

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


ERREUR()
{
	echo -e "$COLERREUR"
	echo "ERREUR!"
	echo -e "$1"
	echo -e "$COLTXT"
	read PAUSE
	sleep 1
	exit 0
}


echo -e "$COLTITRE"
echo "*************************************************"
echo "* Script de vidage de /etc/passwd et /etc/group *"
echo "*************************************************"

echo -e "$COLINFO"
echo "Pour des besoins de synchronisation RSYNC+SSH entre SE3 SysRescCD live,"
echo "j'ai bricolé ce script réduisant au minimum les fichiers /etc/passwd"
echo "et /etc/group"
echo "Cela permet de ne pas avoir des correspondances uid/uidNumber et gid/gidNumber"
echo "différentes entre les deux OS."

REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "$COLTXT"
	echo -e "Souhaitez-vous mettre en place ces fichiers réduits? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ "$REPONSE" = "" ]; then
		REPONSE="n"
		ERREUR "Vous avez souhaité abandonner."
	fi
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLCMD"
	cp /etc/passwd /tmp/
	cp /etc/group /tmp/
	echo "root:x:0:0:root:/root:/bin/zsh" > /etc/passwd
	echo "sshd:x:22:22:sshd:/var/empty:/dev/null" >> /etc/passwd
	echo "root::0:root" > /etc/group
	echo "sshd::22:" >> /etc/group

	echo -e "$COLINFO"
	echo "Voici les fichiers mis en place:"
	echo -e "$COLTXT"
	echo "/etc/passwd:"
	echo -e "$COLCMD\c"
	cat /etc/passwd

	echo -e "$COLTXT"
	echo "/etc/group:"
	echo -e "$COLCMD\c"
	cat /etc/group

	echo -e "$COLINFO"
	echo "Une sauvegarde des fichiers initiaux a été effectuée dans /tmp"
	echo ""
	echo "Pour mes bricolages de mirroring, il reste à:"
	echo "   - configurer le réseau: net-setup eth0"
	echo "   - mettre un mot de passe à root (passwd)"
	echo "   - démarrer le serveur SSH: /etc/init.d/sshd start"
	echo "     ou pour eviter des problemes avec NetworkManager:"
	echo "                              /etc/init.d/sshd_crob start"
fi

echo -e "${COLTITRE}"
echo "***********"
echo "* Terminé *"
echo "***********"
echo -e "${COLTXT}"
echo "Appuyez sur ENTREE pour quitter..."
read PAUSE




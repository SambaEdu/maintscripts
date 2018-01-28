#!/bin/sh

# Auteur: Stephane Boireau
# Derniere modification: 25/06/2013

source /bin/crob_fonctions.sh

t=$(grep "cle_ssh=" /proc/cmdline)
if [ -z "$t" ]; then
	exit
fi

source /proc/cmdline 2> /dev/null

ladate=$(date "+%Y%m%d%H%M%S")

echo -e "$COLTITRE"
echo "************************************"
echo "* Mise en place des cles publiques *"
echo "************************************"

echo -e "$COLCMD"
mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ "${cle_ssh:0:7}" = "http://" ]; then
	mkdir -p /root/tmp/cles_pub_${ladate}
	cd /root/tmp/cles_pub_${ladate}
	wget ${cle_ssh}
	if [ "$?" != "0" ]; then
		echo -e "$COLERREUR"
		echo "ECHEC du telechargement de ${cle_ssh}"
	else
		fich=$(basename ${cle_ssh})
		tar -xzf ${fich}
		if [ "$?" != "0" ]; then
			echo -e "$COLERREUR"
			echo "ECHEC du desarchivage de $fich"
			exit
			echo -e "$COLTXT"
		else
			find . -name "*.pub" |while read A
			do
				# La commande 'file' n'est pas presente dans slitaz
				#t=$(file $A | grep -i ": ASCII text")
				#if [ -z "$t" ]; then
				#	echo -e "$COLERREUR"
				#	echo "Fichier $A invalide."
				#else
					t=$(egrep -i "(^ssh-dss |^ssh-rsa )" $A)
					if [ -z "$t" ]; then
						echo -e "$COLERREUR"
						echo "Fichier $A invalide."
					else
						t=$(wc -l "$A" |cut -d" " -f1)
						if [ "$t" != "1" ]; then
							echo -e "$COLERREUR"
							echo "Fichier $A invalide: Plus d'une ligne."
						else
							echo -e "$COLTXT"
							echo "Ajout de la cle $A"
							echo -e "$COLCMD"
							cat $A >> /root/.ssh/authorized_keys
							chmod -R 700 /root/.ssh
						fi
					fi
				#fi
			done
		fi
	fi
else
	echo "$cle_ssh" | sed -e "s|,|\n|g" | while read A
	do
		if [ -e "/root/cles_pub_ssh/$A.pub" ]; then
			echo -e "$COLTXT"
			echo "Ajout de la cle $A"
			echo -e "$COLCMD"
			cat /root/cles_pub_ssh/$A.pub >> /root/.ssh/authorized_keys
			chmod -R 700 /root/.ssh
		fi
	done
fi

echo -e "$COLTXT"
echo "Lancement du serveur SSH"
echo -e "$COLCMD"
#/etc/init.d/sshd start
/etc/init.d/sshd_crob start
echo -e "$COLTXT"

sleep 3

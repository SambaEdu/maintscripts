#!/bin/sh

# Auteur: Stephane Boireau
# Derniere modification: 25/06/2013

#source /root/bin/crob_fonctions.sh
#source=/root/bin
#dest=/home/hacker/.ssh

source /bin/crob_fonctions.sh

source=/root
if [ -n "$1" -a -e "$1" ]; then
	dest=$1/.ssh
	mkdir -p "$dest"
else
	dest=/root/.ssh
fi

if [ -e "$source/cles_pub_ssh" ]; then
	test_cles_pub=$(ls $source/cles_pub_ssh/*.pub)
	if [ ! -z "$test_cles_pub" ]; then
		echo -e "$COLINFO"
		echo -e "Des cles publiques sont presentes."
		echo -e "Vous pouvez ajouter ces cles a la liste des identites permettant de se connecter"
		echo -e "a la station sans saisie du mot de passe en compte 'root'."
		echo -e "Si vous ignorez ce dont il s'agit, ou si vous n'etes pas certain qu'il s'agit"
		echo -e "bien de la cle publique d'une personne fiable, n'ajoutez aucune de ces cles."

		#(/root/.ssh/authorized_keys)
		echo -e "$COLTXT"
		echo "Voici la liste des cles:"
		echo -e "$COLCMD\c"
		ls $source/cles_pub_ssh/*.pub

		cle_a_ajouter=""
		if [ -n "$1" -a -e "$source/cles_pub_ssh/$1.pub" ]; then
			cle_a_ajouter=$source/cles_pub_ssh/$1.pub
			REPONSE="o"
		fi

		if [ -z "$cle_a_ajouter" ]; then
			REPONSE=""
			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
			do
				echo -e "$COLTXT"
				echo -e "Voulez-vous inserer une ou plusieurs de ces cles"
				echo -e "dans ${dest}/authorized_keys ? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
				read REPONSE
			done
		fi

		if [ "$REPONSE" = "o" ]; then
			mkdir -p ${dest}
			chmod 700 ${dest}
			#chown hacker ${dest}
			if [ -n "$cle_a_ajouter" ]; then
				echo -e "$COLTXT"
				echo -e "Ajout de la cle ${cle_a_ajouter}"
				cat ${cle_a_ajouter} >> ${dest}/authorized_keys
			else
				ls $source/cles_pub_ssh/*.pub | while read A
				do
					REPONSE=""
					while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
					do
						echo -e "$COLTXT"
						echo -e "Voulez-vous inserer ${COLINFO}${A}${COLTXT}"
						echo -e "dans ${dest}/authorized_keys ? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
						read REPONSE < /dev/tty
						if [ -z "$REPONSE" ]; then
							REPONSE="n"
						fi
					done
	
					if [ "$REPONSE" = "o" ]; then
						cat ${A} >> ${dest}/authorized_keys
					fi
				done
			fi

			if [ -e ${dest}/authorized_keys ]; then
				chmod 600 ${dest}/authorized_keys
			fi

			if [ "$2" != "PAS_DE_CONFIG_MAINTENANT" ]; then
				# Configurer le reseau
				CONFIG_RESEAU

				# Demarrer SSH
				# Le service SSH est normalement demarre avec le livecd... conditionne au succès de la config IP/DHCP lors du boot?
				echo -e "$COLTXT"
				echo "Test: Le service SSHD tourne-t-il?"
				echo -e "$COLCMD\c"
				t=$(ps aux | grep ssh|grep -v grep)
				if [ -n "$t" -a -e "/var/run/sshd.pid" ]; then
					echo $t
				else
					echo -e "$COLTXT"
					echo "Il semble que non..."

					echo -e "$COLTXT"
					echo "Lancement de SSHD..."
					echo -e "$COLCMD\c"
					#/etc/init.d/sshd start
					/etc/init.d/sshd_crob start
				fi
			fi

#			REPONSE=""
#			while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
#			do
#				echo -e "$COLTXT"
#				echo -e "Voulez-vous demarrer le serveur SSH? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}]"
#				read REPONSE
#				if [ -z "$REPONSE" ]; then
#					REPONSE="n"
#				fi
#			done

#			if [ "$REPONSE" = "o" ]; then
#				echo -e "$COLTXT"
#				echo "Demarrage du serveur SSH:"
#				echo -e "$COLCMD\c"
#				echo "/etc/init.d/dropbear start"
#				/etc/init.d/dropbear start

#				echo -e "$COLINFO"
#				echo "Le compte hacker n'a pas de mot de passe par defaut."
#				echo "Seule une connexion par cle pub/priv peut alors fonctionner."
#				echo "La connexion directe en root est par ailleurs desactivee."
#				echo "Pour acceder a cette machine, effectuez:"
#				echo "     ssh hacker@IP"
#				echo "Puis"
#				echo "     su -"
#				echo "Le mot de passe 'root' est 'root'."
#			fi
		fi
	fi
fi
echo -e "$COLTXT"


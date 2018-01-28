#!/bin/sh

# Script de configuration du client partimage (v.3)
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Dernière modification: 26/02/2013

source /bin/crob_fonctions.sh

# Pour eviter de s'embeter avec un certificat
mode_nossl="y"
if echo "$*" | grep -q "nossl=n"; then
	mode_nossl="n"
fi

clear
echo -e "$COLTITRE"
echo "***************************************************"
echo "*      Ce script doit vous aider à effectuer      *"
echo "*    la sauvegarde vers un serveur partimaged     *"
echo "* ou la restauration depuis un serveur partimaged *"
echo "***************************************************"

CONFIG_RESEAU

HD=""
while [ -z "$HD" ]
do
	AFFICHHD
	
	DEFAULTDISK=$(GET_DEFAULT_DISK)
	
	echo -e "$COLTXT"
	echo "Sur quel disque se trouve la partition à sauvegarder/restaurer?"
	echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
	echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
	read HD
	
	if [ -z "$HD" ]; then
		HD=${DEFAULTDISK}
	fi

	tst=$(sfdisk -s /dev/$HD 2>/dev/null)
	if [ -z "$tst" ]; then
		echo -e "$COLERREUR"
		echo "Le disque $HD n'existe pas."
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour corriger."
		read PAUSE
		HD=""
	fi
done

REPONSE=""
while [ "$REPONSE" != "1" ]
do
	echo -e "$COLTXT"
	echo "Voici les partitions sur le disque /dev/$HD:"
	echo -e "$COLCMD"
	#echo "fdisk -l /dev/$HD"
	#fdisk -l /dev/$HD
	LISTE_PART ${HD} afficher_liste=y
	
	#liste_tmp=($(fdisk -l /dev/$HD | grep "^/dev/$HD" | tr "\t" " " | grep -v "Linux swap" | grep -v "xtended" | grep -v "W95 Ext'd" | cut -d" " -f1))
	LISTE_PART ${HD} avec_tableau_liste=y
	if [ ! -z "${liste_tmp[0]}" ]; then
		DEFAULTPART=$(echo ${liste_tmp[0]} | sed -e "s|^/dev/||")
	else
		DEFAULTPART="hda1"
	fi
	
	echo -e "$COLTXT"
	echo "Quelle partition souhaitez-vous sauvegarder ou restaurer?"
	echo "     (ex.: hda1, hdc2,...)"
	echo -e "Partition: [${COLDEFAUT}${DEFAULTPART}${COLTXT}] $COLSAISIE\c"
	read PARTITION
	
	if [ -z "$PARTITION" ]; then
		PARTITION="${DEFAULTPART}"
	fi

	#if ! fdisk -s /dev/$PARTITION > /dev/null; then
	t=$(fdisk -s /dev/$PARTITION)
	if [ -z "$t" -o ! -e "/sys/block/$HD/$PARTITION/partition" ]; then
		echo -e "$COLERREUR"
		echo "ERREUR: La partition proposée n'existe pas!"
		echo -e "$COLTXT"
		echo "Appuyez sur ENTREE pour corriger."
		read PAUSE
		#exit 1
		REPONSE="2"
	else
		REPONSE=""
	fi

	while [ "$REPONSE" != "1" -a "$REPONSE" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre (${COLCHOIX}1${COLTXT}), ou faut-il corriger (${COLCHOIX}2${COLTXT})? [${COLDEFAUT}1${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ -z "$REPONSE" ]; then
			REPONSE="1"
		fi
	done
done

iface="eth0"
if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
	TMP_IP=$(ifconfig ${iface} | grep "inet " | cut -d":" -f2 | cut -d" " -f1)
else
	TMP_IP=$(ifconfig ${iface} | grep "inet "|sed -e "s|^ *||g"| cut -d" " -f2)
fi
oct1=$(echo "$TMP_IP"| cut -d"." -f1)
oct2=$(echo "$TMP_IP"| cut -d"." -f2)
oct3=$(echo "$TMP_IP"| cut -d"." -f3)
IPPROPOSEE="${oct1}.${oct2}.${oct3}.1"

echo -e "$COLTXT"
echo -e "Quelle est l'IP du serveur partimaged? [${COLDEFAUT}${IPPROPOSEE}${COLTXT}] $COLSAISIE\c"
read IPSER

if [ -z "$IPSER" ]; then
	IPSER=${IPPROPOSEE}
fi

echo -e "$COLTXT"
if ping -c 1 $IPSER > /dev/null; then
	echo "La machine d'IP $IPSER a répondu au ping."
else
	echo "La machine d'IP $IPSER n'a pas répondu au ping."
	echo -e "Voulez-vous tout de même poursuivre? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
	read REPONSE

	if [ "$REPONSE" != "o" ]; then
		ERREUR "Vous n'avez pas souhaité poursuivre."
	fi
fi

partimaged_options=""
if [ "$mode_nossl" = "y" -o "$mode_nossl" = "o" ]; then
	partimaged_options="${partimaged_options} -n"
fi

REPONSE=""
while [ "$REPONSE" != "r" -a "$REPONSE" != "s"  ]
do
	echo -e "$COLTXT"
	echo -e "Souhaitez-vous ${COLCHOIX}s${COLTXT}auvegarder ou ${COLCHOIX}r${COLTXT}estaurer la partition /dev/$PARTITION? (${COLCHOIX}s/r${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "s" ]; then
	VERIF=""
	while [ "$VERIF" != "c" -a "$VERIF" != "a"  ]
	do
		echo -e "$COLTXT"
		echo -e "Vous vous apprêtez à sauvegarder le contenu de la partition /dev/$PARTITION \nvers le serveur dont l'IP est $IPSER"
		echo -e "Veuillez ${ROUGE}c${COLTXT}onfirmer ou ${ROUGE}a${COLTXT}nnuler: (${COLCHOIX}c/a${COLTXT}) $COLSAISIE\c"
		read VERIF

	done

	if [ "$VERIF" = "a" ]; then
		echo -e "$COLERREUR"
		echo "ANNULATION!"
		echo -e "$COLTXT"
		exit 0
	fi

	#echo -e "$COLTXT"
	#echo -e "Quel est le nom de l'image à créer? $COLSAISIE\c"
	#read IMAGE
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel est le nom de l'image à créer? [${COLDEFAUT}sauvegarde${COLTXT}] $COLSAISIE\c"
		read IMAGE

		if [ -z "$IMAGE" ]; then
			IMAGE="sauvegarde"
		fi

		# A FAIRE: Ajouter un test sur les caract�res saisis

		POURSUIVRE_OU_CORRIGER "1"
	done


	echo -e "$COLTXT"
	echo "Voulez-vous fournir un nom d'utilisateur?"
	echo "Laisser vide si vous ne le voulez pas."
	echo -e "Nom de l'utilisateur: $COLSAISIE\c"
	read NOMUSER

	chaine=""
	if [ ! -z "$NOMUSER" ]; then
		chaine="-U${NOMUSER}"

		echo -e "$COLTXT"
		echo -e "Quel est le mot de passe de cet utilisateur?  \033[41;31m\c"
		read MDP
		echo -e "\033[0;39m                                                                                "

		if [ ! -z "$MDP" ]; then
			chaine="${chaine} -P${MDP}"
		fi
	else 
		partimaged_options="${partimaged_options} -L"
	fi

	echo -e "$COLPARTIE"
	echo "======================"
	echo " Niveau de compression "
	echo "======================"

	echo -e "$COLTXT"
	echo -e "Quel niveau de compression souhaitez-vous?"
	echo -e " - ${COLCHOIX}0${COLTXT} Aucune compression"
	echo -e " - ${COLCHOIX}1${COLTXT} Compression gzip"
	echo -e " - ${COLCHOIX}2${COLTXT} Compression bzip2"
	echo    "     (plus fort, mais ne permet pas la restauration du MBR)"
	COMPRESS=""
	while [ "$COMPRESS" != "0" -a "$COMPRESS" != "1" -a "$COMPRESS" != "2" ]
	do
		echo -e "Niveau de compression: [${COLDEFAUT}1${COLTXT}] ${COLSAISIE}\c"
		read COMPRESS

		if [ -z "$COMPRESS" ]; then
			COMPRESS=1
		fi
	done

	echo -e "$COLTXT"
	echo -e "Vous allez sauvegarder le contenu de la partition /dev/$PARTITION \nvers une image $IMAGE \nsur le serveur dont l'IP est $IPSER"
	#echo "Dernière chance d'annuler!"
	#echo -e "Taper ${COLCHOIX}OUI${COLTXT} pour confirmer: $COLSAISIE\c"
	#read LETSGO
	echo "Appuyez sur ENTREE pour poursuivre ou CTRL+C pour abandonner..."
	read PAUSE

	#if [ "$LETSGO" = "OUI" ]; then
		echo -e "$COLCMD"
		if ping -c 1 $IPSER > /dev/null; then
			partimage -z$COMPRESS -o -d save /dev/$PARTITION $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options} || ERREUR "La sauvegarde a échoué!"
		else
			echo -e "$COLERREUR"
			echo "$IPSER ne répond pas au ping."
			echo -e "Impossible de sauvegarder votre machine. \nVeuillez vérifier que votre serveur est en fonctionnement \net que votre configuration (réseau, partimaged,...) est correcte."
			echo "Relancez ensuite le présent script client."
		fi
	#else
	#	exit 0
	#fi

else
	VERIF=""
	while [ "$VERIF" != "c" -a "$VERIF" != "a"  ]
	do
		echo -e "$COLTXT"
		echo -e "Vous vous apprêtez à restaurer le contenu de la partition /dev/$PARTITION \ndepuis le serveur dont l'IP est $IPSER"
		echo -e "Veuillez ${COLCHOIX}c${COLTXT}onfirmer ou ${COLCHOIX}a${COLTXT}nnuler: (${COLCHOIX}c/a${COLTXT}) $COLSAISIE\c"
		read VERIF
	done

	if [ "$VERIF" = "a" ]; then
		echo -e "$COLERREUR"
		echo "ANNULATION!"
		echo -e "$COLTXT"
		exit 0
	fi

	IMAGE=""
	while [ -z "$IMAGE" ]
	do
		echo -e "$COLTXT"
		echo -e "Quel est le nom de l'image à restaurer? \n${COLCHOIX}NOM DE L'IMAGE${COLTXT}: [${COLDEFAUT}sauvegarde.000${COLTXT}] $COLSAISIE\c"
		read IMAGE

		if [ -z "$IMAGE" ]; then
			IMAGE="sauvegarde.000"
		fi

		# A FAIRE: Ajouter un test sur les caract�res saisis

		POURSUIVRE_OU_CORRIGER "1"
	done

	echo -e "$COLTXT"
	echo "Voulez-vous/devez-vous fournir un nom d'utilisateur?"
	echo "Laisser vide si vous ne le voulez pas."
	echo "(ce choix dépend du choix fait pour le serveur)"
	echo -e "Nom de l'utilisateur: $COLSAISIE\c"
	read NOMUSER

	chaine=""
	if [ ! -z "$NOMUSER" ]; then
		chaine="-U${NOMUSER}"

		echo -e "$COLTXT"
		echo -e "Quel est le mot de passe de cet utilisateur?  \033[41;31m\c"
		read MDP
		#echo -e "\033[0;39m                                                                                "
		echo -e "\033[0;39m                                                                                                  "

		if [ ! -z "$MDP" ]; then
			chaine="${chaine} -P${MDP}"
		fi
	else 
		partimaged_options="${partimaged_options} -L"
	fi

	echo -e "$COLTXT"
	echo -e "Vous allez restaurer le contenu de la partition /dev/$PARTITION \nd'après l'image $IMAGE \nsituée sur le serveur dont l'IP est $IPSER"
	echo "Dernière chance d'annuler!"
	echo -e "Taper ${COLCHOIX}OUI${COLTXT} pour confirmer: $COLSAISIE\c"
	read LETSGO


	if [ "$LETSGO" = "OUI" ]; then
		echo -e "$COLCMD"
		if ping -c 1 $IPSER > /dev/null; then
			echo -e "$COLTXT"
			echo -e "Faut-il restaurer le secteur de boot \nd'apres l'image $IMAGE? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE

			if [ ! -z "$NOMUSER" ]; then
				echo -e "$COLCMD"
				if [ "$REPONSE" = "o" ]; then
					#partimagessl restmbr $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options}
					partimage restmbr $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options}
					sleep 2
					sfdisk -R /dev/$HD
				fi
				#partimagessl restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options} || ERREUR "La restauration a échoué!"
				partimage restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options} || ERREUR "La restauration a échoué!"
			else
				echo -e "$COLCMD"
				if [ "$REPONSE" = "o" ]; then
					partimage restmbr $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options}
					sleep 2
					sfdisk -R /dev/$HD
				fi
				partimage restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 ${chaine} ${partimaged_options} || ERREUR "La restauration a échoué!"
			fi
		else
			echo -e "$COLERREUR"
			echo  -e "Impossible de restaurer votre machine. \nVeuillez verifier que votre serveur est en fonctionnement, \net que votre configuration (reseau, partimaged,...) est correcte."
		fi
	else
		echo -e "$COLERREUR"
		echo "ANNULATION!"
		echo -e "$COLTXT"
		exit 0
	fi
fi
echo -e "$COLTITRE"
echo "Terminé!"
echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour finir."
read PAUSE

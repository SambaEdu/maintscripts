#!/bin/sh

# Script de configuration du client partimage (v.3)
# Humblement realise par S.Boireau du RUE de Bernay/Pont-Audemer
# Derni√®re modification: 24/06/2013

source /bin/crob_fonctions.sh
source /bin/bibliotheque_ip_masque.sh

clear
echo -e "$COLTITRE"
echo "******************************************"
echo "* Ce script doit vous aider √† restaurer  *"
echo "* une image depuis un serveur partimaged *"
echo "******************************************"

CONFIG_RESEAU

if [ -e "/tmp/iface.txt" ]; then
	iface=$(cat /tmp/iface.txt)
else
	iface="eth0"
fi

# Pour rÈcupÈrer l'IP via la ligne de commande de boot:
source /proc/cmdline 2>/dev/null
if [ -n "$ip_serveur_partimaged" ]; then
	IPSER=$ip_serveur_partimaged
else
	if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
		IP=$(ifconfig ${iface} | grep "inet " | cut -d":" -f2 | cut -d" " -f1)
		MASK=$(ifconfig ${iface} | grep "inet " | cut -d":" -f4 | cut -d" " -f1)
	else
		IP=$(ifconfig ${iface} | grep "inet "|sed -e "s|^ *||g"| cut -d" " -f2)
		MASK=$(ifconfig ${iface} | grep "inet "|sed -e "s|.*netmask ||g"|cut -d" " -f1)
	fi

	NETWORK=$(calcule_reseau $IP $MASK)
	#BROADCAST=$(calcule_broadcast $IP $MASK)
	
	MASK1=$(echo $MASK|cut -d"." -f1)
	MASK2=$(echo $MASK|cut -d"." -f2)
	MASK3=$(echo $MASK|cut -d"." -f3)
	MASK4=$(echo $MASK|cut -d"." -f4)
	NUM_MASK=$(($(echo $(binaire ${MASK1})$(binaire ${MASK2})$(binaire ${MASK3})$(binaire ${MASK4})|sed -e "s|[^1]||g"|wc -c)-1))
	
	# ==================================
	# On lance une dÈtection du serveur:
	ladate=$(date +%Y%m%d%H%M%S)
	echo 'echo $$ > /tmp/recherche_serveur_partimaged_${1}.pid
nmap -oG /tmp/recherche_serveur_partimaged_${1}.txt -p 4025 '$NETWORK'/'$NUM_MASK' 1&>2 /dev/null
' > /tmp/detection_serveur_partimaged.sh
	chmod +x /tmp/detection_serveur_partimaged.sh
	sh /tmp/detection_serveur_partimaged.sh ${ladate} 2>/dev/null &
	# ==================================
	
	echo -e "$COLINFO"
	echo "Il est possible de tenter de detecter le serveur partimaged en recherchant les"
	echo "machines qui auraient le port 4025 ouvert."
	echo "Cette recherche peut etre un peu longue (~30s pour un reseau de classe C) et la"
	echo "detection semble mieux fonctionner quand le serveur est en debut de plage"
	echo "d'apres ce que j'ai observe en vmware."
	
	REP=""
	while [ "${REP}" != "1" -a "${REP}" != "2" ]
	do
		echo -e "$COLTXT"
		echo -e "Voulez-vous tenter une detection du serveur partimaged (${COLCHOIX}1${COLTXT})"
		echo -e "ou preferez-vous saisir l'IP du serveur partimaged (${COLCHOIX}2${COLTXT}) ? [${COLDEFAUT}2${COLTXT}] $COLSAISIE\c"
		read REP
	
		if [ -z "$REP" ]; then
			REP=2
		fi
	done
	
	if [ "$REP" = "1" ]; then
		FICH=/tmp/recherche_serveur_partimaged_${ladate}.pid
	
		echo -e "$COLTXT"
		echo -e "   Patience... la detection est lancee... ${COLINFO}\c"
		t=0
		TEMOIN=0
		while [ "$TEMOIN" = "0" ]
		do
			if [ "$(ps -p $(cat $FICH) | wc -l)" = "1" ]; then
				# Le processus de recherche s'est achevÈ.
				TEMOIN=1
			fi
			t=$(($t+1))
			echo -en "\r$t "
			sleep 1
		done
	
		echo -e "$COLTXT"
		echo "Le processus de recherche s'est achevÈ:"
		echo -e "$COLCMD"
		grep "Ports: 4025/open" /tmp/recherche_serveur_partimaged_${ladate}.txt

		#IPPROPOSEE=$(grep "Ports: 4025/open" /tmp/recherche_serveur_partimaged_${ladate}.txt | cut -d" " -f2)
		IPPROPOSEE=$(grep "Ports: 4025/open" /tmp/recherche_serveur_partimaged_${ladate}.txt | head -n1|cut -d" " -f2)
	
		if [ -z "$IPPROPOSEE" ]; then
			echo "Aucun serveur n'a ÈtÈ dÈtectÈ."
			REP="2"
		fi
	fi
	
	if [ "$REP" = "2" ]; then
		if [ "${ifconfig}" = "/sbin/ifconfig" ]; then
			TMP_IP=$(ifconfig ${iface} | grep "inet " | cut -d":" -f2 | cut -d" " -f1)
		else
			TMP_IP=$(ifconfig ${iface} | grep "inet "|sed -e "s|^ *||g"| cut -d" " -f2)
		fi
		oct1=$(echo "$TMP_IP"| cut -d"." -f1)
		oct2=$(echo "$TMP_IP"| cut -d"." -f2)
		oct3=$(echo "$TMP_IP"| cut -d"." -f3)
		IPPROPOSEE="${oct1}.${oct2}.${oct3}.1"
	fi
fi

# Pour faire au moins un tour dans la boucle (pour tÈlÈcharger les paramËtres) mÍme si IPSER a ÈtÈ passÈe via /proc/cmdline
PREMIER_PASSAGE="o"
while [ -z "$IPSER" -o "$PREMIER_PASSAGE" = "o" ]
do
	PREMIER_PASSAGE="n"

	if [ -z "$IPSER" ]; then
		echo -e "$COLTXT"
		echo -e "Quelle est l'IP du serveur partimaged? [${COLDEFAUT}${IPPROPOSEE}${COLTXT}] $COLSAISIE\c"
		read IPSER
	
		if [ -z "$IPSER" ]; then
			IPSER=${IPPROPOSEE}
		fi
	fi

	echo -e "$COLTXT"
	if ping -c 1 $IPSER > /dev/null; then
		echo "La machine d'IP $IPSER a r√©pondu au ping."

		sleep 1
	else
		echo "La machine d'IP $IPSER n'a pas r√©pondu au ping."
		echo -e "Voulez-vous tout de m√™me poursuivre avec cette IP? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
		read REPONSE

		if [ "$REPONSE" != "o" ]; then
			#ERREUR "Vous n'avez pas souhait√© poursuivre."
			IPSER=""
			# On va proposer de saisir une autre IP
		fi
	fi

	if [ -n "$IPSER" ]; then
		echo -e "$COLTXT"
		echo "Tentative de r√©cup√©ration des parametres de l'op√©ration."
		echo -e "$COLCMD\c"
		ladate=$(date "+%Y%m%d-%H%M%S")
		doss_tmp=/tmp/restauration_partimaged_${ladate}
		mkdir -p ${doss_tmp}
		chmod 700 ${doss_tmp}
		cd ${doss_tmp}
		wget http://$IPSER/parametres.txt
		if [ ! -e "parametres.txt" ]; then
			echo -e "$COLERREUR"
			echo "La r√©cup√©ration du fichier de parametres a √©chou√©."
	
			# Proposer de choisir une autre IP
			IPSER=""
	
		else
			PARTITION=$(grep "^PARTITION=" parametres.txt | cut -d"=" -f2)
			PARTTABLE=$(grep "^PARTTABLE=" parametres.txt | cut -d"=" -f2)
			IMAGE=$(grep "^IMAGE=" parametres.txt | cut -d"=" -f2)

			partimaged_user=$(grep "^partimaged_user=" parametres.txt | cut -d"=" -f2)
			partimaged_pass=$(grep "^partimaged_pass=" parametres.txt | cut -d"=" -f2)
			mode_nossl=$(grep "^mode_nossl=" parametres.txt | cut -d"=" -f2)

			sleep 1
	
			if [ -n "$PARTTABLE" ]; then
				echo -e "$COLTXT"
				echo -e "Tentative de r√©cup√©ration de la table de partitions: ${COLINFO}$PARTTABLE"
				echo -e "$COLCMD\c"
				wget http://$IPSER/$PARTTABLE
	
				sleep 1
	
				if [ ! -e "$PARTTABLE" ]; then
					echo -e "$COLERREUR"
					echo "La r√©cup√©ration du fichier $PARTTABLE a √©chou√©."
					echo "On ne controlera pas si les partitions coincident."
				else
					HD=$(grep "^# partition table of /dev/" $PARTTABLE | cut -d"/" -f3)
	
					t=$(sfdisk -s /dev/$HD 2> /dev/null)
					#if [ -n "$HD" -a -n "$t" ]; then
					#	tmp_date=$(date +%Y%m%d%H%M%S)
					#	sfdisk -d /dev/${HD} > /tmp/${HD}.${tmp_date}.out
					#else
					if [ -z "$HD" -o -z "$t" ]; then
	
						AFFICHHD
	
						DEFAULTDISK=$(GET_DEFAULT_DISK)

						HD=""
						while [ -z "$HD" ]
						do
							echo -e "$COLTXT"
							echo "Sur quel disque se trouve la partition √† restaurer?"
							echo "    (ex.: hda, hdb, hdc, hdd, sda, sdb, sdc, sdd)"
							echo -e "Disque: [${COLDEFAUT}${DEFAULTDISK}${COLTXT}] $COLSAISIE\c"
							read HD
		
							if [ -z "$HD" ]; then
								HD=${DEFAULTDISK}
							fi

							t=$(sfdisk -s /dev/$HD 2> /dev/null)
							if [ -z "$t" ]; then
								echo -e "${COLERREUR}"
								echo -e "Il semble que le disque choisi n'existe pas.${COLTXT}"
								HD=""
							fi
						done
					fi

					tmp_date=$(date +%Y%m%d%H%M%S)
					HD_CLEAN=$(echo ${HD}|sed -e "s|[^0-9A-Za-z]|_|g")
					fdisk -l /dev/$HD > /tmp/fdisk_l_${HD_CLEAN}.txt 2>&1
					#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${HD}'" /tmp/fdisk_l_${HD_CLEAN}.txt|cut -d"'" -f2)

					if [ "$(IS_GPT_PARTTABLE ${HD})" = "y" ]; then
						TMP_disque_en_GPT=/dev/${HD}
					else
						TMP_disque_en_GPT=""
					fi

					if [ -z "$TMP_disque_en_GPT" ]; then
						sfdisk -d /dev/${HD} > /tmp/${HD}.${tmp_date}.out
						test_diff=$(diff -abB /tmp/${HD}.${tmp_date}.out $PARTTABLE)
					else
						sgdisk -b /tmp/gpt_${HD}.${tmp_date}.out /dev/${HD}
						test_diff=$(diff -abB /tmp/gpt_${HD}.${tmp_date}.out $PARTTABLE)
					fi
	
					if [ ! -z "${test_diff}" ]; then
						echo -e "$COLTXT"
						echo "Votre table de partition ne coincide pas avec celle de la sauvegarde."
						if [ -z "$TMP_disque_en_GPT" ]; then
							echo "La table de partition locale est:"
							echo -e "$COLCMD\c"
							cat /tmp/${HD}.${tmp_date}.out
	
							echo -e "$COLTXT"
							echo "La table de partition correspondant √† la sauvegarde est:"
							echo -e "$COLCMD\c"
							cat $PARTTABLE
						fi
						DEFAUT_REFAIRE_PART="o"
					else
						echo -e "$COLTXT"
						echo "La table de partitions locale et la table sauvegard√©e sont identiques."
						echo "La restauration de la table parait inutile."
	
						DEFAUT_REFAIRE_PART="n"
					fi
	
					REPONSE=""
					while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
					do
						echo -e "$COLTXT"
						echo -e "Voulez-vous refaire la table de partition? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}${DEFAUT_REFAIRE_PART}${COLTXT}] $COLSAISIE\c"
						read REPONSE
	
						if [ -z "$REPONSE" ]; then
							REPONSE=${DEFAUT_REFAIRE_PART}
						fi
					done
	
					echo -e "$COLCMD"
					if [ "$REPONSE" = "o" ]; then
						echo -e "$COLTXT"
						echo "Restauration de la table de partition..."
						echo -e "$COLCMD"
						sleep 1
						if [ -z "$TMP_disque_en_GPT" ]; then
							sfdisk /dev/$HD < $PARTTABLE
						else
							sgdisk -l $PARTTABLE /dev/$HD
						fi

						if [ "$?" != "0" ]; then
							echo -e "$COLERREUR"
							echo "Une erreur s est semble-t-il produite."
							if [ -z "$TMP_disque_en_GPT" ]; then
								REPONSE=""
								while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
								do
									echo -e "$COLTXT"
									echo -e "Voulez-vous forcer le repartitionnement avec l option -f de sfdisk? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
									read REPONSE
								done
	
								echo -e "$COLCMD"
								if [ "$REPONSE" = "o" ]; then
	
									sfdisk -f /dev/$HD < $PARTTABLE
	
								fi
							fi
						fi
					else
						echo -e "$COLTXT"
						echo "On ne modifie pas la table de partition."
					fi
				fi
			else
				echo -e "${COLERREUR}"
				echo -e "ATTENTION:${COLINFO}"
				if [ -z "$TMP_disque_en_GPT" ]; then
					echo "Aucun fichier table de partition (obtenu par sfdisk -d /dev/\$HD > \$HD.out)"
				else
					echo "Aucun fichier table de partition (obtenu par sgdisk -b \$HD.out /dev/\$HD)"
				fi
				echo "n'a ÈtÈ trouvÈ sur le serveur."
				echo "La restauration d'une partition ne pourra fonctionner que si les partitions"
				echo "avaient des tailles compatibles."
			fi
		fi
	fi
done

if [ -z "$HD" ]; then
	HD=""
	while [ -z "$HD" ]
	do
		AFFICHHD
	
		DEFAULTDISK=$(GET_DEFAULT_DISK)
	
		echo -e "$COLTXT"
		echo "Sur quel disque se trouve la partition √† restaurer?"
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
fi

if [ -z "$PARTITION" ]; then
	REPONSE=""
	while [ "$REPONSE" != "1" ]
	do
		echo -e "$COLTXT"
		echo "Voici les partitions sur le disque /dev/$HD:"
		echo -e "$COLCMD"
		echo "fdisk -l /dev/$HD"
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
		echo "Quelle partition souhaitez-vous restaurer?"
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
			echo "ERREUR: La partition propos√©e n'existe pas!"
			echo -e "$COLTXT"
			read PAUSE
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
fi


echo -e "$COLTXT"
echo "R√©capitulatif: Voici les partitions sur le disque /dev/$HD:"
echo -e "$COLCMD\c"
#echo "fdisk -l /dev/$HD"
#fdisk -l /dev/$HD
LISTE_PART ${HD} afficher_liste=y

echo -e "$COLTXT"
echo -e "Vous vous appr√™tez √† restaurer le contenu de la partition ${COLINFO}/dev/${PARTITION}${COLTXT}"
echo -e "d'apres l'image ${COLINFO}${IMAGE}${COLTXT}"
echo -e "situ√©e sur le serveur dont l'IP est ${COLINFO}${IPSER}${COLTXT}"

VERIF=""
while [ "$VERIF" != "c" -a "$VERIF" != "a"  ]
do
	echo -e "$COLTXT"
	echo -e "Veuillez ${COLCHOIX}c${COLTXT}onfirmer ou ${COLCHOIX}a${COLTXT}nnuler: (${COLCHOIX}c/a${COLTXT}) [${COLDEFAUT}c${COLTXT}] $COLSAISIE\c"
	read VERIF

	if [ -z "$VERIF" ]; then
		VERIF="c"
	fi
done

if [ "$VERIF" = "a" ]; then
	echo -e "$COLERREUR"
	echo "ANNULATION!"
	echo -e "$COLTXT"
	sleep 3
	exit 0
fi

# ===========================================================================

if [ "$mode_nossl" = "y" ]; then
	partimage_options=" -n"
fi

# ===========================================================================
REPONSE=""
# Je dÈsactive cette section
# Le resultat que j'obtiens lors des tests est sinon est systËme non bootable
REPONSE="n"
while [ "$REPONSE" != "o" -a "$REPONSE" != "n"  ]
do
	echo -e "$COLTXT"
	echo -e "Faut-il restaurer le secteur de boot \nd'apres l'image $IMAGE? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "$COLTXT"
	echo "Restauration du secteur de boot..."
	echo -e "$COLCMD\c"
	if [ -n "$partimaged_user" -a -n "$partimaged_pass" ]; then
		echo "partimage restmbr $IMAGE -s$IPSER -b -f3 ${chaine} -U${partimaged_user} -P${partimaged_pass} ${partimage_options}"
		sleep 1
		partimage restmbr $IMAGE -s$IPSER -b -f3 ${chaine} -U${partimaged_user} -P${partimaged_pass} ${partimage_options}
	else
		echo "partimage restmbr $IMAGE -s$IPSER -b -f3 ${chaine} ${partimage_options}"
		sleep 1
		partimage restmbr $IMAGE -s$IPSER -b -f3 ${chaine} ${partimage_options}
	fi
	sleep 1
	echo "sfdisk -R /dev/$HD"
	sfdisk -R /dev/$HD
	sleep 1
fi
# ===========================================================================

echo -e "$COLTXT"
echo "Restauration de l'image..."
echo -e "$COLCMD\c"
if [ -n "$partimaged_user" -a -n "$partimaged_pass" ]; then
	echo "partimage restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 -U${partimaged_user} -P${partimaged_pass} ${partimage_options}"
	sleep 1
	partimage restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 -U${partimaged_user} -P${partimaged_pass} ${partimage_options} || ERREUR "La restauration a √©chou√©!"
else
	echo "partimage restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 ${partimage_options}"
	sleep 1
	partimage restore /dev/$PARTITION $IMAGE -s$IPSER -b -f3 ${partimage_options} || ERREUR "La restauration a √©chou√©!"
fi

echo -e "$COLINFO"
echo "Si le secteur de boot comportait un chargeur de d√©marrage LILO/GRUB"
echo "et que le Linux n'est plus pr√©sent, il faut penser √† 'nettoyer'"
echo "le secteur de boot."
REPONSE=""
while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Faut-il 'nettoyer' le secteur de boot? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] ${COLSAISIE}\c"
	read REPONSE

	if [ -z "$REPONSE" ]; then
		REPONSE="n"
	fi
done

if [ "$REPONSE" = "o" ]; then
	echo -e "${COLTXT}"
	echo "Nettoyage du secteur de boot."
	echo -e "${COLCMD}\c"
	install-mbr /dev/$HD
fi

echo -e "$COLTITRE"
echo "Termin√©!"
echo -e "$COLTXT"
echo "Appuyez sur ENTREE pour finir."
read PAUSE

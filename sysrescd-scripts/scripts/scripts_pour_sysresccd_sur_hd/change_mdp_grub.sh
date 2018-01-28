#!/bin/bash

# Script de changement de mot de passe GRUB:
# Version du: 19/05/2012

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
echo "***********************************"
echo "* Changement du mot de passe GRUB *"
echo "***********************************"

# Pour eliminer les options ar_nowait,... qui ne permettent pas de d�finir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

fichier_conf=/boot/grub/menu.lst

CHANGE_MDP_LINUX() {
	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	NOUVEAU_MDP=$1

	if [ ! -z "$NOUVEAU_MDP" ]; then
		MD5_NOUVEAU_MDP=$(echo -e "md5crypt\n${NOUVEAU_MDP}" | grub --batch 2> /dev/null | grep "Encrypted" | sed -e 's/Encrypted: //g')
	fi

	if [ ! -z "$NOUVEAU_MDP" ]; then
		if cat ${fichier_conf} | grep "password" | grep "#linux" > /dev/null; then
			sed -r 's|(password --md5 ).*( #linux)|\1'$MD5_NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}
		else
			sed -r 's|^(title)( *)(Linux)|\1\2\3\npassword --md5 '$MD5_NOUVEAU_MDP' #linux|' ${fichier_conf}.${ladate} > ${fichier_conf}
			mv ${fichier_conf} ${fichier_conf}.${ladate}
			t=$(grep "# MDP GRUB:" ${fichier_conf}.${ladate})
			if [ -n "$t" ]; then
				sed -r 's|^(# MDP GRUB:)|\1\npassword --md5 '$MD5_NOUVEAU_MDP' #linux|' ${fichier_conf}.${ladate} > ${fichier_conf}
			else
				sed -r 's|^(default .*)|\1\n# MDP GRUB:\npassword --md5 '$MD5_NOUVEAU_MDP' #linux|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#linux" > /dev/null; then
			sed -e "/password --md5 .* #linux/d" ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	fi

	if [ "$?" != "0" ]; then
		echo -e "${COLERREUR}Il s'est produit une erreur. Restauration du fichier precedent."
		echo -e "${COLCMD}\c"
		cp ${fichier_conf}.${ladate} ${fichier_conf}
	fi
}

CHANGE_MDP_SAUVE() {
	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	NOUVEAU_MDP=$1

	if [ ! -z "$NOUVEAU_MDP" ]; then
		MD5_NOUVEAU_MDP=$(echo -e "md5crypt\n${NOUVEAU_MDP}" | grub --batch 2> /dev/null | grep "Encrypted" | sed -e 's/Encrypted: //g')
	fi

	if [ ! -z "$NOUVEAU_MDP" ]; then
		if cat ${fichier_conf} | grep "password" | grep "#sauve" > /dev/null; then
			sed -r 's|(password --md5 ).*( #sauve)|\1'$MD5_NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}
		else
			sed -r 's|^(title)( *)(Sauvegarde)|\1\2\3\npassword --md5 '$MD5_NOUVEAU_MDP' #sauve|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#sauve" > /dev/null; then
			sed -e "/password --md5 .* #sauve/d" ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	fi

	if [ "$?" != "0" ]; then
		echo -e "${COLERREUR}Il s'est produit une erreur. Restauration du fichier precedent."
		echo -e "${COLCMD}\c"
		cp ${fichier_conf}.${ladate} ${fichier_conf}
	fi
}

CHANGE_MDP_RESTAURE() {
	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	NOUVEAU_MDP=$1

	if [ ! -z "$NOUVEAU_MDP" ]; then
		MD5_NOUVEAU_MDP=$(echo -e "md5crypt\n${NOUVEAU_MDP}" | grub --batch 2> /dev/null | grep "Encrypted" | sed -e 's/Encrypted: //g')
	fi

	if [ ! -z "$NOUVEAU_MDP" ]; then
		if cat ${fichier_conf} | grep "password" | grep "#restaure" > /dev/null; then
			sed -r 's|(password --md5 ).*( #restaure)|\1'$MD5_NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}
		else
			sed -r 's|^(title)( *)(Restauration)|\1\2\3\npassword --md5 '$MD5_NOUVEAU_MDP' #restaure|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#restaure" > /dev/null; then
			sed -e "/password --md5 .* #restaure/d" ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	fi

	if [ "$?" != "0" ]; then
		echo -e "${COLERREUR}Il s'est produit une erreur. Restauration du fichier precedent."
		echo -e "${COLCMD}\c"
		cp ${fichier_conf}.${ladate} ${fichier_conf}
	fi
}

if [ "$change_mdp" = "auto" ]; then
	if [ -n "$mdp_linux" ]; then
		echo -e "$COLTXT"
		echo "Changement du mot de passe SysRescCD"
		echo -e "$COLCMD\c"
		CHANGE_MDP_LINUX "$mdp_linux"
	fi
	if [ -n "$mdp_sauve" ]; then
		echo -e "$COLTXT"
		echo "Changement du mot de passe SysRescCD sauve"
		echo -e "$COLCMD\c"
		CHANGE_MDP_SAUVE "$mdp_sauve"
	fi
	if [ -n "$mdp_restaure" ]; then
		echo -e "$COLTXT"
		echo "Changement du mot de passe SysRescCD restaure"
		echo -e "$COLCMD\c"
		CHANGE_MDP_RESTAURE "$mdp_restaure"
	fi
else
	REPONSE="o"
	while [ "$REPONSE" = "o" ]
	do
		QUELMDP=""
		while [ "$QUELMDP" != "1" -a "$QUELMDP" != "2" -a "$QUELMDP" != "3" ]
		do
			echo -e "${COLTXT}"
			echo -e "Vous pouvez changer le mot de passe de:"
			echo -e " (${COLCHOIX}1${COLTXT}) boot sous Linux sans pré-selection\c"
			#if cat /etc/lilo.conf | grep "password" | grep "#sauve" > /dev/null; then
			tst=$(grep "^title" ${fichier_conf} | grep "Sauvegarde")
			if [ -n "$tst" ]; then
				echo -e ","
				echo -e " (${COLCHOIX}2${COLTXT}) boot sous Linux avec lancement du script de sauvegarde\c"
			fi
			#if cat /etc/lilo.conf | grep "label=restaure" > /dev/null; then
			tst=$(grep "^title" ${fichier_conf} | grep "Restauration")
			if [ -n "$tst" ]; then
				echo -e ","
				echo -e " (${COLCHOIX}3${COLTXT}) boot sous Linux avec lancement du script de restauration."
			fi
	
			echo -e "${COLTXT}"
			echo -e "Quel mot de passe souhaitez-vous changer/définir? $COLSAISIE\c"
			read QUELMDP
		done
	
	
		echo -e "$COLINFO"
		#echo -e "Veuillez éviter dans votre mot de passe les espaces, les accents, les caractères"
		#echo -e "spéciaux qui pourraient ne pas être disponibles sur le clavier minimal chargé"
		#echo -e "lors de l affichage de LILO."
		echo "Le clavier chargé lors du boot est assez limité."
		echo "Veuillez vous limiter à un mot de passe alphanumérique."
	
		SUITE="n"
		while [ "${SUITE}" = "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Veuillez saisir le nouveau mot de passe: $COLSAISIE\c"
			read NOUVEAU_MDP
	
			test=$(echo "${NOUVEAU_MDP}" | sed -e "s/[0-9A-Za-z]//g")
			if [ ! -z "$test" ]; then
				echo -e "${COLERREUR}"
				echo "Des caractères susceptibles de ne pas être disponibles au niveau de GRUB"
				echo "ont été saisis."
				SUITE="n"
			else
				SUITE="o"
			fi
		done
	
		if [ ! -z "$NOUVEAU_MDP" ]; then
			MD5_NOUVEAU_MDP=$(echo -e "md5crypt\n${NOUVEAU_MDP}" | grub --batch 2> /dev/null | grep "Encrypted" | sed -e 's/Encrypted: //g')
		fi
	
		echo -e "${COLTXT}"
		echo -e "Modification du mot de passe..."
		echo -e "${COLCMD}\c"
		case  $QUELMDP in
			1)
				CHANGE_MDP_LINUX "$NOUVEAU_MDP"
			;;
			2)
				CHANGE_MDP_SAUVE "$NOUVEAU_MDP"
			;;
			3)
				CHANGE_MDP_RESTAURE "$NOUVEAU_MDP"
			;;
		esac
	
		echo -e "$COLINFO"
		echo -e "Modification terminée!"
	
		REPONSE=""
		while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
		do
			echo -e "${COLTXT}"
			echo -e "Voulez-vous modifier un autre mot de passe? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
			read REPONSE
		done
	done
fi

# Modification des droits pour le cas ou on met des mots de passe.
chmod 600 ${fichier_conf}

#echo -e "${COLTXT}"
#echo "Réinstallation de LILO dans le MBR:"
#echo -e "${COLCMD}"
#lilo

echo -e "$COLINFO"
echo -e "Des copies de sauvegarde du ${fichier_conf} ont été effectuées."
echo -e "Ces fichiers étaient destinés à vous permettre de revenir à une version"
echo -e "antérieure du fichier de configuration en cas de pépin lors des modifications"
echo -e "de mots de passe."
echo -e "Ces fichiers contiennent peut-être des mots de passe."
echo -e "Vous pouvez souhaiter ne pas laisser de trace des anciens mots de passe."

REPONSE=""
if [ "$change_mdp" = "auto" ]; then
	if [ "$cacher_mdp" = "y" ]; then
		REPONSE="o"
	else
		REPONSE="n"
	fi
fi
if [ "$change_mdp" = "auto" ]; then
	REPONSE="n"
fi

while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
do
	echo -e "${COLTXT}"
	echo -e "Voulez-vous supprimer les fichiers de sauvegarde des versions précédentes"
	echo -e "du ${fichier_conf}? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
	read REPONSE
done

if [ "$REPONSE" = "o" ]; then
	echo -e "${COLTXT}"
	echo -e "Suppression des fichiers ${fichier_conf}.*"
	echo -e "${COLCMD}\c"
	rm -f ${fichier_conf}.*
fi

echo -e "${COLTITRE}"
echo "Terminé."
echo -e "${COLTXT}"

if [ -z "$delais_reboot" ]; then
	# Pour etre sur que le nettoyage de tache ait le temps de passer
	delais_reboot=120
fi

t=$(grep "auto_reboot=y" /proc/cmdline)
if [ -n "$t" -a "$work" = "change_mdp_grub.sh" ]; then
	echo -e "$COLTXT"
	#echo "Reboot dans $delais_reboot secondes..."
	#sleep $delais_reboot
	COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes..."
	reboot
fi

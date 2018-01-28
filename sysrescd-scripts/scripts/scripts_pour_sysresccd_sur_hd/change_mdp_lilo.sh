#!/bin/bash

# Script de changement de mot de passe LILO:
# Version du: 05/04/2014

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
echo "* Changement du mot de passe LILO *"
echo "***********************************"

fichier_conf=/etc/lilo.conf

# Pour eliminer les options ar_nowait,... qui ne permettent pas de d�finir des variables
cat /proc/cmdline | sed -e "s| |\n|g" | grep "=" > /tmp/tmp_proc_cmdline.txt
source /tmp/tmp_proc_cmdline.txt

REPONSE="o"

temoin_mdp_anonyme="n"
if grep -q "password=XXXXX" ${fichier_conf}; then
	echo -e "$COLERREUR"
	echo -e "ATTENTION: Le fichier ${fichier_conf} contient un ou des mots de passe anonymes."
	echo -e "           Si vous reinstallez LILO, il est indispensable de redefinir/changer"
	echo -e "           les mots de passe pour les choix:"
	echo -e "$COLCMD\c"
	grep "password=XXXXX" ${fichier_conf} | sed -e "s/password=XXXXX #//"

	temoin_mdp_anonyme="y"
fi

#t_mdp_linux=$(grep "mdp_linux=" /proc/cmdline|cut -d"=" -f2|cut -d" " -f1)
#t_mdp_sauve=$(grep "mdp_sauve=" /proc/cmdline|cut -d"=" -f2|cut -d" " -f1)
#t_mdp_restaure=$(grep "mdp_restaure=" /proc/cmdline|cut -d"=" -f2|cut -d" " -f1)

t_mdp_linux=$(grep "mdp_linux=" /proc/cmdline)
t_mdp_sauve=$(grep "mdp_sauve=" /proc/cmdline)
t_mdp_restaure=$(grep "mdp_restaure=" /proc/cmdline)

if [ "$change_mdp" = "auto" -a -z "$t_mdp_linux" -a -z "$t_mdp_sauve" -a -z "$t_mdp_restaure" ]; then
	echo -e "${COLERREUR}En mode change_mdp=auto, un mot de passe au moins doit etre fourni."
	temoin_erreur="y"
fi

if [ "$change_mdp" = "auto" -a "$temoin_mdp_anonyme" = "y" ]; then
	if [ -z "$t_mdp_linux" -o -z "$t_mdp_sauve" -o -z "$t_mdp_restaure" ]; then
		echo -e "${COLERREUR}En mode change_mdp=auto, si des mots de passe ont ete anonymes, tous les mots de passe doivent etre fournis (mot de passe linux, mot de passe sauve et mot de passe restaure)."
		temoin_erreur="y"
	fi
fi

CHANGE_MDP_LINUX() {
	NOUVEAU_MDP=$1

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #linux)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#linux" > /dev/null; then
			sed -r 's|(label=Linux)|\1\npassword='$NOUVEAU_MDP' #linux|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#linux" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#linux" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #linux" > ${fichier_conf}
		fi
	fi

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #lin_alt)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Lin_alt" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#lin_alt" > /dev/null; then
				sed -r 's|(label=Lin_alt)|\1\npassword='$NOUVEAU_MDP' #lin_alt|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#lin_alt" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#lin_alt" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #lin_alt" > ${fichier_conf}
		fi
	fi

	# ============================================

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #lin_std)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#lin_std" > /dev/null; then
			sed -r 's|(label=Lin_std)|\1\npassword='$NOUVEAU_MDP' #lin_std|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#lin_std" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#lin_std" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #lin_std" > ${fichier_conf}
		fi
	fi

	# ============================================

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #lin_std64)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#lin_std64" > /dev/null; then
			sed -r 's|(label=Lin_std64)|\1\npassword='$NOUVEAU_MDP' #lin_std64|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#lin_std64" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#lin_std64" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #lin_std64" > ${fichier_conf}
		fi
	fi

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #lin_alt64)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Lin_alt64" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#lin_alt64" > /dev/null; then
				sed -r 's|(label=Lin_alt)|\1\npassword='$NOUVEAU_MDP' #lin_alt64|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#lin_alt64" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#lin_alt64" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #lin_alt64" > ${fichier_conf}
		fi
	fi

}

CHANGE_MDP_SAUVE() {
	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	NOUVEAU_MDP=$1

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #sauve)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#sauve" > /dev/null; then
			sed -r 's|(label=sauve)|\1\npassword='$NOUVEAU_MDP' #sauve|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#sauve" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#sauve" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #sauve" > ${fichier_conf}
		fi
	fi

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #svg_alt)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Svg_alt" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#svg_alt" > /dev/null; then
				sed -r 's|(label=Svg_alt)|\1\npassword='$NOUVEAU_MDP' #svg_alt|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#svg_alt" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#svg_alt" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #svg_alt" > ${fichier_conf}
		fi
	fi

	# ============================================

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #svg_std)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Svg_std" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#svg_std" > /dev/null; then
				sed -r 's|(label=Svg_std)|\1\npassword='$NOUVEAU_MDP' #svg_std|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#svg_std" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#svg_std" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #svg_std" > ${fichier_conf}
		fi
	fi

	# ============================================

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #svg_std64)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#svg_std64" > /dev/null; then
			sed -r 's|(label=Svg_std64)|\1\npassword='$NOUVEAU_MDP' #svg_std64|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#svg_std64" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#svg_std64" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #svg_std64" > ${fichier_conf}
		fi
	fi

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #svg_alt64)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Svg_alt64" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#svg_alt64" > /dev/null; then
				sed -r 's|(label=Svg_alt64)|\1\npassword='$NOUVEAU_MDP' #svg_alt64|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#svg_alt64" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#svg_alt64" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #svg_alt64" > ${fichier_conf}
		fi
	fi

}

CHANGE_MDP_RESTAURE() {
	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	NOUVEAU_MDP=$1

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #restaure)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#restaure" > /dev/null; then
			sed -r 's|(label=restaure)|\1\npassword='$NOUVEAU_MDP' #restaure|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#restaure" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#restaure" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #restaure" > ${fichier_conf}
		fi
	fi

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #rst_alt)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Rst_alt" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#rst_alt" > /dev/null; then
				sed -r 's|(label=Rst_alt)|\1\npassword='$NOUVEAU_MDP' #rst_alt|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#rst_alt" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#rst_alt" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #rst_alt" > ${fichier_conf}
		fi
	fi

	# ============================================================

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #rst_std)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#rst_std" > /dev/null; then
			sed -r 's|(label=Rst_std)|\1\npassword='$NOUVEAU_MDP' #rst_std|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#rst_std" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#rst_std" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #rst_std" > ${fichier_conf}
		fi
	fi

	sleep 2

	# ============================================================

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #rst_std64)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if ! grep "password" ${fichier_conf} | grep "#rst_std64" > /dev/null; then
			sed -r 's|(label=Rst_std64)|\1\npassword='$NOUVEAU_MDP' #rst_std64|' ${fichier_conf}.${ladate} > ${fichier_conf}
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#rst_std64" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#rst_std64" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #rst_std64" > ${fichier_conf}
		fi
	fi

	sleep 2

	ladate=$(date "+%Y_%m_%d-%HH%MMIN%SS")
	cp ${fichier_conf} ${fichier_conf}.${ladate}
	chmod 700 ${fichier_conf}.${ladate}

	if [ ! -z "$NOUVEAU_MDP" ]; then
		sed -r 's|(password=).*( #rst_alt64)|\1'$NOUVEAU_MDP'\2|' ${fichier_conf}.${ladate} > ${fichier_conf}

		if grep -q "label=Rst_alt64" ${fichier_conf}; then
			if ! grep "password" ${fichier_conf} | grep "#rst_alt64" > /dev/null; then
				sed -r 's|(label=Rst_alt)|\1\npassword='$NOUVEAU_MDP' #rst_alt64|' ${fichier_conf}.${ladate} > ${fichier_conf}
			fi
		fi
	else
		if cat ${fichier_conf} | grep "password" | grep "#rst_alt64" > /dev/null; then
			ANCIEN_MDP=$(cat ${fichier_conf} | grep "password" | grep "#rst_alt64" | cut -d"=" -f2 | cut -d" " -f1 | head -n1)
			cat ${fichier_conf}.${ladate} | grep -v "password=$ANCIEN_MDP #rst_alt64" > ${fichier_conf}
		fi
	fi
}


if [ "$temoin_erreur" != "y" ]; then
	if [ "$change_mdp" = "auto" ]; then
		if [ -n "$t_mdp_linux" ]; then
			echo -e "$COLTXT"
			echo "Changement du mot de passe SysRescCD"
			echo -e "$COLCMD\c"
			CHANGE_MDP_LINUX "$mdp_linux"
		fi
		if [ -n "$t_mdp_sauve" ]; then
			echo -e "$COLTXT"
			echo "Changement du mot de passe SysRescCD sauve"
			echo -e "$COLCMD\c"
			CHANGE_MDP_SAUVE "$mdp_sauve"
		fi
		if [ -n "$t_mdp_restaure" ]; then
			echo -e "$COLTXT"
			echo "Changement du mot de passe SysRescCD restaure"
			echo -e "$COLCMD\c"
			CHANGE_MDP_RESTAURE "$mdp_restaure"
		fi
	else
		while [ "$REPONSE" = "o" ]
		do
			QUELMDP=""
			while [ "$QUELMDP" != "1" -a "$QUELMDP" != "2" -a "$QUELMDP" != "3" -a "$QUELMDP" != "4" ]
			do
				echo -e "${COLTXT}"
				echo -e "Vous pouvez changer le mot de passe de:"
				echo -e " (${COLCHOIX}1${COLTXT}) boot sous Linux sans pre-selection\c"
				#if cat ${fichier_conf} | grep "password" | grep "#sauve" > /dev/null; then
				if cat ${fichier_conf} | grep "label=sauve" > /dev/null; then
					echo -e ","
					echo -e " (${COLCHOIX}2${COLTXT}) boot sous Linux avec lancement du script de sauvegarde\c"
				fi
				if cat ${fichier_conf} | grep "label=restaure" > /dev/null; then
					echo -e ","
					echo -e " (${COLCHOIX}3${COLTXT}) boot sous Linux avec lancement du script de restauration."
				fi
				echo -e " (${COLCHOIX}4${COLTXT}) meme mot de passe pour Linux/Sauve/Restaure."
		
				echo -e "${COLTXT}"
				echo -e "Quel mot de passe souhaitez-vous changer/definir? $COLSAISIE\c"
				read QUELMDP
			done
		
		
			echo -e "$COLINFO"
			#echo -e "Veuillez eviter dans votre mot de passe les espaces, les accents, les caracteres"
			#echo -e "speciaux qui pourraient ne pas être disponibles sur le clavier minimal charge"
			#echo -e "lors de l affichage de LILO."
			echo "Le clavier charge lors du boot est assez limite."
			echo "Veuillez vous limiter a un mot de passe alphanumerique."
		
			SUITE="n"
			while [ "${SUITE}" = "n" ]
			do
				echo -e "${COLTXT}"
				echo -e "Veuillez saisir le nouveau mot de passe: $COLSAISIE\c"
				read NOUVEAU_MDP
		
				test=$(echo "${NOUVEAU_MDP}" | sed -e "s/[0-9A-Za-z]//g")
				if [ ! -z "$test" ]; then
					echo -e "${COLERREUR}"
					echo "Des caracteres susceptibles de ne pas être disponibles au niveau de LILO"
					echo "ont ete saisis."
					SUITE="n"
				else
					SUITE="o"
				fi
			done
		
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
				4)
					CHANGE_MDP_LINUX "$NOUVEAU_MDP"
					CHANGE_MDP_SAUVE "$NOUVEAU_MDP"
					CHANGE_MDP_RESTAURE "$NOUVEAU_MDP"
				;;
			esac
			#rm -f /tmp/lilo_debut*
			#rm -f /tmp/lilo_fin*
		
			echo -e "$COLINFO"
			echo -e "Modification terminee!"

			if [ "$QUELMDP" ="4" ]; then
				REPONSE=""
				while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				do
					echo -e "${COLTXT}"
					echo -e "Voulez-vous modifier un autre mot de passe? (${COLCHOIX}o/n${COLTXT}) [${COLDEFAUT}n${COLTXT}] $COLSAISIE\c"
					read REPONSE

					if [ -z "$REPONSE" ]; then
						REPONSE="n"
					fi
				done
			else
				REPONSE=""
				while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
				do
					echo -e "${COLTXT}"
					echo -e "Voulez-vous modifier un autre mot de passe? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
					read REPONSE
				done
			fi
		done
	fi

	# Modification des droits pour le cas ou on met des mots de passe.
	chmod 600 ${fichier_conf}
	
	echo -e "${COLTXT}"
	echo "Reinstallation de LILO dans le MBR:"
	echo -e "${COLCMD}"
	lilo
	
	echo -e "$COLINFO"
	echo -e "Des copies de sauvegarde du ${fichier_conf} ont ete effectuees."
	echo -e "Ces fichiers etaient destines a vous permettre de revenir a une version"
	echo -e "anterieure du fichier de configuration en cas de pepin lors des modifications"
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

	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous supprimer les fichiers de sauvegarde des versions precedentes"
		echo -e "du ${fichier_conf}? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done
	
	if [ "$REPONSE" = "o" ]; then
		echo -e "${COLTXT}"
		echo -e "Suppression des fichiers ${fichier_conf}.*"
		echo -e "${COLCMD}\c"
		rm -f ${fichier_conf}.*
	fi
	
	echo -e "$COLINFO"
	echo -e "Si le fichier ${fichier_conf} contient des mots de passe, il est possible"
	echo -e "de consulter ce fichier pour trouver les mots de passe... même depuis Window\$."
	echo -e "C'est un probleme de securite."

	REPONSE=""
	if [ "$change_mdp" = "auto" ]; then
		if [ "$cacher_mdp" = "y" ]; then
			REPONSE="o"
		else
			REPONSE="n"
		fi
	fi

	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" ]
	do
		echo -e "${COLTXT}"
		echo -e "Voulez-vous cacher les mots de passe du fichier ${fichier_conf}? (${COLCHOIX}o/n${COLTXT}) $COLSAISIE\c"
		read REPONSE
	done
	
	if [ "$REPONSE" = "o" ]; then
		echo -e "${COLTXT}"
		echo -e "Securisation du ${fichier_conf}"
		echo -e "${COLCMD}\c"
		mv ${fichier_conf} ${fichier_conf}.secu
	#	cat ${fichier_conf}.secu | while read A
	#	do
	#		if echo "$A" | grep password | grep "#linux" > /dev/null; then
	#			echo "     password=XXXXX #linux" >> ${fichier_conf}
	#		else
	#			if echo "$A" | grep password | grep "#sauve" > /dev/null; then
	#				echo "     password=XXXXX #sauve" >> ${fichier_conf}
	#			else
	#				if echo "$A" | grep password | grep "#restaure" > /dev/null; then
	#					echo "     password=XXXXX #restaure" >> ${fichier_conf}
	#				else
	#					echo "$A" >> ${fichier_conf}
	#				fi
	#			fi
	#		fi
	#	done
	
		sed -r 's/(password=)[A-Za-z0-9]+( #*)/password=XXXXX\2/' ${fichier_conf}.secu > ${fichier_conf}
	
		echo -e "${COLTXT}"
		echo "Voici le nouveau contenu des lignes password:"
		echo -e "${COLCMD}\c"
		grep password ${fichier_conf}
		rm -f ${fichier_conf}.secu
	fi
	
	echo -e "${COLTITRE}"
	echo "Termine."
	echo -e "${COLTXT}"
fi

if [ -z "$delais_reboot" ]; then
	# Pour etre sur que le nettoyage de tache ait le temps de passer
	delais_reboot=120
fi

t=$(grep "auto_reboot=y" /proc/cmdline)
if [ -n "$t" -a "$work" = "change_mdp_lilo.sh" ]; then
	echo -e "$COLTXT"
	#echo "Reboot dans $delais_reboot secondes..."
	#sleep $delais_reboot
	COMPTE_A_REBOURS "Reboot dans " $delais_reboot " secondes..."
	reboot
fi

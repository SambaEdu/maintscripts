#!/bin/bash

## $Id: se3_upgrade_wheezy.sh 9321 2016-05-03 15:38:29Z keyser $ ##

####Script permettant de migrer un serveur Se3 de squeeze en wheezy ####
### Auteur : Franck Molle franck.molle@ac-rouen.fr

#Couleurs
COLTITRE="\033[1;35m"   # Rose
COLDEFAUT="\033[0;33m"  # Brun-jaune
COLCMD="\033[1;37m"     # Blanc
COLERREUR="\033[1;31m"  # Rouge
COLTXT="\033[0;37m"     # Gris
COLINFO="\033[0;36m"	# Cyan
COLPARTIE="\033[1;34m"	# Bleu

ERREUR()
{
	echo -e "$COLERREUR"
	echo "ERREUR!"
	echo -e "$1"
	echo -e "$COLTXT"
	
}

ERREXIT()
{
	DEBIAN_PRIORITY="high"
	DEBIAN_FRONTEND="dialog" 
	export  DEBIAN_PRIORITY
	export  DEBIAN_FRONTEND
	exit 1
}

POURSUIVRE()
{
	REPONSE=""
	while [ "$REPONSE" != "o" -a "$REPONSE" != "n" -a "$REPONSE" != "O" ]
	do
		echo -e "$COLTXT"
		echo -e "Peut-on poursuivre? (${COLCHOIX}O/n${COLTXT}) $COLSAISIE\c"
		read -t 30 REPONSE
		if [ -z "$REPONSE" ]; then
			REPONSE="o"
		fi
	done

	if [ "$REPONSE" != "o" -a "$REPONSE" != "O" ]; then
		ERREUR "Abandon!"
		ERREXIT		
	fi
}

LINE_TEST()
{
if ( ! wget -q --output-document=/dev/null 'http://wawadeb.crdp.ac-caen.fr/index.html') ; then
	ERREUR "Votre connexion internet ou la configuration du proxy ne semble pas fonctionnelle !!" 
	exit 1
fi
}



GENSOURCESQUEEZE()
{
rm -f /etc/apt/sources.list.d/*
 
cat >/etc/apt/sources.list <<END
deb http://archive.debian.org/debian squeeze main contrib non-free
deb http://archive.debian.org/debian squeeze-lts main contrib non-free
END

cat >/etc/apt/sources.list.d/se3.list <<END
# sources pour se3
deb http://wawadeb.crdp.ac-caen.fr/debian squeeze se3
END
}


GENSOURCEWHEEZY()
{
mv /etc/apt/sources.list /etc/apt/sources.list_save_migration
cat >/etc/apt/sources.list <<END
# Sources standard:
deb http://ftp.fr.debian.org/debian/ wheezy main non-free contrib

# Security Updates:
deb http://security.debian.org/ wheezy/updates main contrib non-free

# wheezy-updates
deb http://ftp.fr.debian.org/debian/ wheezy-updates main contrib non-free

# wheezy-backports
#deb http://ftp.fr.debian.org/debian/ wheezy-backports main


END
}

GENSOURCESE3()
{

cat >/etc/apt/sources.list.d/se3.list <<END
# sources pour se3
deb http://wawadeb.crdp.ac-caen.fr/debian wheezy se3

#### Sources testing desactivee en prod ####
deb http://wawadeb.crdp.ac-caen.fr/debian wheezy se3testing

#### Sources backports smb41  ####
deb http://wawadeb.crdp.ac-caen.fr/debian wheezybackports smb41
END
}
#date
LADATE=$(date +%d-%m-%Y)
chemin_migr="/root/migration_squeeze2wheezy"
mkdir -p $chemin_migr
fichier_log="$chemin_migr/migration-$LADATE.log"
touch $fichier_log
BPC_SCRIPT="/etc/init.d/backuppc"
BPC_PID="/var/run/backuppc/BackupPC.pid"

MAIL_REPORT()
{

[ -e /etc/ssmtp/ssmtp.conf ] && MAIL_ADMIN=$(cat /etc/ssmtp/ssmtp.conf | grep root | cut -d= -f2)
if [ ! -z "$MAIL_ADMIN" ]; then
	REPORT=$(cat $fichier_log)
	#On envoie un mail a  l'admin
	echo "$REPORT"  | mail -s "[SE3] Rapport de migration $0" $MAIL_ADMIN
fi
}

SCREEN_TEST()
{


SCREENOK=$(ps ax | grep screen | grep -v grep)

if [ -z "$SCREENOK" ]; then
	echo "Pas de session screen en cours....Il est conseille de l'utiliser lors de la migration"
	echo "Voulez vous continuez (o/N) ? "
	read REPLY
	if [ "$REPLY" != "O" ] &&  [ "$REPLY" != "o" ] && [ -n $REPLY ]; then
			ERREUR "Abandon !"
			exit 1
	fi

fi

}


show_title()
{

echo -e "$COLTITRE"
echo "*********************************************"
echo "* Script de migration de Squeeze vers Wheezy *" | tee -a $fichier_log
echo "*********************************************"
echo -e "$COLTXT"
}

show_help()
{
echo "Script de migration de Squeeze vers Wheezy
A lancer sans option ou avec les options suivantes 
-d|--download : prépare la migration sans la lancer en téléchargeant uniquement les paquets nécessaires

--no-update	: ne pas vérifier la mise à jour du script de migration sur le serveur central mais utiliser la version locale

--debug	: lance le script en outrepassant les tests de taille et de place libre des partitions. A NE PAS UTILISER EN PRODUCTION

-h|--help		: cette aide
"
}

while :; do
	case $1 in
		-h|-\?|--help)
		show_help
		exit
		;;
      
		-d|--download)
		download="yes"
		;;
		
		--no-update)
		touch /root/nodl
		;;
  
		--debug)
		touch /root/debug
		;;
  
		--)
		shift
		break
		;;
     
		-?*)
		printf 'Attention : option inconnue ignorée: %s\n' "$1" >&2
		;;
  
		*)
		break
		esac
 		shift
done

option="-y"
PERMSE3_OPTION="--light"
DEBIAN_PRIORITY="critical"
DEBIAN_FRONTEND="noninteractive"
export  DEBIAN_FRONTEND
export  DEBIAN_PRIORITY

NODL="no"
DEBUG="no"
#########################################  

[ -e /root/debug ] && DEBUG="yes"
[ -e /root/nodl ] && NODL="yes"


if [ -e /etc/apt/listchanges.conf ]; then
	if [ "$DEBUG" = "yes" ]; then
		sed -i "s|^frontend=.*|frontend=pager|" /etc/apt/listchanges.conf
	else
		sed -i "s|^frontend=.*|frontend=mail|" /etc/apt/listchanges.conf
	fi
fi

if [ "$download" = "yes" ]; then
	show_title
	echo -e "$COLINFO"
	echo "Pré-téléchargement des paquets uniquement"
	echo -e "$COLTXT"
	SCREEN_TEST
	GENSOURCESQUEEZE
	echo -e "$COLINFO"
	echo "Partie Squeeze - Mise à jour des dépots en cours....Patientez"
	echo -e "$COLTXT"
	[ "$DEBUG" != "yes" ] && apt-get clean
	apt-get -qq update -o Acquire::Check-Valid-Until=false
	(
	dpkg -l|grep se3-|cut -d ' ' -f3|while read package
	do
	LC_ALL=C apt-get -s install $package|grep newest >/dev/null|| echo $package
	done
	)>/root/se3_update_list
	list_module=$(cat /root/se3_update_list)
	if [ -n "$list_module" ]; then
		echo ""
		echo "Téléchargement des modules SE3 devant être mis à jour avant migration" 
		apt-get install $list_module -d -y --force-yes --allow-unauthenticated 2>&1
	fi
	rm -f /root/se3_update_list
	echo -e "$COLINFO"
	echo "Téléchargement des paquets ldap squeeze si nécessaire"
	echo -e "$COLTXT"
	apt-get install ldap-utils libldap-2.4-2 slapd -d -y --allow-unauthenticated
	GENSOURCEWHEEZY
	echo -e "$COLINFO"
	echo "Mise a jour des dépots Wheezy"
	echo -e "$COLTXT"
	apt-get -qq update
	echo -e "$COLINFO"
	echo "Téléchargement des paquets Wheezy nécessaires à la migration lancé"
	echo -e "$COLTXT"
	sleep 1
	apt-get dist-upgrade -d -y --allow-unauthenticated
	echo -e "$COLINFO"
	echo "terminé !!"
	echo -e "$COLTXT"
	echo "Taille du cache actuel : $(du -sh /var/cache/apt/archives/ |  awk '{print $1}')"
	touch "$chemin_migr/download_only"
	echo -e "$COLINFO"
	echo "Rétablissement des sources squeeze"
	echo -e "$COLTXT"
	GENSOURCESQUEEZE
	apt-get -qq update -o Acquire::Check-Valid-Until=false
	exit 0
fi

show_title

POURSUIVRE

sleep 1


echo -e "$COLPARTIE"
echo "Preparation et tests du systeme" | tee -a $fichier_log
echo -e "$COLTXT"

# On teste la version de debian
 
if  ! egrep -q "^6.0" /etc/debian_version;  then
        if egrep -q "^7." /etc/debian_version; then
                echo "Votre serveur est deja en version Debian Wheezy"
                echo "Vous pouvez continuer si vous souhaitez terminer une migration precedente"
                echo "Le script se positionnera automatiquement au bon endroit"
                POURSUIVRE
        else
                echo "Votre serveur n'est pas en version Debian squeeze."
                echo "Operation annulee !"
                exit 1
        fi
else
	DIST="squeeze"
fi


LINE_TEST

SCREEN_TEST

if [ "$NODL" != "yes" ]; then
	echo -e "$COLINFO"
	echo "Verification en ligne que vous avez bien la derniere version des scripts de migration"
	echo -e "$COLTXT"
	cd /root
	SCRIPT_FILE="se3_upgrade_wheezy.sh"
	SCRIPT_FILE_MD5="se3_upgrade_wheezy.md5"
	SCRIPTS_DIR="/usr/share/se3/sbin"
	
	rm -f $SCRIPT_FILE_MD5 $SCRIPT_FILE
	wget -N --tries=1 --connect-timeout=1 http://wawadeb.crdp.ac-caen.fr/majse3/$SCRIPT_FILE || ERREUR="1"
	wget -N --tries=1 --connect-timeout=1 http://wawadeb.crdp.ac-caen.fr/majse3/$SCRIPT_FILE_MD5 || ERREUR="1"
	if [ "$ERREUR" = "1" ];then
		ERREUR "Problème pour récupérer la version en ligne : ABANDON !"
		ERREXIT		
	fi
	
	MD5_CTRL_FILE=$(cat $SCRIPT_FILE_MD5)
	MD5_CTRL_DL=$(md5sum $SCRIPT_FILE)
	if [ "$MD5_CTRL_FILE" != "$MD5_CTRL_DL" ]
	then	
		echo -e "$COLERREUR"
		echo "Controle MD5 du script téléchargé incorrecte, relancez le script afin qu'il soit de nouveau telechargé"
		echo -e "$COLTXT"
		exit 1
	fi

# 	tar -xzf $SCRIPT_FILE
	cd $SCRIPTS_DIR
	MD5_CTRL_LOCAL=$(md5sum $SCRIPT_FILE)
	cd -
# 	MD5_CTRL1=$(cat se3_upgrade_wheezy.md5)
	#MD5_CTRL2=$(cat migration_ldap_lenny.md5)
	# MD5_CTRL3=$(cat migration_UTF8.md5)
	chmod +x *.sh

	if [ "$MD5_CTRL_FILE" != "$MD5_CTRL_LOCAL" ]; then
		RELANCE="YES" 
		cp $SCRIPT_FILE $SCRIPTS_DIR/
	fi
	if [ "$RELANCE" == "YES" ]
	then
		echo -e "$COLINFO"
		echo "Les scripts de migration ont ete mis a jour depuis le serveur central, veuiller relancer se3_upgrade_wheezy.sh"
		echo "afin de prendre en compte les changements"
		exit 1
		echo -e "$COLTXT"
	
	
	fi
	echo -e "$COLINFO"
	echo "Vous disposez de la derniere version des scritps de migration, la migration peut se poursuivre..."
	sleep 2
	echo -e "$COLTXT"
else
echo "mode no-update pas de téléchargement"
sleep 2
fi



#init des params
. /usr/share/se3/includes/config.inc.sh -cml
. /usr/share/se3/includes/functions.inc.sh


# On teste si on a de la place pour faire la maj
PARTROOT=`df | grep "/\$" | sed -e "s/ .*//"`
PARTROOT_SIZE=$(fdisk -s $PARTROOT)
rm -f /root/dead.letter
if [ "$PARTROOT_SIZE" -le 2000000 ]; then
	ERREUR "La partition racine fait moins de 2Go, c'est insuffisant pour passer en Wheezy" | tee -a $fichier_log
	if [ "$DEBUG" = "yes" ]; then
		echo "mode debug actif"
		POURSUIVRE
	else
		exit 1
	fi
fi


libre_root=$(($(stat -f --format="%a*%S/1048576" /))) 
libre_var=$(($(stat -f --format="%a*%S/1048576" /var))) 

if [ "$libre_root" -lt 1000 ]; then
	echo "Espace insuffisant sur / : $libre_root Mo"
		if [ "$DEBUG" = "yes" ]; then
		echo "mode debug actif"
		POURSUIVRE
	else
		exit 1
	fi
fi



if [ "$replica_status" == "" -o "$replica_status" == "0" ]
then
	echo "Serveur ldap en standalone ---> OK"
else
	ERREUR "Le serveur ldap soit etre en standalone (pas de replication ldap) !!!\nModifiez cette valeur et relancez le script" | tee -a $fichier_log
	exit 1
fi

[ "$DEBUG" != "yes" ] && [ ! -e "$chemin_migr/download_only" ] && apt-get clean && echo "Suppression du cache effectué"

if [ "$libre_var" -lt 1000 ];then
	echo "Espace insuffisant sur /var : $libre_var Mo"
	
	if [ "$DEBUG" = "yes" ]; then
		echo "mode debug actif"
		POURSUIVRE
	else
		exit 1
	fi
	
fi

CHANGEMYSQL localmenu "1"



if [ ! -e $chemin_migr/phase1-ok ]; then
	#grep -q "http://archive.debian.org/debian lenny main" /etc/apt/sources.list || 
	echo -e "$COLINFO"
	echo "Génération des sources squeeze"
	echo -e "$COLTXT"
	GENSOURCESQUEEZE
    echo -e "$COLINFO"
    echo "Mise à jour des paquets disponibles....Patientez svp"
    echo -e "$COLTXT"
    apt-get -qq update -o Acquire::Check-Valid-Until=false
    echo "Maj si besoin de debian-archive-keyring"
    apt-get install debian-archive-keyring --allow-unauthenticated
    SE3_CANDIDAT=$(apt-cache policy se3 | grep "Candidat" | awk '{print $2}')
    SE3_INSTALL=$(apt-cache policy se3 | grep "Install" | awk '{print $2}')
    #[ "$SE3_CANDIDAT" != "$SE3_INSTALL" ] && ERREUR "Il semble que votre serveur se3 n'est pas a jour\nMettez votre serveur a jour puis relancez le script de migration" && exit 1

    echo -e "$COLPARTIE"
    echo "Migration phase 1 : Mise a jour SE3 si necessaire"
    echo -e "$COLTXT"
    /usr/share/se3/scripts/install_se3-module.sh se3 | grep -v "pre>" | tee -a $fichier_log
    #/usr/share/se3/scripts/se3-upgrade.sh | grep -v pre


    if [ "$?" != "0" ]; then
    ERREUR "Une erreur s'est produite lors de la mise à jour des modules\nIl est conseille de couper la migration"
	POURSUIVRE
	
    fi
    touch $chemin_migr/phase1-ok
else
	echo "$chemin_migr/phase1-ok existe, on passe cette phase"
fi

echo -e "$COLINFO"
echo "Test de montage sur Backuppc"
echo -e "$COLTXT"
df -h | grep backuppc && umount /var/lib/backuppc
if [ ! -z "$(df -h | grep /var/lib/backuppc)" ]; then 
	ERREUR "Il semble qu'une ressource soit montee sur /var/lib/backuppc. Il faut la demonter puis relancer"
	exit 1
else
	[ -e $BPC_SCRIPT ] && $BPC_SCRIPT stop
	[ ! -h /var/lib/backuppc ] && rm -rf /var/lib/backuppc/*
fi


if [ "$DIST" = "squeeze" ]; then
	echo -e "$COLINFO"
	echo "Mise à jour slapd et consors vers leur dernière version stable"
	echo -e "$COLTXT"
	apt-get install ldap-utils libldap-2.4-2 slapd -y --allow-unauthenticated
# 	aptitude install slapd -y --> aptitude sucks and can desinstall se3 !!
	# purges trace slapd backup 
	rm -rf /var/backups/slapd*
	rm -rf /var/backups/${ldap_base_dn}*
	SLAPD_VERSION=$(dpkg -s slapd | grep Version |cut -d" " -f2)
	PATHSAVLDAP="/var/backups/$SLAPD_VERSION"
	mkdir -p $PATHSAVLDAP
	ldapsearch -xLLL -D $adminRdn,$ldap_base_dn -w $adminPw > "$PATHSAVLDAP/${ldap_base_dn}.ldif"
fi



if [ ! -e $chemin_migr/phase2a-ok ]; then

# 	cat /var/lib/ldap/DB_CONFIG | grep -v "sactivation logs ldap" > $chemin_migr/DB_CONFIG
# 	cp $chemin_migr/DB_CONFIG /var/lib/ldap/DB_CONFIG
	cp /etc/ldap/slapd.conf $chemin_migr/

	chown -R openldap:openldap /var/lib/ldap/

	# echo "" > /etc/environment 

# 	/etc/init.d/nut stop
# 
# 	# purge config nut
# 	rm -f /etc/nut/*
# 	rm -f /etc/default/nut 
	touch $chemin_migr/phase2a-ok 
	
else
	echo -e "$COLINFO"
	echo "$chemin_migr/phase2a-ok existe, on passe cette phase" | tee -a $fichier_log
	echo -e "$COLTXT"
	
fi

if [ ! -e $chemin_migr/phase2b-ok ]; then
	echo -e "$COLPARTIE"
	echo "Partie 2 : Migration en Wheezy - installations des paquets prioritaires" | tee -a $fichier_log
	echo -e "$COLTXT"
	POURSUIVRE

	[ -z "$LC_ALL" ] && LC_ALL=C && export LC_ALL=C 
	[ -z "$LANGUAGE" ] && export LANGUAGE=fr_FR:fr:en_GB:en  
	[ -z "$LANG" ] && export LANG=fr_FR@euro 


	# Creation du source.list wheezy

	GENSOURCEWHEEZY
	

	# On se lance
	echo "Dpkg::Options {\"--force-confold\";}" > /etc/apt/apt.conf	
	# 	echo "Dpkg::Options {\"--force-confnew\";}" > /etc/apt/apt.conf
	echo -e "$COLINFO"
	echo "mise a jour des depots...Patientez svp" 
	echo -e "$COLTXT"
	apt-get -qq update
	if [ "$?" != "0" ]; then
		ERREUR "Une erreur s'est produite lors de la mise a jour des paquets disponibles. Reglez le probleme et relancez le script"
		GENSOURCESQUEEZE
		ERREXIT
	fi

	echo "Ok !"
	


	echo -e "$COLINFO"
	echo "Maj si besoin de debian-archive-keyring"
	echo -e "$COLTXT"

	apt-get install debian-archive-keyring --allow-unauthenticated | tee -a $fichier_log
	apt-get -qq update 


	#Supression des fonts pourries MS 
	# if [ -e "/usr/share/doc/ttf-mscorefonts-installer" ]; then
	# 	echo -e "$COLINFO"
	# 	echo "Suppression fonts MS inutiles"
	# 	echo -e "$COLTXT"
	# 	apt-get remove ttf-mscorefonts-installer -y 
	# 	apt-get autoremove -y
	# fi


	
	rm -f /etc/init.d/backuppc.ori 
	if [ -e "$BPC_SCRIPT" ]; then
		echo -e "$COLINFO"
		echo "Test bon fonctionnenment backuppc et Suppression en cas de besoin"
		echo -e "$COLTXT"
		if [ ! -e "$BPC_PID" ]; then
			$BPC_SCRIPT start 
			if [ "$?" != "0" ]; then
				apt-get remove backuppc --purge -y
				rm -f /etc/apache2se/sites-enabled/backuppc.conf
			else
				$BPC_SCRIPT stop
			fi
		else
			$BPC_SCRIPT stop
		fi
	fi

	
# Suppression complète  d'ocs 

	if [ -n "$(dpkg -l | grep se3-ocs | grep -v se3-ocs-clientwin)" ]; then
		apt-get remove --purge se3-ocs ocsinventory-server ocsinventory-agent -y
		mysqladmin -f drop ocsweb 
		rm -f /var/www/se3/includes/dbconfig.inc.php
		mysql -e "drop USER ocs@localhost" -b mysql
		mysql -e "drop USER ocs" -b mysql
		rm -f /etc/apache2se/conf.d/ocsinventory.conf
		rm -f /etc/apache2/conf.d/ocsreports.conf
	fi
	
	# On assure la comptibilite mysql superieur a 5.1.12
	sed -i 's/^skip-bdb/#skip-bdb/g'  /etc/mysql/my.cnf

	echo "mise a jour de lib6 - locales" | tee -a $fichier_log

	echo -e "${COLINFO}Ne pas s'alarmer des erreurs sur les locales, c'est inevitable a cette etape de la migration\nIl est egalement possible que le noyau en cours se desinstalle, un autre sera installe ensuite$COLTXT"
	echo -e "$COLTXT"
	aptitude install libc6 locales  -y < /dev/tty | tee -a $fichier_log
	
# wine
	if [ "$?" != "0" ]; then
		mv /etc/apt/sources.list_save_migration /etc/apt/sources.list 
		ERREUR "Une erreur s'est produite lors de la mise a jour des paquets lib6 et locales. Reglez le probleme et relancez le script"
		ERREXIT
	fi
	echo -e "$COLINFO"
	echo "mise a jour de lib6  et locales ---> OK" | tee -a $fichier_log
	echo -e "$COLTXT"
	sleep 3
	
	
	
	echo "mise a jour de lib6 - locales  et mysql-server" | tee -a $fichier_log

	aptitude -o Dpkg::Options::="--force-confnew" install mysql-server -y | tee -a $fichier_log
	if [ "$?" != "0" ]; then
		mv /etc/apt/sources.list_save_migration /etc/apt/sources.list 
		ERREUR "Une erreur s'est produite lors de la mise a jour du paquet mysql-server. Reglez le probleme et relancez le script"
		ERREXIT
	fi
	echo -e "$COLINFO"
	echo "mise a jour de  mysql-server ---> OK" | tee -a $fichier_log
	echo -e "$COLTXT"
	sleep 3
	touch $chemin_migr/phase2b-ok
	

else
	echo -e "$COLINFO"
	echo "$chemin_migr/phase2b-ok existe, on passe cette phase"
	echo "Reprise du script phase 3"
	echo -e "$COLTXT"
	
	echo "Dpkg::Options {\"--force-confold\";}" > /etc/apt/apt.conf	
	# 	echo "Dpkg::Options {\"--force-confnew\";}" > /etc/apt/apt.conf
	echo -e "$COLINFO"
	echo "mise a jour des depots...Patientez svp" 
	echo -e "$COLTXT"
	apt-get -qq update
	if [ "$?" != "0" ]; then
		ERREUR "Une erreur s'est produite lors de la mise a jour des paquets disponibles. Reglez le probleme et relancez le script" 
		ERREXIT
	fi

fi


# if [ -e "/usr/share/ocsinventory-server" -a ! -e "$chemin_migr/ocs-ok" ]; then
# 	rootsql=$(grep password  /root/.my.cnf | cut -d"=" -f2)
# 	ocssql=$(grep PSWD_BASE  /var/www/se3/includes/dbconfig.inc.php | cut -d\" -f4)
# 
# 	echo -e "$COLPARTIE"
# 	echo "Partie 3 : Mise a jour OCS Inventory" 
# 	echo -e "$COLTXT"
# 	echo "ocsinventory-server	ocsinventory-server/password-confirm	password	$rootsql
# ocsinventory-server	ocsinventory-server/mysql/admin-pass	password	$rootsql
# # Mot de passe de connexion MySQL pour ocsinventory-server :
# ocsinventory-server	ocsinventory-server/mysql/app-pass	password	$ocssql
# ocsinventory-server	ocsinventory-server/app-password-confirm	password	$ocssql
# " > config_ocs.txt
# 	debconf-set-selections < config_ocs.txt
# 	# DEBIAN_PRIORITY="high"
# 	# 	DEBIAN_FRONTEND="dialog" 
# 	# DEBIAN_FRONTEND="dialog" DEBIAN_PRIORITY="high" 
# 	apt-get install ocsinventory-server -y 
# 
# 	if [ "$?" != "0" ]; then
# 		echo -e "$COLINFO"
# 		echo "Reconfiguration du paquet OCS pour correction Erreur dpkg"
# 		echo -e "$COLTXT"
# 		dpkg-reconfigure ocsinventory-server && echo "Ok !!" 
# 	else
# 		echo -e "$COLINFO"
# 		echo "Configuration du paquet OCS Ok !!"
# 		echo -e "$COLTXT"
# 	fi
# 
# 	echo -e "$COLINFO"
# 	echo "Configuration du paquet OCS Ok !!"
# 	echo -e "$COLTXT"
# 	/etc/init.d/apache2se restart
# 	sleep 2
# 	APACHE2SE_PID="/var/run/apache2se.pid"
# 	OCSCONF="/etc/ocsinventory/ocsinventory.conf"
# 
# 	if [ -e "$OCSCONF" ]; then
# 		if [ ! -e "$APACHE2SE_PID" ]; then
# 				echo "Interface Web HS - Tentative de reparation automatique de la conf OCS"
# 				grep -q "PerlSetEnv OCS_DB_PORT 3306" $OCSCONF || sed "s/PerlSetEnv OCS_DB_PORT/PerlSetEnv OCS_DB_PORT 3306 /" -i $OCSCONF 
# 				/etc/init.d/apache2se restart 
# 				sleep 2
# 				if [ ! -e "$APACHE2SE_PID" ]; then
# 					echo "Interface Web toujours HS malgre la tentative de reparation automatique"
# 					echo "Extrait de /var/log/apache2se/errorse.log"
# 					tail /var/log/apache2se/errorse.log
# 				fi
# 			
# 		fi
# 	fi
# 
# fi


echo -e "$COLPARTIE"
echo "Partie 4 : Migration en Wheezy - installations des paquets restants" 
echo -e "$COLTXT"
POURSUIVRE
echo -e "$COLINFO"
echo "migration du systeme lancee.....ça risque d'être long ;)" 
echo -e "$COLTXT"

# DEBIAN_FRONTEND="non-interactive" 
apt-get dist-upgrade $option  < /dev/tty | tee -a $fichier_log


if [ "$?" != "0" ]; then
	echo -e "$COLERREUR Une erreur s'est produite lors de la migration vers wheezy"
	echo "En fonction du probleme, vous pouvez choisir de poursuivre tout de meme ou bien d'abandonner afin de terminer la migration manuellement"
	#/usr/share/se3/scripts/install_se3-module.sh se3
	echo -e "$COLTXT"
	echo "Voulez vous continuez (o/N) ? "
	read REPLY
	if [ "$REPLY" != "O" ] &&  [ "$REPLY" != "o" ] && [ -n $REPLY ]; then
			ERREUR "Abandon !"
			GENSOURCESE3
			ERREXIT
	fi
	
fi

touch $chemin_migr/phase4-ok
echo "migration du systeme OK" | tee -a $fichier_log



echo -e "$COLINFO"
echo "Retour à la conf sudo par défaut sous Wheezy" | tee -a $fichier_log

echo -e "$COLTXT"


if [ -e /etc/sudoers.dpkg-dist ]; then
  [ ! -e /etc/sudoers.d/sudoers-se3 ] && mv /etc/sudoers /etc/sudoers.d/sudoers-se3
  mv /etc/sudoers.dpkg-dist /etc/sudoers && echo "/etc/sudoers.dpkg-dist restauré"
fi
 


echo -e "$COLINFO"
echo "Ajout paquets complementaires si besoin" 
echo -e "$COLTXT"


#Install ssmtp si necessaire
apt-get install ssmtp -y >/dev/null | tee -a $fichier_log


# update noyau wheezy
arch="686"
[ "$(arch)" != "i686" ] && arch="amd64"

apt-get install linux-image-$arch firmware-linux-nonfree  -y | tee -a $fichier_log



echo -e "$COLPARTIE"
echo "Partie 5 : Installation de wine et Samba 4.1" | tee -a $fichier_log
echo -e "$COLTXT"



echo -e "$COLINFO"
echo "Ajout du support de l'architecture i386 pour dpkg" | tee -a $fichier_log
echo -e "$COLTXT"

dpkg --add-architecture i386
echo "Mise à jour des paquets disponibles....Patientez svp"
apt-get -qq update

echo -e "$COLINFO"
echo "Installation de Wine:i386" | tee -a $fichier_log
echo -e "$COLTXT"

apt-get install wine-bin:i386 -y | tee -a $fichier_log

[ ! -e "$chemin_migr/download_only" ] && apt-get clean

echo -e "$COLINFO"
echo "Installation du backport samba 4.1" | tee -a $fichier_log
echo -e "$COLTXT"
GENSOURCESE3

echo -e "$COLINFO"
echo "Génération des sources SE3 dans /etc/apt/sources.list.d/se3.list "
echo -e "$COLTXT"
echo "Mise à jour des paquets disponibles....Patientez svp"
apt-get -qq update
apt-get install samba --allow-unauthenticated -y | tee -a $fichier_log


echo -e "$COLINFO"
echo "On stopppe le service winbind" | tee -a $fichier_log
echo -e "$COLTXT"
service winbind stop | tee -a $fichier_log
insserv -r winbind | tee -a $fichier_log


echo -e "$COLINFO"
echo "Réécriture du fichier /etc/default/slapd pour utiliser slapd.conf au lieu de cn=config" 
echo -e "$COLTXT"
# Retour Slapd.conf
/etc/init.d/slapd stop
#sed -i "s/#SLAPD_CONF=/SLAPD_CONF=\"\/etc\/ldap\/slapd.conf\"/g" /etc/default/slapd
echo 'SLAPD_CONF="/etc/ldap/slapd.conf"
SLAPD_USER="openldap"
SLAPD_GROUP="openldap"
SLAPD_PIDFILE=
SLAPD_SERVICES="ldap:/// ldapi:///"
SLAPD_SENTINEL_FILE=/etc/ldap/noslapd
SLAPD_OPTIONS=""
' > /etc/default/slapd

# [ grep  ] || sed -i "s/SLAPD_CONF=/SLAPD_CONF=\"\/etc\/ldap\/slapd.conf\"/g" /etc/default/slapd
cp $chemin_migr/slapd.conf /etc/ldap/slapd.conf
chown openldap:openldap /etc/ldap/slapd.conf
sleep 2
/etc/init.d/slapd start
sleep 3


echo -e "$COLINFO"
echo "Arrêt de nscd - nscd sucks !" | tee -a $fichier_log
echo -e "$COLTXT"

# nscd sucks !
if [ -e /etc/init.d/nscd  ]; then
	update-rc.d nscd disable
	/etc/init.d/nscd stop
fi

echo -e "$COLPARTIE"
echo "Partie 5 : Nettoyage de fichiers obsolètes sur /home et modification des droit sur /home/profiles" | tee -a $fichier_log
echo -e "$COLTXT"

if [ -e /home/netlogon/EnableGPO.bat ]; then
    mv  /home/netlogon/EnableGPO.bat /var/se3/
    rm -f /home/netlogon/*.bat
    rm -f /home/netlogon/*.txt
    mv  /var/se3/EnableGPO.bat /home/netlogon/
else
    rm -f /home/netlogon/*.bat
    rm -f /home/netlogon/*.txt
fi


ls /home/ | while read USER
do
    rm -fr /home/$USER/profil/Demarrer/*	
done

echo -e "$COLINFO"
echo "Modification des droits sur /home/profiles pour samba 4.1" | tee -a $fichier_log
echo -e "$COLTXT"

chmod 777 /home/profiles
setfacl -b /home/profiles
sleep 2
chgrp lcs-users /home/profiles || POURSUIVRE 

echo -e "$COLINFO"
echo "Suppression immédiat du profil errant pour admin "
echo -e "$COLTXT"


echo -e "$COLINFO"
echo "Suppression des profils itinérant" | tee -a $fichier_log
echo -e "$COLTXT"

echo -e "$COLINFO"
echo "Suppression immédiate des profil errant XP et Seven pour admin"
echo -e "$COLTXT"
rm -rf /home/profiles/admin*
sleep 1

echo -e "$COLINFO"
echo "Les autres profils seront effacés ensuite en arrière plan afin de ne pas ralentir le script" | tee -a $fichier_log
sleep 2
echo -e "$COLTXT"



echo -e "$COLPARTIE"
echo "Partie 6 : Mise a jour des paquets se3 sous wheezy"  | tee -a $fichier_log
echo -e "$COLTXT"


/etc/init.d/samba restart
echo -e "$COLINFO"
echo "Mise à jour des paquets SE3"
echo -e "$COLTXT"
/usr/share/se3/scripts/install_se3-module.sh se3 | tee -a $fichier_log


echo -e "$COLINFO"
echo "Redemarrage des services...."
echo -e "$COLCMD"
/etc/init.d/apache2se restart

/etc/init.d/mysql restart
/etc/init.d/samba restart

# modif base sql
mysql -e "UPDATE se3db.params SET value = 'wheezy' WHERE value = 'squeeze';" 
# mysql -e "UPDATE se3db.params SET value = '2.5' WHERE value = '2.4';" 


echo -e "$COLPARTIE"
echo "Partie 7 : Nettoyage et conversion des fichiers utilisateurs en UTF-8"  | tee -a $fichier_log
echo -e "$COLTXT"


echo "Commande lancée en arrière plan afin de gagner du temps"
echo " résultats consultables dans le fichier $fichier_log"


if [ ! -e "/usr/bin/convmv" ]
then
        echo "convmv n'est pas installe, on l'installe"
        apt-get install convmv
fi

at_script="$chemin_migr/clean_and_utf8.sh"
cat > $at_script <<END
#!/bin/bash
rm -rf /home/profiles/*
/usr/bin/convmv --notest -f iso-8859-15 -t utf-8 -r /home 2&>1 | grep -v Skipping >> $fichier_log
/usr/bin/convmv --notest -f iso-8859-15 -t utf-8 -r /var/se3 2&>1 | grep -v Skipping >> $fichier_log
END
chmod 700 $at_script
# at now +15 minutes -f $at_script
$at_script & 

sleep 2

# A voir si l'on en a besoin
# echo -e "$COLINFO"
# echo "On relance samba puis on lance create_adminse3.sh"
# echo -e "$COLTXT"
# service samba restart
# sleep 3
# # /usr/share/se3/sbin/instance_se3.sh
# /usr/share/se3/sbin/create_adminse3.sh

echo -e "$COLINFO"
echo "nettoyage du cache et des paquets inutiles"
echo -e "$COLTXT"
# nettoyage
rm -f /etc/php5/conf.d/suhosin.ini

apt-get autoremove -y
apt-get clean



echo -e "$COLINFO"
echo "Termine !!!"
echo -e "$COLTXT"

[ -e /etc/ssmtp/ssmtp.conf ] && MAIL_REPORT

rm -f /etc/apt/apt.conf
DEBIAN_PRIORITY="high"
DEBIAN_FRONTEND="dialog" 
export  DEBIAN_PRIORITY
export  DEBIAN_FRONTEND








exit 0

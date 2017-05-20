#!/bin/bash
#***************************************************************************************************
# Auteur Jean yves Morvan - académie de Rouen

COLTXT="\033[1;37m"
COLTITRE="\033[1;35m"
COLENTREE="\033[1;33m"

mkdir -p /root/save
cp  /etc/dhcp3/dhcpd.conf /root/save
cp /var/lib/samba/secrets.tdb /root/save
cp /etc/samba/smb.conf /root/save
cp /etc/ldap.secret /root/save
if [ -f /etc/se3/setup_se3.data ]
then cp /etc/se3/setup_se3.data  /root/save/setup_se3.data.old
fi
#***************************************************************************************************
#***************************************************************************************************
Base_DN=`grep suffix /etc/ldap/slapd.conf | cut -f2 -s -d'"'`
clear
echo -e "$COLTITRE"
echo "##########################################################################"
echo "# Recuperation de la base DN :                                           #"
echo "#Base DN =" $Base_DN                                                     
echo "# Si la base DN est correcte, appuyez sur ENTREE sinon appuyer sur CTL-C #"
echo "##########################################################################"
read PAUSE




#***************************************************************************************************
clear
echo -e "$COLTITRE"
echo "##############################"
echo "# Sauvegarde de la base LDAP #"
echo "##############################"

echo -e "$COLTXT"
slapcat > /root/save/ldap_se3_sav.ldif
#***************************************************************************************************
#***************************************************************************************************
clear
echo -e "$COLTITRE"
echo "#################################################################"
echo "# Sauvegarde de des branches computers et parcs de la base LDAP #"
echo "#################################################################"

echo -e "$COLTXT"
slapcat -s ou=Computers,$Base_DN -l /root/save/computers.ldif
slapcat -s ou=Parcs,$Base_DN -l /root/save/parcs.ldif
slapcat -s ou=Printers,$Base_DN -l /root/save/printers.ldif
slapcat -s ou=Rights,$Base_DN -l /root/save/rights.ldif

#***************************************************************************************************

#***************************************************************************************************
clear
echo -e "$COLTITRE"
echo "#########################################################"
echo "# Sauvegarde des différents mots de passe et parametres #"
echo "#########################################################"

 echo -e "*******************Paramètres LDAP*******************" > /root/save/parametres.txt
echo -e "$COLTXT"
domaine1=`grep suffix /etc/ldap/slapd.conf  | cut -f1 -s -d','| cut -f2 -s -d'='`
domaine="$domaine1.ac-rouen.fr"
echo -e "Domaine de messagerie : $domaine" >> /root/save/parametres.txt

echo -n "Base DN : " >> /root/save/parametres.txt
grep suffix /etc/ldap/slapd.conf | cut -f2 -s -d'"' >> /root/save/parametres.txt

echo -n "Root DN : " >> /root/save/parametres.txt
grep rootdn /etc/ldap/slapd.conf | cut -f2 -s -d'"' | cut -f2 -s -d'=' | cut -f1 -s -d',' >> /root/save/parametres.txt

echo -n "Mot de passe LDAP : " >> /root/save/parametres.txt
cat /etc/ldap.secret >>  /root/save/parametres.txt

 echo -e "*******************Autres mots de passe*******************" >> /root/save/parametres.txt
echo -n "Mot de passe MySql : " >> /root/save/parametres.txt
grep password /root/.my.cnf | cut -f2 -s -d'=' >> /root/save/parametres.txt

echo -n "Mot de passe de AdminSE3 : " >> /root/save/parametres.txt
 `mysql se3db  --column-names=0 -e "select value from params where name='xppass' ;" >> /root/save/parametres.txt` 


 echo -e "*******************Paramètres samba*******************" >> /root/save/parametres.txt
 echo -n "Domaine samba : " >> /root/save/parametres.txt
 grep workgroup /etc/samba/smb.conf | cut -f2 -s -d'='  >> /root/save/parametres.txt
echo -e "\n"
 echo -n "Nom NetBios : " >> /root/save/parametres.txt
 grep "netbios name" /etc/samba/smb.conf | cut -f2 -s -d'='  >> /root/save/parametres.txt
echo -e "\n"
 echo -n "@ip  et masque :" >> /root/save/parametres.txt
 grep -m 1 interfaces /etc/samba/smb.conf | cut -f2 -s -d'='  >> /root/save/parametres.txt
echo -e "\n"

echo -e "*******************DHCP*******************" >> /root/save/parametres.txt 
echo -n "Pool DHCP : " >> /root/save/parametres.txt

grep range /etc/dhcp/dhcpd.conf | cut -f2-3 -s -d' ' | cut -f1 -s -d';' >> /root/save/parametres.txt
grep range /etc/dhcp3/dhcpd.conf | cut -f2-3 -s -d' ' | cut -f1 -s -d';' >> /root/save/parametres.txt
echo -e "*******************partitions*******************" >> /root/save/parametres.txt 
echo -n "partitions  : " >> /root/save/parametres.txt
df >> /root/save/parametres.txt

echo -e "*******************DHCP*******************" >> /root/save/parametres.txt 
clamav=`(dpkg -s se3-clamav | grep "Status: install ok") 2> /dev/null`
backup=`(dpkg -s se3-backup | grep "Status: install ok") 2> /dev/null`
ocs=`(dpkg -s se3-ocs | grep "Status: install ok") 2> /dev/null`
dhcp=`(dpkg -s se3-dhcp | grep "Status: install ok") 2> /dev/null `
clonage=`(dpkg -s se3-clonage | grep "Status: install ok") 2> /dev/null `
unattended=`(dpkg -s se3-unattended | grep "Status: install ok") 2> /dev/null`
wpkg=`(dpkg -s se3-wpkg | grep "Status: install ok") 2> /dev/null `
internet=`(dpkg -s se3-internet | grep "Status: install ok") 2> /dev/null`
synchro=`(dpkg -s se3-synchro | grep "Status: install ok") 2> /dev/null`
if [[ $clamav == "" ]]
then    
 echo -e Clamav : \*\*\*\* >> /root/save/parametres.txt 
else 
 echo -e Clamav : Installe >> /root/save/parametres.txt 
fi
if [[ $backup == "" ]]
then
 echo -e Backup : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e backup : Installe >> /root/save/parametres.txt 
fi
if [[ $ocs == "" ]]
then
 echo -e ocs : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e ocs : Installe >> /root/save/parametres.txt 
 
fi
if [[ $dhcp == "" ]]
then
 echo -e Dhcp : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e Dhcp : Installe >> /root/save/parametres.txt 
fi
if [[ $clonage == "" ]]
then
 echo -e Clonage : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e Clonage : Installe >> /root/save/parametres.txt 
fi
if [[ $unattended == "" ]]
then
 echo -e Unattended : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e Unattended : Installe >> /root/save/parametres.txt 
fi
if [[ $wpkg == "" ]]
then
 echo -e Wpkg : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e Wpkg : Installe >> /root/save/parametres.txt 
fi
if [[ $internet == "" ]]
then
 echo -e Internet : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e Internet : Installe >> /root/save/parametres.txt 
fi
if [[ $synchro == "" ]]
then
 echo -e Synchro : \*\*\*\* >> /root/save/parametres.txt 
else
 echo -e Synchro : Installe >> /root/save/parametres.txt 
fi
echo "*******************reservation dhcp*******************" 
mkdir /test
chmod -R 777 /test
mysql se3db -e "select ip,name,mac from se3_dhcp into outfile '/test/dhcp.csv' fields terminated by ';' lines terminated by '\r\n'"
cp /test/dhcp.csv /root/save
rm -rf /test/ 
#***************************************************************************************************
clear
echo -e "$COLENTREE"
echo "####################################"
echo "# Appuyer sur ENTREE pour terminer #"
echo "####################################"
cd /
echo -e "$COLTITRE"
read PAUSE


echo "saisir ip du nouveau se3"
read newip
echo "copie du dossier save dans ${newip}/root/" 
scp -r /root/save root@$newip:/root/ 
ssh root@$newip 'mkdir /etc/se3; mkdir /var/lib/samba'
scp /root/save/secret.tdb root@$newip:/var/lib/samba/ 
scp /root/save/setup_se3.data root@$newip:/etc/se3/ 


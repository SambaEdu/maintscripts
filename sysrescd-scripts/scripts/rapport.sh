#!/bin/sh

# Auteur: Stephane Boireau
# Derniere modification: 02/02/2015

# Passer en parametres...

source /bin/crob_fonctions.sh

doss_rapport="/livemnt/tftpmem"

echo -e "$COLTITRE"
echo "****************************"
echo "*   Script de generation   *"
echo "*   d'un rapport sur la	*"
echo "* configuration materielle *"
echo "****************************"

echo -e "$COLTXT"
echo "Generation d'un rapport dans /${doss_rapport}/"
#echo -e "$COLCMD"

echo -e "${COLTXT}"
echo -e "Lancement de thttpd pour permettre une recuperation du rapport..."
echo -e "${COLCMD}"
/etc/init.d/thttpd start

mkdir -p ${doss_rapport}
chmod 755 ${doss_rapport}
#/root/bin/modules.sh info all > ${doss_rapport}/modules.txt
lsmod > ${doss_rapport}/lsmod.txt
lshw > ${doss_rapport}/lshw.txt

#mkdir -p /mnt/disk
sfdisk -g 2>/dev/null| grep "^/dev/" | sed -e "s|^/dev/||" | cut -d":" -f1 | cut -d"/" -f3 | while read A
do

	TMP_HD_CLEAN=$(echo ${A}|sed -e "s|[^0-9A-Za-z]|_|g")
	fdisk -l /dev/$A > /tmp/fdisk_l_${TMP_HD_CLEAN}.txt 2>&1
	#TMP_disque_en_GPT=$(grep "WARNING: GPT (GUID Partition Table) detected on '/dev/${A}'" /tmp/fdisk_l_${TMP_HD_CLEAN}.txt|cut -d"'" -f2)

	if [ "$(IS_GPT_PARTTABLE ${A})" = "y" ]; then
		TMP_disque_en_GPT=/dev/${A}
	else
		TMP_disque_en_GPT=""
	fi

	if [ -z "$TMP_disque_en_GPT" ]; then
		sfdisk -d /dev/$A > ${doss_rapport}/disk_${A}.out
		fdisk -l /dev/$A >  ${doss_rapport}/disk_${A}.fdisk
	else
		sgdisk -b ${doss_rapport}/disk_gpt_${A}.out /dev/$A
		sgdisk -p /dev/$A >  ${doss_rapport}/disk_${A}.sgdisk
	fi

	#fdisk -l /dev/${A} | grep "^/dev/" | grep Linux | grep -v "Linux swap" | grep -v "xtended" | cut -d" " -f1 | sed -e "s|^/dev/||" | while read B
	#fdisk -l /dev/${A} | grep "^/dev/" | egrep "(Linux|FAT|NTFS)" | grep -v "Linux swap" | grep -v "xtended" | grep -vi "Ext" | grep -vi "Hidden" | cut -d" " -f1 | sed -e "s|^/dev/||" | while read B
	LISTE_PART ${A} avec_tableau_liste=y
	cat /tmp/liste_part_extraite_par_LISTE_PART.txt | while read B
	do
		type=$(TYPE_PART $B)

		B_sans_dev=$(echo "$B"|sed -e "s|^/dev/||")

		mkdir -p /mnt/${B_sans_dev}
		if [ -z "$type" ]; then
			echo -e "$COLTXT"
			echo "Montage de la partition /dev/${B_sans_dev}"
			echo -e "$COLCMD"
			#mount /dev/${B_sans_dev} /mnt/disk
			mount /dev/${B_sans_dev} /mnt/${B_sans_dev}
		else
			if [ "$type" = "ntfs" ]; then
				echo -e "$COLTXT"
				echo "Montage de la partition /dev/${B_sans_dev} ($type) en read-write"
				echo -e "$COLCMD"
				ntfs-3g /dev/${B_sans_dev} /mnt/${B_sans_dev}
				if [ "$?" != "0" ]; then
					echo -e "$COLTXT"
					echo "Nouvel essai de montage de la partition /dev/${B_sans_dev} ($type) en read-only"
					echo -e "$COLCMD"
					mount -t ntfs /dev/${B_sans_dev} /mnt/${B_sans_dev}
				fi
			else
				echo -e "$COLTXT"
				echo "Montage de la partition /dev/${B_sans_dev} ($type)"
				echo -e "$COLCMD"
				#mount -t $type /dev/${B_sans_dev} /mnt/disk
				mount -t $type /dev/${B_sans_dev} /mnt/${B_sans_dev}
			fi
		fi
		if [ "$?" = "0" ]; then
			df -h | grep "^/dev/${B_sans_dev} " > ${doss_rapport}/df_${B_sans_dev}.txt
			#find /mnt/disk/ -type f -name "*.000" > ${doss_rapport}/sauvegardes_${B_sans_dev}.txt
			#find /mnt/disk/ -type f -name "*.ntfs" >> ${doss_rapport}/sauvegardes_${B_sans_dev}.txt
			#find /mnt/${B_sans_dev}/ -type f -name "*.000" > ${doss_rapport}/sauvegardes_${B_sans_dev}.txt

			find /mnt/${B_sans_dev}/ -type f -name "*.000" > ${doss_rapport}/tmp_sauvegardes_${B_sans_dev}.txt

			while read C
			do
				t=$(file "$C"|egrep -i "(gzip compressed data|PartImage file|bzip2 compressed data)")
				if [ -n "$t" ]; then
					echo "$C" >> ${doss_rapport}/sauvegardes_${B_sans_dev}.txt
				fi
			done < ${doss_rapport}/tmp_sauvegardes_${B_sans_dev}.txt

			find /mnt/${B_sans_dev}/ -type f -name "*.ntfs" >> ${doss_rapport}/sauvegardes_${B_sans_dev}.txt

			while read C
			do

				#D=$(echo "$C" | sed -e "s|.000$||")
				#if [ -e "${D}.txt" ]; then
				#	echo "Infos sur $C" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#	cat "${D}.txt" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#	echo "___+*+___" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#fi
				#D=$(echo "$C" | sed -e "s|.ntfs$||")
				#if [ -e "${D}.txt" ]; then
				#	echo "Infos sur $C" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#	cat "${D}.txt" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#	echo "___+*+___" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#fi

				test_ext=$(echo "$C" | grep "000$")
				if [ ! -z "$test_ext" ]; then
					D=$(echo "$C" | sed -e "s|.000$||")
				else
					D=$(echo "$C" | sed -e "s|.ntfs$||")
				fi

				echo "Infos sur $C" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				if [ -e "${D}.txt" ]; then
					cat "${D}.txt" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				else
					echo "Neant." >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				fi
				echo "Volume de la sauvegarde:" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				du -sh ${D}.* >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				echo "___+*+___" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt
				#echo "_-_-_-_-_" >> ${doss_rapport}/sauvegardes_${B_sans_dev}_details.txt

			done < ${doss_rapport}/sauvegardes_${B_sans_dev}.txt
			#umount /mnt/disk
			echo -e "$COLTXT"
			echo "Demontage de la partition /dev/${B_sans_dev}"
			echo -e "$COLCMD"
			umount /mnt/${B_sans_dev}
		fi
	done
done
cd ${doss_rapport}/
tst=$(ls disk_*.fdisk disk_*.sgdisk 2>/dev/null)
if [ -n "$tst" ]; then
  tar -czf disques.tar.gz disk_*.out disk_*.fdisk disk_*.sgdisk
fi
tst=$(ls sauvegardes_*.txt 2>/dev/null)
if [ -n "$tst" ]; then
  tar -czf sauvegardes.tar.gz sauvegardes_*.txt
fi
tst=$(ls df_*.txt 2>/dev/null)
if [ -n "$tst" ]; then
  tar -czf df.tar.gz df_*.txt
fi

# Recherche des modules disque et reseau
#lshw -c storage |grep module |sed -r 's|(.*)( module=)(.*)|\3|'|cut -d" " -f1 > ${doss_rapport}/storage_driver.txt
#lshw -c network |grep module |sed -r 's|(.*)( module=)(.*)|\3|'|cut -d" " -f1 > ${doss_rapport}/network_driver.txt
lshw -c storage |grep driver |sed -r 's|(.*)( driver=)(.*)|\3|'|cut -d" " -f1 > ${doss_rapport}/storage_driver.txt
lshw -c network |grep driver |sed -r 's|(.*)( driver=)(.*)|\3|'|cut -d" " -f1 > ${doss_rapport}/network_driver.txt

chmod 755 ${doss_rapport}/*

# Liste des interfaces:
# ifconfig -a | cut -d" " -f1 | grep -v "^$"

# Verifier que la config reseau est OK.
OLD_IFS=$IFS
IFS=" "
while read A
do
	B=$(expr "${A}" : ".\{3\}\(.\{0,1\}\)")
	if [ "$B" = "ip=" ]; then
		ip=$(echo "$B" | cut -d"=" -f2)
	fi

	B=$(expr "${A}" : ".\{5\}\(.\{0,1\}\)")
	if [ "$B" = "mask=" ]; then
		mask=$(echo "$B" | cut -d"=" -f2)
	fi

	B=$(expr "${A}" : ".\{7\}\(.\{0,1\}\)")
	if [ "$B" = "reboot=" ]; then
		reboot=$(echo "$B" | cut -d"=" -f2)
	fi

done < /proc/cmdline
IFS=$OLD_IFS

#if [ ! -z "$ip" -a ! -z "$mask" ]; then
#	ifconfig eth0 down
#	ifconfig eth0 $ip netmask $mask
#fi

#echo "reboot=$reboot"
#echo "auto_reboot=$auto_reboot"
#sleep 3
#if [ ! -z "$reboot" ]; then
if [ ! -z "$auto_reboot" ]; then
	#delais=$(($reboot*60))
	#sleep $delais
	#reboot

	if [ -z "$delais_reboot" ]; then
		#delais_reboot=10
		delais_reboot=90
	fi

	#if [ "$reboot" = "y" ]; then
	if [ "$auto_reboot" = "y" ]; then
		echo -e "$COLTXT"
		#echo "Reboot dans $delais_reboot secondes."
		#sleep $delais_reboot
		COMPTE_A_REBOURS "Reboot dans" $delais_reboot "secondes."
		echo -e "$COLCMD\c"
		reboot
	else
		if [ "$auto_reboot" = "halt" ]; then
			echo -e "$COLTXT"
			#echo "Reboot dans $delais_reboot secondes."
			#sleep $delais_reboot
			COMPTE_A_REBOURS "Extinction dans" $delais_reboot "secondes."
			echo -e "$COLCMD\c"
			halt
		else
			#sleep 5
			COMPTE_A_REBOURS "On quitte dans" 5 "secondes."
		fi
	fi
fi

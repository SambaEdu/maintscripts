#!/bin/bash
# Distributed under the terms of the GNU General Public License, v2 or later

bootdir='/livemnt/boot'

depend() 
{
	need net
}

start()
{
	ebegin "Starting the pxe-boot-server"

	# ---- check the cdrom files exist
	if ! ls -l ${bootdir}/sysrcd.dat ${bootdir}/???linux/???linux.cfg >/dev/null 2>&1
	then
		eerror "Files are missing, please check you are running a valid SystemRescueCd"
		return 1
	fi

	# ---- check the config file exists
	if [ ! -f /etc/conf.d/pxebootsrv ]
	then
		eerror "The pxebootsrv configuration file \"/etc/conf.d/pxebootsrv\" does not exists. Cannot continue."
		return 1
	fi

	# ---- check the major options are set to 'yes' or 'no'
	if [ $PXEBOOTSRV_DODHCPD != "yes" ] && [ $PXEBOOTSRV_DODHCPD != "no" ]
	then
		eerror "Invalid value for PXEBOOTSRV_DODHCPD. Must be \"yes\" or \"no\" (lowercase)."
		return 1
	fi

	if [ $PXEBOOTSRV_DOTFTPD != "yes" ] && [ $PXEBOOTSRV_DOTFTPD != "no" ]
	then
		eerror "Invalid value for PXEBOOTSRV_DOTFTPD. Must be \"yes\" or \"no\" (lowercase)."
		return 1
	fi

	if [ $PXEBOOTSRV_DOHTTPD != "yes" ] && [ $PXEBOOTSRV_DOHTTPD != "no" ]
	then
		eerror "Invalid value for PXEBOOTSRV_DOHTTPD. Must be \"yes\" or \"no\" (lowercase)."
		return 1
	fi

	if [ $PXEBOOTSRV_DONFSD != "yes" ] && [ $PXEBOOTSRV_DONFSD != "no" ]
	then
		eerror "Invalid value for PXEBOOTSRV_DONFSD. Must be \"yes\" or \"no\" (lowercase)."
		return 1
	fi

	if [ $PXEBOOTSRV_DONBD != "yes" ] && [ $PXEBOOTSRV_DONBD != "no" ]
	then
		eerror "Invalid value for PXEBOOTSRV_DONBD. Must be \"yes\" or \"no\" (lowercase)."
		return 1
	fi

	if [ $PXEBOOTSRV_DONBD = "yes" ] && [ $PXEBOOTSRV_DONFSD = "yes" ]
	then
		eerror "You must choose between NFS and NBD server, they cannot be enabled in the same time."
		return 1
	fi

	if [ $PXEBOOTSRV_DODHCPD == "yes" ]
	then
		# ---- prepare /etc/dhcp/dhcpd.conf from /etc/conf.d/pxebootsrv
		[ -f /etc/dhcp/dhcpd.conf ] && cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.bak
		cp /etc/dhcp/dhcpd.orig /etc/dhcp/dhcpd.conf
	
		if [ -z "$PXEBOOTSRV_SUBNET" -o -z "$PXEBOOTSRV_NETMASK" ]
		then
			eerror "Invalid values for PXEBOOTSRV_SUBNET or PXEBOOTSRV_NETMASK"
			return 1
		else
			sed -i -e "s/subnet 192.168.1.0 netmask 255.255.255.0/subnet $PXEBOOTSRV_SUBNET netmask $PXEBOOTSRV_NETMASK/" /etc/dhcp/dhcpd.conf
			sed -i -e "s/option subnet-mask 255.255.255.0;/option subnet-mask $PXEBOOTSRV_NETMASK;/" /etc/dhcp/dhcpd.conf
		fi
	
		if [ -z "$PXEBOOTSRV_DEFROUTE" ]
		then
			eerror "The config variable PXEBOOTSRV_DEFROUTE is missing"
			return 1
		else
			sed -i -e "s/option routers 192.168.1.254;/option routers $PXEBOOTSRV_DEFROUTE;/" /etc/dhcp/dhcpd.conf
		fi
	
		if [ -z "$PXEBOOTSRV_DHCPRANGE" ]
		then
			eerror "The config variable PXEBOOTSRV_DHCPRANGE is missing"
			return 1
		else
			sed -i -e "s/range dynamic-bootp 192.168.1.100 192.168.1.150;/range dynamic-bootp $PXEBOOTSRV_DHCPRANGE;/" /etc/dhcp/dhcpd.conf
		fi
	
		if [ -z "$PXEBOOTSRV_TFTPSERVER" ]
		then
			eerror "The config variable PXEBOOTSRV_TFTPSERVER is missing"
			return 1
		else
			sed -i -e "s/next-server 192.168.1.5;/next-server $PXEBOOTSRV_TFTPSERVER;/" /etc/dhcp/dhcpd.conf
		fi
	
		if [ -n "$PXEBOOTSRV_DNS" ]
		then
			sed -i -e "s/option domain-name-servers 192.168.1.254;/option domain-name-servers $PXEBOOTSRV_DNS;/" /etc/dhcp/dhcpd.conf
		fi
	fi

	if [ $PXEBOOTSRV_DOTFTPD == "yes" ]
	then
		# ---- prepare pxelinux config file
		[ ! -d /tftpboot/pxelinux.cfg ] && mkdir -p /tftpboot/pxelinux.cfg
		[ ! -f /tftpboot/pxelinux.0 ] && cp /usr/share/syslinux/pxelinux.0 /tftpboot/
		[ -f /tftpboot/pxelinux.cfg/default.bak ] && rm -f /tftpboot/pxelinux.cfg/default.bak
		[ -f /tftpboot/pxelinux.cfg/default ] && mv /tftpboot/pxelinux.cfg/default /tftpboot/pxelinux.cfg/default.bak
		cp --remove-destination ${bootdir}/???linux/{*msg,*c32,*.0,memdisk,netboot} /tftpboot/
		cp --remove-destination ${bootdir}/???linux/???linux.cfg /tftpboot/pxelinux.cfg/default
		if [ -n "$PXEBOOTSRV_TIMEOUT" ]
		then
			sed -i -e "s!^TIMEOUT .*!TIMEOUT $PXEBOOTSRV_TIMEOUT!i" /tftpboot/pxelinux.cfg/default
		fi
		if [ $PXEBOOTSRV_DOHTTPD == "yes" ]
		then
			sed -i -e "s!scandelay=.!scandelay=5 netboot=$PXEBOOTSRV_HTTPSERVER ${PXEBOOTSRV_EXTRA}!g" /tftpboot/pxelinux.cfg/default
		fi
		if [ $PXEBOOTSRV_DONBD == "yes" ]
		then
			sed -i -e "s!scandelay=.!scandelay=5 netboot=nbd://$PXEBOOTSRV_LOCALIP:2000 ${PXEBOOTSRV_EXTRA}!g" /tftpboot/pxelinux.cfg/default
		fi
		if [ $PXEBOOTSRV_DONFSD == "yes" ]
		then
			sed -i -e "s!scandelay=.!scandelay=5 netboot=nfs://$PXEBOOTSRV_LOCALIP:/tftpboot ${PXEBOOTSRV_EXTRA}!g" /tftpboot/pxelinux.cfg/default
		fi
	fi

	# ---- start the NFS server
	if [ $PXEBOOTSRV_DONFSD == "yes" ]
	then
		# ---- nfs export /tftpboot
		touch /etc/exports
		sed -i -e 's!^/tftpboot!#/tftpboot!g' /etc/exports
		echo "/tftpboot *(fsid=0,ro,no_subtree_check,all_squash,insecure,anonuid=1000,anongid=1000)" >> /etc/exports
	fi

	# ---- start the NBD server
	if [ $PXEBOOTSRV_DONBD == "yes" ]
	then
		PXEBOOTSRV_DOHTTPD="no"
		/usr/bin/nbd-server $PXEBOOTSRV_LOCALIP:2000 /tftpboot/sysrcd.dat -r
	fi

	# ---- stop network manager to avoid conflicts
	/etc/init.d/NetworkManager stop

	# ---- start the DHCPD service
	if [ $PXEBOOTSRV_DODHCPD == "yes" ]
	then
		/etc/init.d/dhcpd restart
		if [ "$?" != "0" ]
		then
			eerror "Cannot start /etc/init.d/dhcpd, check /var/log/messages"
			return 1
		fi 
	fi

	# ---- start the THTTPD service
	if [ $PXEBOOTSRV_DOHTTPD == "yes" ]
	then
		/etc/init.d/thttpd restart
		if [ "$?" != "0" ]
		then
			eerror "Cannot start /etc/init.d/thttpd"
			return 1
		fi 
	fi

	# ---- start the TFTPD service
	if [ $PXEBOOTSRV_DOTFTPD == "yes" ]
	then
		/etc/init.d/in.tftpd restart
		if [ "$?" != "0" ]
		then
			eerror "Cannot start /etc/init.d/in.tftpd"
			return 1
		fi 
	fi

	# ---- start the NFS server
	if [ $PXEBOOTSRV_DONFSD == "yes" ]
	then
                /etc/init.d/nfs restart
		if [ "$?" != "0" ]
		then
			eerror "Cannot start /etc/init.d/nfs"
			return 1
		fi

	fi
	
	return 0
}

stop()
{
	ebegin "Stopping the pxe-boot-server"

	/etc/init.d/thttpd stop
	/etc/init.d/in.tftpd stop
	/etc/init.d/dhcpd stop

	return 0
}

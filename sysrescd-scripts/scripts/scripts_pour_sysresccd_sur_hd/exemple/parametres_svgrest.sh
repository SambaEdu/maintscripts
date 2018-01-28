# Param�tres pour un SysRescCD install� sur disque dur.

# Partition � sauvegarder/restaurer:
PARDOS=hda1

# Partition du syst�me SysRescCD:
SYSRESCDPART=hda2

# Format de sauvegarde:
# - partimage
# - ntfsclone
# - dar
TYPE_SVG=partimage

# Pr�ciser le type de la partition � sauvegarder dans le cas d'une sauvegarde dar
TYPE_PARDOS_FS=""

# Nom de l'image par d�faut
NOM_IMAGE_DEFAUT=image.${TYPE_SVG}

# Sauvegarde/restauration automatique avec le nom d'image par d�faut:
svgrest_auto=n

# Action apr�s sauvegarde/restauration:
#�- reboot
# ou
# - arret
svgrest_arret_ou_reboot=reboot

# Emplacement de stockage des sauvegardes:
EMPLACEMENT_SVG=/home/sauvegarde



# ================================================
# Chemin de ntfsclone
chemin_ntfs=/usr/sbin

# Chemin de dar
chemin_dar=/usr/bin

# ================================================
# Adaptation de l'extension au type de sauvegarde:
case ${TYPE_SVG} in
	"partimage")
		SUFFIXE_SVG='000'
	;;
	"ntfsclone")
		SUFFIXE_SVG='ntfs'
	;;
	"dar")
		SUFFIXE_SVG='1.dar'
	;;
esac

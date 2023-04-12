#!/bin/sh -x
set -e
. /etc/os-release

# http://download.proxmox.com/iso

ISO_FILE=$1
DEBIAN_RELEASE=$2
DEBIAN_RELEASE=${DEBIAN_RELEASE:="$VERSION_CODENAME"} # default to version in /etc/os-release


[ -z "$ISO_FILE" ] && echo "upgrade-proxomox.sh iso-image-file" &&  exit 1

DIRNAME="$(eval dirname '$0')"

[ ! -f "$ISO_FILE"  ]   && echo "File not found: $ISO_FILE" &&  exit 1
[ ! -d "/media/cdrom" ] && mkdir -p "/media/cdrom"

mount -o loop "$ISO_FILE" /media/cdrom

echo "deb [trusted=yes] file:///media/cdrom/ $DEBIAN_RELEASE pve" >>/etc/apt/sources.list
apt     update
apt-get upgrade
apt-get dist-upgrade

umount /media/cdrom
sed -i '/\/media\/cdrom/d' /etc/apt/sources.list

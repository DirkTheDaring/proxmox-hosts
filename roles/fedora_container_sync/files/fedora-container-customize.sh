#!/usr/bin/bash
# Inspired by: https://fedoramagazine.org/how-to-build-fedora-container-images/
set -ex
SOURCE_DIR="/mnt/pve/shared/template/cache"
ROOT_DIR="/var/cache/Fedora-Container-Base-root"
TARGET_DIR=$SOURCE_DIR
MAX=3

function get_resolv_conf 
{
  local REALPATH
  local BASENAME

  # heuristic: if systemd-resolved symlinks the file get original
  if [[ -L /etc/resolv.conf ]]; then
	  REALPATH=$(realpath /etc/resolv.conf)
	  DIRNAME=$(dirname "${REALPATH}")
	  echo $DIRNAME/resolv.conf
	  return
  fi 
  echo /etc/resolv.conf
}

function get_container_images
{
  find "$1" -type f -name "Fedora-Container-Base-*.x86_64.tar.xz"
}
function get_latest_container_image
{
  get_container_images "$1"\
  | grep -v "sshd.x86_64.tar.xz$"\
  | sort -Vr\
  | head -1
}

if [[ $EUID -ne 0 ]]; then
    echo  "must be run as root."
    exit 1
fi

IMAGE=$(get_latest_container_image "$SOURCE_DIR")

if [ -z "$IMAGE" ]; then
    echo "* no image found"
    exit 0
fi

TARGET_NAME=$(basename -s .x86_64.tar.xz "${IMAGE}")-sshd.x86_64.tar.xz

if [ -f "${TARGET_DIR}/${TARGET_NAME}" ]; then
	exit 0
fi

RESOLV_FILE=$(get_resolv_conf)

rm -rf "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}"

# Extract layer.tar from .xz repo and write it to stdout
# then extract the layer.tar file to ROOT_DIR
tar --wildcards -xOvJf "${IMAGE}" '*/layer\.tar'\
| tar xv -C "${ROOT_DIR}"

cp "${RESOLV_FILE}" "${ROOT_DIR}/etc/resolv.conf"
chroot "${ROOT_DIR}" dnf update -y
chroot "${ROOT_DIR}" dnf install -y openssh-server systemd-networkd iproute procps-ng sssd-client which
chroot "${ROOT_DIR}" dnf clean all
chroot "${ROOT_DIR}" systemctl enable sshd
chroot "${ROOT_DIR}" systemctl enable systemd-networkd
#chroot "${ROOT_DIR}" useradd core -G wheel
chroot "${ROOT_DIR}" rm -f "${ROOT_DIR}/etc/resolv.conf"

# with .tmp we avoid that other scripts star processing *.xz while xz is still not finished 
tar -C "${ROOT_DIR}" --transform='s|^\./||S' -cJvf "${TARGET_DIR}/${TARGET_NAME}.tmp" .
mv "${TARGET_DIR}/${TARGET_NAME}.tmp" "${TARGET_DIR}/${TARGET_NAME}"
rm -rf "${ROOT_DIR}"

find "${TARGET_DIR}" -type f -name "*-sshd.x86_64.tar.xz"\
| sort -Vr | awk -v MAX=${MAX} '{ if ( NR > MAX ) print }'\
| while read -r FILENAME; do rm -f "${FILENAME}" ; done

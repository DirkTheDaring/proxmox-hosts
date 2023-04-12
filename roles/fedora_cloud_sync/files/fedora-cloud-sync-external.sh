#!/usr/bin/bash
set -e
DOWNLOAD_DIR=/mnt/pve/shared/images/000

URL0=https://ftp.halifax.rwth-aachen.de/fedora/linux/releases/ #/36/Cloud/aarch64/images/
ARCH_LIST="x86_64 aarch64"
ERROR=0
for ARCH in $ARCH_LIST; do
    FEDORA_VERSION=$(curl -s "${URL0}" |grep -Po '(?<=href=")[^"]*'|grep -P "^[0-9]+/$"|sort -Vr |head -1)
    URL1=${URL0}${FEDORA_VERSION}Cloud/${ARCH}/images/
    BASENAME=$(curl -s $URL1|grep -Po '(?<=href=")[^"]*' | grep ".qcow2$"| sort -Vr| head -1)
    
    URL="${URL1}${BASENAME}"
    
    TARGET_NAME=$BASENAME
    
    if [ -f "${TARGET_NAME}" ]; then
        echo "Already exists: ${TARGET_NAME}"
	continue
    fi
    
    mkdir -p "${DOWNLOAD_DIR}"
    
    CHECKSUM_BASENAME=$(basename -s .${ARCH}.qcow2 "${BASENAME}"|sed s/^Fedora-Cloud-Base/Fedora-Cloud/ )-${ARCH}-CHECKSUM
    CHECKSUM_URL=${URL1}${CHECKSUM_BASENAME}
    CHECKSUM_FILENAME=${DOWNLOAD_DIR}/${CHECKSUM_BASENAME}
    
    if [ ! -f "${CHECKSUM_FILENAME}" ]; then
        curl -s -o "${CHECKSUM_FILENAME}" "${CHECKSUM_URL}"
    fi
    
    EXPECTED_SHA256SUM=$(cat $CHECKSUM_FILENAME|grep "^SHA256.*$BASENAME"|awk '{print $NF}')
    if [ -z "$EXPECTED_SHA256SUM" ]; then
        echo "Removing checksum file as it does not contain a sha256 checksum:  $CHECKSUM_FILENAME"
        rm -f "${CHECKSUM_FILENAME}"
	ERROR=1
        continue
    fi
    
    FILENAME="${DOWNLOAD_DIR}/${BASENAME}"
    
    if [ ! -f "${FILENAME}" ]; then
	echo "* Download ${FILENAME}"
        curl -o "${FILENAME}.tmp" "$URL"
        ACTUAL_SHA256SUM=$(sha256sum ${FILENAME}.tmp|awk '{print $1}')
        if [ "$EXPECTED_SHA256SUM" != "$ACTUAL_SHA256SUM" ]; then
            rm -f ${FILENAME}.tmp
	    ERROR=1
            continue
        fi
        mv "${FILENAME}.tmp" "${FILENAME}"
    fi
done

exit $ERROR

# FIXME Cleanup max 3 old cheksum + qcow files
# FIXME create a SBOM entry

#!/usr/bin/env bash
set -e
SOURCE_DIR=$1
TARGET_DIR=$2
PATTERN="fedora-coreos-*-qemu.x86_64.qcow2"
MAX=3

function echo_stderr {
  echo "$@" 1>&2;
}

for VAR_NAME in SOURCE_DIR TARGET_DIR; do

    eval DIR=\$$VAR_NAME

    if [ -z "${DIR}" ]; then
        echo_stderr "please provide ${VAR_NAME}"
        exit 1
    fi

    if [ ! -d "${DIR}" ]; then
        echo_stderr "directory provided by '${VAR_NAME}' does not exist: ${DIR}"
        exit 1
    fi

done

echo_stderr "* Unpack from '${SOURCE_DIR}' to '${TARGET_DIR}'"

# Remove any leftover tmp files
find "${TARGET_DIR}" -type f -name '*.tmp' -exec rm -f {} \;

LIST=($(find "${SOURCE_DIR}" -type f -name "${PATTERN}.xz"))
for IMAGE in ${LIST[@]}; do

  UNPACKED_IMAGE=$(basename -s .xz "${IMAGE}")
  TARGET="${TARGET_DIR}/${UNPACKED_IMAGE}"
  if [ -f "${TARGET}" ] ; then
          continue
  fi

  echo_stderr "  Unpacking '${IMAGE}' to '${TARGET}'"

  xz -dc "${IMAGE}" >"${TARGET}.tmp"
  mv "${TARGET}.tmp" "${TARGET}"
done

echo_stderr "* Cleanup ${PATTERN} max ${MAX} files"
find "${TARGET_DIR}" -maxdepth 1 -name "${PATTERN}"| sort -Vr | awk -v MAX=${MAX} '{ if ( NR > MAX ) print }' \
| while read -r FILENAME; do rm -f "${FILENAME}" ; done

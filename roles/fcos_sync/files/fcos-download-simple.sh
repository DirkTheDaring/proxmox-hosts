#!/usr/bin/env bash
set -e
IMAGE_LIST="metal qemu"
DIRNAME=$(dirname "$0")
function echo_stderr {
  echo "$@" 1>&2; 
}

if [ -z "$1" ]; then
  echo_stderr "please provide target dir."
  exit 1
fi

TARGET_DIR=$1
if [ ! -d "$TARGET_DIR" ]; then
  echo_stderr "target dir does not exist: $TARGET_DIR"
  exit 1
fi
echo_stderr "* Download"

# Remove any leftover tmp files
#find "${TARGET_DIR}" -type f -name '*.tmp' -exec rm -f {} \;
for IMAGE in $IMAGE_LIST; do
  URL=$($DIRNAME/fcos-latest-version.sh $IMAGE)
  SHA256=$($DIRNAME/fcos-latest-version.sh ${IMAGE}-sha256)

  BASENAME=$(basename "$URL")
  TARGET_FILE="$TARGET_DIR/$BASENAME"

  [ -f "$TARGET_FILE" ] && continue
  echo "$TARGET_FILE"

  # Download into tmp first, rename after passed test
  TARGET_FILE_TMP=${TARGET_FILE}.tmp
  curl -s -L -o "${TARGET_FILE_TMP}" -C - "$URL" 
  SHA256_DOWNLOAD=$(sha256sum "$TARGET_FILE_TMP"|cut -d" " -f1)
  if [ "$SHA256" != "$SHA256_DOWNLOAD" ]; then
      echo_stderr "download failed for $TARGET_FILE_TMP. Cleanup"
      rm -f "$TARGET_FILE_TMP"
  fi
  # finally, after passed checksum rename it to real name
  mv "${TARGET_FILE_TMP}" "${TARGET_FILE}"

done

# Cleanup. Keep last 3 versions
echo_stderr "* Cleanup"
for IMAGE in $IMAGE_LIST; do
  PATTERN="fedora-coreos*$IMAGE*.xz"
  find "${TARGET_DIR}" -maxdepth 1 -name "$PATTERN" | sort -Vr | awk '{ if ( NR > 3 ) print }' \
  | while read -r FILENAME; do rm -f "${FILENAME}" ; done 
done

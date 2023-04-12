#!/usr/bin/env bash
set -e
FCOS_DIR="${HOME}/pub/linux/fcos"
TARGET_DIR=.

function get_config_file
{
  for NAME in ./.fcos-sync $HOME/.fcos-sync /etc/fcos-sync/fcos-sync.conf; do
      if [ -e "$NAME" ]; then
	      echo "$NAME"
	      return
      fi
  done
}
CONFIG_FILE=$(get_config_file)
if [ -n "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

if [ ! -d "$FCOS_DIR" ]; then
	echo "directory does not exist: $FCOS_DIR"
	exit 1
fi

mkdir -p "$TARGET_DIR"
$(dirname "$0")/fcos-unpack.sh "$FCOS_DIR" "$TARGET_DIR"

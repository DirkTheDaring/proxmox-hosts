#!/usr/bin/env bash
set -ex
FCOS_DIR="${HOME}/pub/linux/fcos"

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

mkdir -p "$FCOS_DIR"
$(dirname "$0")/fcos-download-simple.sh "$FCOS_DIR"

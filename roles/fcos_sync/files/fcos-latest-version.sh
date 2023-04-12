#!/usr/bin/env bash
set -e

# debian: apt install -y jq
# fedora: dnf install -y jq

IMAGE=$1
IMAGE=${IMAGE:="baremetal"}
CHANNEL=$2
CHANNEL=${CHANNEL:="stable"} # default to stable if CHANNEL is empty
URL="https://builds.coreos.fedoraproject.org/streams/$CHANNEL.json"

CACHETIME_DAYS=1
CACHE_DIR="$HOME/.cache/fcos"
FILENAME="$CACHE_DIR/$CHANNEL.json"

# CACHE_DAYS	the cachetime in days
# CACHE_DIR	the cache dir
# URL		the url where to download
# FILENAME	optional, if not set, filename is derived from url
function download_with_cache
{
    local CACHE_DAYS=$1
    local CACHE_DIR=$2
    local URL=$3
    local FILENAME=$4
    local CACHE_FILE CURRENT_EPOCH EPOCH DIFF MAX

    [ -z "$FILENAME" ] && FILENAME=$(basename "$URL")

    [ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
    CACHE_FILE=$CACHE_DIR/$FILENAME
    
    CURRENT_EPOCH=$(date +'%s')
    if [ -f "$CACHE_FILE"  ]; then
      EPOCH=$(stat "$CACHE_FILE" --format "%W")
    
      DIFF=$(($CURRENT_EPOCH - $EPOCH))
      MAX=$(( 24 * 3600 * $CACHE_DAYS))
      if [ $DIFF -gt $MAX ]; then
        rm -f "$CACHE_FILE"
      fi
    fi
    
    if [ ! -f "$CACHE_FILE"  ]; then
      curl -o "$CACHE_FILE" -L "$URL"
    fi

    echo $CACHE_FILE
}

CACHE_FILE=$(download_with_cache "$CACHETIME_DAYS" "$CACHE_DIR" "$URL")

if [ "$IMAGE" = "qemu" ]; then
    JQ='.architectures.x86_64.artifacts.qemu.formats["qcow2.xz"].disk.location'
elif [ "$IMAGE" = "qemu-sha256" ]; then
    JQ='.architectures.x86_64.artifacts.qemu.formats["qcow2.xz"].disk.sha256'
elif [ "$IMAGE" = "metal" ]; then
    JQ='.architectures.x86_64.artifacts.metal.formats["raw.xz"].disk.location'
elif [ "$IMAGE" = "metal-sha256" ]; then
    JQ='.architectures.x86_64.artifacts.metal.formats["raw.xz"].disk.sha256'
else 
    exit 0
fi

cat ${CACHE_FILE} \
| jq -r "$JQ"

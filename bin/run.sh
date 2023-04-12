#!/usr/bin/bash
set -eux
BASENAME=$(basename -s .sh "$0")
ARRAY=(${BASENAME//-/ })
echo "# = ${#ARRAY[@]}"

CLUSTER=${ARRAY[1]}
TARGET=playbook.yaml

[[ "${ARRAY[0]}" == run  ]] && ACTION=ansible-playbook  TARGET=playbook.yaml
[[ "${ARRAY[0]}" == test ]] && ACTION=ansible-inventory TARGET=--list


LIST=($(cat<<EOF
inventory/$CLUSTER/hosts.yaml
inventory/$CLUSTER/groups.yaml
EOF
))

ITEMS=()
for FILEPATH in "${LIST[@]}"; do
        if [ ! -e "${FILEPATH}" ]; then
                echo "$FILEPATH not found." >&2
                exit 1
        else
                ITEMS+=(-i)
                ITEMS+=(${FILEPATH})
        fi
done

$ACTION \
  ${ITEMS[@]} \
  "${TARGET}" \
  "$@"

#!/usr/bin/env bash
set -ex
# Ansible will regenerate the /etc/storage-configuration.conf
# This way it can pick-up configuration changes and in turn
# this script is only run when the storage-configuration.conf has changed
# The script only runs then on the first node of any cluster
# therefore limiting a "change storm" of the configuration

if [ -n "$1" ]; then
    . "$1"
else
    . /etc/storage-configuration.conf
fi

function apply_nfs
{

    # ugly remove and add logic, but i found no easy way to
    # verify if setting is the same as we have no with the
    # parameters. With the FIRST_NODE_NAME logic above, we
    # at least only apply it to one node of cluster, the first.

    if pvesm status --storage "${SHARE_NAME}" 2>&1 >/dev/null; then
        pvesm remove "${SHARE_NAME}"
    fi

    pvesm add "${SHARE_TYPE}"\
     "${SHARE_NAME}"\
     --content "${SHARE_CONTENT}"\
     --path "${MOUNT_PATH}"\
     --server "${NFS_SERVER}"\
     --export "${NFS_EXPORT}"\
     --options "${NFS_OPTIONS}"
}

CURRENT_NODE_NAME=$(hostname -s)
FIRST_NODE_NAME=$( ls /etc/pve/nodes | head -1 )

# we pick the first node name as default.
# overriden by setting NODE_NAME to a specific value
NODE_NAME="${NODE_NAME:=${FIRST_NODE_NAME}}"

# Shall only run on first node of a cluster (or the NODE_NAME set before in an environment variable)
# (this ensures "only once" when ansible tries to run it on all cluster nodes)
# but we can have nodes which are not part of the cluster, then this still works.
# as the first node will always be then the node name of the machine
# Therefore a remove/add operations only happens once in a cluster like on a single node
# this because the /etc/pve/storage.cfg file is shared by the proxmox cluster

if [ "${CURRENT_NODE_NAME}" != "${NODE_NAME}" ]; then
    echo "Skipping. Current node ${CURRENT_NODE_NAME} does not match the required node name ${NODE_NAME}"
    exit 0
fi

I=0
while true;
do
    for VAR_NAME in SHARE_NAME SHARE_TYPE SHARE_CONTENT MOUNT_PATH NFS_SERVER NFS_EXPORT NFS_OPTIONS;
    do
        eval ${VAR_NAME}=\$${VAR_NAME}${I}
    done
    # quit loop if there is no SHARE_NAME anymore
    [ -z "${SHARE_NAME}" ] && exit 0

    apply_nfs

    I=$(( I+1 ))
done

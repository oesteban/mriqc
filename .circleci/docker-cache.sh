#!/bin/bash
#
# Docker cache script
#
#

# Setting      # $ help set
set -e         # Exit immediately if a command exits with a non-zero status.
set -u         # Treat unset variables as an error when substituting.
set -x         # Print command traces before executing command.

DOCKER_ROOT_DIR="/var/lib/docker"
DOCKER_VOLUMES="${DOCKER_ROOT_DIR}/btrfs/subvolumes"

DOCKER_CACHE_DIR="/home/ubuntu/.cache/docker"

mkdir -p /home/ubuntu/btrfs
for layerpath in $( find ${DOCKER_VOLUMES} -maxdepth 1 ); do
	layerid=$( basename $layerpath )
	echo "Caching layer $layerid"
	# Cache this layer
	btrfs subvolume snapshot -r $layerpath /home/ubuntu/btrfs/$layerid | gzip -9 > ${DOCKER_CACHE_DIR}/$layerid.gz
done
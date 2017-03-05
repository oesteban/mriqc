#!/bin/bash
#
# Docker cache script
#
#

# Setting      # $ help set
set -e         # Exit immediately if a command exits with a non-zero status.
set -u         # Treat unset variables as an error when substituting.
set -x         # Print command traces before executing command.

DOCKER_CACHE_DIR="/home/ubuntu/.cache/docker"

# Modify the docker directory
echo "DOCKER_OPTS=\"-g ${DOCKER_CACHE_DIR} -s btrfs -D\"" >> /etc/default/docker

if [ ! -d "${DOCKER_CACHE_DIR}" ]; then
	echo "No docker cache found in ${DOCKER_CACHE_DIR}"
	service docker restart
	exit 0
fi

if [ ! -d "${DOCKER_CACHE_DIR}/btrfs" ]; then
	echo "No BTRFS system found"
fi

if [ ! -d "${DOCKER_CACHE_DIR}/btrfs-sys" ]; then
	echo "No cache of BTRFS system found"
fi

# Print empty layers
find ${DOCKER_CACHE_DIR}/btrfs/subvolumes -maxdepth 1 \! -empty -print

# Link layers
mv ${DOCKER_CACHE_DIR}/btrfs ${DOCKER_CACHE_DIR}/btrfs-sys
mkdir -p ${DOCKER_CACHE_DIR}/btrfs
btrfs subvolume create ${DOCKER_CACHE_DIR}/btrfs/subvolumes
for src in $( ls ${DOCKER_CACHE_DIR}/btrfs-sys/subvolumes/* ); do
	layer=$( basename $src )

	if find "$src" -mindepth 1 -print -quit | grep -q .; then
		btrfs subvolume create ${DOCKER_CACHE_DIR}/btrfs/subvolumes/$layer
		cp -r $src/* ${DOCKER_CACHE_DIR}/btrfs/subvolumes/$layer/
	else
		echo "Layer $layer is empty"
	fi
done

chown --reference=/var/lib/docker ${DOCKER_CACHE_DIR}
chmod --reference=/var/lib/docker ${DOCKER_CACHE_DIR}
service docker restart

# Clean-up broken layers
# for broken in $( find ${DOCKER_CACHE_DIR}/btrfs-sys/subvolumes/ -user nobody -type d ); do
# 	rm ${DOCKER_CACHE_DIR}/btrfs/subvolumes/$( basename $broken )
# 	echo "Removed pruned broken layer $( basename $broken)"
# done

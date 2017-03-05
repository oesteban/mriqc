#!/bin/bash
#
# Docker cache script
#
#

# Setting      # $ help set
set -e         # Exit immediately if a command exits with a non-zero status.
set -u         # Treat unset variables as an error when substituting.
set -x         # Print command traces before executing command.

mkdir -p /home/ubuntu/.cache/docker/btrfs/
mv /home/ubuntu/.cache/docker/btrfs /home/ubuntu/.cache/docker/btrfs-sys

# Link layers
mkdir -p /home/ubuntu/.cache/docker/btrfs/subvolumes
for src in $( ls /home/ubuntu/.cache/docker/btrfs-sys/subvolumes/* ); do
	layer=$( basename $src )
	ln -s $src /home/ubuntu/.cache/docker/btrfs/subvolumes/$layer
done

# Clean-up broken layers
for broken in $( find /home/ubuntu/.cache/docker/btrfs-sys/subvolumes/ -user nobody -type d ); do
	rm /home/ubuntu/.cache/docker/btrfs/subvolumes/$( basename $broken )
	echo "Removed pruned broken layer $( basename $broken)"
done
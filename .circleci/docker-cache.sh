#!/bin/bash
#
# Docker cache script
#
#

# Setting      # $ help set
set -e         # Exit immediately if a command exits with a non-zero status.
set -u         # Treat unset variables as an error when substituting.
set -x         # Print command traces before executing command.

rsync -ra --sparse /home/ubuntu/.var/lib/docker/* ~/.cache/docker/
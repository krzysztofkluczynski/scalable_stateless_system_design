#!/bin/bash

NAME=$1
# DISK_PATH="image/${NAME}.qcow2"

echo "Stopping VM: $NAME"
virsh destroy "$NAME" 2>/dev/null || echo "$NAME already stopped"

echo "Undefining VM: $NAME"
virsh undefine "$NAME" 2>/dev/null

# if [ -f "$DISK_PATH" ]; then
#   echo "Removing disk: $DISK_PATH"
#   rm -f "$DISK_PATH"
# fi

echo "VM $NAME deleted successfully."

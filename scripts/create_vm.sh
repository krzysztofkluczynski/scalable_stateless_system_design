#!/bin/bash

set -e

NAME=$1
IP=$2  # expected to be 192.168.122.101 or .102

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BASE_IMAGE="/var/lib/libvirt/images/ubuntu-server.qcow2"
DISK_IMAGE="/var/lib/libvirt/images/${NAME}.qcow2"

NETWORK_TEMPLATE="$PROJECT_ROOT/cloud-init/network-config-template.yaml"
NETWORK_CONFIG="$PROJECT_ROOT/cloud-init/network-config"

# === Step 1: Create VM disk (qcow2 overlay)
if [ ! -f "$DISK_IMAGE" ]; then
  echo "Creating disk image for $NAME..."
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$DISK_IMAGE" 5G
fi

# === Step 2: Prepare cloud-init network config
cp "$NETWORK_TEMPLATE" "$NETWORK_CONFIG"
sed -i "s/IPADDR/${IP}/g" "$NETWORK_CONFIG"

echo "Generating seed image..."
cloud-localds --network-config="$NETWORK_CONFIG" "/var/lib/libvirt/images/seed-${NAME}.img" "$PROJECT_ROOT/cloud-init/user-data"

# === Step 3: Launch the VM
virt-install \
  --name "$NAME" \
  --memory 4096 \
  --vcpus 1 \
  --disk path="$DISK_IMAGE",format=qcow2 \
  --disk path="/var/lib/libvirt/images/seed-${NAME}.img",device=cdrom \
  --network network=default \
  --graphics none \
  --os-variant ubuntu20.04 \
  --import \
  --noautoconsole



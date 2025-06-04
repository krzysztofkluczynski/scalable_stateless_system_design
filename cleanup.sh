#!/bin/bash
set -e

# === Config ===
IMAGE_DIR="image"
HAPROXY_CONFIG="haproxy/haproxy.cfg"
CLOUDINIT_CONFIG="cloud-init/network-config"
LOG_FILE="logs/autoscaler.log"

echo "Stopping autoscaler (if running)..."
pkill -f autoscaler.sh || true

echo "Killing HAProxy (if running)..."
sudo pkill haproxy || true

# Cleanup VMs 
for vm in vm1 vm2; do
  echo "Destroying VM: $vm"
  sudo virsh destroy "$vm" 2>/dev/null || true
  sudo virsh undefine "$vm" --remove-all-storage 2>/dev/null || true
  sudo rm -f "${IMAGE_DIR}/${vm}.qcow2"
done

# Cleanup configs and logs
echo "Removing generated cloud-init config..."
rm -f "$CLOUDINIT_CONFIG"

echo "Removing generated cloud-init seed images..."
sudo rm -f /var/lib/libvirt/images/seed-vm1.img /var/lib/libvirt/images/seed-vm2.img

echo "Removing dynamic HAProxy entries between autoscaler markers..."
sed -i '/# BEGIN AUTOSCALER SERVERS/,/# END AUTOSCALER SERVERS/ {/BEGIN AUTOSCALER SERVERS/b; /END AUTOSCALER SERVERS/b; d}' haproxy/haproxy.cfg

echo "Removing autoscaler log..."
rm -f "$LOG_FILE"



#!/bin/bash

# Virtual machine configuration
VM_NAME="alpine-vm"
VM_DISK="alpine-vm.qcow2"
VM_RAM="512"  # RAM for the VM (in MB)
VM_CPUS="1"   # Number of CPUs
DISK_SIZE="3G"  # Disk size (adjust based on your needs)

# Path to your already downloaded Alpine Linux image
ALPINE_IMAGE_PATH="./alpine-minirootfs-3.17.0-x86_64.tar.gz"
# Make sure the image file is downloaded before running the script

# Virtual machine IP (static IP or DHCP, depending on your config)
VM_IP="192.168.122.10"

# 1. Check if the Alpine image exists
if [ ! -f "$ALPINE_IMAGE_PATH" ]; then
  echo "Alpine image not found! Please download it separately and place it in the current directory."
  exit 1
fi

# 2. Create the disk for the virtual machine
echo "Creating disk for VM..."
qemu-img create -f qcow2 $VM_DISK $DISK_SIZE

# 3. Unpack the Alpine Linux image
sudo mkdir -p /mnt/alpine
sudo mount -o loop $ALPINE_IMAGE_PATH /mnt/alpine
sudo cp -a /mnt/alpine/* ./  # Copy all contents to the new VM disk
sudo umount /mnt/alpine

# 4. Create the VM using QEMU
echo "Creating the virtual machine..."
qemu-system-x86_64 \
  -m $VM_RAM \
  -vcpus $VM_CPUS \
  -hda $VM_DISK \
  -boot d \
  -cdrom /path/to/ubuntu.iso \  # Modify to actual ISO path
  -network bridge=virbr0,model=virtio \
  -nographic &  # Run the VM in the background

# 5. Wait for VM to boot, SSH access for installation
echo "Waiting for VM to boot up... (Please give it a minute)"

# 6. Install Python and FastAPI (inside VM)
echo "Setting up Python and FastAPI..."
# You will need to access the VM through a console or SSH here to install these dependencies.
# Here's an example of commands you'd run inside the VM:
sshpass -p 'your_password' ssh root@192.168.122.10 << EOF
  apk update
  apk add python3 py3-pip
  pip3 install fastapi uvicorn
EOF

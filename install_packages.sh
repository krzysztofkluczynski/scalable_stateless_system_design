echo "Installing required packages (if missing)..."
sudo apt update
sudo apt install -y \
  haproxy \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virtinst \
  cloud-init \
  jq \
  curl \
  apache2-utils \
  cloud-image-utils
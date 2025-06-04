```
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst cloud-init
```

```
pip install -r requirements.txt
```

```
sudo mv ~/WSO/image/ubuntu-server.qcow2 /var/lib/libvirt/images/
```

```
./initial.sh
```

```
curl http://localhost/
```

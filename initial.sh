#!/bin/bash

set -euo pipefail

# === CONFIG ===
VM1_NAME="vm1"
VM1_IP="192.168.122.101" 
HAPROXY_CONFIG="haproxy/haproxy.cfg"
AUTOSCALER_SCRIPT="scripts/autoscaler.sh"

MARKER_START="# BEGIN AUTOSCALER SERVERS"
SERVER_LINE="    server $VM1_NAME $VM1_IP:8000 weight 50 check"

echo "[0/4] Adding $VM1_NAME to HAProxy config if not present..."

if ! sed -n "/$MARKER_START/,/# END AUTOSCALER SERVERS/p" "$HAPROXY_CONFIG" | grep -q "$VM1_NAME"; then
  sed -i "/$MARKER_START/a\\
$SERVER_LINE" "$HAPROXY_CONFIG"
  echo "Inserted server $VM1_NAME into autoscaler section."
else
  echo "Server $VM1_NAME already present in autoscaler section."
fi

echo "[1/4] Starting HAProxy..."
sudo haproxy -f "$HAPROXY_CONFIG" &
sleep 1

echo "[2/4] Creating initial VM: $VM1_NAME ($VM1_IP)..."
./scripts/create_vm.sh "$VM1_NAME" "$VM1_IP"

echo "[3/4] Waiting for FastAPI to boot..."
until curl -s "http://${VM1_IP}:8000" >/dev/null; do
  echo "  ...waiting for FastAPI on ${VM1_IP}:8000"
  sleep 2
done

echo "[4/4] Launching autoscaler in background..."
mkdir -p logs
nohup bash "$AUTOSCALER_SCRIPT" > logs/autoscaler.log 2>&1 &

echo "System initialized. Access service at: http://localhost/"

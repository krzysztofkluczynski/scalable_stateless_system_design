#!/bin/bash

THRESHOLD=20
CHECK_INTERVAL=60

VM2_NAME="vm2"
VM2_IP="192.168.122.102"
API_ENDPOINT="http://192.168.122.101:8000/metrics"  # IP of vm1

while true; do
    echo "Checking traffic..."
    metrics=$(curl -s "$API_ENDPOINT")
    requests=$(echo "$metrics" | jq '.requests')
    elapsed=$(echo "$metrics" | jq '.elapsed_seconds')

    rpm=$((requests * 60 / elapsed))
    echo "Requests per minute: $rpm"

    if [ "$rpm" -gt "$THRESHOLD" ]; then
        if ! virsh list --name | grep -q "$VM2_NAME"; then
            echo "High traffic - scaling UP: creating $VM2_NAME"
            ./scripts/create_vm.sh "$VM2_NAME" "$VM2_IP"
            ./scripts/update_haproxy.sh add "$VM2_NAME" "$VM2_IP"
        else
            echo "$VM2_NAME already running"
        fi
    elif [ "$rpm" -lt "$THRESHOLD" ]; then
        if virsh list --name | grep -q "$VM2_NAME"; then
            echo "Low traffic - scaling DOWN: deleting $VM2_NAME"
            ./scripts/delete_vm.sh "$VM2_NAME"
            ./scripts/update_haproxy.sh remove "$VM2_NAME" "$VM2_IP"
        else
            echo "$VM2_NAME already stopped"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done

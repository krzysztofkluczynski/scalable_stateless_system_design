#!/bin/bash

THRESHOLD=20
CHECK_INTERVAL=60

VM2_NAME="vm2"
VM2_IP="192.168.122.102"
API_ENDPOINT="http://192.168.122.101:8000/metrics"  # IP of vm1

# Initial check if VM2 is running
if virsh list --name | grep -q "$VM2_NAME"; then
    vm_running=true
else
    vm_running=false
fi

MIN_ELAPSED=10 

while true; do
    echo "Checking traffic..."
    metrics=$(curl -s "$API_ENDPOINT")
    requests=$(echo "$metrics" | jq '.requests')
    elapsed=$(echo "$metrics" | jq '.elapsed_seconds')

    # Skip if elapsed is too small
    if (( $(echo "$elapsed < $MIN_ELAPSED" | bc -l) )); then
        echo "Elapsed time $elapsed is too small (< $MIN_ELAPSED), skipping calculation"
        sleep 2
        continue
    fi

    # Avoid division by zero just in case
    if (( $(echo "$elapsed == 0" | bc -l) )); then
        echo "Elapsed time is zero, skipping calculation"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    rpm=$(echo "scale=2; $requests * 60 / $elapsed" | bc) #TODO: BIERZE CZAS OD POCZATKU DZIALANIA PROGRAMU, TRZEBA PRZEMYSLEC I BRAC NP Z OSTATNIEJ MINUTY
    echo "Requests per minute: $rpm"

    if [ "$(echo "$rpm > $THRESHOLD" | bc -l)" -eq 1 ]; then
        if ! $vm_running; then
            echo "High traffic - scaling UP: creating $VM2_NAME"
            ./scripts/create_vm.sh "$VM2_NAME" "$VM2_IP"
            ./scripts/update_haproxy.sh add "$VM2_NAME" "$VM2_IP"
            vm_running=true
        else
            echo "$VM2_NAME already running"
        fi
    elif [ "$(echo "$rpm < $THRESHOLD" | bc -l)" -eq 1 ]; then
        if $vm_running; then
            echo "Low traffic - scaling DOWN: deleting $VM2_NAME"
            ./scripts/delete_vm.sh "$VM2_NAME"
            ./scripts/update_haproxy.sh remove "$VM2_NAME" "$VM2_IP"
            vm_running=false
        else
            echo "$VM2_NAME already stopped"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done

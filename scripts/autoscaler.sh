#!/bin/bash

BASE_THRESHOLD=10
CHECK_INTERVAL=5
CHECK_DURATION=15
TRIES_THRESHOLD=$((CHECK_DURATION / CHECK_INTERVAL))
MAX_VMS=3

BASE_IP="192.168.122.10"
HAPROXY_URL="http://localhost:9000/stats;csv"
BACKEND_NAME="servers"
RATE_COLUMN=34

above_threshold_cnt=0
below_threshold_cnt=0
n_of_vms=1  # vm1 always active

# Associative array to track if a VM was ever alive
declare -A vm_was_seen

ensure_vm_alive() {
    local vm_name=$1
    local ip=$2

    echo "Checking if $vm_name ($ip) is alive..."
    if curl -s --max-time 2 "http://$ip:8000/status" | grep -q "OK"; then
        echo "$vm_name is alive."
        vm_was_seen["$vm_name"]=1
    elif [[ "${vm_was_seen[$vm_name]:-0}" == "1" ]]; then
        echo "$vm_name was seen before but is now down. Restarting..."
        unset "vm_was_seen[$vm_name]"
        echo "Cleared seen flag for $vm_name after restart attempt"

        # echo "Removing $vm_name from HAProxy before restart..."
        # ./scripts/update_haproxy.sh remove "$vm_name" "$ip"

        ./scripts/delete_vm.sh "$vm_name"
        ./scripts/create_vm.sh "$vm_name" "$ip"
        ./scripts/update_haproxy.sh add "$vm_name" "$ip"
    else
        echo "$vm_name has never responded yet. Skipping restart."
    fi
}


while true; do
    echo "Checking traffic..."

    # Always ensure vm1 is up
    ensure_vm_alive "vm1" "${BASE_IP}1"

    # Ensure other active VMs are alive if they were ever seen before & s if they shoudl work according to traffic
    for ((i=2; i<=n_of_vms; i++)); do
        ensure_vm_alive "vm$i" "${BASE_IP}$i"
    done

    line=$(curl -s "$HAPROXY_URL" | grep "^$BACKEND_NAME,BACKEND")

    if [ -z "$line" ]; then
        echo "Couldn't fetch rate."
        sleep $CHECK_INTERVAL
        continue
    fi

    rate=$(echo "$line" | awk -F',' "{print \$$RATE_COLUMN}")
    echo "Request rate = $rate req/s"

    # Scale down logic
    if (( rate < BASE_THRESHOLD * (n_of_vms - 1) )); then
        ((below_threshold_cnt++))
        echo "Rate below scale down threshold ($below_threshold_cnt/$TRIES_THRESHOLD)"
    else
        below_threshold_cnt=0
        echo "Rate above scale down threshold"
    fi

    if (( below_threshold_cnt >= TRIES_THRESHOLD )); then
        if (( n_of_vms > 1 )); then
            echo "Rate below scale down threshold for $CHECK_DURATION s, SCALING DOWN"
            ./scripts/delete_vm.sh "vm$n_of_vms"
            ./scripts/update_haproxy.sh remove "vm$n_of_vms" "$BASE_IP$n_of_vms"
            unset "vm_was_seen[vm$n_of_vms]"
            ((n_of_vms--))
        else
            echo "Only vm1 is running. Not scaling down further."
        fi
        below_threshold_cnt=0
        continue
    fi

    # Skip scale-up if already at max
    if (( n_of_vms == MAX_VMS )); then
        sleep $CHECK_INTERVAL
        continue
    fi

    # Scale up logic
    if (( rate > BASE_THRESHOLD * n_of_vms )); then
        ((above_threshold_cnt++))
        echo "Rate above scale up threshold ($above_threshold_cnt/$TRIES_THRESHOLD)"
    else
        above_threshold_cnt=0
        echo "Rate below scale up threshold"
    fi

    if (( above_threshold_cnt >= TRIES_THRESHOLD )); then
        ((n_of_vms++))
        echo "Rate above scale up threshold for $CHECK_DURATION s, SCALING UP to $n_of_vms"
        ./scripts/create_vm.sh "vm$n_of_vms" "$BASE_IP$n_of_vms"
        ./scripts/update_haproxy.sh add "vm$n_of_vms" "$BASE_IP$n_of_vms"
        # vm_was_seen["vm$n_of_vms"]=1
        above_threshold_cnt=0
    fi

    sleep $CHECK_INTERVAL
done

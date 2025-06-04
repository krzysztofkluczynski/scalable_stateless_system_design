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
n_of_vms=1
while true; do
    echo "Checking traffic..."

    line=$(curl -s "$HAPROXY_URL" | grep "^$BACKEND_NAME,BACKEND")

    if [ -z "$line" ]; then
        echo "Couldn't fetch rate."
        sleep $CHECK_INTERVAL
        continue
    fi

    rate=$(echo "$line" | awk -F',' "{print \$$RATE_COLUMN}")

    echo "Request rate = $rate req/s"

    if (( rate < BASE_THRESHOLD * (n_of_vms - 1) )); then
        ((below_threshold_cnt++))
        echo "Rate below scale down threshold ($below_threshold_cnt/$TRIES_THRESHOLD)"
    else
        below_threshold_cnt=0
        echo "Rate above scale down threshold"
    fi

    if (( below_threshold_cnt >= TRIES_THRESHOLD )); then
        echo "Rate below scale down threshold for $CHECK_DURATION s, SCALING DOWN"
        ./scripts/delete_vm.sh "vm$n_of_vms"
        ./scripts/update_haproxy.sh remove "vm$n_of_vms" "$BASE_IP$n_of_vms"
        ((n_of_vms--))
        below_threshold_cnt=0
        continue
    fi

    if (( n_of_vms == MAX_VMS)); then
        sleep $CHECK_INTERVAL
        continue
    fi

    if (( rate > BASE_THRESHOLD * n_of_vms )); then
        ((above_threshold_cnt++))
        echo "Rate above scale up threshold ($above_threshold_cnt/$TRIES_THRESHOLD)"
    else
        above_threshold_cnt=0
        echo "Rate below scale up threshold"
    fi

    if (( above_threshold_cnt >= TRIES_THRESHOLD )); then
        echo "Rate above scale up threshold for $CHECK_DURATION s, SCALING UP"
        ((n_of_vms++))
        ./scripts/create_vm.sh "vm$n_of_vms" "$BASE_IP$n_of_vms"
        ./scripts/update_haproxy.sh add "vm$n_of_vms" "$BASE_IP$n_of_vms"
        above_threshold_cnt=0
    fi



    sleep $CHECK_INTERVAL
done

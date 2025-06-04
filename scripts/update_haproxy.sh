#!/bin/bash

ACTION=$1
NAME=$2
IP=$3

HAPROXY_CFG="haproxy/haproxy.cfg"
MARKER_START="# BEGIN AUTOSCALER SERVERS"
MARKER_END="# END AUTOSCALER SERVERS"

function reload_haproxy {
    if haproxy -c -f "$HAPROXY_CFG"; then
        haproxy -f "$HAPROXY_CFG" -sf $(pidof haproxy)
        echo "HAProxy reloaded successfully."
    else
        echo "HAProxy config test failed! Not reloading."
        exit 1
    fi
}

case "$ACTION" in
  add)
    # Check if server already exists inside the autoscaler block
    if sed -n "/$MARKER_START/,/$MARKER_END/p" "$HAPROXY_CFG" | grep -q "server $NAME"; then
      echo "Server $NAME already present in autoscaler section."
    else
      # Insert server line after MARKER_START line
      sed -i "/$MARKER_START/a\    server $NAME $IP:8000 weight 50 check" "$HAPROXY_CFG"
      echo "Added server $NAME $IP to autoscaler section."
      reload_haproxy
    fi
    ;;
  remove)
    # Remove server line inside autoscaler section only
    # Using a temporary file to ensure we don't delete elsewhere by mistake
    awk -v start="$MARKER_START" -v end="$MARKER_END" -v srv="server $NAME" '
      $0 ~ start { print; inblock=1; next }
      $0 ~ end { inblock=0; print; next }
      inblock && $0 ~ srv { next }  # skip server line inside block
      { print }
    ' "$HAPROXY_CFG" > "${HAPROXY_CFG}.tmp" && mv "${HAPROXY_CFG}.tmp" "$HAPROXY_CFG"
    echo "Removed server $NAME from autoscaler section."
    reload_haproxy
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac

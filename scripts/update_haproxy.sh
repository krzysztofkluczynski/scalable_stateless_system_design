#!/bin/bash
ACTION=$1
NAME=$2
IP=$3

if [ "$ACTION" == "add" ]; then
  echo "server $NAME $IP:8000 check" >> /etc/haproxy/haproxy.cfg
elif [ "$ACTION" == "remove" ]; then
  sed -i "/server $NAME/d" /etc/haproxy/haproxy.cfg
fi

systemctl reload haproxy
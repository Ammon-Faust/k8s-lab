#!/bin/bash
# Run on nodes 2 and 3 (k8s-2 and k8s-3)
# Usage: ./install-agent.sh <server-ip> <token>

SERVER_IP="${1:?Usage: $0 <server-ip> <token>}"
TOKEN="${2:?Usage: $0 <server-ip> <token>}"

curl -sfL https://get.k3s.io | sh -s - server \
  --server "https://${SERVER_IP}:6443" \
  --token "${TOKEN}"   

#!/bin/bash
# Run on the first node (k8s-1)
curl -sfL https://get.k3s.io | sh -s - server --cluster-init 

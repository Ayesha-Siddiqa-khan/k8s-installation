#worker-node.sh (Run only on Worker Node)

#!/bin/bash
set -e
# Paste join command from control plane below
sudo kubeadm join MASTER_PRIVATE_IP:6443 --token YOUR_TOKEN \\
--discovery-token-ca-cert-hash sha256:YOUR_HASH
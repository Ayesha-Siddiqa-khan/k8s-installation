cat > ~/fix-cluster.sh << 'EOF'
#!/bin/bash

echo "=== Fixing cluster IP ==="

# Get current public IP automatically
NEW_IP=$(curl -s ifconfig.me)
echo "Your new public IP: $NEW_IP"

# Get old IP from kubeconfig
OLD_IP=$(grep server ~/.kube/config | grep -oP '[\d.]+(?=:6443)')
echo "Old IP in kubeconfig: $OLD_IP"

if [ "$NEW_IP" == "$OLD_IP" ]; then
  echo "IP has not changed. Nothing to do!"
  exit 0
fi

# Update kubeconfig
sed -i "s|https://${OLD_IP}:6443|https://${NEW_IP}:6443|g" ~/.kube/config
echo "Kubeconfig updated"

# Regenerate API server certificate
sudo cp /etc/kubernetes/pki/apiserver.{crt,key} /tmp/
sudo rm /etc/kubernetes/pki/apiserver.{crt,key}

cat > /tmp/patch.yaml << YAML
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
apiServer:
  certSANs:
    - "${NEW_IP}"
    - "10.0.0.40"
    - "10.96.0.1"
    - "localhost"
    - "127.0.0.1"
    - "kubernetes"
    - "kubernetes.default"
    - "kubernetes.default.svc"
    - "kubernetes.default.svc.cluster.local"
YAML

sudo kubeadm init phase certs apiserver --config /tmp/patch.yaml
echo "Certificate regenerated"

# Restart API server
sudo crictl rm $(sudo crictl ps -a --name kube-apiserver -q) 2>/dev/null
echo "Waiting for API server to restart..."
sleep 30

# Test
kubectl get nodes
echo ""
echo "=== DONE! Copy this kubeconfig to GitHub secret ==="
echo ""
cat ~/.kube/config
EOF

chmod +x ~/fix-cluster.sh
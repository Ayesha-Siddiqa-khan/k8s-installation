cat > control-plane.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail

POD_CIDR="192.168.0.0/16"
CALICO_VERSION="v3.28.0"

echo "========================================"
echo "Detecting IP addresses..."
echo "========================================"

CONTROL_PLANE_PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Try AWS IMDSv2 first
TOKEN=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

if [ -n "$TOKEN" ]; then
  CONTROL_PLANE_PUBLIC_IP=$(curl -s -m 2 \
    -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/public-ipv4 || true)
else
  CONTROL_PLANE_PUBLIC_IP=$(curl -s -m 2 \
    http://169.254.169.254/latest/meta-data/public-ipv4 || true)
fi

echo "Private IP: $CONTROL_PLANE_PRIVATE_IP"
echo "Public IP:  ${CONTROL_PLANE_PUBLIC_IP:-Not found}"

echo "========================================"
echo "Checking required services..."
echo "========================================"

sudo systemctl enable containerd kubelet || true
sudo systemctl restart containerd
sudo systemctl restart kubelet || true

echo "========================================"
echo "Initializing Kubernetes control plane..."
echo "========================================"

KUBEADM_ARGS=(
  "init"
  "--pod-network-cidr=${POD_CIDR}"
  "--apiserver-advertise-address=${CONTROL_PLANE_PRIVATE_IP}"
  "--cri-socket=unix:///var/run/containerd/containerd.sock"
)

if [ -n "${CONTROL_PLANE_PUBLIC_IP:-}" ]; then
  KUBEADM_ARGS+=("--apiserver-cert-extra-sans=${CONTROL_PLANE_PUBLIC_IP},${CONTROL_PLANE_PRIVATE_IP}")
else
  KUBEADM_ARGS+=("--apiserver-cert-extra-sans=${CONTROL_PLANE_PRIVATE_IP}")
fi

sudo kubeadm "${KUBEADM_ARGS[@]}"

echo "========================================"
echo "Configuring kubectl..."
echo "========================================"

mkdir -p "$HOME/.kube"
sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "========================================"
echo "Installing Calico network plugin..."
echo "========================================"

kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml" || true

curl -L -o custom-resources.yaml \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

# Make sure Calico CIDR matches kubeadm POD_CIDR
sed -i "s#cidr: 192.168.0.0/16#cidr: ${POD_CIDR}#g" custom-resources.yaml

kubectl apply -f custom-resources.yaml

echo "========================================"
echo "Waiting for Kubernetes nodes..."
echo "========================================"

sleep 20
kubectl get nodes -o wide || true

echo "========================================"
echo "Waiting for Calico pods..."
echo "========================================"

kubectl wait --for=condition=Available deployment/tigera-operator -n tigera-operator --timeout=180s || true

echo "Showing all pods:"
kubectl get pods -A -o wide || true

echo "========================================"
echo "Creating kubeconfig backup..."
echo "========================================"

cp "$HOME/.kube/config" "$HOME/.kube/config.bak"

# Do NOT replace main kubeconfig with public IP on the server.
# Instead create a separate public kubeconfig for laptop/external kubectl.
if [ -n "${CONTROL_PLANE_PUBLIC_IP:-}" ]; then
  cp "$HOME/.kube/config" "$HOME/.kube/config-public"
  sed -i "s#server: https://${CONTROL_PLANE_PRIVATE_IP}:6443#server: https://${CONTROL_PLANE_PUBLIC_IP}:6443#g" "$HOME/.kube/config-public"

  echo "Public kubeconfig created at:"
  echo "$HOME/.kube/config-public"
fi

echo "========================================"
echo "Worker Node Join Command:"
echo "========================================"

kubeadm token create --print-join-command

echo "========================================"
echo "Control plane setup completed."
echo "========================================"

echo "Now check:"
echo "kubectl get nodes -o wide"
echo "kubectl get pods -A -o wide"
SCRIPT

chmod +x control-plane.sh
./control-plane.sh

# create join command script for worker nodes
kubeadm token create --print-join-command



#if cluster is already initialized and you want to reset and start over, run this script:

cat > reset-control-plane.sh <<'SCRIPT'
#!/bin/bash
set -e

echo "Resetting Kubernetes control plane..."

sudo kubeadm reset -f || true

sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/kubernetes

sudo systemctl restart containerd || true
sudo systemctl restart kubelet || true

echo "Reset completed. Now run the control-plane script."
SCRIPT

chmod +x reset-control-plane.sh
./reset-control-plane.sh
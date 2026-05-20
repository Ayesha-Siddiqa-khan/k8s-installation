cat > control-plane.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail

POD_CIDR="192.168.0.0/16"
CALICO_VERSION="v3.28.0"

echo "========================================"
echo "Detecting IP addresses..."
echo "========================================"

CONTROL_PLANE_PRIVATE_IP=$(hostname -I | awk '{print $1}')

TOKEN=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

if [ -n "${TOKEN:-}" ]; then
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
echo "Starting required services..."
echo "========================================"

sudo systemctl enable containerd kubelet || true
sudo systemctl restart containerd
sudo systemctl restart kubelet || true

echo "========================================"
echo "Initializing Kubernetes control plane..."
echo "========================================"

if [ ! -f /etc/kubernetes/admin.conf ]; then

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

else
  echo "Kubernetes control plane already initialized."
  echo "Skipping kubeadm init."
fi

echo "========================================"
echo "Configuring kubectl..."
echo "========================================"

mkdir -p "$HOME/.kube"
sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

sudo mkdir -p /root/.kube
sudo cp -f /etc/kubernetes/admin.conf /root/.kube/config

echo "========================================"
echo "Installing Calico network plugin..."
echo "========================================"

kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml" || true

curl -L -o custom-resources.yaml \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

sed -i "s#cidr: 192.168.0.0/16#cidr: ${POD_CIDR}#g" custom-resources.yaml

kubectl apply -f custom-resources.yaml

echo "========================================"
echo "Creating kubeconfig backup..."
echo "========================================"

cp "$HOME/.kube/config" "$HOME/.kube/config.bak"

echo "Private kubeconfig:"
echo "$HOME/.kube/config"

if [ -n "${CONTROL_PLANE_PUBLIC_IP:-}" ]; then

  echo "========================================"
  echo "Creating public kubeconfig for laptop..."
  echo "========================================"

  cp "$HOME/.kube/config" "$HOME/.kube/config-public"

  kubectl config set-cluster kubernetes \
    --server="https://${CONTROL_PLANE_PUBLIC_IP}:6443" \
    --kubeconfig="$HOME/.kube/config-public"

  echo "Public kubeconfig created:"
  echo "$HOME/.kube/config-public"
fi

echo "========================================"
echo "Creating worker join commands..."
echo "========================================"

JOIN_CMD_PRIVATE=$(sudo kubeadm token create --print-join-command --ttl 24h)

echo "sudo ${JOIN_CMD_PRIVATE} --cri-socket=unix:///var/run/containerd/containerd.sock" > "$HOME/join-worker-private.sh"
chmod +x "$HOME/join-worker-private.sh"

echo "Private worker join command saved at:"
echo "$HOME/join-worker-private.sh"

if [ -n "${CONTROL_PLANE_PUBLIC_IP:-}" ]; then

  JOIN_CMD_PUBLIC=$(echo "$JOIN_CMD_PRIVATE" | sed "s#${CONTROL_PLANE_PRIVATE_IP}:6443#${CONTROL_PLANE_PUBLIC_IP}:6443#g")

  echo "sudo ${JOIN_CMD_PUBLIC} --cri-socket=unix:///var/run/containerd/containerd.sock" > "$HOME/join-worker-public.sh"
  chmod +x "$HOME/join-worker-public.sh"

  echo "Public worker join command saved at:"
  echo "$HOME/join-worker-public.sh"
fi

echo "========================================"
echo "Waiting for cluster components..."
echo "========================================"

sleep 20

echo "========================================"
echo "Nodes:"
echo "========================================"

kubectl get nodes -o wide || true

echo "========================================"
echo "All pods:"
echo "========================================"

kubectl get pods -A -o wide || true

echo "========================================"
echo "Worker Node Join Command:"
echo "========================================"

cat "$HOME/join-worker-private.sh"

echo "========================================"
echo "Control plane setup completed successfully."
echo "========================================"

echo "Next commands:"
echo "kubectl get nodes -o wide"
echo "kubectl get pods -A -o wide"
echo "cat ~/join-worker-private.sh"
echo "cat ~/join-worker-public.sh"
SCRIPT

chmod +x control-plane.sh
./control-plane.sh
##control-plane.sh (Run only on Control Plane)

#!/bin/bash
set -e
# Replace CONTROL_PLANE_PRIVATE_IP before running
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=CONTROL_PLANE_PRIVATE_IP

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes -o wide
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
kubectl apply -f custom-resources.yaml


kubectl get pods -A

kubeadm token create --print-join-command
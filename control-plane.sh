##control-plane.sh (Run only on Control Plane)

#!/bin/bash
set -e
# Replace CONTROL_PLANE_PRIVATE_IP before running
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=CONTROL_PLANE_PRIVATE_IP

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#Verify the cluster is up and running
kubectl get nodes -o wide
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a

#Network Plugin Installation (Calico)
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
kubectl apply -f custom-resources.yaml


kubectl get pods -A
#Generate the join command for worker nodes
kubeadm token create --print-join-command

#kube config secerts find
kubectl config view --raw 

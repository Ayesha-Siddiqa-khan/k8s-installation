##control-plane.sh (Run only on Control Plane)

#!/bin/bash
set -e
# Replace CONTROL_PLANE_PRIVATE_IP before running
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=CONTROL_PLANE_PRIVATE_IP

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Generate the join command for worker nodes
kubeadm token create --print-join-command


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

#Backup kube config and update the server IP address to the public IP of the control plane node
cp ~/.kube/config ~/.kube/config.bak
sed -i 's#server: https://10.0.1.27:6443#server: https://34.205.81.125:6443#g' ~/.kube/config

#kube config secerts find
kubectl config view --raw
#Encode the kubeconfig file in base64 for GitHub Actions secrets 
cat /home/ubuntu/kubeconfig-public.b64
base64 -d /home/ubuntu/kubeconfig-public.b64 | grep "server:"

# Get Database URL from Terraform
cd E:\github\progressive-delivery-fastapi\terraform
terraform output -raw db_database_url



# Get Redis URL from Terraform
cd E:\github\progressive-delivery-fastapi\terraform
terraform output -raw redis_url














#Prepare kubeconfig for GitHub Actions (if needed)
sudo cp /etc/kubernetes/admin.conf /etc/kubernetes/admin.github.conf
sudo sed -i 's#https://10.0.1.235:6443#https://32.192.20.16:6443#g' /etc/kubernetes/admin.github.conf
sudo grep "server:" /etc/kubernetes/admin.github.conf

#Encode the kubeconfig file in base64 for GitHub Actions secrets
sudo base64 -w 0 /etc/kubernetes/admin.github.conf > kubeconfig.github.b64
cat kubeconfig.github.b64
# To decode and verify the kubeconfig file check ip address in the server field

base64 -d /home/ubuntu/kubeconfig-private.b64 | grep "server:"




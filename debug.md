#Master Node: Public IP Certificate Fix

# Variables
PRIVATE_IP=10.0.1.27
PUBLIC_IP=34.205.81.125

# Backup old API server certificate
sudo cp /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver.crt.bak
sudo cp /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/apiserver.key.bak

# Remove old certificate
sudo rm -f /etc/kubernetes/pki/apiserver.crt
sudo rm -f /etc/kubernetes/pki/apiserver.key

# Generate new API server certificate with public IP
sudo kubeadm init phase certs apiserver \
  --apiserver-advertise-address=$PRIVATE_IP \
  --apiserver-cert-extra-sans=$PUBLIC_IP

# Restart kube-apiserver
sudo crictl stop $(sudo crictl ps --name kube-apiserver -q)

# Wait 30 seconds, then check certificate SANs
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A2 "Subject Alternative Name"






#Update kubeconfig on Master Node
# Backup kubeconfig
cp ~/.kube/config ~/.kube/config.bak

# Replace private IP with public IP
sed -i 's#server: https://10.0.1.217:6443#server: https://3.238.140.125:6443#g' ~/.kube/config

# Check kubeconfig server
grep server ~fig/.kube/con

# Test cluster access
kubectl get nodes




#ECR ImagePullBackOff Fix

# Variables
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=257536659737
NAMESPACE=fashion-style

# Create ECR image pull secret
kubectl -n $NAMESPACE create secret docker-registry ecr-secret \
  --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region ${AWS_REGION})"

# Attach secret to deployment
kubectl -n $NAMESPACE patch deployment fashion-style \
  -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"ecr-secret"}]}}}}'

# Restart deployment
kubectl -n $NAMESPACE rollout restart deployment/fashion-style

# Check rollout
kubectl -n $NAMESPACE rollout status deployment/fashion-style

# Check pods
kubectl -n $NAMESPACE get pods -o wide



#Debug Commands


kubectl -n "deployment name" get pods -o wide

kubectl -n "deployment name" describe pod POD_NAME

kubectl -n "deployment name" get events --sort-by=.lastTimestamp | tail -n 30

kubectl -n "deployment name" describe deployment fashion-style

kubectl -n "deployment name" logs POD_NAME

kubectl -n "deployment name" logs POD_NAME --previous
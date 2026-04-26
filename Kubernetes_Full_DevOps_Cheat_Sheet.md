# Kubernetes (K8s) Commands Cheat Sheet – Full DevOps Edition

## Basic Cluster Commands
```bash
kubectl version --short
kubectl cluster-info
kubectl get all
kubectl api-resources
kubectl api-versions
```

## Contexts & Config
```bash
kubectl config get-contexts
kubectl config current-context
kubectl config use-context dev
kubectl config set-context --current --namespace=dev
```

## Pods
```bash
kubectl get pods -o wide
kubectl describe pod pod-name
kubectl logs -f pod-name
kubectl exec -it pod-name -- bash
kubectl delete pod pod-name
```

## Deployments
```bash
kubectl get deploy
kubectl create deployment web --image=nginx
kubectl scale deployment web --replicas=5
kubectl rollout status deployment/web
kubectl rollout undo deployment/web
```

## Services
```bash
kubectl get svc
kubectl expose deployment web --type=NodePort --port=80
kubectl describe svc web
kubectl get endpoints
```

## ConfigMaps & Secrets
```bash
kubectl create configmap app-config --from-literal=env=prod
kubectl create secret generic db-secret --from-literal=password=1234
kubectl get configmaps
kubectl get secrets
```

## Nodes
```bash
kubectl get nodes -o wide
kubectl cordon node1
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon node1
```

## Storage
```bash
kubectl get pv
kubectl get pvc
kubectl get sc
```

## Troubleshooting
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl top nodes
kubectl top pods
kubectl logs pod-name --previous
```

## EKS
```bash
aws eks update-kubeconfig --region us-east-1 --name mycluster
kubectl get nodes
```

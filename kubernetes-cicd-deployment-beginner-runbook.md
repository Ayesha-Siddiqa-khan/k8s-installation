# Kubernetes CI/CD Deployment Runbook for Beginners

**Project example used in this guide:** Terra Pilot CI/CD deployment  
**Purpose:** Help you check where your app is deployed, how to find the app name, how to find the correct port, and how to open the app in the browser after a new Kubernetes deployment.

---

## 1. What happened in our current deployment

From the GitHub Actions screen, the deployment completed successfully.

In Kubernetes, your app was deployed in this namespace:

```bash
teera-pilot-production-app
```

Your app has two deployments:

```bash
terra-pilot-cicd-backend
terra-pilot-cicd-frontend
```

Your pods were running successfully:

```text
terra-pilot-cicd-backend-6fd5ffdbdf-2mg6p     Running   node: ip-10-0-1-113
terra-pilot-cicd-backend-6fd5ffdbdf-48zmp     Running   node: ip-10-0-1-29

terra-pilot-cicd-frontend-7b495698c7-m7qkl    Running   node: ip-10-0-1-113
terra-pilot-cicd-frontend-7b495698c7-wcd64    Running   node: ip-10-0-1-29
```

Your services were:

```text
terra-pilot-cicd-backend    NodePort   8000:30131/TCP
terra-pilot-cicd-frontend   NodePort   3000:31905/TCP
```

So the correct frontend URL pattern is:

```text
http://NODE_PUBLIC_IP:31905
```

In your case, if `34.234.211.60` is the public IP of one of your Kubernetes nodes, the frontend URL should be:

```text
http://34.234.211.60:31905
```

The earlier URL failed because this port was wrong:

```text
http://34.234.211.60:31234
```

Your frontend NodePort was not `31234`. It was `31905`.

---

## 2. Important beginner concept

In Kubernetes, your app does not run directly as a normal program on an EC2 instance.

The flow is usually like this:

```text
Deployment -> ReplicaSet -> Pods -> Nodes
```

Meaning:

- **Deployment** is the main app definition.
- **ReplicaSet** controls how many copies of your app should run.
- **Pod** is the actual running unit of your app.
- **Node** is the machine/instance where the pod is running.
- **Service** exposes your pods so you can access the app.
- **NodePort** opens a port on the node so the app can be accessed from outside the cluster.

For example:

```text
Frontend Deployment
    -> Frontend Pods
        -> Running on worker nodes
            -> Exposed by frontend Service
                -> Open in browser using Public IP + NodePort
```

---

## 3. Your basic checklist after every new deployment

Whenever you make a new instance or run a new CI/CD deployment, follow this pattern:

```text
1. SSH into your server
2. Check kubectl connection
3. Find namespace
4. Find deployment/app name
5. Check pods and which nodes they are running on
6. Check services
7. Find NodePort
8. Find node public IP
9. Allow port in AWS Security Group
10. Open app in browser
11. If it fails, debug service, endpoints, pods, and logs
```

---

## 4. Step 1 — SSH into your instance

Use your own key and public IP.

```bash
ssh -i your-key.pem ubuntu@YOUR_INSTANCE_PUBLIC_IP
```

### What this command does

This connects you to your Ubuntu EC2 instance.

Example:

```bash
ssh -i terra-pilot-key.pem ubuntu@34.234.211.60
```

---

## 5. Step 2 — Check if kubectl is connected to your cluster

```bash
kubectl config current-context
```

### What this command does

It shows which Kubernetes cluster your `kubectl` command is currently connected to.

If this command fails, it means your `kubectl` is not configured correctly on that instance.

Now check nodes:

```bash
kubectl get nodes -o wide
```

### What this command does

It shows all Kubernetes nodes in your cluster.

The important columns are:

```text
NAME        STATUS   ROLES           INTERNAL-IP
node-name   Ready    worker          10.0.x.x
node-name   Ready    control-plane   10.0.x.x
```

Use this command to know:

- Which nodes are active
- Which node is master/control-plane
- Which node is worker
- What private IP each node has

---

## 6. Step 3 — Find all namespaces

```bash
kubectl get namespaces
```

### What this command does

It shows all namespaces in your cluster.

A namespace is like a separate folder or section inside Kubernetes.

Example:

```text
default
kube-system
teera-pilot-production-app
```

Your app was inside:

```bash
teera-pilot-production-app
```

---

## 7. Step 4 — Find your app/deployment name

Use this command:

```bash
kubectl get deploy -A
```

### What this command does

It shows all deployments from all namespaces.

Example from your deployment:

```text
NAMESPACE                    NAME                        READY
teera-pilot-production-app   terra-pilot-cicd-backend    2/2
teera-pilot-production-app   terra-pilot-cicd-frontend   2/2
```

Here:

```bash
terra-pilot-cicd-backend
terra-pilot-cicd-frontend
```

are your app deployment names.

### Beginner tip

If you do not know your app name, always start with:

```bash
kubectl get deploy -A
```

This command is the easiest way to find your deployed app.

---

## 8. Step 5 — Check pods and find which node your app is running on

After finding your namespace, run:

```bash
kubectl get pods -n teera-pilot-production-app -o wide
```

### What this command does

It shows your pods and the node where each pod is running.

Important columns:

```text
NAME      READY   STATUS    IP              NODE
pod-name  1/1     Running   192.168.x.x     ip-10-0-1-113
```

Your current output showed:

```text
terra-pilot-cicd-backend-6fd5ffdbdf-2mg6p     Running   ip-10-0-1-113
terra-pilot-cicd-backend-6fd5ffdbdf-48zmp     Running   ip-10-0-1-29

terra-pilot-cicd-frontend-7b495698c7-m7qkl    Running   ip-10-0-1-113
terra-pilot-cicd-frontend-7b495698c7-wcd64    Running   ip-10-0-1-29
```

So your app was running on these nodes:

```text
ip-10-0-1-113
ip-10-0-1-29
```

### Generic command pattern

Replace `YOUR_NAMESPACE` with your namespace:

```bash
kubectl get pods -n YOUR_NAMESPACE -o wide
```

Example:

```bash
kubectl get pods -n teera-pilot-production-app -o wide
```

---

## 9. Step 6 — Check full app status in one command

```bash
kubectl get all -n teera-pilot-production-app -o wide
```

### What this command does

It shows almost everything in that namespace:

- Pods
- Services
- Deployments
- ReplicaSets

This is a very useful command when you want a full overview.

Generic pattern:

```bash
kubectl get all -n YOUR_NAMESPACE -o wide
```

---

## 10. Step 7 — Check services and find the correct port

Run:

```bash
kubectl get svc -n teera-pilot-production-app -o wide
```

### What this command does

It shows how your app is exposed.

Your output was:

```text
NAME                        TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)
terra-pilot-cicd-backend    NodePort   10.106.124.151   <none>        8000:30131/TCP
terra-pilot-cicd-frontend   NodePort   10.97.110.35     <none>        3000:31905/TCP
```

### How to read this output

For frontend:

```text
3000:31905/TCP
```

This means:

```text
App/service port: 3000
Public NodePort: 31905
Protocol: TCP
```

So the frontend should be opened like this:

```text
http://NODE_PUBLIC_IP:31905
```

For backend:

```text
8000:30131/TCP
```

This means:

```text
Backend service port: 8000
Public NodePort: 30131
Protocol: TCP
```

So the backend can be tested like this:

```text
http://NODE_PUBLIC_IP:30131
```

---

## 11. Step 8 — Get only the frontend NodePort

Use this command:

```bash
kubectl get svc terra-pilot-cicd-frontend \
  -n teera-pilot-production-app \
  -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

### What this command does

It prints only the NodePort number of the frontend service.

Example output:

```text
31905
```

Then open:

```text
http://NODE_PUBLIC_IP:31905
```

---

## 12. Step 9 — Get only the backend NodePort

```bash
kubectl get svc terra-pilot-cicd-backend \
  -n teera-pilot-production-app \
  -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

### What this command does

It prints only the NodePort number of the backend service.

Example output:

```text
30131
```

Then test:

```text
http://NODE_PUBLIC_IP:30131
```

---

## 13. Step 10 — Find the public IP of your Kubernetes node

First check the node private IPs:

```bash
kubectl get nodes -o wide
```

### What this command does

It shows your node names and internal/private IPs.

Example:

```text
ip-10-0-1-113
ip-10-0-1-29
ip-10-0-1-232
```

To open a NodePort app in the browser, you need the **public IP** of a Kubernetes node.

If AWS CLI is configured, use this command:

```bash
aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=10.0.1.113,10.0.1.29,10.0.1.232" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,State:State.Name}" \
  --output table
```

### What this command does

It takes private IPs and shows their matching public IPs in AWS.

Then use the public IP like this:

```text
http://PUBLIC_IP:NODEPORT
```

Example:

```text
http://34.234.211.60:31905
```

---

## 14. Step 11 — Add AWS Security Group inbound rule

If your browser shows:

```text
This site can't be reached
ERR_CONNECTION_REFUSED
```

or the page keeps loading, check your AWS Security Group.

For your frontend, allow this port:

```text
Custom TCP
Port: 31905
Source: 0.0.0.0/0
```

For backend, allow this port:

```text
Custom TCP
Port: 30131
Source: 0.0.0.0/0
```

For testing only, you can allow the full Kubernetes NodePort range:

```text
Custom TCP
Port range: 30000-32767
Source: 0.0.0.0/0
```

### Important security note

For practice/testing, `0.0.0.0/0` is okay for a short time.

For production, restrict the source to your own IP if possible.

---

## 15. Step 12 — Open the frontend app

For your current deployment:

```text
Frontend NodePort = 31905
```

Open:

```text
http://34.234.211.60:31905
```

Only use this exact URL if:

- `34.234.211.60` is the public IP of a Kubernetes node
- AWS Security Group allows port `31905`
- Frontend pods are running
- Frontend service has endpoints

---

## 16. Step 13 — Test from inside the server

If browser does not work, test from the Ubuntu server:

```bash
curl -v http://127.0.0.1:31905
```

### What this command does

It checks whether the NodePort is reachable from inside the server.

Also test the service cluster IP:

```bash
curl -v http://10.97.110.35:3000
```

### What this command does

It checks whether the frontend service is working inside the Kubernetes cluster network.

For backend:

```bash
curl -v http://10.106.124.151:8000
```

---

## 17. Step 14 — Check service endpoints

Run:

```bash
kubectl get endpoints -n teera-pilot-production-app
```

### What this command does

It checks whether your service is connected to your pods.

Good result example:

```text
terra-pilot-cicd-frontend   192.168.8.67:3000,192.168.166.131:3000
terra-pilot-cicd-backend    192.168.8.68:8000,192.168.166.132:8000
```

If endpoints are empty, like this:

```text
terra-pilot-cicd-frontend   <none>
```

then your service selector is not matching your pod labels.

---

## 18. Step 15 — Check pod labels

```bash
kubectl get pods -n teera-pilot-production-app --show-labels
```

### What this command does

It shows the labels attached to your pods.

Your service selector was:

```text
app=terra-pilot-cicd,tier=frontend
```

So frontend pods must have these labels:

```text
app=terra-pilot-cicd
tier=frontend
```

Backend service selector was:

```text
app=terra-pilot-cicd,tier=backend
```

So backend pods must have:

```text
app=terra-pilot-cicd
tier=backend
```

---

## 19. Step 16 — Describe service for deeper debugging

Frontend:

```bash
kubectl describe svc terra-pilot-cicd-frontend -n teera-pilot-production-app
```

Backend:

```bash
kubectl describe svc terra-pilot-cicd-backend -n teera-pilot-production-app
```

### What this command does

It shows detailed service information:

- Type
- Cluster IP
- Port
- TargetPort
- NodePort
- Selector
- Endpoints

This helps you confirm whether the service is correctly pointing to the pods.

---

## 20. Step 17 — Check deployment rollout status

Frontend:

```bash
kubectl rollout status deploy/terra-pilot-cicd-frontend -n teera-pilot-production-app
```

Backend:

```bash
kubectl rollout status deploy/terra-pilot-cicd-backend -n teera-pilot-production-app
```

### What this command does

It tells you if the deployment completed successfully.

Good result:

```text
deployment "terra-pilot-cicd-frontend" successfully rolled out
```

---

## 21. Step 18 — Check logs

Frontend logs:

```bash
kubectl logs deploy/terra-pilot-cicd-frontend -n teera-pilot-production-app
```

Backend logs:

```bash
kubectl logs deploy/terra-pilot-cicd-backend -n teera-pilot-production-app
```

### What this command does

It shows application logs.

Use this when:

- The pod is running but app is not opening
- Backend API is failing
- Frontend build is serving incorrectly
- There is an internal app error

If there are multiple containers, use:

```bash
kubectl logs POD_NAME -n teera-pilot-production-app
```

---

## 22. Step 19 — Describe a pod

First list pods:

```bash
kubectl get pods -n teera-pilot-production-app
```

Then describe one pod:

```bash
kubectl describe pod POD_NAME -n teera-pilot-production-app
```

Example:

```bash
kubectl describe pod terra-pilot-cicd-frontend-7b495698c7-m7qkl -n teera-pilot-production-app
```

### What this command does

It shows detailed pod information:

- Which node the pod is running on
- Events
- Image name
- Container port
- Restart reason
- Health check failures
- Pull errors

---

## 23. Step 20 — Temporary test with port-forward

If NodePort is not working and you only want to test quickly, use port-forward:

```bash
kubectl port-forward \
  -n teera-pilot-production-app \
  svc/terra-pilot-cicd-frontend \
  8080:3000 \
  --address 0.0.0.0
```

### What this command does

It forwards your server port `8080` to the frontend service port `3000`.

Then open:

```text
http://34.234.211.60:8080
```

But for this to work from your browser, AWS Security Group must allow port `8080`.

### Important

Port-forward is temporary. When you close the terminal, it stops.

For real deployment access, use:

- NodePort
- LoadBalancer
- Ingress

---

## 24. Common error: ERR_CONNECTION_REFUSED

You saw this error:

```text
34.234.211.60 refused to connect
ERR_CONNECTION_REFUSED
```

Most common reasons:

### Reason 1 — Wrong port

You tried:

```text
http://34.234.211.60:31234
```

But your frontend NodePort was:

```text
31905
```

Correct:

```text
http://34.234.211.60:31905
```

### Reason 2 — Security Group does not allow the port

Allow:

```text
31905
```

or for testing:

```text
30000-32767
```

### Reason 3 — Wrong public IP

You may be using the public IP of an instance that is not properly connected to NodePort traffic.

Check node public IPs and try the public IP of worker nodes.

### Reason 4 — Service has no endpoints

Check:

```bash
kubectl get endpoints -n teera-pilot-production-app
```

If endpoint is empty, fix pod labels or service selector.

### Reason 5 — App is not listening on the expected container port

Check deployment YAML:

```bash
kubectl get deploy terra-pilot-cicd-frontend -n teera-pilot-production-app -o yaml
```

Check the container port and service targetPort.

---

## 25. One-command overview for your current deployment

Run this whenever you want a full diagnosis:

```bash
kubectl get deploy -A
kubectl get pods -n teera-pilot-production-app -o wide
kubectl get svc -n teera-pilot-production-app -o wide
kubectl get endpoints -n teera-pilot-production-app
kubectl get nodes -o wide
```

### What this gives you

It tells you:

- Your app/deployment name
- Your namespace
- Pod status
- Node names
- Service type
- NodePort
- Whether service is connected to pods
- Node IPs

---

## 26. Reusable command pattern for future deployments

For a new deployment, change these values:

```bash
export NS="your-namespace"
export FRONTEND_DEPLOY="your-frontend-deployment"
export BACKEND_DEPLOY="your-backend-deployment"
export FRONTEND_SVC="your-frontend-service"
export BACKEND_SVC="your-backend-service"
```

Example for your current project:

```bash
export NS="teera-pilot-production-app"
export FRONTEND_DEPLOY="terra-pilot-cicd-frontend"
export BACKEND_DEPLOY="terra-pilot-cicd-backend"
export FRONTEND_SVC="terra-pilot-cicd-frontend"
export BACKEND_SVC="terra-pilot-cicd-backend"
```

Now run:

```bash
# Show deployments in namespace
kubectl get deploy -n "$NS"

# Show pods and their nodes
kubectl get pods -n "$NS" -o wide

# Show services and ports
kubectl get svc -n "$NS" -o wide

# Show endpoints
kubectl get endpoints -n "$NS"

# Get frontend NodePort only
kubectl get svc "$FRONTEND_SVC" -n "$NS" -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'

# Get backend NodePort only
kubectl get svc "$BACKEND_SVC" -n "$NS" -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'

# Check frontend rollout
kubectl rollout status deploy/"$FRONTEND_DEPLOY" -n "$NS"

# Check backend rollout
kubectl rollout status deploy/"$BACKEND_DEPLOY" -n "$NS"

# Check frontend logs
kubectl logs deploy/"$FRONTEND_DEPLOY" -n "$NS"

# Check backend logs
kubectl logs deploy/"$BACKEND_DEPLOY" -n "$NS"
```

---

## 27. Your current Terra Pilot quick commands

Use these commands for the current deployment:

```bash
# Check current Kubernetes context
kubectl config current-context

# Show all nodes
kubectl get nodes -o wide

# Show all deployments
kubectl get deploy -A

# Show Terra Pilot pods and nodes
kubectl get pods -n teera-pilot-production-app -o wide

# Show Terra Pilot services and NodePorts
kubectl get svc -n teera-pilot-production-app -o wide

# Get frontend NodePort
kubectl get svc terra-pilot-cicd-frontend -n teera-pilot-production-app -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'

# Get backend NodePort
kubectl get svc terra-pilot-cicd-backend -n teera-pilot-production-app -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'

# Check frontend deployment
kubectl rollout status deploy/terra-pilot-cicd-frontend -n teera-pilot-production-app

# Check backend deployment
kubectl rollout status deploy/terra-pilot-cicd-backend -n teera-pilot-production-app

# Check service endpoints
kubectl get endpoints -n teera-pilot-production-app

# Frontend logs
kubectl logs deploy/terra-pilot-cicd-frontend -n teera-pilot-production-app

# Backend logs
kubectl logs deploy/terra-pilot-cicd-backend -n teera-pilot-production-app
```

Current frontend URL pattern:

```text
http://NODE_PUBLIC_IP:31905
```

Current backend URL pattern:

```text
http://NODE_PUBLIC_IP:30131
```

---

## 28. How to know frontend vs backend

Usually:

- **Frontend** is what opens in your browser.
- **Backend** is your API server.

In your project:

```text
terra-pilot-cicd-frontend = frontend app
terra-pilot-cicd-backend = backend API
```

Frontend service:

```text
3000:31905/TCP
```

Backend service:

```text
8000:30131/TCP
```

So browser should normally open frontend:

```text
http://NODE_PUBLIC_IP:31905
```

Backend is usually tested through API endpoints:

```text
http://NODE_PUBLIC_IP:30131
```

Example:

```bash
curl -v http://NODE_PUBLIC_IP:30131
```

---

## 29. If you want to make access more professional

NodePort is good for testing and learning.

For a more professional deployment, use one of these later:

### Option 1 — LoadBalancer

Kubernetes creates an AWS Load Balancer.

Service type:

```yaml
type: LoadBalancer
```

Then you open the app using the AWS Load Balancer DNS.

### Option 2 — Ingress

Ingress gives you domain-based routing.

Example:

```text
https://app.yourdomain.com
```

This is better for production.

### Option 3 — NGINX Ingress Controller + Cert Manager

This is a professional setup for:

- Domain
- HTTPS
- Routing
- Multiple services
- TLS certificates

---

## 30. Final beginner mental model

Whenever you deploy an app, ask these questions:

```text
1. Did GitHub Actions finish successfully?
2. Which Kubernetes namespace was used?
3. What is my deployment/app name?
4. Are my pods running?
5. Which nodes are the pods running on?
6. What service exposes the app?
7. Is service type NodePort, LoadBalancer, or ClusterIP?
8. What is the correct NodePort?
9. What is the public IP of the node?
10. Is the port allowed in AWS Security Group?
11. Does the service have endpoints?
12. Are logs clean?
```

If you can answer these 12 questions, you can debug most beginner Kubernetes deployment issues.

---

## 31. Super short command cheat sheet

```bash
# Check cluster
kubectl config current-context
kubectl get nodes -o wide

# Find app name
kubectl get deploy -A

# Check app pods
kubectl get pods -n YOUR_NAMESPACE -o wide

# Check app services
kubectl get svc -n YOUR_NAMESPACE -o wide

# Check endpoints
kubectl get endpoints -n YOUR_NAMESPACE

# Describe service
kubectl describe svc YOUR_SERVICE_NAME -n YOUR_NAMESPACE

# Check logs
kubectl logs deploy/YOUR_DEPLOYMENT_NAME -n YOUR_NAMESPACE

# Check rollout
kubectl rollout status deploy/YOUR_DEPLOYMENT_NAME -n YOUR_NAMESPACE
```

---

## 32. Your current values to remember

```text
Namespace:
teera-pilot-production-app

Frontend deployment:
terra-pilot-cicd-frontend

Backend deployment:
terra-pilot-cicd-backend

Frontend service:
terra-pilot-cicd-frontend

Backend service:
terra-pilot-cicd-backend

Frontend NodePort:
31905

Backend NodePort:
30131

Frontend URL pattern:
http://NODE_PUBLIC_IP:31905

Backend URL pattern:
http://NODE_PUBLIC_IP:30131
```

---

## 33. Practice task

Practice this flow until it becomes automatic:

```bash
kubectl get deploy -A
kubectl get pods -n teera-pilot-production-app -o wide
kubectl get svc -n teera-pilot-production-app -o wide
kubectl get endpoints -n teera-pilot-production-app
kubectl get nodes -o wide
```

Then answer:

```text
What is my namespace?
What is my frontend deployment name?
What is my backend deployment name?
What is my frontend NodePort?
What is my backend NodePort?
Which nodes are my pods running on?
What URL should I open in the browser?
```

Once you can answer these questions without confusion, you will have a strong beginner-level understanding of Kubernetes deployment checking.

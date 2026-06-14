# Kagent UI Access Using NodePort

This note contains the commands needed to check Kagent status and expose the Kagent UI using a Kubernetes NodePort service.

## 1. Check Kagent Pods

Check all Kubernetes pods:

```bash
kubectl get pods -A
```

Check only Kagent pods:

```bash
kubectl get pods -n kagent
```

Expected result: Kagent pods should show `Running`, for example:

```text
kagent-ui                 1/1 Running
kagent-controller         1/1 Running
kagent-kmcp-controller    1/1 Running
k8s-agent                 1/1 Running
kagent-postgresql         1/1 Running
```

## 2. Check Kagent Services

```bash
kubectl get svc -n kagent
```

Look for the Kagent UI service:

```text
kagent-ui   ClusterIP   <cluster-ip>   <none>   8080/TCP
```

## 3. Convert Kagent UI Service to NodePort

```bash
kubectl patch svc kagent-ui -n kagent -p '{"spec":{"type":"NodePort"}}'
```

This changes the Kagent UI service from internal-only `ClusterIP` to externally reachable `NodePort`.

## 4. Check the Assigned NodePort

```bash
kubectl get svc kagent-ui -n kagent
```

You should see something similar to:

```text
kagent-ui   NodePort   10.x.x.x   <none>   8080:31234/TCP
```

In this example, `31234` is the NodePort.

## 5. Get Only the NodePort Number

```bash
kubectl get svc kagent-ui -n kagent -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

## 6. Open Kagent UI in Browser

Use your EC2 public IP and the NodePort:

```text
http://YOUR_EC2_PUBLIC_IP:NODEPORT
```

Example:

```text
http://13.50.100.25:31234
```

Replace:

- `YOUR_EC2_PUBLIC_IP` with your actual EC2 public IP.
- `NODEPORT` with the port shown by Kubernetes.

## 7. Add AWS Security Group Rule

In your EC2 Security Group, add an inbound rule:

```text
Type: Custom TCP
Port: NODEPORT
Source: Your IP only
```

Important: avoid opening the NodePort to `0.0.0.0/0` unless it is only for short temporary testing.

## 8. Test from EC2

Run this on the EC2 instance:

```bash
NODEPORT=$(kubectl get svc kagent-ui -n kagent -o jsonpath='{.spec.ports[0].nodePort}')
curl -I http://localhost:$NODEPORT
```

If the service is reachable, you should get an HTTP response.

## 9. Optional: Change Back to ClusterIP

When you no longer need NodePort access, you can change the service back to ClusterIP:

```bash
kubectl patch svc kagent-ui -n kagent -p '{"spec":{"type":"ClusterIP"}}'
```

## Quick Command Set

```bash
kubectl get pods -n kagent
kubectl get svc -n kagent
kubectl patch svc kagent-ui -n kagent -p '{"spec":{"type":"NodePort"}}'
kubectl get svc kagent-ui -n kagent
kubectl get svc kagent-ui -n kagent -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

## Notes

- `ClusterIP` means the service is reachable only inside the Kubernetes cluster.
- `NodePort` exposes the service on every Kubernetes node using a high port, usually between `30000` and `32767`.
- On AWS, the NodePort will not open in your browser unless the EC2 Security Group allows that port.
- For safer access, restrict the Security Group source to your own IP address.


kubectl -n kagent logs deploy/kagent-tools --tail=200
kubectl -n kagent logs deploy/kagent-controller --tail=200
kubectl -n kagent logs deploy/k8s-agent --tail=200
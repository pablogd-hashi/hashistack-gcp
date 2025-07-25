# GKE Consul Integration - Complete Setup Guide

This directory contains the complete, tested configuration to integrate a GKE cluster with existing HashiCorp Consul infrastructure as an admin partition client.

## Overview

The GKE cluster connects to existing Consul servers as a client in the **k8s-test** admin partition, enabling:
- ✅ Service mesh connectivity between Kubernetes and Nomad workloads
- ✅ Consul Connect service discovery across platforms
- ✅ Cross-platform service communication
- ✅ Unified monitoring and observability
- ✅ Admin partition isolation and security

## Architecture

```
┌─────────────────┐    ┌──────────────────────┐
│ GKE Cluster     │    │ HashiCorp VMs        │
│ (k8s-test       │◄──►│ (Consul Servers)     │
│  partition)     │    │ - DC1: gcp-dc1       │
│ europe-west1    │    │ - europe-west1       │
│                 │    │ - Servers: 3 nodes   │
└─────────────────┘    └──────────────────────┘
```

## Prerequisites

1. **GKE cluster deployed** and kubectl configured
2. **Consul Enterprise license**
3. **Access to HashiCorp Consul servers** with admin permissions
4. **Helm 3.x installed**

## Files in this directory

- `gke-consul-values.yaml` - **Working Helm values** (based on successful minikube config)
- `setup-secrets-auto.sh` - Automated script to create all required secrets
- `setup-secrets.sh` - Interactive script for secret creation
- `deploy-consul.sh` - Script to deploy Consul using Helm
- `create-partition-token.sh` - Script to create new admin partitions and tokens

## Complete Setup Process

### Step 1: Authenticate with GKE

```bash
# Authenticate kubectl with your GKE cluster (europe-west1 region)
gcloud container clusters get-credentials gke-cluster-gke --region europe-west1 --project <your-project-id>

# Verify connection
kubectl cluster-info
```

### Step 2: Create Admin Partition and Token

First, create the `k8s-test` admin partition on your Consul servers:

```bash
# Set Consul environment (use your actual server IP)
export CONSUL_HTTP_ADDR="http://<consul-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<your-bootstrap-token>"

# Create the admin partition
echo 'Name = "k8s-test"
Description = "Admin partition for k8s testing"' | consul partition write -

# Create partition policy (minimal required permissions)
consul acl policy create \
  -partition "k8s-test" \
  -name "k8s-test-partition-policy" \
  -description "Policy for k8s-test partition" \
  -rules='
namespace_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
}
node_prefix "" {
  policy = "write"
}
key_prefix "" {
  policy = "write"
}
session_prefix "" {
  policy = "write"
}
mesh = "write"
peering = "write"'

# Create partition token
consul acl token create \
  -description "Token for k8s-test partition" \
  -partition "k8s-test" \
  -policy-name "k8s-test-partition-policy"
```

**Save the SecretID** from the token creation output - you'll need it for Kubernetes secrets.

### Step 3: Get Required Certificates

The GKE setup requires Consul CA certificates from your existing infrastructure:

```bash
# Navigate to your DC1 terraform directory (Europe-based cluster)
cd ../../dc1/terraform

# Verify the certificates exist
ls -la consul-agent-ca.pem consul-agent-ca-key.pem

# These files contain:
# - consul-agent-ca.pem: Consul CA certificate for TLS (from europe-west1 servers)
# - consul-agent-ca-key.pem: Consul CA private key
```

### Step 4: Create Kubernetes Secrets

```bash
# Create consul namespace
kubectl create namespace consul

# Set your Consul Enterprise license
export CONSUL_ENT_LICENSE="your-consul-enterprise-license-here"

# Create all required secrets
kubectl create secret generic consul-ent-license \
  --namespace=consul \
  --from-literal=key="$CONSUL_ENT_LICENSE"

kubectl create secret generic consul-ca-cert \
  --namespace=consul \
  --from-file=tls.crt="../../dc1/terraform/consul-agent-ca.pem"

kubectl create secret generic consul-ca-key \
  --namespace=consul \
  --from-file=tls.key="../../dc1/terraform/consul-agent-ca-key.pem"

kubectl create secret generic consul-bootstrap-token \
  --namespace=consul \
  --from-literal=token="<your-bootstrap-token>"

kubectl create secret generic consul-partitions-acl-token \
  --namespace=consul \
  --from-literal=token="<YOUR_K8S_TEST_PARTITION_TOKEN>"

kubectl create secret generic consul-dns-token \
  --namespace=consul \
  --from-literal=token="<your-bootstrap-token>"
```

### Step 5: Deploy Consul to GKE

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Deploy Consul with the working configuration
helm install consul hashicorp/consul \
  --namespace consul \
  --values gke-consul-values.yaml \
  --wait
```

### Step 6: Verify Deployment

```bash
# Check pod status
kubectl get pods -n consul

# Expected pods (no consul servers - this is correct!):
# - consul-connect-injector: Service mesh injection
# - consul-dns-proxy: DNS resolution
# - consul-mesh-gateway: Cross-partition communication  
# - consul-terminating-gateway: External service integration
# - consul-webhook-cert-manager: Certificate management

# Check logs for successful connection
kubectl logs -n consul -l app=consul -l component=connect-injector

# Should show: "connected to Consul server" and "Admin Partition already exists: name=k8s-test"
```

### Step 7: Verify Integration

```bash
# Get mesh gateway LoadBalancer IP
kubectl get svc consul-mesh-gateway -n consul

# Check Consul UI - you should see k8s services registered
# Visit your Consul UI at: http://<consul-server-ip>:8500
# Navigate to Services -> Filter by k8s-test partition
```

## Configuration Details

### Key Configuration Elements

The `gke-consul-values.yaml` contains these critical settings:

```yaml
global:
  datacenter: gcp-dc1                    # Must match your Consul datacenter (europe-west1)
  adminPartitions:
    enabled: true
    name: "k8s-test"                     # The partition we created
  
externalServers:
  enabled: true
  hosts:                                 # Your actual Consul server IPs
    - "<consul-server-ip-1>"
    - "<consul-server-ip-2>" 
    - "<consul-server-ip-3>"
  tlsServerName: server.gcp-dc1.consul   # Must match server certificate
  k8sAuthMethodHost: https://<gke-api-endpoint> # Your GKE API server endpoint

server:
  enabled: false                         # No local Consul servers
```

### Network Requirements

- ✅ **GKE private nodes** can reach external Consul servers (NAT Gateway configured)
- ✅ **Port 8502** accessible on Consul servers for gRPC communication
- ✅ **TLS enabled** with proper certificate validation

## Troubleshooting

### Connection Issues

```bash
# Check if Consul servers are reachable
kubectl run debug-pod --image=nicolaka/netshoot --rm -it --restart=Never -- nc -zv <consul-server-ip> 8502

# Check pod logs
kubectl logs -n consul <pod-name>

# Common issues:
# - "ACL not found": Wrong partition token
# - "TLS handshake failed": Certificate/server name mismatch  
# - "Connection timeout": Network connectivity issues
```

### Verify Secrets

```bash
# List all secrets
kubectl get secrets -n consul

# Check secret contents (base64 encoded)
kubectl get secret consul-bootstrap-token -n consul -o jsonpath='{.data.token}' | base64 -d
```

### Reset and Redeploy

```bash
# Complete cleanup and restart
kubectl delete namespace consul
kubectl create namespace consul

# Recreate secrets (see Step 4)
# Redeploy Consul (see Step 5)
```

## Integration Examples

### Deploy a Service with Consul Connect

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/connect-service: "web-app"
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
```

This service will automatically:
- Register in Consul service catalog
- Get a service mesh sidecar (Envoy proxy)
- Be discoverable from Nomad workloads
- Participate in cross-platform service mesh

## Success Criteria

✅ **Pods running**: All expected pods in Running state  
✅ **Logs show connection**: "connected to Consul server" messages  
✅ **Services registered**: Kubernetes services visible in Consul UI  
✅ **Cross-platform discovery**: Nomad can discover k8s services  
✅ **Service mesh active**: Envoy sidecars injected into annotated pods

## Maintenance

### Updating Configuration

```bash
# Update values and upgrade
helm upgrade consul hashicorp/consul \
  --namespace consul \
  --values gke-consul-values.yaml
```

### Monitoring

```bash
# Watch pod status
kubectl get pods -n consul -w

# Monitor logs
kubectl logs -n consul -l app=consul -f

# Check service registration
kubectl port-forward -n consul svc/consul-ui 8500:80
# Visit http://localhost:8500
```

This configuration has been tested and verified to work with the existing HashiCorp infrastructure. The key was using the exact working minikube configuration and only adapting the k8sAuthMethodHost for GKE.
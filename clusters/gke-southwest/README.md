# GKE Southwest Cluster - Consul Admin Partitions Demo

This directory contains the configuration for deploying a GKE cluster as a Consul admin partition client, connecting to the main DC1 HashiStack cluster.

## Overview

- **Region**: `europe-southwest1`
- **Admin Partition**: `k8s-southwest1`
- **Cluster Name**: `gke-southwest`
- **Purpose**: Demo environment for Consul admin partitions with service mesh
- **External Consul Servers**: Connects to DC1 cluster (3 servers)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ DC1 HashiStack Cluster (Primary)                   │
│ ├── Consul Enterprise Servers (3x)                 │
│ ├── Nomad Enterprise Servers (3x)                  │
│ └── Bootstrap ACL Tokens & CA Certificates         │
└─────────────────┬───────────────────────────────────┘
                  │
                  │ Admin Partition Connection
                  │
┌─────────────────▼───────────────────────────────────┐
│ GKE Southwest Cluster (k8s-southwest1 Partition)   │
│ ├── Consul Connect Inject                          │
│ ├── Mesh Gateway (cross-partition communication)   │
│ ├── Service Mesh for applications                  │
│ └── DTAP Environment Support                       │
└─────────────────────────────────────────────────────┘
```

## 🚀 Quick Demo Deployment

### Prerequisites

1. **GKE Cluster**: Deployed and kubectl configured
2. **DC1 Cluster**: HashiStack cluster running with Consul Enterprise
3. **Enterprise License**: Valid Consul Enterprise license
4. **Helm**: Installed and configured

### Step 1: Validate Configuration

Run the validation script to ensure certificates and configuration are ready:

```bash
cd clusters/gke-southwest
./validate-certs.sh
```

**Expected Output:**
```
🔍 Validating Consul certificates and configuration for GKE Southwest...
✅ Certificate files exist
✅ Certificate and key are valid
✅ Certificate and private key match
📅 Certificate expires: Jul  7 06:43:51 2030 GMT
✅ External server IPs configured correctly
✅ k8sAuthMethodHost configured correctly
✅ Admin partition name configured correctly (k8s-southwest1)

🎉 All validations passed! GKE Southwest cluster ready for Consul deployment.
```

### Step 2: Set Environment Variables

```bash
# Required: Set your Consul Enterprise license
export CONSUL_ENT_LICENSE="02MV4UU43BK5HGYYTOJZWFQMTMNNEWU33JKZXXMZJMIFCVK2BNFHGKV2DGRGEOSJ2..."

# Optional: If you have DC1 bootstrap token (script will create placeholder if not)
export CONSUL_BOOTSTRAP_TOKEN="your-bootstrap-token-from-dc1"
```

### Step 3: Create Kubernetes Secrets (Automated)

Use the automated secret creation script:

```bash
./create-consul-secrets.sh
```

**What the script does:**
- ✅ Creates `consul` namespace
- ✅ Creates Enterprise license secret
- ✅ Creates CA certificate and key secrets
- ✅ Creates bootstrap token secret (or placeholder)
- ✅ Creates DNS token secret
- ✅ Creates gossip encryption key (if available)

**Expected Output:**
```
Creating Consul secrets for GKE Southwest cluster...
Warning: No terraform state found. Using hardcoded values from configuration.
Warning: No bootstrap token available. Using placeholder for gossip key.
namespace/consul created
secret/consul-ent-license created
secret/consul-bootstrap-token created
secret/consul-gossip-encryption-key created
secret/consul-ca-cert created
secret/consul-ca-key created
secret/consul-dns-token created
✅ All secrets created successfully for southwest cluster!
```

### Step 4: Deploy Consul with Helm

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Deploy Consul with admin partition configuration
helm install consul hashicorp/consul \
  --namespace consul \
  --values helm/values.yaml \
  --wait \
  --timeout 10m
```

### Step 5: Verify Deployment

```bash
# Check pods are running
kubectl get pods -n consul

# Check services
kubectl get services -n consul

# View mesh gateway (for cross-partition communication)
kubectl get service consul-mesh-gateway -n consul

# Check connect inject webhook
kubectl get mutatingwebhookconfiguration consul-consul-connect-injector
```

**Expected Pods:**
```
NAME                                             READY   STATUS    RESTARTS
consul-connect-injector-5f7b8b8c4d-xyz12        1/1     Running   0
consul-controller-6d8f9c7b5c-abc34              1/1     Running   0
consul-mesh-gateway-7c9d8f6b5a-def56            1/1     Running   0
consul-webhook-cert-manager-789b456c78-ghi90    1/1     Running   0
```

## 📋 Manual Step-by-Step Process

If you prefer manual deployment or need to customize the process:

### Step 1: Create Namespace

```bash
kubectl create namespace consul
```

### Step 2: Create Secrets Manually

#### Enterprise License
```bash
kubectl create secret generic consul-ent-license \
  --namespace=consul \
  --from-literal=key="$CONSUL_ENT_LICENSE"
```

#### CA Certificate (from DC1)
```bash
kubectl create secret generic consul-ca-cert \
  --namespace=consul \
  --from-file=tls.crt="helm/consul-ca.pem"
```

#### CA Private Key (from DC1)
```bash
kubectl create secret generic consul-ca-key \
  --namespace=consul \
  --from-file=tls.key="helm/consul-ca-key.pem"
```

#### Bootstrap Token
```bash
# Replace with actual token from DC1 cluster
kubectl create secret generic consul-bootstrap-token \
  --namespace=consul \
  --from-literal=token="your-bootstrap-token"
```

#### DNS Token
```bash
kubectl create secret generic consul-dns-token \
  --namespace=consul \
  --from-literal=token="your-bootstrap-token"
```

#### Gossip Encryption Key
```bash
# Get from DC1: consul keyring -list
kubectl create secret generic consul-gossip-encryption-key \
  --namespace=consul \
  --from-literal=key="your-gossip-key"
```

### Step 3: Deploy Consul
```bash
helm install consul hashicorp/consul \
  --namespace consul \
  --values helm/values.yaml
```

## 🔧 Configuration Details

### Helm Values Configuration (`helm/values.yaml`)

Key configuration parameters:

```yaml
global:
  adminPartitions:
    enabled: true
    name: "k8s-southwest1"
  
externalServers:
  enabled: true
  hosts:
    - "34.175.142.171"  # DC1 Server 1
    - "34.175.10.229"   # DC1 Server 2
    - "34.175.110.150"  # DC1 Server 3
  k8sAuthMethodHost: "https://34.76.173.55"

meshGateway:
  enabled: true  # For cross-partition communication
  
connectInject:
  enabled: true  # Service mesh injection
  transparentProxy:
    defaultEnabled: true
```

### External Server IPs

The configuration connects to these DC1 Consul servers:
- `34.175.142.171` (Server 1)
- `34.175.10.229` (Server 2) 
- `34.175.110.150` (Server 3)

### k8s Auth Method Host

Kubernetes API endpoint: `https://34.76.173.55`

## 🧪 Demo Applications

### Deploy Sample Application with Service Mesh

```bash
# Create demo namespace
kubectl create namespace demo

# Label for automatic injection
kubectl label namespace demo consul.hashicorp.com/connect-inject=true

# Deploy sample app
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/connect-service: "demo-app"
    spec:
      containers:
      - name: demo-app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: demo
spec:
  selector:
    app: demo-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Verify Service Mesh Injection

```bash
# Check that sidecar proxy was injected
kubectl get pods -n demo -o wide

# Should see 2 containers (app + envoy sidecar)
kubectl describe pod -n demo -l app=demo-app
```

## 📊 Verification and Testing

### Check Admin Partition Status

From DC1 Consul server:
```bash
export CONSUL_HTTP_ADDR="http://34.175.142.171:8500"
export CONSUL_HTTP_TOKEN="your-bootstrap-token"

# List partitions
consul partition list

# List services in southwest partition
consul catalog services -partition k8s-southwest1
```

### Test Cross-Partition Communication

```bash
# From k8s-southwest1, query services in default partition
kubectl exec -n demo deployment/demo-app -c demo-app -- \
  nslookup consul.service.consul
```

### Check Mesh Gateway

```bash
# View mesh gateway logs
kubectl logs -n consul -l app=consul,component=mesh-gateway

# Check gateway service
kubectl get service consul-mesh-gateway -n consul -o wide
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Pods stuck in pending state
```bash
# Check events
kubectl get events -n consul --sort-by='.lastTimestamp'

# Check node resources
kubectl describe nodes
```

#### 2. Connect inject webhook not working
```bash
# Check webhook configuration
kubectl get mutatingwebhookconfiguration consul-consul-connect-injector

# Check webhook logs
kubectl logs -n consul -l app=consul,component=connect-injector
```

#### 3. Secrets not found
```bash
# List all secrets
kubectl get secrets -n consul

# Check specific secret
kubectl get secret consul-ent-license -n consul -o yaml
```

#### 4. External server connection issues
```bash
# Test connectivity to DC1 servers
kubectl run test-pod --image=busybox:1.28 -i --tty --rm -- sh
# From inside pod:
nslookup 34.175.142.171
telnet 34.175.142.171 8500
```

### Debug Commands

```bash
# Check all Consul resources
kubectl get all -n consul

# Describe failing pods
kubectl describe pods -n consul

# View all events
kubectl get events -n consul --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints -n consul
```

## 🎯 Demo Script

For live demos, use this sequence:

### 1. Pre-Demo Setup (5 minutes)
```bash
# Validate everything is ready
./validate-certs.sh

# Set license (prepare beforehand)
export CONSUL_ENT_LICENSE="your-license"
```

### 2. Live Demo (10 minutes)
```bash
# Show empty cluster
kubectl get all -n consul 2>/dev/null || echo "Consul namespace doesn't exist yet"

# Create secrets (automated)
./create-consul-secrets.sh

# Deploy Consul
helm install consul hashicorp/consul --namespace consul --values helm/values.yaml --wait

# Show running cluster
kubectl get all -n consul

# Deploy demo app with service mesh
kubectl create namespace demo
kubectl label namespace demo consul.hashicorp.com/connect-inject=true
# ... deploy demo app ...

# Show service mesh injection
kubectl get pods -n demo
```

### 3. Verification (5 minutes)
```bash
# Show partition in DC1 Consul UI
echo "Visit: http://34.175.142.171:8500/ui/default/admin-partitions"

# Show services registered
consul catalog services -partition k8s-southwest1

# Show mesh gateway
kubectl get service consul-mesh-gateway -n consul
```

## 📁 File Structure

```
clusters/gke-southwest/
├── README.md                          # This guide
├── helm/
│   ├── values.yaml                    # Consul Helm configuration
│   ├── consul-ca.pem                  # CA certificate (from DC1)
│   └── consul-ca-key.pem             # CA private key (from DC1)
├── validate-certs.sh                  # Configuration validation script
└── create-consul-secrets.sh          # Automated secrets creation
```

## 🔗 External References

- [Consul Admin Partitions Documentation](https://developer.hashicorp.com/consul/docs/enterprise/admin-partitions)
- [Consul on Kubernetes](https://developer.hashicorp.com/consul/docs/k8s)
- [Consul Helm Chart Values](https://developer.hashicorp.com/consul/docs/k8s/helm)

---

**Demo Status**: ✅ Ready for deployment  
**Last Updated**: July 2025  
**Consul Version**: 1.21.0-ent  
**Helm Chart**: hashicorp/consul latest
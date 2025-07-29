# Admin Partitions Setup Guide

This guide covers setting up Consul Enterprise admin partitions with GKE clusters.

## Overview

Admin partitions provide multi-tenancy in Consul Enterprise, allowing you to isolate services across different environments or teams. This setup demonstrates:

- **k8s-west1 partition**: GKE cluster (europe-west1) for development/testing/acceptance
- **k8s-southwest1 partition**: GKE cluster (europe-southwest1) for development/testing/production

## Prerequisites

1. Consul Enterprise cluster running on VMs with admin partitions enabled
2. Two GKE clusters deployed and accessible via kubectl
3. Consul Enterprise License configured on servers
4. Bootstrap token from Consul servers
5. CA certificates from Consul servers (for TLS)

## Setup Process

### Step 1: Verify Consul Server Status

First, ensure your Consul Enterprise servers are running and admin partitions are enabled:

```bash
# Check Consul server status
consul members

# Verify admin partitions are enabled
consul partition list
```

You should see the `default` partition listed.

### Step 2: Get Current Server IPs

Get the current IP addresses of your Consul servers:

```bash
# List Consul server instances
gcloud compute instances list --filter="name~hashi-server"
```

Note the external IP addresses - you'll need these for the GKE configuration.

### Step 3: Configure GKE Helm Values

Update the Consul server IP addresses in your GKE Helm values files.

**For GKE Southwest cluster** (`clusters/gke-southwest/helm/values.yaml`):

```yaml
externalServers:
  enabled: true
  hosts:
    - "your-server-ip-1"    # Replace with actual server IP
    - "your-server-ip-2"    # Replace with actual server IP
    - "your-server-ip-3"    # Replace with actual server IP
  httpsPort: 8501
  useSystemRoots: false

global:
  name: consul
  adminPartitions:
    enabled: true
    name: "k8s-southwest1"
  
  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: consul-bootstrap-acl-token
      secretKey: token

  tls:
    enabled: true
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt
```

**For GKE Europe-West1 cluster** (`clusters/gke-europe-west1/helm/values.yaml`):

```yaml
# Similar configuration but with partition name: "k8s-west1"
global:
  adminPartitions:
    name: "k8s-west1"
```

### Step 4: Create Kubernetes Secrets

Create the required secrets for TLS and ACL tokens in each GKE cluster:

```bash
# Authenticate with GKE Southwest cluster
cd clusters/gke-southwest/terraform
terraform output -raw gke_auth_command | sh

# Create namespace
kubectl create namespace consul

# Create bootstrap token secret (use your actual bootstrap token)
kubectl create secret generic consul-bootstrap-acl-token \
  --from-literal=token="your-bootstrap-token" \
  -n consul

# Create CA certificate secret (use your actual CA cert)
kubectl create secret generic consul-ca-cert \
  --from-literal=tls.crt="your-ca-certificate-content" \
  -n consul
```

Repeat for the other GKE cluster.

### Step 5: Deploy Consul to GKE Clusters

Deploy Consul to your GKE clusters:

```bash
# Deploy to GKE Southwest
cd clusters/gke-southwest/helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install consul hashicorp/consul -n consul -f values.yaml

# Wait for deployment to complete
kubectl get pods -n consul -w
```

Repeat for the GKE Europe-West1 cluster.

### Step 6: Verify Partition Creation

Check that the admin partitions were created successfully:

```bash
# From your local machine with Consul CLI configured
export CONSUL_HTTP_ADDR="http://your-consul-server:8500"
export CONSUL_HTTP_TOKEN="your-bootstrap-token"

# List all partitions
consul partition list

# You should see: default, k8s-southwest1, k8s-west1
```

### Step 7: Create Namespace Hierarchies

Create the environment namespaces within each partition:

```bash
# Create namespaces in k8s-southwest1 partition
consul namespace create -partition k8s-southwest1 development
consul namespace create -partition k8s-southwest1 testing
consul namespace create -partition k8s-southwest1 production

# Create namespaces in k8s-west1 partition
consul namespace create -partition k8s-west1 development
consul namespace create -partition k8s-west1 testing
consul namespace create -partition k8s-west1 acceptance
```

## Verification

### Step 8: Deploy Test Services

Deploy a test application to verify the partition setup:

```bash
# Deploy to k8s-southwest1 development namespace
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-southwest1"
        consul.hashicorp.com/namespace: "development"
    spec:
      containers:
      - name: test-app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: development
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Step 9: Verify Service Registration

Check that services are registered in the correct partitions:

```bash
# List services in k8s-southwest1 development namespace
consul catalog services -partition k8s-southwest1 -namespace development

# List services in k8s-west1 development namespace  
consul catalog services -partition k8s-west1 -namespace development
```

## Partition Configuration

### Current Partitions

- **default**: Main partition on VM servers (for Nomad workloads)
- **k8s-west1**: GKE cluster europe-west1 (development, testing, acceptance)
- **k8s-southwest1**: GKE cluster europe-southwest1 (development, testing, production)

### Environment Namespaces

Each partition supports multiple environments for application lifecycle management:

**k8s-west1**: 
- development (active development)
- testing (integration testing)
- acceptance (user acceptance testing)

**k8s-southwest1**: 
- development (active development)
- testing (integration testing)  
- production (live production workloads)

## Troubleshooting

### Issue: Pods Not Ready

**Symptoms**: Consul pods stuck in "Pending" or "CrashLoopBackOff" state

**Solution**: 
1. Check if server IPs in values.yaml match current running instances:
   ```bash
   kubectl logs -n consul -l app=consul,component=connect-injector
   ```

2. Verify secrets exist:
   ```bash
   kubectl get secrets -n consul
   ```

3. Check network connectivity from GKE to Consul servers:
   ```bash
   kubectl run test-pod --image=busybox --rm -it -- nc -zv your-server-ip 8501
   ```

### Issue: xDS Stream Limits

**Symptoms**: Error "too many xDS streams open" in consul-dataplane logs

**Solution**:
1. Reduce number of services deployed per cluster
2. Keep total services under 6-8 per cluster
3. Deploy services in phases rather than all at once

### Issue: Service Mesh Not Working

**Symptoms**: Services cannot communicate despite being deployed

**Solution**:
1. Check service intentions exist:
   ```bash
   consul intention list -partition k8s-southwest1
   ```

2. Verify partition names match between config and applications:
   ```bash
   kubectl get pods -n development -o yaml | grep consul.hashicorp.com/partition
   ```

3. Ensure services are registered in correct partition:
   ```bash
   consul catalog services -partition k8s-southwest1 -namespace development
   ```

### Issue: Authentication Failures

**Symptoms**: "Permission denied" errors when accessing Consul API

**Solution**:
1. Verify bootstrap token is correct:
   ```bash
   consul acl token read -self
   ```

2. Check token has required permissions:
   ```bash
   consul acl token read -id your-token-id
   ```

## Success Criteria

- ✅ All Consul pods running in both GKE clusters
- ✅ Partitions visible in `consul partition list`
- ✅ Services register in correct partitions and namespaces
- ✅ Cross-partition service discovery working (if configured)
- ✅ Service mesh communication enabled with proper intentions
- ✅ No xDS stream limit errors in logs

## Current Configuration Files

**Important Configuration Locations**:
- **GKE Southwest Helm Values**: `clusters/gke-southwest/helm/values.yaml`
- **GKE Europe-West1 Helm Values**: `clusters/gke-europe-west1/helm/values.yaml`

**Critical Settings in values.yaml**:
- Admin partition names (`k8s-southwest1`, `k8s-west1`)
- External Consul server IPs (must match current running instances)
- TLS enabled with CA certificates
- ACLs enabled with bootstrap token
- Connect injection enabled for service mesh

## Next Steps

After successful admin partition setup:

1. **Deploy Applications**: Use partition and namespace annotations in your deployments
2. **Configure Service Intentions**: Set up service-to-service communication rules
3. **Set up CTS**: Configure Consul Terraform Sync for automated infrastructure management
4. **Monitor and Observe**: Set up logging and metrics collection across partitions
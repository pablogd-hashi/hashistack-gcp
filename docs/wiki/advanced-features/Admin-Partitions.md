# Admin Partitions

**Navigation:** [Home](../Home.md) > [Advanced Features](Admin-Partitions.md) > Admin Partitions

> **Quick Links:** [Prerequisites](#prerequisites) | [GKE Setup](#gke-admin-partitions) | [OpenShift CRC](#openshift-crc-admin-partition)

---

## Overview

Deploy Consul admin partitions for multi-tenant isolation. Admin partitions provide complete administrative boundaries within a single Consul datacenter.

**Supported platforms:**
- **GKE clusters** (k8s-west1, k8s-southwest1) - Partition clients
- **OpenShift CRC** (openshift-crc) - Can be partition client or standalone

---

## Prerequisites

**Critical requirements:**

1. **[VM Cluster Deployment](../infrastructure/VM-Cluster-Deployment.md)** - DC1 must be deployed **with ACLs enabled**

2. **ACLs must be configured** - Admin partitions require ACL system

3. **For GKE:** [GKE clusters deployed](../infrastructure/GKE-Cluster-Deployment.md)

4. **For OpenShift CRC:** [OpenShift running](../infrastructure/OpenShift-Integration.md)

5. **CA certificates** from Consul servers

---

## GKE Admin Partitions

### Step 1: Create Admin Partitions on Consul Servers

```bash
# Ensure DC1 environment variables are set
source <(task eval-dc1)

# Create k8s-west1 partition
consul partition create -name "k8s-west1" \
  -description "Admin partition for GKE West1"

# Create k8s-southwest1 partition
consul partition create -name "k8s-southwest1" \
  -description "Admin partition for GKE Southwest1"

# Verify
consul partition list
```

### Step 2: Create ACL Policies and Tokens

```bash
# Use automated task
task -t consul/admin-partitions/Taskfile.yml consul:deploy-policies
task -t consul/admin-partitions/Taskfile.yml consul:deploy-roles
task -t consul/admin-partitions/Taskfile.yml consul:deploy-tokens
```

This creates:
- Partition-specific ACL policies
- Admin roles for each partition
- Bootstrap tokens for Helm deployments

### Step 3: Get CA Certificates from Consul Servers

**Option A: Using Boundary (Recommended)**
```bash
# Get server IP
DC1_SERVER_IP=$(terraform -chdir=clusters/dc1/terraform output -json consul_server_ips | jq -r '.[0]')

# Connect via Boundary and get certificates
boundary connect ssh -target-id <dc1-server-target> -- \
  "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem

boundary connect ssh -target-id <dc1-server-target> -- \
  "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem
```

**Option B: Direct SSH**
```bash
DC1_SERVER_IP=$(terraform -chdir=clusters/dc1/terraform output -json consul_server_ips | jq -r '.[0]')

ssh debian@$DC1_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem
ssh debian@$DC1_SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem
```

### Step 4: Create Kubernetes Secrets

**For GKE West1:**
```bash
kubectl config use-context <gke-west1-context>

kubectl create namespace consul

# License
kubectl create secret generic consul-ent-license \
  --from-literal=key="$CONSUL_ENT_LICENSE" \
  -n consul

# Bootstrap token
kubectl create secret generic consul-bootstrap-token \
  --from-literal=token="$(cat consul/admin-partitions/tokens/k8s-west1-admin.token)" \
  -n consul

# CA certificates
kubectl create secret generic consul-ca-cert \
  --from-file=tls.crt=consul-agent-ca.pem \
  -n consul

kubectl create secret generic consul-ca-key \
  --from-file=tls.key=consul-agent-ca-key.pem \
  -n consul
```

**Repeat for GKE Southwest1** (change context and token file to `k8s-southwest1-admin.token`)

### Step 5: Deploy Consul to GKE with Helm

```bash
cd clusters/gke-europe-west1/helm

# Update values.yaml with current DC1 server IPs
task update-gke-west-values

# Deploy
helm install consul hashicorp/consul \
  --namespace consul \
  --values values.yaml
```

**Key Helm values:**
```yaml
global:
  adminPartitions:
    enabled: true
    name: "k8s-west1"

externalServers:
  enabled: true
  hosts:
    - "35.228.1.100"  # DC1 server IPs
    - "35.228.1.101"
    - "35.228.1.102"
  k8sAuthMethodHost: "https://container.googleapis.com/v1/projects/PROJECT/locations/REGION/clusters/CLUSTER"

server:
  enabled: false  # No servers in partition client mode
```

---

## OpenShift CRC Admin Partition

### Prerequisites

- OpenShift CRC running
- DC1 Consul servers deployed with ACLs
- `openshift-crc` partition created on DC1

### Step 1: Create Partition on Consul Servers

```bash
consul partition create -name "openshift-crc" \
  -description "Admin partition for OpenShift CRC"
```

### Step 2: Create ACL Token

```bash
# Create policy
consul acl policy create \
  -name "openshift-crc-admin-policy" \
  -rules @consul/admin-partitions/policies/openshift-crc-admin-policy.hcl

# Create role
consul acl role create \
  -name "openshift-crc-admin" \
  -policy-name "openshift-crc-admin-policy"

# Create token
consul acl token create \
  -description "Admin token for openshift-crc partition" \
  -role-name "openshift-crc-admin" | tee consul/admin-partitions/tokens/openshift-crc-admin-token.txt
```

### Step 3: Get Certificates and Deploy

Follow similar steps as GKE above:
1. Get CA certificates from DC1 servers
2. Create OpenShift secrets
3. Apply SCCs
4. Deploy with Helm

**Reference:** See OpenShift-specific Helm values in `clusters/openshift-crc/helm/values.yaml`

---

## Verification

### Check Partition Registration

```bash
# List partitions
consul partition list

# Check services in partition
consul catalog services -partition k8s-west1

# Check nodes in partition
consul catalog nodes -partition k8s-west1
```

### Verify GKE Consul Deployment

```bash
kubectl get pods -n consul

# Should see:
# - consul-connect-injector
# - consul-webhook-cert-manager
# - No consul-server pods (partition client mode)
```

### Test Service Registration

Deploy a test service in GKE:

```bash
kubectl create namespace test
kubectl label namespace test consul.hashicorp.com/connect-inject=true

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-app
  namespace: test
  annotations:
    consul.hashicorp.com/connect-inject: "true"
spec:
  containers:
  - name: nginx
    image: nginx:alpine
EOF

# Check in Consul
consul catalog services -partition k8s-west1 -namespace test
```

---

## Demo Application

Deploy Google Boutique microservices to demonstrate admin partitions:

```bash
task -t consul/admin-partitions/Taskfile.yml deploy-boutique-full
```

This deploys a multi-service application across the partition with full service mesh integration.

---

## What's Next?

After setting up admin partitions:

1. **Deploy applications** to partitioned namespaces
2. **Configure service intentions** for cross-partition communication
3. **Set up service exports** for service sharing

---

**Previous:** [Secure Access with Boundary](../infrastructure/Secure-Access-with-Boundary.md) | **Next:** [Cluster Peering](Cluster-Peering.md) | **[Back to Top](#admin-partitions)**

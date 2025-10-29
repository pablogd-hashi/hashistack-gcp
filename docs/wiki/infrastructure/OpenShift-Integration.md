# OpenShift Integration

**Navigation:** [Home](../Home.md) > [Core Infrastructure](Image-Building-with-Packer.md) > OpenShift Integration

> **Quick Links:** [Prerequisites](#prerequisites) | [OpenShift CRC](#openshift-crc-local) | [OpenShift ROSA](#openshift-rosa-aws)

---

## Overview

Deploy Consul Enterprise on Red Hat OpenShift for local development (CRC) or production (ROSA). OpenShift deployments run standalone Consul servers, not admin partition clients like GKE.

**Deployment options:**
- **OpenShift CRC** - Code Ready Containers for local development
- **OpenShift ROSA** - Red Hat OpenShift on AWS for production

---

## Prerequisites

**Required:**

1. **Consul Enterprise license** configured in HCP Terraform or local variables

2. **OpenShift CLI (oc)** installed:
   ```bash
   # macOS
   brew install openshift-cli

   # Or download from Red Hat
   ```

3. **Helm** installed:
   ```bash
   brew install helm
   ```

4. **For CRC:** Minimum 9GB RAM, 4 CPU cores free

5. **For ROSA:** AWS account with appropriate permissions

---

## OpenShift CRC (Local)

**Use case:** Local development and testing

### Step 1: Install and Start CRC

```bash
# Download from https://developers.redhat.com/products/openshift-local/overview

# Set up CRC
crc setup

# Start cluster (requires Red Hat account)
crc start

# Get credentials
crc console --credentials
```

### Step 2: Login to OpenShift

```bash
# Use credentials from previous step
oc login -u kubeadmin -p <password> https://api.crc.testing:6443

# Verify
oc cluster-info
oc get nodes
```

### Step 3: Create Consul Namespace

```bash
oc new-project consul
```

### Step 4: Apply Security Context Constraints

OpenShift requires SCCs for privileged operations:

```bash
# Add SCCs for all Consul service accounts
oc adm policy add-scc-to-user anyuid -z consul-server -n consul
oc adm policy add-scc-to-user anyuid -z consul-client -n consul
oc adm policy add-scc-to-user anyuid -z consul-connect-injector -n consul
oc adm policy add-scc-to-user anyuid -z consul-mesh-gateway -n consul
oc adm policy add-scc-to-user anyuid -z consul-terminating-gateway -n consul
oc adm policy add-scc-to-user anyuid -z consul-webhook-cert-manager -n consul
oc adm policy add-scc-to-user anyuid -z consul-dns-proxy -n consul
oc adm policy add-scc-to-user anyuid -z consul-server-acl-init -n consul
oc adm policy add-scc-to-user anyuid -z consul-tls-init -n consul
oc adm policy add-scc-to-user anyuid -z consul-gossip-encryption-autogenerate -n consul
```

### Step 5: Create Secrets

```bash
# Consul Enterprise license
oc create secret generic consul-license \
  --from-literal=key="YOUR_CONSUL_LICENSE" \
  -n consul

# Image pull secret (for HashiCorp registry)
oc create secret docker-registry hashicorp-registry \
  --docker-server=docker.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  -n consul
```

### Step 6: Deploy Consul with Helm

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Deploy Consul
cd clusters/openshift-crc/helm

helm install consul hashicorp/consul \
  --namespace consul \
  --values values.yaml

# Wait for pods
oc get pods -n consul -w
```

### Step 7: Access Consul UI

```bash
# Port forward
oc port-forward svc/consul-ui 8500:443 -n consul

# Access at https://localhost:8500
# Get token
oc get secret consul-bootstrap-acl-token -n consul -o jsonpath='{.data.token}' | base64 -d
```

---

## OpenShift ROSA (AWS)

**Use case:** Production deployments on AWS

### Step 1: Create ROSA Cluster

```bash
# Install ROSA CLI
brew install rosa-cli

# Login
rosa login

# Create cluster
rosa create cluster --cluster-name=consul-cluster \
  --region=us-east-1 \
  --compute-machine-type=m5.xlarge \
  --compute-nodes=3
```

Wait ~40 minutes for cluster creation.

### Step 2: Get kubeconfig

```bash
rosa describe cluster -c consul-cluster
oc login <api-url> --token=<token>
```

### Step 3: Follow Same Steps as CRC

Repeat steps 3-7 from CRC section above.

---

## Helm Values Configuration

**Key configurations for OpenShift:**

```yaml
global:
  name: consul
  image: "hashicorp/consul-enterprise:1.21.2-ent-ubi"  # UBI image required
  openshift:
    enabled: true  # Critical for OpenShift

  gossipEncryption:
    autoGenerate: true

  tls:
    enabled: true

  acls:
    manageSystemACLs: true

server:
  enabled: true
  replicas: 1  # For CRC; increase for ROSA

connectInject:
  enabled: true
  default: false
  cni:
    enabled: false  # Multus has authorization issues
    multus: false
```

**Reference values:** `clusters/openshift-crc/helm/values.yaml`

---

## OpenShift-Specific Considerations

### Security Context Constraints

OpenShift's security model requires explicit SCCs. Without them, pods will fail with permission errors.

### UBI Images

Use Universal Base Images (UBI) for RHEL compatibility:
- `hashicorp/consul-enterprise:1.21.2-ent-ubi`

### Multus CNI

Multus CNI integration has known issues with OpenShift authorization. Recommend disabling:
```yaml
connectInject:
  cni:
    enabled: false
    multus: false
```

### Routes vs Ingress

OpenShift uses Routes instead of Kubernetes Ingress for external access.

---

## Verification

```bash
# Check pods
oc get pods -n consul

# Check services
oc get svc -n consul

# Check Consul members
oc exec -it consul-server-0 -n consul -- consul members

# Check logs
oc logs -f consul-server-0 -n consul
```

---

## What's Next?

After deploying Consul on OpenShift:

1. **Deploy applications** to the consul namespace
2. **Enable service mesh** with `consul.hashicorp.com/connect-inject: "true"` annotation
3. **Configure service intentions** for zero-trust networking

For admin partitions integration, see: **[Admin Partitions](../advanced-features/Admin-Partitions.md)** (OpenShift CRC section)

---

**Previous:** [GKE Cluster Deployment](GKE-Cluster-Deployment.md) | **Next:** [Secure Access with Boundary](Secure-Access-with-Boundary.md) | **[Back to Top](#openshift-integration)**

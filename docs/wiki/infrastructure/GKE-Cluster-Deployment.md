# GKE Cluster Deployment

**Navigation:** [Home](../Home.md) > [Core Infrastructure](Image-Building-with-Packer.md) > GKE Cluster Deployment

> **Quick Links:** [Prerequisites](#prerequisites) | [Deploy GKE West](#deploy-gke-west1) | [Deploy GKE Southwest](#deploy-gke-southwest1)

---

## Overview

Deploy Google Kubernetes Engine (GKE) clusters for Consul admin partitions integration. These clusters will run Consul agents as partition clients, connecting to your VM-based Consul servers.

**Clusters:**
- **GKE West1** (europe-west1) - Admin partition: `k8s-west1`
- **GKE Southwest** (europe-southwest1) - Admin partition: `k8s-southwest1`

**Deployment time:** ~8 minutes per cluster

---

## Prerequisites

**Required before deployment:**

1. **[VM Cluster Deployment](VM-Cluster-Deployment.md)** - DC1 must be deployed and operational with ACLs enabled

2. **HCP Terraform workspaces** created:
   - `gke-europe-west1`
   - `gke-southwest`

3. **Variable sets applied** to GKE workspaces:
   - GCP Common (GOOGLE_CREDENTIALS, gcp_project)
   - HashiStack Common (licenses, versions)

4. **Kubernetes Engine API** enabled:
   ```bash
   gcloud services enable container.googleapis.com
   ```

5. **kubectl installed** and configured:
   ```bash
   brew install kubectl
   ```

---

## Deploy GKE West1

### Step 1: Navigate to Terraform Directory

```bash
cd clusters/gke-europe-west1/terraform
```

### Step 2: Deploy Cluster

```bash
terraform init
terraform plan
terraform apply
```

**Expected resources** (~15 resources):
- GKE cluster (regional, 3 zones)
- Node pools with auto-scaling (1-3 nodes per zone)
- VPC network (10.10.0.0/24)
- Pod network (10.11.0.0/16)
- Service network (10.12.0.0/16)

**Deployment time:** ~8 minutes

### Step 3: Authenticate kubectl

```bash
# Get kubeconfig
gcloud container clusters get-credentials gke-cluster \
  --region europe-west1 \
  --project YOUR_PROJECT_ID

# Or use task
task gke-auth-west

# Verify
kubectl get nodes
```

### Step 4: Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces
```

---

## Deploy GKE Southwest1

### Step 1: Navigate to Terraform Directory

```bash
cd clusters/gke-southwest/terraform
```

### Step 2: Deploy Cluster

```bash
terraform init
terraform plan
terraform apply
```

Configuration matches GKE West1 but in different region.

### Step 3: Authenticate kubectl

```bash
gcloud container clusters get-credentials gke-cluster \
  --region europe-southwest1 \
  --project YOUR_PROJECT_ID

# Or use task
task gke-auth-southwest
```

---

## Cluster Configuration

### GKE West1 (europe-west1)

**Network:**
- Cluster VPC: 10.10.0.0/24
- Pod CIDR: 10.11.0.0/16
- Service CIDR: 10.12.0.0/16

**Node pools:**
- Machine type: e2-standard-4
- Auto-scaling: 1-3 nodes per zone
- Total nodes: 3-9 (across 3 zones)

**Features:**
- Regional cluster (HA across zones)
- Workload Identity enabled
- Network policy enabled
- Auto-repair and auto-upgrade enabled

### GKE Southwest1 (europe-southwest1)

**Network:**
- Cluster VPC: 10.20.0.0/24
- Pod CIDR: 10.21.0.0/16
- Service CIDR: 10.22.0.0/16

**Configuration:** Same as GKE West1

---

## Using Task Automation

```bash
# Deploy both GKE clusters
task deploy-both-gke

# Authenticate to clusters
task gke-auth-west
task gke-auth-southwest

# Get cluster info
kubectl config get-contexts
```

---

## What's Next?

After deploying GKE clusters, proceed to:

**[Admin Partitions](../advanced-features/Admin-Partitions.md)** - Configure Consul admin partitions and deploy Consul to GKE as partition clients

**Note:** Do not deploy Consul to GKE yet. Admin partitions must be created on the Consul servers first.

---

**Previous:** [VM Cluster Deployment](VM-Cluster-Deployment.md) | **Next:** [OpenShift Integration](OpenShift-Integration.md) | **[Back to Top](#gke-cluster-deployment)**

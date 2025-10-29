# VM Cluster Deployment

**Navigation:** [Home](../Home.md) > [Core Infrastructure](Image-Building-with-Packer.md) > VM Cluster Deployment

> **Quick Links:** [Prerequisites](#prerequisites) | [Deploy DC1](#deploy-dc1-primary-datacenter) | [Deploy DC2](#deploy-dc2-secondary-datacenter) | [Verification](#verification)

---

## Overview

Deploy Consul Enterprise and Nomad Enterprise server clusters on Google Cloud Platform VMs. This page covers deploying both primary (DC1) and optional secondary (DC2) datacenters.

**What gets deployed:**
- 3 server nodes (Consul + Nomad servers in HA configuration)
- 2-4 client nodes (Nomad workload execution)
- VPC networks with firewall rules
- TLS certificates and ACL bootstrapping
- Service mesh configuration

**Deployment time:**
- DC1: ~10 minutes
- DC2: ~10 minutes (if multi-DC)

---

## Prerequisites

**Required before deployment:**

1. **[Prerequisites and Setup](../getting-started/Prerequisites-and-Setup.md)** completed:
   - HCP Terraform workspaces created (`hashistack-dc1`, optionally `hashistack-dc2`)
   - Variable sets configured (GCP Common, HashiStack Common)
   - Service account JSON added to `GOOGLE_CREDENTIALS`

2. **[Custom VM Images](Image-Building-with-Packer.md)** built:
   - Run `task build-images` first
   - Verify with `gcloud compute images list --filter="family=hashistack"`

3. **Terraform CLI authenticated:**
   ```bash
   terraform login
   ```

---

## Deploy DC1 (Primary Datacenter)

### Step 1: Navigate to DC1 Terraform Directory

```bash
cd clusters/dc1/terraform
```

### Step 2: Initialize Terraform

```bash
terraform init
```

This connects to your HCP Terraform workspace and downloads required providers.

### Step 3: Review Planned Changes

```bash
terraform plan
```

**Expected resources** (~24 resources):
- VPC network and subnets
- Firewall rules (Consul, Nomad, SSH, service mesh)
- 3 server instances (e2-standard-2)
- 2-4 client instances (e2-standard-2)
- External IP addresses
- Service account with IAM bindings

### Step 4: Apply Infrastructure

```bash
terraform apply
```

Review the plan and type `yes` to proceed.

**Deployment process:**
1. Creates VPC and networking
2. Launches server instances
3. Launches client instances
4. Bootstraps Consul ACLs
5. Generates TLS certificates
6. Configures Nomad-Consul integration

**Output example:**
```
Apply complete! Resources: 24 added, 0 changed, 0 destroyed.

Outputs:

consul_server_ips = [
  "35.228.1.100",
  "35.228.1.101",
  "35.228.1.102",
]
nomad_client_ips = [
  "35.228.2.100",
  "35.228.2.101",
]
consul_bootstrap_token = <sensitive>
nomad_bootstrap_token = <sensitive>
```

### Step 5: Get Environment Variables

```bash
# From project root
task eval-dc1
```

**Copy and paste the output** into your terminal:

```bash
export CONSUL_HTTP_ADDR="http://35.228.1.100:8500"
export CONSUL_HTTP_TOKEN="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
export NOMAD_ADDR="http://35.228.1.100:4646"
export NOMAD_TOKEN="e5f6g7h8-i9j0-1234-cdef-567890abcdef"
```

### Step 6: Complete Nomad-Consul Integration

```bash
nomad setup consul -y
```

This configures Nomad to register services with Consul.

---

## Deploy DC2 (Secondary Datacenter)

**Prerequisites:**
- DC1 deployed and operational
- HCP Terraform workspace `hashistack-dc2` created
- Same variable sets applied

### Step 1: Navigate to DC2 Terraform Directory

```bash
cd clusters/dc2/terraform
```

### Step 2: Deploy DC2

```bash
terraform init
terraform plan
terraform apply
```

DC2 deployment is independent of DC1 and follows the same process.

### Step 3: Get DC2 Environment Variables

```bash
# From project root
task eval-dc2

# Or for both datacenters
task eval-both
```

Set both DC1 and DC2 environment variables in separate terminal sessions or use suffixes:

```bash
export CONSUL_HTTP_ADDR_DC1="http://35.228.1.100:8500"
export CONSUL_HTTP_TOKEN_DC1="..."
export CONSUL_HTTP_ADDR_DC2="http://34.88.1.100:8500"
export CONSUL_HTTP_TOKEN_DC2="..."
```

### Step 4: Configure Nomad-Consul Integration

```bash
# Point to DC2
export CONSUL_HTTP_ADDR="$CONSUL_HTTP_ADDR_DC2"
export CONSUL_HTTP_TOKEN="$CONSUL_HTTP_TOKEN_DC2"
export NOMAD_ADDR="http://34.88.1.100:4646"
export NOMAD_TOKEN="..."

nomad setup consul -y
```

---

## Verification

### Verify Consul Cluster

```bash
# List Consul members
consul members

# Expected output:
# Node            Address          Status  Type    Build       Protocol  DC    Partition  Segment
# hashi-server-0  10.0.1.10:8301  alive   server  1.21.2+ent  2         dc1   default    <all>
# hashi-server-1  10.0.1.11:8301  alive   server  1.21.2+ent  2         dc1   default    <all>
# hashi-server-2  10.0.1.12:8301  alive   server  1.21.2+ent  2         dc1   default    <all>

# Check Consul leader
consul operator raft list-peers

# List services
consul catalog services
```

### Verify Nomad Cluster

```bash
# Check Nomad servers
nomad server members

# Expected output:
# Name                 Address      Port  Status  Leader  Raft Version  Protocol  Version
# hashi-server-0.dc1  10.0.1.10    4648  alive   true    3             2         1.10.3+ent

# Check Nomad clients
nomad node status

# Expected output:
# ID        Node Class  DC   Drain  Eligibility  Status
# abc123... <none>      dc1  false  eligible     ready
# def456... <none>      dc1  false  eligible     ready

# Check cluster health
nomad operator raft list-peers
```

### Access Web UIs

**Consul UI:**
```
http://<consul-server-ip>:8500
```
- Token: Use `$CONSUL_HTTP_TOKEN`
- Navigate to Services → Should see `consul`, `nomad`

**Nomad UI:**
```
http://<nomad-server-ip>:4646
```
- Token: Use `$NOMAD_TOKEN`
- Navigate to Servers → Should see 3 servers
- Navigate to Clients → Should see 2-4 clients

### Test Nomad Job Submission

```bash
# Create test job
cat > test.nomad.hcl <<'EOF'
job "test" {
  datacenters = ["dc1"]
  type = "service"

  group "test" {
    task "test" {
      driver = "docker"
      config {
        image = "nginx:alpine"
      }
    }
  }
}
EOF

# Submit job
nomad job run test.nomad.hcl

# Check status
nomad job status test

# Clean up
nomad job stop -purge test
```

---

## Deployment Configuration

### Server Configuration

**Instance type:** `e2-standard-2` (2 vCPU, 8GB RAM)

**Roles:**
- Consul server (voting member)
- Nomad server (scheduling)
- Co-located for simplicity

**High availability:**
- 3 servers tolerate 1 failure
- Raft consensus for leader election
- Automatic failover

### Client Configuration

**Instance type:** `e2-standard-2` (2 vCPU, 8GB RAM)

**Roles:**
- Nomad client (workload execution)
- Consul client (service registration)
- Docker runtime for containers

**Scaling:**
- Start with 2 clients
- Scale up by increasing `client_count` variable
- No downtime for adding clients

### Network Configuration

**DC1 (europe-north1):**
```
VPC: 10.0.0.0/16
├── Servers: 10.0.1.0/24
└── Clients: 10.0.2.0/24
```

**DC2 (europe-west1):**
```
VPC: 10.1.0.0/16
├── Servers: 10.1.1.0/24
└── Clients: 10.1.2.0/24
```

**Firewall rules allow:**
- Consul gossip: 8301-8302 (TCP/UDP)
- Consul RPC: 8300 (TCP)
- Consul HTTP/HTTPS: 8500-8501 (TCP)
- Consul DNS: 8600 (TCP/UDP)
- Nomad RPC: 4647 (TCP)
- Nomad HTTP: 4646 (TCP)
- Nomad Serf: 4648 (TCP/UDP)
- Service mesh: 20000, 21000-21255 (TCP)
- SSH: 22 (TCP)

---

## Using Task Automation

For simplified deployment, use the Taskfile:

```bash
# Deploy DC1
task deploy-dc1

# Deploy DC2
task deploy-dc2

# Deploy both
task deploy-both-dc

# Get environment variables
task eval-dc1
task eval-dc2
task eval-both

# Show cluster information
task show-dc1-info
task show-dc2-info

# SSH to servers
task ssh-dc1-server
task ssh-dc2-server
```

---

## Multi-Datacenter Considerations

After deploying both DC1 and DC2:

1. **Independent clusters:** Each datacenter operates independently
2. **No automatic federation:** Datacenters are not WAN-federated by default
3. **Cluster peering required:** Use [Cluster Peering](../advanced-features/Cluster-Peering.md) for cross-DC communication
4. **Separate ACLs:** Each datacenter has its own ACL tokens and policies
5. **Service exports:** Services must be explicitly exported for cross-DC access

---

## Customization

### Scaling Clients

Edit variable in HCP Terraform workspace or local tfvars:

```hcl
client_count = 4  # Increase from default 2
```

Re-run `terraform apply` to add clients.

### Changing Instance Types

```hcl
server_machine_type = "e2-standard-4"  # Upgrade to 4 vCPU, 16GB RAM
client_machine_type = "e2-standard-4"
```

### Changing Regions

For DC1:
```hcl
gcp_region = "us-central1"  # Change from europe-north1
```

For DC2:
```hcl
gcp_region = "us-west1"  # Change from europe-west1
```

---

## What's Next?

After deploying VM clusters:

1. **[Configure Boundary](Secure-Access-with-Boundary.md)** - Set up secure SSH access (recommended)
2. **[Deploy Monitoring](../operations/Monitoring-and-Observability.md)** - Add Prometheus and Grafana
3. **[Set Up Cluster Peering](../advanced-features/Cluster-Peering.md)** - Connect DC1 and DC2 (if multi-DC)
4. **[Deploy Admin Partitions](../advanced-features/Admin-Partitions.md)** - Add GKE clusters for multi-tenancy

---

**Previous:** [Image Building with Packer](Image-Building-with-Packer.md) | **Next:** [GKE Cluster Deployment](GKE-Cluster-Deployment.md) | **[Back to Top](#vm-cluster-deployment)**

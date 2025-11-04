# OpenShift ROSA Consul Admin Partition

Deploy Consul Enterprise to OpenShift ROSA as an admin partition connecting to external Consul servers running on GCP VMs.

**📖 [Back to Main README](../../README.md)**

## Overview

This configuration deploys Consul Enterprise to OpenShift ROSA in **admin partition mode** (not as Consul servers). The OpenShift cluster connects to your existing Consul server cluster (DC1/DC2) running on GCP VMs and operates as an isolated admin partition named `openshift-rosa`.

### Architecture

```
Consul Servers (GCP VMs) - Enterprise
├── Admin Partition: "k8s-west1" (GKE europe-west1)
├── Admin Partition: "k8s-southwest1" (GKE europe-southwest1)
└── Admin Partition: "openshift-rosa" (OpenShift ROSA) ← This configuration
    ├── Namespace: "development"
    ├── Namespace: "testing"
    └── Namespace: "production"
```

## Prerequisites

### Required Infrastructure
- ✅ **Consul Enterprise servers** running on GCP VMs with admin partitions enabled
- ✅ **OpenShift ROSA cluster** deployed and accessible via `oc` CLI
- ✅ **Consul Enterprise license** key
- ✅ **Network connectivity** from OpenShift to Consul server external IPs

### Required Tools
- `oc` CLI configured with cluster-admin access
- `helm` v3.x
- `consul` CLI (for creating ACL policies and partitions)

### Required Credentials
- Consul Enterprise license key
- Consul root bootstrap token
- CA certificates from Consul servers

## Quick Start

### 1. Get Consul Server External IPs

First, get the external IPs of your Consul servers:

```bash
# Using gcloud CLI
gcloud compute instances list \
  --filter='name~hashi-server' \
  --format='table(name,INTERNAL_IP,EXTERNAL_IP,zone)'

# Example output:
# NAME                INTERNAL_IP  EXTERNAL_IP    ZONE
# hashi-server-0-181  10.2.0.5     34.88.172.144  europe-north1-a
# hashi-server-1-181  10.2.0.6     34.88.43.17    europe-north1-c
# hashi-server-2-181  10.2.0.4     34.88.45.49    europe-north1-b
```

**Update `helm/values.yaml` with these external IPs:**

```yaml
externalServers:
  enabled: true
  hosts:
    - "34.88.172.144"  # hashi-server-0-181
    - "34.88.43.17"    # hashi-server-1-181
    - "34.88.45.49"    # hashi-server-2-181
```

### 2. Create Admin Partition in Consul

Create the `openshift-rosa` admin partition and ACL policies on your Consul servers:

```bash
# Set Consul connection details
export CONSUL_HTTP_ADDR="http://34.88.172.144:8500"
export CONSUL_HTTP_TOKEN="<your-root-bootstrap-token>"

# Create admin partition
consul partition create \
  -name "openshift-rosa" \
  -description "Admin partition for OpenShift ROSA cluster"

# Verify creation
consul partition list
```

### 3. Create ACL Policy and Token

Create an ACL policy for the OpenShift partition:

```bash
# Create policy file
cat > openshift-rosa-admin-policy.hcl <<'EOF'
# Admin policy for openshift-rosa partition - provides full administrative access

operator = "read"

partition "openshift-rosa" {
  policy = "write"

  key_prefix "" {
    policy = "write"
  }

  service_prefix "" {
    policy = "write"
  }

  node_prefix "" {
    policy = "write"
  }

  acl = "write"

  namespace_prefix "" {
    policy = "write"

    key_prefix "" {
      policy = "write"
    }

    service_prefix "" {
      policy = "write"
    }

    node_prefix "" {
      policy = "read"
    }

    acl = "write"
  }
}
EOF

# Create the policy
consul acl policy create \
  -name "openshift-rosa-admin-policy" \
  -description "Admin policy for openshift-rosa partition" \
  -rules @openshift-rosa-admin-policy.hcl

# Create role
consul acl role create \
  -name "openshift-rosa-admin" \
  -description "Admin role for openshift-rosa partition" \
  -policy-name "openshift-rosa-admin-policy"

# Create token
consul acl token create \
  -description "Admin token for openshift-rosa partition" \
  -role-name "openshift-rosa-admin" | tee openshift-rosa-admin-token.txt

# Extract token ID
cat openshift-rosa-admin-token.txt | grep SecretID | awk '{print $2}' > openshift-rosa-admin.token
```

### 4. Obtain CA Certificates from Consul Servers

You need the CA certificate and key from your Consul servers to enable TLS. Choose one of these methods:

#### Option A: Using SSH (if SSH keys are configured)

```bash
# Get the IP of a Consul server
SERVER_IP=$(gcloud compute instances list \
  --filter='name~hashi-server-0' \
  --format='value(EXTERNAL_IP)' \
  --limit=1)

# Copy CA certificate
ssh debian@$SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem

# Copy CA key
ssh debian@$SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem

# Verify files
ls -lh consul-agent-ca*.pem
```

#### Option B: Using Boundary (if Boundary is deployed)

```bash
# Set Boundary connection
export BOUNDARY_ADDR="https://a4a6eb9e-a049-4296-bbf3-833bc6f9b443.boundary.hashicorp.cloud"

# Find your Consul server target ID
boundary targets list

# Connect and copy certificates (replace <target-id> with actual ID)
boundary connect ssh -target-id <target-id> -- \
  "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem

boundary connect ssh -target-id <target-id> -- \
  "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem
```

#### Option C: Manual SCP

```bash
# Using service account or your SSH key
SERVER_IP="34.88.172.144"

scp debian@$SERVER_IP:/etc/consul.d/tls/consul-agent-ca.pem ./
scp debian@$SERVER_IP:/etc/consul.d/tls/consul-agent-ca-key.pem ./
```

### 5. Create Kubernetes Secrets in OpenShift

Switch to your OpenShift cluster and create the required secrets:

```bash
# Switch to OpenShift context
oc config use-context <your-openshift-context>

# Create consul namespace
oc create namespace consul

# Create enterprise license secret
# Get your license from: cat ~/Documents/Infrastructure/openshift/01-consul/consul.hclic
oc create secret generic consul-ent-license \
  --from-literal=key="$(cat ~/Documents/Infrastructure/openshift/01-consul/consul.hclic)" \
  -n consul

# Create bootstrap token secret
# IMPORTANT: Use the root bootstrap token (e.g., "ConsulR0cks"), NOT the partition token
# This is required for manageSystemACLs: true with external servers
oc create secret generic consul-bootstrap-token \
  --from-literal=token="ConsulR0cks" \
  -n consul

# Create CA certificate secret
oc create secret generic consul-ca-cert \
  --from-file=tls.crt=consul-agent-ca.pem \
  -n consul

# Create CA key secret
oc create secret generic consul-ca-key \
  --from-file=tls.key=consul-agent-ca-key.pem \
  -n consul

# Verify secrets
oc get secrets -n consul
```

**CRITICAL: Bootstrap Token Note**

When using `global.acls.manageSystemACLs: true` with `externalServers`, the bootstrap token secret **MUST** contain the Consul root bootstrap token (the one used to bootstrap the entire Consul cluster), NOT the partition-specific admin token.

Why? The Helm ACL initialization job needs global permissions to:
- Create component tokens (connect-injector, controller, mesh-gateway, etc.)
- Manage Kubernetes auth method
- Configure ACL bindings

The partition admin token only has permissions within its partition and cannot perform these system-level operations.

### 6. Create Image Pull Secret (if needed)

If your OpenShift cluster requires image pull secrets:

```bash
# Copy from your existing OpenShift deployment
cp ~/Documents/Infrastructure/openshift/01-consul/18338488-openshift-secret-pull-secret.yaml .

# Apply it
oc apply -f 18338488-openshift-secret-pull-secret.yaml -n consul
```

### 7. Deploy Consul with Helm

```bash
# Navigate to helm directory
cd clusters/openshift-rosa/helm

# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Consul
helm install consul hashicorp/consul \
  --namespace consul \
  --values values.yaml \
  --wait

# Monitor deployment
oc get pods -n consul -w
```

Expected pods:
- `consul-connect-inject-*` (2 replicas)
- `consul-controller-*` (1 replica)
- `consul-mesh-gateway-*` (2 replicas)
- `consul-webhook-cert-manager-*` (1 replica)

### 8. Verify Deployment

```bash
# Check all pods are running
oc get pods -n consul

# Check Consul services registration
export CONSUL_HTTP_ADDR="http://34.88.172.144:8500"
export CONSUL_HTTP_TOKEN="ConsulR0cks"

# List services in the openshift-rosa partition
consul catalog services -partition openshift-rosa

# Verify partition exists
consul partition list | grep openshift-rosa

# Check Consul UI (if accessible)
# Navigate to: http://34.88.172.144:8500/ui/gcp-dc1/partitions/openshift-rosa
```

### 9. Create Application Namespaces

Create namespaces for your applications with proper labels:

```bash
# Create development namespace
oc create namespace development

# Label it for Consul injection (matching namespaceSelector in values.yaml)
oc label namespace development bofa.com/esm=enabled

# Enable injection
oc label namespace development consul.hashicorp.com/connect-inject=enabled

# Create production namespace
oc create namespace production
oc label namespace production bofa.com/esm=enabled
oc label namespace production consul.hashicorp.com/connect-inject=enabled

# Verify labels
oc get namespace development --show-labels
oc get namespace production --show-labels
```

## Configuration Details

### External Servers Setup

The `externalServers` configuration tells OpenShift how to connect to your Consul servers:

```yaml
externalServers:
  enabled: true
  hosts:
    - "34.88.172.144"  # External IP of server-0
    - "34.88.43.17"    # External IP of server-1
    - "34.88.45.49"    # External IP of server-2
  httpsPort: 8501      # TLS-enabled HTTP port
  grpcPort: 8502       # gRPC port for dataplanes
  tlsServerName: server.gcp-dc1.consul  # TLS server name
  k8sAuthMethodHost: https://kubernetes.default.svc  # OpenShift API
```

**Important Notes:**

1. **Use External IPs Only**: Do not include internal IPs (10.2.0.x) unless you have VPC peering configured between OpenShift and GCP.

2. **Dataplane Discovery**: After initial connection, dataplanes will discover internal IPs from Consul servers. If these IPs are not reachable, you may see connection errors in logs - this is expected without VPC peering.

3. **TLS Server Name**: Must match the TLS certificate on your Consul servers (usually `server.<datacenter>.consul`).

4. **Kubernetes API**: This is the OpenShift API endpoint used for Kubernetes auth method. The default (`https://kubernetes.default.svc`) works in most cases.

### OpenShift-Specific Configuration

Key OpenShift-specific settings in `values.yaml`:

```yaml
global:
  openshift:
    enabled: true  # Enables OpenShift compatibility mode

  image: hashicorp/consul-enterprise:1.22.0-rc1-ent-ubi  # UBI-based image for OpenShift

connectInject:
  cni:
    enabled: true
    multus: true  # Enable Multus CNI for OpenShift
    cniBinDir: "/var/lib/cni/bin"
    cniNetDir: "/etc/kubernetes/cni/net.d"

  namespaceSelector: |  # Only inject into labeled namespaces
    matchExpressions:
      - key: bofa.com/esm
        operator: In
        values:
          - enabled
```

## Troubleshooting

### Common Issues

#### 1. ACL Permission Errors

**Error:** `lacks permission 'acl:read'`

**Solution:** Ensure you're using the root bootstrap token, not the partition admin token:

```bash
# Wrong - using partition token
oc create secret generic consul-bootstrap-token \
  --from-literal=token="$(cat openshift-rosa-admin.token)" \
  -n consul

# Correct - using root bootstrap token
oc create secret generic consul-bootstrap-token \
  --from-literal=token="ConsulR0cks" \
  -n consul
```

#### 2. Pods Not Becoming Ready

**Symptoms:** Pods stuck at 0/1 or 1/2 Ready

**Debug:**

```bash
# Check pod logs
oc logs -n consul deployment/consul-connect-inject

# Check events
oc get events -n consul --sort-by='.lastTimestamp'

# Describe pod
oc describe pod -n consul <pod-name>
```

**Common causes:**
- Missing or incorrect secrets
- Cannot reach external Consul servers
- TLS certificate mismatch
- Image pull failures

#### 3. Connection to Consul Servers Fails

**Error:** `dial tcp 34.88.172.144:8501: i/o timeout`

**Solutions:**

```bash
# Test connectivity from OpenShift
oc run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v --max-time 10 https://34.88.172.144:8501/v1/status/leader

# Check firewall rules on GCP
gcloud compute firewall-rules list --filter="name~consul"

# Verify Consul servers are listening
ssh debian@34.88.172.144 "sudo netstat -tlnp | grep 8501"
```

#### 4. Services Not Registering

**Symptoms:** Applications deployed but not visible in Consul

**Debug:**

```bash
# Check if namespace is labeled for injection
oc get namespace development --show-labels

# Check sidecar injection
oc get pod -n development <pod-name> -o jsonpath='{.spec.containers[*].name}'
# Should show both application container and consul-dataplane

# Check connect-inject logs
oc logs -n consul deployment/consul-connect-inject -f
```

#### 5. xDS Stream Limit Errors

**Error:** `this server has too many xDS streams open`

**Solutions:**

1. **Increase Consul server limits** (on GCP VMs):

```bash
# SSH to Consul server
ssh debian@34.88.172.144

# Edit Consul config
sudo vi /etc/consul.d/consul.hcl

# Add limits section:
limits {
  http_max_conns_per_client = -1  # Unlimited (or set a high value)
}

# Restart Consul
sudo systemctl restart consul
```

2. **Configure VPC peering** so dataplanes can reach internal IPs and reduce connection churn.

### Verification Commands

```bash
# Check Consul partition
consul partition list

# Check services in partition
consul catalog services -partition openshift-rosa

# Check specific service
consul catalog nodes -service <service-name> -partition openshift-rosa

# Check ACL token
consul acl token read -id <token-id>

# Check service mesh connectivity
consul intention list -partition openshift-rosa

# Port-forward to Envoy admin
oc port-forward -n development pod/<pod-name> 19000:19000
curl http://localhost:19000/clusters
```

## Upgrading

To upgrade Consul:

```bash
# Update values.yaml with new image version
vi values.yaml

# Upgrade using Helm
helm upgrade consul hashicorp/consul \
  --namespace consul \
  --values values.yaml \
  --wait

# Monitor rollout
oc rollout status deployment/consul-connect-inject -n consul
```

## Uninstalling

To remove Consul from OpenShift:

```bash
# Uninstall Helm release
helm uninstall consul -n consul

# Delete namespace (optional - removes all resources)
oc delete namespace consul

# Clean up partition on Consul servers (if needed)
consul partition delete -name openshift-rosa
```

## File Structure

```
clusters/openshift-rosa/
├── README.md                    # This documentation
├── helm/
│   └── values.yaml             # Helm values for admin partition
└── certificates/               # Store certificates here (gitignored)
    ├── consul-agent-ca.pem
    └── consul-agent-ca-key.pem
```

## Success Criteria

- ✅ **Admin partition created** in Consul and visible in UI
- ✅ **OpenShift pods running** (connect-inject, controller, mesh-gateway)
- ✅ **Services register** in `openshift-rosa` partition when deployed
- ✅ **Sidecar injection works** for labeled namespaces
- ✅ **Service mesh communication** works between services
- ✅ **Cross-partition communication** works (if configured with mesh gateways)

## Next Steps

1. **Deploy demo applications** to test the service mesh
2. **Configure service intentions** for service-to-service communication
3. **Set up mesh gateways** for cross-partition communication
4. **Configure service-defaults** for protocol-specific settings (gRPC, HTTP, TCP)
5. **Monitor with metrics** using Prometheus/Grafana

## Additional Resources

- [Consul Admin Partitions Documentation](https://developer.hashicorp.com/consul/docs/enterprise/admin-partitions)
- [Consul on Kubernetes](https://developer.hashicorp.com/consul/docs/k8s)
- [Consul Service Mesh on OpenShift](https://developer.hashicorp.com/consul/docs/k8s/deployment-configurations/openshift)
- [Main Project README](../../README.md)

# Key Differences: Server vs Admin Partition Configuration

This document highlights the key differences between deploying Consul as **servers** (your original `values_rosa.yaml`) versus deploying as an **admin partition** (the new configuration).

## Side-by-Side Comparison

| Aspect | Server Mode | Admin Partition Mode |
|--------|-------------|---------------------|
| **Purpose** | Run Consul servers | Connect to external servers |
| **Server Pods** | `server.enabled: true` | `server.enabled: false` |
| **Client Pods** | `client.enabled: false` | `client.enabled: false` |
| **Admin Partitions** | Not configured | `adminPartitions.enabled: true` |
| **External Servers** | Not configured | `externalServers.enabled: true` |
| **Storage** | Requires PVC (`storageClass`, `storage`) | No storage needed |
| **Replicas** | 3 server replicas | 0 servers (uses external) |
| **Bootstrap Token** | Auto-generated | Must provide from external cluster |
| **CA Certificates** | Auto-generated | Must copy from external servers |
| **Gossip Encryption** | `autoGenerate: true` | Uses external cluster's gossip key |

## Configuration Changes

### 1. Global Section

**Server Mode (Original):**
```yaml
global:
  name: consul
  image: "hashicorp/consul-enterprise:1.22.0-rc1-ent-ubi"
  gossipEncryption:
    autoGenerate: true  # Generates new gossip key
  tls:
    enabled: true  # Generates own certificates
  acls:
    manageSystemACLs: true  # Creates new ACL system
```

**Admin Partition Mode (New):**
```yaml
global:
  name: consul
  datacenter: gcp-dc1  # Must match external cluster
  image: "hashicorp/consul-enterprise:1.22.0-rc1-ent-ubi"

  adminPartitions:
    enabled: true
    name: "openshift-rosa"  # Partition name

  tls:
    enabled: true
    enableAutoEncrypt: true
    caCert:
      secretName: consul-ca-cert  # From external servers
      secretKey: tls.crt
    caKey:
      secretName: consul-ca-key  # From external servers
      secretKey: tls.key

  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: consul-bootstrap-token  # Root token from external
      secretKey: token
```

### 2. Server Section

**Server Mode (Original):**
```yaml
server:
  enabled: true
  replicas: 3
  storageClass: gp3
  storage: 50Gi
  resources:
    requests:
      memory: "2Gi"
      cpu: "100m"
```

**Admin Partition Mode (New):**
```yaml
server:
  enabled: false  # No servers - connect to external
```

### 3. External Servers Section

**Server Mode (Original):**
```yaml
# Not present - this cluster IS the servers
```

**Admin Partition Mode (New):**
```yaml
externalServers:
  enabled: true
  hosts:
    - "34.88.172.144"  # External server IPs
    - "34.88.43.17"
    - "34.88.45.49"
  httpsPort: 8501
  grpcPort: 8502
  tlsServerName: server.gcp-dc1.consul
  k8sAuthMethodHost: https://kubernetes.default.svc
```

### 4. Secrets Required

**Server Mode (Original):**
```bash
# Only need:
oc create secret generic consul-ent-license --from-literal=key="<license>"
oc create secret generic 18338488-openshift-secret-pull-secret ...
```

**Admin Partition Mode (New):**
```bash
# Need all of these:
oc create secret generic consul-ent-license --from-literal=key="<license>"
oc create secret generic consul-bootstrap-token --from-literal=token="<root-token>"
oc create secret generic consul-ca-cert --from-file=tls.crt=consul-agent-ca.pem
oc create secret generic consul-ca-key --from-file=tls.key=consul-agent-ca-key.pem
oc create secret generic 18338488-openshift-secret-pull-secret ...
```

## Migration Path

If you want to migrate from server mode to admin partition mode:

### Step 1: Backup Current Configuration
```bash
# Export services and config entries
consul catalog services > services-backup.txt
consul config list -kind service-defaults > service-defaults-backup.txt
consul config list -kind service-intentions > intentions-backup.txt
```

### Step 2: Create Admin Partition on External Servers
```bash
# On your GCP Consul servers
export CONSUL_HTTP_ADDR="http://34.88.172.144:8500"
export CONSUL_HTTP_TOKEN="ConsulR0cks"

consul partition create -name "openshift-rosa" \
  -description "Migrated from standalone cluster"
```

### Step 3: Uninstall Old Configuration
```bash
# In OpenShift
helm uninstall consul -n consul
oc delete namespace consul
```

### Step 4: Deploy New Configuration
```bash
# Follow the quickstart guide
./quickstart.sh
```

### Step 5: Restore Services
Re-deploy your applications - they will automatically register in the new partition.

## Benefits of Admin Partition Mode

1. **Centralized Management**: Single Consul UI for all clusters
2. **Shared ACL System**: Consistent policies across partitions
3. **Cross-Partition Communication**: Mesh gateways enable service mesh across clusters
4. **Reduced Resource Usage**: No need for server pods in each cluster
5. **Simplified Operations**: One place to manage Consul configuration
6. **Better Multi-Tenancy**: Complete isolation between teams/environments

## Use Cases

### Use Server Mode When:
- ✅ Running a standalone Consul cluster
- ✅ Complete isolation from other clusters is required
- ✅ Different Consul versions per cluster
- ✅ Air-gapped environments

### Use Admin Partition Mode When:
- ✅ Part of a larger multi-cluster architecture
- ✅ Centralized management is desired
- ✅ Cross-cluster service mesh needed
- ✅ Resource optimization is important
- ✅ Consistent ACL policies across clusters

## Common Pitfalls to Avoid

### 1. Wrong Bootstrap Token
❌ **Wrong:** Using partition admin token for `consul-bootstrap-token` secret
✅ **Correct:** Using root bootstrap token from Consul servers

### 2. Certificate Mismatch
❌ **Wrong:** Using self-signed certificates that don't match servers
✅ **Correct:** Copying CA certificates directly from Consul servers

### 3. Unreachable External IPs
❌ **Wrong:** Using internal IPs (10.x.x.x) without VPC peering
✅ **Correct:** Using external IPs or configuring VPC peering first

### 4. Missing Datacenter Name
❌ **Wrong:** Not specifying datacenter or using wrong name
✅ **Correct:** Using exact datacenter name from external servers (`gcp-dc1`)

### 5. Wrong TLS Server Name
❌ **Wrong:** `tlsServerName: consul.service.consul`
✅ **Correct:** `tlsServerName: server.gcp-dc1.consul`

## Verification

After deploying in admin partition mode, verify with:

```bash
# Check partition exists
consul partition list

# Check services registered in partition
consul catalog services -partition openshift-rosa

# Check connectivity from OpenShift pod
oc run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v https://34.88.172.144:8501/v1/status/leader

# Check Consul UI
# Navigate to: http://34.88.172.144:8500/ui/gcp-dc1/partitions/openshift-rosa
```

## Further Reading

- [Consul Admin Partitions Documentation](https://developer.hashicorp.com/consul/docs/enterprise/admin-partitions)
- [External Servers Configuration](https://developer.hashicorp.com/consul/docs/k8s/installation/deployment-configurations/servers-outside-kubernetes)
- [Multi-Cluster Federation](https://developer.hashicorp.com/consul/docs/k8s/deployment-configurations/multi-cluster)

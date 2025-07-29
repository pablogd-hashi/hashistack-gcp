# Consul Cluster Peering

## Overview

Consul cluster peering enables secure service mesh communication between separate Consul datacenters without requiring WAN federation. This configuration establishes peering between DC1 and DC2 clusters, allowing services in one datacenter to discover and communicate with services in another datacenter through encrypted mesh gateways.

### What Cluster Peering Provides

**Cross-Datacenter Service Mesh:**
- Secure service-to-service communication across datacenters
- Service discovery across peered clusters
- Zero-trust networking with mutual TLS
- Traffic management and load balancing

**Operational Benefits:**
- Independent cluster lifecycle management
- Fault isolation between datacenters
- Selective service sharing between clusters
- Simplified network architecture compared to WAN federation

**Enterprise Features:**
- Advanced traffic policies and routing
- Sameness groups for automated failover
- Comprehensive audit logging and monitoring
- Integration with service mesh observability

This guide provides the step-by-step process to establish cluster peering between DC1 and DC2 after both clusters are deployed.

## Prerequisites

- Both DC1 and DC2 clusters deployed and running
- Consul Enterprise with ACLs enabled
- Nomad Enterprise running on both clusters
- Valid Consul and Nomad tokens available

## How to run in tasks

### Phase 1: Configure Nomad-Consul Integration

Execute on **both DC1 and DC2**:

```bash
# Configure Nomad workload identity
nomad setup consul -y
```

### Phase 2: Create Nomad Namespace (DC1 Only)

Execute on **DC1 only**:

```bash
# Create namespace for API Gateway
nomad namespace apply \
  -description "namespace for Consul API Gateways" \
  ingress

# Create ACL binding rule for API Gateway
consul acl binding-rule create \
    -method 'nomad-workloads' \
    -description 'Nomad API gateway' \
    -bind-type 'templated-policy' \
    -bind-name 'builtin/api-gateway' \
    -bind-vars 'Name=${value.nomad_job_id}' \
    -selector '"nomad_service" not in value and value.nomad_namespace==ingress'
```

### Phase 3: Configure Mesh Gateway ACLs

Execute on **both DC1 and DC2**:

```bash
# Create ACL policy for Mesh Gateways
consul acl policy create -name mesh-gateway \
  -description "Policy for the Mesh Gateways" \
  -rules @mesh-acl.hcl

# Create ACL role for mesh gateways
consul acl role create -name mesh-gateway-role \
  -description "A role for the MGW policies" \
  -policy-name mesh-gateway

# Create binding rule for mesh gateway workloads
consul acl binding-rule create \
  -method nomad-workloads \
  -bind-type role \
  -bind-name mesh-gateway-role \
  -selector 'value.nomad_service=="mesh-gateway"'
```

### Phase 4: Deploy Mesh Gateways

Execute on **both DC1 and DC2**:

```bash
# Deploy mesh gateway for cross-datacenter communication
nomad run -var datacenter=gcp-dc1 mesh-gateway.hcl  # On DC1
nomad run -var datacenter=gcp-dc2 mesh-gateway.hcl  # On DC2
```

### Phase 5: Configure Service Mesh

Execute on **both DC1 and DC2**:

```bash
# Configure proxy defaults
consul config write configs/proxy-defaults.hcl

# Configure mesh connectivity
consul config write configs/mesh.hcl
```

### Phase 5: Deploy Backend Services (DC2 Only)

Execute on **DC2 only**:

```bash
# Deploy backend services
nomad run -var datacenter=gcp-dc2 -var replicas_public=2 -var replicas_private=2 ../../nomad-apps/demo-fake-service/backend.nomad.hcl
```

### Phase 6: Deploy Frontend Service (DC1 Only)

Execute on **DC1 only**:

```bash
# Deploy frontend service
nomad run -var datacenter=gcp-dc1 ../../nomad-apps/demo-fake-service/frontend.nomad.hcl
```

### Phase 7: Establish Cluster Peering

Execute on **DC1** (create peering connection):

```bash
# Generate peering token
consul peering generate-token -name gcp-dc2-default

# Copy the token output for use in DC2
```

Execute on **DC2** (accept peering):

```bash
# Establish peering using token from DC1
consul peering establish -name gcp-dc1-default -peering-token "TOKEN_FROM_DC1"
```

### Phase 8: Configure Service Exports

Execute on **DC2** (export services to DC1):

```bash
# Export backend services to DC1
consul config write default-exported.hcl
```

### Phase 9: Configure Service Intentions

Execute on **DC1**:

```bash
# Allow frontend to access backend services
consul config write configs/intentions/front-intentions.hcl
consul config write configs/intentions/private-api-intentions.hcl
consul config write configs/intentions/public-api-intentions.hcl
```

Execute on **DC2**:

```bash
# Configure backend service intentions
consul config write configs/intentions/private-api-intentions.hcl
consul config write configs/intentions/public-api-intentions.hcl
```

### Phase 10: Deploy API Gateway (DC1 Only)

Execute on **DC1 only**:

```bash
# Deploy API Gateway
nomad run ../../nomad-apps/api-gw.nomad/api-gw.nomad.hcl

# Configure API Gateway listener
consul config write configs/api-gateway/listener.hcl

# Configure HTTP routes
consul config write configs/api-gateway/httproute.hcl

# Enable API Gateway to frontend intentions
consul config write configs/intentions/front-intentions.hcl
```

### Phase 11: Configure Service Defaults (Optional)

Execute on **both DC1 and DC2** if needed:

```bash
# Configure service defaults for better traffic management
consul config write configs/servicedefaults/service-defaults-frontend.hcl
consul config write configs/servicedefaults/service-defaults-private-api.hcl
consul config write configs/servicedefaults/service-defaults-public-api.hcl
```

### Phase 12: Configure Failover (Choose One Option)

**Option A: Service Resolvers**

Execute on **DC1**:
```bash
# Configure service resolver for failover
consul config write public-api-resolver.hcl
```

**Option B: Sameness Groups (Recommended)**

Execute on **DC1**:
```bash
# Configure sameness groups for DC1
consul config write configs/sameness-groups/sg-dc1.hcl
consul config write configs/sameness-groups/default-exported-sg.hcl
consul config write configs/sameness-groups/public-api-intentions-sg.hcl
```

Execute on **DC2**:
```bash
# Configure sameness groups for DC2
consul config write configs/sameness-groups/sg-dc2.hcl
```

## Verification

### Check Peering Status

```bash
# On both clusters
consul peering list

# Check mesh gateway status
nomad job status mesh-gateway

# Check service connectivity
curl http://[API_GATEWAY_LB_IP]:8081
```

### Check Service Discovery

```bash
# On DC1 - should see DC2 services
consul catalog services -peer gcp-dc2-default

# On DC2 - should see DC1 services (if any exported)
consul catalog services -peer gcp-dc1-default
```

## Troubleshooting

### Common Issues

1. **Mesh gateway not connecting**: Check external IP configuration in mesh-gateway.hcl
2. **Services not discoverable**: Verify exported-services configuration
3. **API Gateway not accessible**: Check load balancer configuration and port forwarding
4. **Intentions blocking traffic**: Review and update service intentions

### Debug Commands

```bash
# Check mesh gateway logs
nomad alloc logs [MESH_GATEWAY_ALLOC_ID]

# Check peering connection health
consul peering read gcp-dc2-default

# Check service mesh connectivity
consul connect proxy-config [SERVICE_NAME]
```

## Architecture Flow

1. **Mesh Gateways**: Enable cross-datacenter communication
2. **Service Mesh**: Consul Connect provides service-to-service encryption
3. **Cluster Peering**: Establishes trust relationship between datacenters
4. **Service Export**: Makes DC2 services discoverable in DC1
5. **Service Intentions**: Control access between services across clusters
6. **API Gateway**: Provides external access to the distributed application

## Load Balancer Access

If DNS is configured, services are accessible via:
- **Frontend (via API Gateway)**: `http://api-gateway-dc1.your-domain:8081`
- **Direct access**: Use load balancer IP from terraform outputs

## Notes

- Ensure firewall rules allow traffic on port 8443 (mesh gateway)
- API Gateway requires port 8081 to be open on the load balancer
- Cross-datacenter communication requires external IP connectivity
- Service intentions are deny-by-default with ACLs enabled
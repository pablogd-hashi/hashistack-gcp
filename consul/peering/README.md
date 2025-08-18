# Consul Cluster Peering

Establish secure service mesh communication between separate Consul datacenters without WAN federation complexity.

**📖 [Back to Main README](../../README.md)**

## Why Cluster Peering?

Cluster peering provides a modern alternative to WAN federation for connecting multiple Consul datacenters:

- **Secure cross-datacenter service mesh** with mutual TLS encryption
- **Independent cluster management** with fault isolation between DCs
- **Selective service sharing** between clusters without full federation
- **Simplified network architecture** compared to traditional WAN federation
- **Zero-trust networking** with encrypted mesh gateways

This guide shows how to establish peering between DC1 and DC2 clusters for distributed application deployment.

## Architecture Overview

```
DC1 Cluster                    DC2 Cluster
┌─────────────────┐           ┌─────────────────┐
│ Frontend App    │           │ Backend APIs    │
│ API Gateway     │◄─────────►│ Private APIs    │
│ Mesh Gateway    │   Peering │ Mesh Gateway    │
└─────────────────┘           └─────────────────┘
        │                             │
        └─────── Service Mesh ────────┘
```

**Components:**
- **Mesh Gateways**: Enable encrypted cross-datacenter communication
- **Cluster Peering**: Trust relationship between separate Consul clusters
- **Service Export**: Makes DC2 services discoverable in DC1
- **Service Intentions**: Control access between services across clusters
- **API Gateway**: External access point for distributed applications

## Prerequisites

### Required Infrastructure
- **Both DC1 and DC2 clusters** deployed and running
- **Consul Enterprise** with ACLs enabled on both clusters
- **Nomad Enterprise** running on both clusters
- **Environment variables** configured for both clusters

### Required Setup
- **Nomad-Consul integration** completed on both clusters
- **Valid tokens** available for both Consul and Nomad
- **Network connectivity** between datacenters on port 8443

## Quick Start

### 1. Set Up Environment Variables
```bash
# Get environment variables for both clusters
task eval-both

# Copy and paste the output to configure:
# - CONSUL_HTTP_ADDR for both DC1 and DC2
# - CONSUL_HTTP_TOKEN for both clusters
# - NOMAD_ADDR and NOMAD_TOKEN for both clusters
```

### 2. Deploy Complete Peering Setup
```bash
# Deploy all peering components automatically
task -t consul/peering/Taskfile.yml consul:deploy-all

# This configures:
# - Mesh gateway ACLs on both clusters
# - Mesh gateways for cross-DC communication
# - Cluster peering connection
# - Service exports from DC2 to DC1
```

### 3. Deploy Demo Applications (Optional)
```bash
# Deploy backend services to DC2
task -t consul/peering/Taskfile.yml consul:deploy-demo-apps

# Deploy frontend service to DC1 with cross-cluster communication
# Services in DC1 can now discover and communicate with DC2 services
```

### 4. Verify Peering
```bash
# Check peering status
task -t consul/peering/Taskfile.yml consul:verify-peering

# Test cross-cluster service discovery
consul catalog services -peer gcp-dc2-default
```

## Deployment Workflows

### Automated Setup (Recommended)
```bash
# Complete end-to-end peering setup
task -t consul/peering/Taskfile.yml consul:deploy-all

# Deploy demo applications
task -t consul/peering/Taskfile.yml consul:deploy-demo-apps

# Verify everything is working
task -t consul/peering/Taskfile.yml consul:verify-peering
```

### Manual Step-by-Step Setup

#### Phase 1: Configure Mesh Gateway ACLs
```bash
# Run on both DC1 and DC2
consul acl policy create -name mesh-gateway \
  -description "Policy for the Mesh Gateways" \
  -rules @mesh-acl.hcl

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

#### Phase 2: Deploy Mesh Gateways
```bash
# Deploy mesh gateway to DC1
export NOMAD_ADDR="http://<dc1-server-ip>:4646"
export NOMAD_TOKEN="<dc1-nomad-token>"
nomad run -var datacenter=gcp-dc1 mesh-gateway.hcl

# Deploy mesh gateway to DC2
export NOMAD_ADDR="http://<dc2-server-ip>:4646"
export NOMAD_TOKEN="<dc2-nomad-token>"
nomad run -var datacenter=gcp-dc2 mesh-gateway.hcl

# Verify deployments
nomad job status mesh-gateway
```

#### Phase 3: Establish Cluster Peering
```bash
# On DC1: Generate peering token
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<dc1-consul-token>"
consul peering generate-token -name gcp-dc2-default

# Copy the token output

# On DC2: Establish peering using the token
export CONSUL_HTTP_ADDR="http://<dc2-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<dc2-consul-token>"
consul peering establish -name gcp-dc1-default -peering-token "TOKEN_FROM_DC1"

# Verify peering
consul peering list
```

#### Phase 4: Configure Service Exports
```bash
# On DC2: Export services to make them discoverable in DC1
consul config write default-exported.hcl

# Verify exported services
consul catalog services -peer gcp-dc2-default
```

## Available Tasks

Use the peering Taskfile for automated operations:

### Setup Tasks
- `task -t consul/peering/Taskfile.yml consul:env-setup` - Set environment variables
- `task -t consul/peering/Taskfile.yml consul:setup-peering` - Configure mesh gateways and ACLs
- `task -t consul/peering/Taskfile.yml consul:establish-peering` - Create peering connection
- `task -t consul/peering/Taskfile.yml consul:verify-peering` - Verify peering status

### Application Tasks
- `task -t consul/peering/Taskfile.yml consul:deploy-demo-apps` - Deploy demo applications
- `task -t consul/peering/Taskfile.yml consul:configure-sameness-groups` - Set up automated failover

### Complete Setup
- `task -t consul/peering/Taskfile.yml consul:deploy-all` - Full automated peering setup

### Cleanup
- `task -t consul/peering/Taskfile.yml consul:cleanup-peering` - Remove peering configuration

## Demo Applications

### Cross-Cluster Application Architecture
```
DC1 (Frontend)              DC2 (Backend)
┌─────────────────┐         ┌─────────────────┐
│ Frontend App    │────────►│ Public API      │
│ API Gateway     │         │ Private API     │
└─────────────────┘         └─────────────────┘
```

### Deploy Demo Applications
```bash
# Deploy backend services to DC2
export NOMAD_ADDR="http://<dc2-server-ip>:4646"
nomad run -var datacenter=gcp-dc2 -var replicas_public=2 -var replicas_private=2 \
  ../../nomad-apps/demo-fake-service/backend.nomad.hcl

# Deploy frontend to DC1 (communicates with DC2 backends)
export NOMAD_ADDR="http://<dc1-server-ip>:4646"
nomad run -var datacenter=gcp-dc1 \
  ../../nomad-apps/demo-fake-service/frontend.nomad.hcl

# Deploy API Gateway for external access
nomad run ../../nomad-apps/api-gw.nomad/api-gw.nomad.hcl
```

### Configure Service Intentions
```bash
# Allow frontend (DC1) to access backend services (DC2)
consul config write configs/intentions/front-intentions.hcl
consul config write configs/intentions/public-api-intentions.hcl
consul config write configs/intentions/private-api-intentions.hcl
```

## Advanced Features

### Sameness Groups (Automated Failover)
Configure automatic failover between datacenters:

```bash
# On DC1: Configure sameness group
consul config write configs/sameness-groups/sg-dc1.hcl

# On DC2: Configure sameness group
consul config write configs/sameness-groups/sg-dc2.hcl

# Services automatically failover between clusters
```

### Service Mesh Configuration
```bash
# Configure proxy defaults for both clusters
consul config write configs/proxy-defaults.hcl

# Configure mesh-wide settings
consul config write configs/mesh.hcl
```

## Verification Commands

### Check Peering Status
```bash
# List all peering connections
consul peering list

# Check detailed peering information
consul peering read gcp-dc2-default

# Verify mesh gateway status
nomad job status mesh-gateway
nomad alloc status <mesh-gateway-alloc-id>
```

### Test Service Discovery
```bash
# From DC1: List services available from DC2
consul catalog services -peer gcp-dc2-default

# From DC2: List services available from DC1
consul catalog services -peer gcp-dc1-default

# Check service health across clusters
consul health service public-api -peer gcp-dc2-default
```

### Test Application Connectivity
```bash
# Get API Gateway endpoint
API_GW_IP=$(terraform output -json | jq -r .api_gateway_ip.value)

# Test frontend access (should show cross-cluster communication)
curl http://$API_GW_IP:8081

# Test direct service access
curl http://<dc1-client-ip>:9090/health
```

## Troubleshooting

### Common Issues

**Mesh Gateway Not Connecting:**
- Check external IP configuration in mesh-gateway.hcl
- Verify firewall rules allow traffic on port 8443
- Ensure mesh gateways are running on both clusters

**Peering Connection Fails with Internal IP Error:**
- Error: `dial tcp 10.x.x.x:8502: i/o timeout` means Consul is using internal IPs
- **Root cause**: Consul servers not advertising WAN addresses properly
- **Solution**: Redeploy clusters with updated Consul configuration
- **Fix applied**: Added `advertise_addr_wan = "$PUBLIC_IP"` to server templates

**Services Not Discoverable:**
- Verify exported-services configuration on DC2
- Check that services are properly registered in Consul
- Confirm peering connection is active with `consul peering list`

**Cross-Cluster Communication Fails:**
- Review service intentions for required allow rules
- Check service mesh proxy configuration
- Verify network connectivity between datacenters

**API Gateway Not Accessible:**
- Check load balancer configuration and port 8081
- Verify API Gateway job is running successfully
- Review HTTP route and listener configuration

### Debug Commands
```bash
# Check mesh gateway logs
nomad alloc logs <mesh-gateway-alloc-id>

# Check service mesh connectivity
consul connect proxy-config <service-name>

# Verify service intentions
consul intention check <source-service> <destination-service>

# Check exported services
consul config read -kind exported-services -name default

# Test service resolution
dig @<consul-server> <service-name>.service.consul
```

### Getting Help

1. **Check peering status**: Use `consul peering read` to verify connection health
2. **Review logs**: Examine mesh gateway and application logs for connection issues
3. **Verify configuration**: Ensure exported services and intentions are properly configured
4. **Test incrementally**: Deploy one service at a time to isolate connectivity issues

## Security Considerations

- **Mutual TLS**: All cross-cluster communication is encrypted
- **Service Intentions**: Deny-by-default with explicit allow rules required
- **ACL Policies**: Mesh gateways run with minimal required permissions
- **Network Isolation**: Only necessary ports (8443) are opened between clusters

## Access Points

After deployment, access your distributed application:

**Via API Gateway:**
- **Frontend**: `http://<api-gateway-lb-ip>:8081`
- **Health Check**: `http://<api-gateway-lb-ip>:8081/health`

**Direct Access:**
- **DC1 Services**: `http://<dc1-client-ip>:9090`
- **DC2 Services**: `http://<dc2-client-ip>:9090`

**Consul UIs:**
- **DC1 Consul**: `http://<dc1-server-ip>:8500`
- **DC2 Consul**: `http://<dc2-server-ip>:8500`

Use `task show-dc1-info` and `task show-dc2-info` to get current IP addresses and access details.

## Success Criteria

- ✅ **Mesh gateways deployed** and running on both clusters
- ✅ **Cluster peering established** between DC1 and DC2
- ✅ **Service exports configured** making DC2 services discoverable in DC1
- ✅ **Cross-cluster service discovery** working via peered connection
- ✅ **Demo applications deployed** with frontend in DC1, backend in DC2
- ✅ **Service mesh communication** working across datacenters
- ✅ **API Gateway accessible** providing external access to distributed application
- ✅ **Service intentions configured** for secure cross-cluster communication
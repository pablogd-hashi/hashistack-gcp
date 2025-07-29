# Service Intentions Guide

## Overview

Service intentions control which services can communicate in the Consul service mesh. In Consul Enterprise, intentions are required for service-to-service communication. This guide covers Consul service intentions for securing service mesh communication.

## Prerequisites

1. Consul Enterprise cluster running with ACLs enabled
2. Services deployed with Consul Connect sidecar proxies
3. Admin partitions configured (if using multiple partitions)
4. Valid Consul admin token with intention management permissions

## How to run in tasks

### Step 1: Configure Consul Environment

Set up your Consul connection details:

```bash
# Set Consul environment variables
export CONSUL_HTTP_ADDR="http://your-consul-server:8500"
export CONSUL_HTTP_TOKEN="your-consul-admin-token"

# Verify connectivity
consul members
```

### Step 2: Verify Service Registration

Check that your services are properly registered:

```bash
# List services in your partition and namespace
consul catalog services -partition k8s-southwest1 -namespace development

# Verify specific service details
consul catalog service frontend -partition k8s-southwest1 -namespace development
```

## Creating Intentions

### Step 3: Basic Intention Commands

```bash
# Allow communication between services
consul intention create -allow source-service destination-service

# Deny communication
consul intention create -deny source-service destination-service

# List all intentions
consul intention list
```

### Step 4: Partition-Specific Intentions

For services in admin partitions (like k8s-southwest1):

```bash
# Allow frontend to call backend services
consul intention create -allow \
  frontend.development.k8s-southwest1 \
  productcatalogservice.development.k8s-southwest1

consul intention create -allow \
  frontend.development.k8s-southwest1 \
  cartservice.development.k8s-southwest1

consul intention create -allow \
  frontend.development.k8s-southwest1 \
  currencyservice.development.k8s-southwest1

# Allow cart service to access Redis
consul intention create -allow \
  cartservice.development.k8s-southwest1 \
  redis-cart.development.k8s-southwest1
```

## Boutique Application Intentions

### Required Intentions for Boutique Demo

```bash
# Frontend to backend services
consul intention create -allow frontend.development.k8s-southwest1 currencyservice.development.k8s-southwest1
consul intention create -allow frontend.development.k8s-southwest1 productcatalogservice.development.k8s-southwest1
consul intention create -allow frontend.development.k8s-southwest1 cartservice.development.k8s-southwest1

# Cart service to Redis
consul intention create -allow cartservice.development.k8s-southwest1 redis-cart.development.k8s-southwest1
```

### Verify Intentions

```bash
# Check specific intention
consul intention check frontend.development.k8s-southwest1 productcatalogservice.development.k8s-southwest1

# List all intentions for a service
consul intention list -filter 'SourceName == "frontend"'
```

## Intention Syntax

### Service Name Format

For services in admin partitions:
```
service-name.namespace.partition
```

Examples:
- `frontend.development.k8s-southwest1`
- `backend.production.k8s-west1`
- `api.default.default` (default partition and namespace)

### Common Patterns

```bash
# Allow all services in a namespace to communicate
consul intention create -allow "*.development.k8s-southwest1" "*.development.k8s-southwest1"

# Allow specific service to call any service
consul intention create -allow "frontend.development.k8s-southwest1" "*.development.k8s-southwest1"

# Cross-partition communication
consul intention create -allow "frontend.development.k8s-west1" "api.production.k8s-southwest1"
```

## Troubleshooting

### Issue: Connection Refused Between Services

1. Check if intention exists:
```bash
consul intention check source-service destination-service
```

2. Create missing intention:
```bash
consul intention create -allow source-service destination-service
```

### Issue: Wrong Partition/Namespace

1. Verify service registration:
```bash
consul catalog services -partition k8s-southwest1 -namespace development
```

2. Update intention with correct names:
```bash
consul intention create -allow frontend.development.k8s-southwest1 backend.development.k8s-southwest1
```

### Issue: Intention Not Taking Effect

1. Check intention is active:
```bash
consul intention list
```

2. Restart affected pods:
```bash
kubectl rollout restart deployment/frontend -n development
```

## Best Practices

1. **Start Restrictive**: Deny by default, allow specific communications
2. **Use Namespaces**: Organize intentions by environment (dev/test/prod)
3. **Document Intentions**: Keep track of service dependencies
4. **Test Changes**: Verify service communication after creating intentions

## Success Criteria

- Services can communicate when intentions allow
- Services are blocked when no intention exists
- Cross-partition communication works with proper intentions
- Applications function correctly with service mesh security enabled
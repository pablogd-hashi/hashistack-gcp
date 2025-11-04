#!/bin/bash
# Quick start script for deploying Consul to OpenShift as an admin partition
# This script guides you through the complete setup process

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OpenShift ROSA Consul Admin Partition${NC}"
echo -e "${BLUE}Quick Start Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v oc &> /dev/null; then
    echo -e "${RED}✗ oc CLI not found${NC}"
    echo "  Install from: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
    exit 1
fi
echo -e "${GREEN}✓ oc CLI found${NC}"

if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm not found${NC}"
    echo "  Install from: https://helm.sh/docs/intro/install/"
    exit 1
fi
echo -e "${GREEN}✓ helm found${NC}"

if ! command -v consul &> /dev/null; then
    echo -e "${RED}✗ consul CLI not found${NC}"
    echo "  Install from: https://developer.hashicorp.com/consul/downloads"
    exit 1
fi
echo -e "${GREEN}✓ consul CLI found${NC}"

# Check OpenShift connection
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗ Not connected to OpenShift cluster${NC}"
    echo "  Run: oc login <cluster-url>"
    exit 1
fi
echo -e "${GREEN}✓ Connected to OpenShift: $(oc whoami --show-server)${NC}"
echo ""

# Step 1: Update external server IPs
echo -e "${BLUE}Step 1: Update External Server IPs${NC}"
echo "Would you like to automatically fetch and update Consul server IPs?"
read -p "Update external servers? (y/n): " UPDATE_SERVERS

if [[ $UPDATE_SERVERS == "y" ]]; then
    cd helm
    ./update-external-servers.sh
    cd ..
    echo ""
fi

# Step 2: Consul partition setup
echo -e "${BLUE}Step 2: Consul Server Configuration${NC}"
echo "Enter your Consul server details:"
read -p "Consul HTTP address (e.g., http://34.88.172.144:8500): " CONSUL_ADDR
read -s -p "Consul root bootstrap token: " CONSUL_TOKEN
echo ""
export CONSUL_HTTP_ADDR="$CONSUL_ADDR"
export CONSUL_HTTP_TOKEN="$CONSUL_TOKEN"

echo ""
echo "Creating admin partition 'openshift-rosa'..."
if consul partition list | grep -q "openshift-rosa"; then
    echo -e "${YELLOW}⚠ Partition 'openshift-rosa' already exists${NC}"
else
    consul partition create \
      -name "openshift-rosa" \
      -description "Admin partition for OpenShift ROSA cluster"
    echo -e "${GREEN}✓ Partition created${NC}"
fi

echo ""
echo "Creating ACL policy..."
if consul acl policy read -name "openshift-rosa-admin-policy" &> /dev/null; then
    echo -e "${YELLOW}⚠ Policy 'openshift-rosa-admin-policy' already exists${NC}"
else
    consul acl policy create \
      -name "openshift-rosa-admin-policy" \
      -description "Admin policy for openshift-rosa partition" \
      -rules @policies/openshift-rosa-admin-policy.hcl
    echo -e "${GREEN}✓ Policy created${NC}"
fi

echo ""
echo "Creating ACL role..."
if consul acl role read -name "openshift-rosa-admin" &> /dev/null; then
    echo -e "${YELLOW}⚠ Role 'openshift-rosa-admin' already exists${NC}"
else
    consul acl role create \
      -name "openshift-rosa-admin" \
      -description "Admin role for openshift-rosa partition" \
      -policy-name "openshift-rosa-admin-policy"
    echo -e "${GREEN}✓ Role created${NC}"
fi

# Step 3: Obtain certificates
echo ""
echo -e "${BLUE}Step 3: Obtain CA Certificates${NC}"
echo "You need CA certificates from your Consul servers."
read -p "Run certificate retrieval script? (y/n): " GET_CERTS

if [[ $GET_CERTS == "y" ]]; then
    ./get-certificates.sh
fi

# Verify certificates exist
if [ ! -f "certificates/consul-agent-ca.pem" ] || [ ! -f "certificates/consul-agent-ca-key.pem" ]; then
    echo -e "${RED}✗ Certificates not found in certificates/ directory${NC}"
    echo "  Please run: ./get-certificates.sh"
    exit 1
fi
echo -e "${GREEN}✓ Certificates found${NC}"

# Step 4: Create Kubernetes secrets
echo ""
echo -e "${BLUE}Step 4: Create Kubernetes Secrets${NC}"

# Check if consul namespace exists
if ! oc get namespace consul &> /dev/null; then
    echo "Creating consul namespace..."
    oc create namespace consul
    echo -e "${GREEN}✓ Namespace created${NC}"
else
    echo -e "${YELLOW}⚠ Namespace 'consul' already exists${NC}"
fi

echo ""
echo "Creating secrets..."

# License secret
if oc get secret consul-ent-license -n consul &> /dev/null; then
    echo -e "${YELLOW}⚠ Secret 'consul-ent-license' already exists${NC}"
else
    read -p "Path to Consul license file: " LICENSE_FILE
    oc create secret generic consul-ent-license \
      --from-literal=key="$(cat $LICENSE_FILE)" \
      -n consul
    echo -e "${GREEN}✓ License secret created${NC}"
fi

# Bootstrap token secret
if oc get secret consul-bootstrap-token -n consul &> /dev/null; then
    echo -e "${YELLOW}⚠ Secret 'consul-bootstrap-token' already exists${NC}"
else
    oc create secret generic consul-bootstrap-token \
      --from-literal=token="$CONSUL_TOKEN" \
      -n consul
    echo -e "${GREEN}✓ Bootstrap token secret created${NC}"
fi

# CA cert secret
if oc get secret consul-ca-cert -n consul &> /dev/null; then
    echo -e "${YELLOW}⚠ Secret 'consul-ca-cert' already exists${NC}"
else
    oc create secret generic consul-ca-cert \
      --from-file=tls.crt=certificates/consul-agent-ca.pem \
      -n consul
    echo -e "${GREEN}✓ CA cert secret created${NC}"
fi

# CA key secret
if oc get secret consul-ca-key -n consul &> /dev/null; then
    echo -e "${YELLOW}⚠ Secret 'consul-ca-key' already exists${NC}"
else
    oc create secret generic consul-ca-key \
      --from-file=tls.key=certificates/consul-agent-ca-key.pem \
      -n consul
    echo -e "${GREEN}✓ CA key secret created${NC}"
fi

# Step 5: Deploy Consul
echo ""
echo -e "${BLUE}Step 5: Deploy Consul with Helm${NC}"
read -p "Deploy Consul now? (y/n): " DEPLOY

if [[ $DEPLOY == "y" ]]; then
    cd helm

    # Add Helm repo
    echo "Adding HashiCorp Helm repository..."
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update

    # Install
    echo "Installing Consul..."
    helm install consul hashicorp/consul \
      --namespace consul \
      --values values.yaml \
      --wait

    echo -e "${GREEN}✓ Consul deployed${NC}"
    cd ..
fi

# Final steps
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Verify deployment:"
echo "   oc get pods -n consul"
echo ""
echo "2. Check partition registration:"
echo "   consul partition list"
echo "   consul catalog services -partition openshift-rosa"
echo ""
echo "3. Create application namespaces:"
echo "   oc create namespace development"
echo "   oc label namespace development bofa.com/esm=enabled"
echo "   oc label namespace development consul.hashicorp.com/connect-inject=enabled"
echo ""
echo "4. Deploy your applications to test the service mesh!"
echo ""
echo "For detailed documentation, see: README.md"

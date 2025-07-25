#!/bin/bash

# Setup Kubernetes Auth Method for k8s-test Partition
set -e

echo "=== Setting up Kubernetes Auth Method for k8s-test partition ==="

# Set Consul server details (replace with your values)
export CONSUL_HTTP_ADDR="http://<consul-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<your-bootstrap-token>"

echo "Using Consul server: $CONSUL_HTTP_ADDR"

# Get GKE details
echo "Getting GKE cluster details..."

# Get GKE API server endpoint
GKE_ENDPOINT=$(kubectl cluster-info | grep 'control plane' | grep -oE 'https://[^[:space:]]*' | sed 's/\[0m$//')
if [ -z "$GKE_ENDPOINT" ]; then
    echo "ERROR: Could not get GKE API endpoint"
    exit 1
fi

echo "GKE API Endpoint: $GKE_ENDPOINT"

# Get Kubernetes CA certificate
echo "Getting Kubernetes CA certificate..."
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode > /tmp/k8s-ca.pem

if [ ! -f "/tmp/k8s-ca.pem" ]; then
    echo "ERROR: Failed to get Kubernetes CA certificate"
    exit 1
fi

echo "CA certificate saved to /tmp/k8s-ca.pem"

# Check if auth method already exists
echo "Checking if auth method already exists..."
if consul acl auth-method read -name gke-k8s-test -partition k8s-test >/dev/null 2>&1; then
    echo "Auth method already exists, deleting it first..."
    consul acl auth-method delete -name gke-k8s-test -partition k8s-test
fi

# Get a service account JWT for authentication
echo "Creating service account and getting JWT..."
kubectl create serviceaccount consul-auth -n consul --dry-run=client -o yaml | kubectl apply -f -

# Get the JWT token
JWT_TOKEN=$(kubectl create token consul-auth -n consul --duration=8760h)

# Create the Kubernetes auth method
echo "Creating Kubernetes auth method for k8s-test partition..."
consul acl auth-method create \
    -type=kubernetes \
    -name=gke-k8s-test \
    -partition=k8s-test \
    -kubernetes-host="$GKE_ENDPOINT" \
    -kubernetes-ca-cert="$(cat /tmp/k8s-ca.pem)" \
    -kubernetes-service-account-jwt="$JWT_TOKEN"

echo "Auth method created successfully!"

# Create binding rule
echo "Creating binding rule..."
if consul acl binding-rule list -method gke-k8s-test -partition k8s-test | grep -q "consul-"; then
    echo "Binding rule already exists, skipping..."
else
    consul acl binding-rule create \
        -method=gke-k8s-test \
        -partition=k8s-test \
        -bind-type=service \
        -bind-name='consul-${serviceaccount.name}' \
        -selector='serviceaccount.namespace==consul'
    echo "Binding rule created successfully!"
fi

# Create binding rules for default namespace (where our apps will run)
echo "Creating binding rule for default namespace..."
if consul acl binding-rule list -method gke-k8s-test -partition k8s-test | grep -q "default"; then
    echo "Default namespace binding rule already exists, skipping..."
else
    consul acl binding-rule create \
        -method=gke-k8s-test \
        -partition=k8s-test \
        -bind-type=service \
        -bind-name='${serviceaccount.name}' \
        -selector='serviceaccount.namespace==default'
    echo "Default namespace binding rule created successfully!"
fi

# Verify the setup
echo ""
echo "=== Verification ==="
echo "Auth method details:"
consul acl auth-method read -name gke-k8s-test -partition k8s-test

echo ""
echo "Binding rules:"
consul acl binding-rule list -method gke-k8s-test -partition k8s-test

echo ""
echo "=== Setup Complete ==="
echo "You can now deploy applications to GKE with Consul Connect"

# Cleanup
rm -f /tmp/k8s-ca.pem
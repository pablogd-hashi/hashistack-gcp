#!/bin/bash

# Deploy Consul to GKE
# This script deploys Consul Helm chart with the GKE configuration

set -e

echo "Deploying Consul to GKE cluster..."

# Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "Error: kubectl not configured for GKE cluster"
    echo "Run: gcloud container clusters get-credentials gke-cluster-gke --region europe-west1 --project hc-1031dcc8d7c24bfdbb4c08979b0"
    exit 1
fi

# Check if secrets exist
echo "Checking if secrets exist..."
if ! kubectl get namespace consul >/dev/null 2>&1; then
    echo "Error: consul namespace not found. Run setup-secrets-auto.sh first."
    exit 1
fi

if ! kubectl get secret consul-ent-license -n consul >/dev/null 2>&1; then
    echo "Error: consul-ent-license secret not found. Run setup-secrets-auto.sh first."
    exit 1
fi

# Add Helm repo
echo "Adding HashiCorp Helm repository..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Deploy Consul
echo "Deploying Consul..."
helm upgrade --install consul hashicorp/consul \
  --namespace consul \
  --values gke-consul-values.yaml \
  --wait \
  --timeout=10m

echo "Consul deployment completed!"
echo ""
echo "Check deployment status:"
echo "kubectl get pods -n consul"
echo ""
echo "Get mesh gateway LoadBalancer IP:"
echo "kubectl get svc consul-mesh-gateway -n consul"
echo ""
echo "Port forward to access Consul UI:"
echo "kubectl port-forward -n consul svc/consul-ui 8500:80"
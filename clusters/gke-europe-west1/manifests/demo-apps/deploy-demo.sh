#!/bin/bash

# Deploy demo applications to GKE with Consul Connect
set -e

echo "🚀 Deploying demo applications to GKE with Consul Connect..."

# Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl not configured. Run 'task gke-auth' first."
    exit 1
fi

# Check if consul namespace exists
if ! kubectl get namespace consul >/dev/null 2>&1; then
    echo "❌ Consul not deployed. Run 'task gke-deploy-consul' first."
    exit 1
fi

echo "📁 Creating namespaces..."
kubectl apply -f namespace-frontend.yaml
kubectl apply -f namespace-backend.yaml

echo "🚀 Deploying frontend application..."
kubectl apply -f frontend-app.yaml

echo "🚀 Deploying backend application..."
kubectl apply -f backend-app.yaml

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backend -n backend
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n frontend

echo ""
echo "✅ Demo applications deployed successfully!"
echo ""
echo "📊 Status:"
kubectl get pods -n frontend
kubectl get pods -n backend
echo ""
echo "🌐 Services:"
kubectl get svc -n frontend
kubectl get svc -n backend
echo ""
echo "🔗 Frontend LoadBalancer URL:"
FRONTEND_IP=$(kubectl get svc frontend -n frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$FRONTEND_IP" != "pending" ] && [ ! -z "$FRONTEND_IP" ]; then
    echo "   http://$FRONTEND_IP:9090"
else
    echo "   Waiting for LoadBalancer IP... Check with: kubectl get svc frontend -n frontend"
fi
echo ""
echo "🔍 To monitor the services:"
echo "   kubectl logs -n frontend -l app=frontend -f"
echo "   kubectl logs -n backend -l app=backend -f"
echo ""
echo "🏥 To check Consul service registration:"
echo "   Visit Consul UI and filter by k8s-test partition"
echo "   Services should appear in frontend and backend namespaces"
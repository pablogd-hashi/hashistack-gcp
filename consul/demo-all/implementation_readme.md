# Service Intentions Demo - k8s-west1 Admin Partition
## Development to Production Promotion with CTS Automation

**Customer Story**: Demonstrate governance-driven service promotion from development to production with automated infrastructure updates through Consul Terraform Sync (CTS).

## Prerequisites

Before starting this demo, ensure you have completed the following setup:

### 1. Admin Partitions Setup
This demo requires Consul Enterprise admin partitions to be properly configured. Follow the complete setup guide:

**📖 [Admin Partitions Setup Guide](../admin-partitions/README.md)**

Key requirements:
- ✅ DC1 HashiStack cluster deployed with Consul Enterprise
- ✅ GKE clusters configured as admin partition clients
- ✅ k8s-west1 admin partition created and connected
- ✅ Consul Connect service mesh enabled
- ✅ Cross-partition networking configured

### 2. Nomad API Gateway Deployment
The demo uses a Nomad-deployed API Gateway for external access. Deploy it following:

**📖 [API Gateway Deployment Guide](../../nomad-apps/api-gw.nomad/README.md)**

Key requirements:
- ✅ API Gateway running in Nomad cluster (port 8081)
- ✅ HTTP listener configured for external traffic
- ✅ Consul integration enabled for service discovery
- ✅ Gateway registered in Consul service catalog

### 3. Environment Validation

Verify your setup is ready:

```bash
# Check admin partition connectivity
export CONSUL_HTTP_ADDR="http://<dc1-server-ip>:8500"
export CONSUL_HTTP_TOKEN="<bootstrap-token>"
consul partition list

# Check API Gateway is running
nomad job status my-api-gateway
consul catalog services | grep api-gateway

# Check GKE cluster connectivity
kubectl get nodes
kubectl get pods -n consul
```

**Expected Results:**
- Consul should show `k8s-west1` partition in the list
- Nomad should show `my-api-gateway` job as running
- API Gateway should be registered in Consul services
- GKE cluster should have Consul pods running

## Architecture Overview

```
k8s-west1 Admin Partition
├── Development Namespace (testing)
├── Production Namespace (live traffic via API Gateway)
├── API Gateway (port 8081, external access)
├── Mesh Gateway (service exports)
└── CTS (watches intentions → updates load balancer)
```

## Step 1: Setup ACL Policies and Tokens

**What we're doing**: Creating permission boundaries for development and production teams using Consul Enterprise ACL policies. Development gets full access to their namespace, production gets additional permissions for CTS and gateways.

**Expected outcome**: Two distinct ACL tokens that enforce namespace isolation while enabling the required integrations.

```bash
# Development policy
cat > dev-policy.hcl << 'EOF'
partition_prefix "" {
  namespace "development" {
    service_prefix "" {
      policy = "write"
      intentions = "write"
    }
    node_prefix "" {
      policy = "read"
    }
  }
}
EOF

# Production policy with CTS permissions
cat > prod-policy.hcl << 'EOF'
partition_prefix "" {
  namespace "production" {
    service_prefix "" {
      policy = "write"
      intentions = "write"
    }
    node_prefix "" {
      policy = "read"
    }
    key_prefix "cts/" {
      policy = "write"
    }
  }
  namespace "production" {
    service "api-gateway" {
      policy = "write"
    }
    service "mesh-gateway" {
      policy = "write"
    }
  }
}
EOF

# Create policies and tokens
consul acl policy create -name "dev-policy" -rules @dev-policy.hcl
consul acl policy create -name "prod-policy" -rules @prod-policy.hcl

export DEV_TOKEN=$(consul acl token create -policy-name "dev-policy" -format json | jq -r .SecretID)
export PROD_TOKEN=$(consul acl token create -policy-name "prod-policy" -format json | jq -r .SecretID)

echo "Development token: $DEV_TOKEN"
echo "Production token: $PROD_TOKEN"
```

**Verification**: 
- You should see two policy creation confirmations
- Two tokens should be displayed
- Test with: `consul acl token read -id $DEV_TOKEN` should show development policy attached

## Step 2: Deploy Boutique to Development

**What we're doing**: Deploying a simplified version of Google's Online Boutique (frontend + product catalog) to the development namespace with Consul Connect sidecar injection. This creates our baseline application for testing service intentions.

**Expected outcome**: Two pods running in development namespace, both registered in Consul service catalog with Connect sidecars.

```bash
# Create development namespace
kubectl create namespace development

# Deploy boutique services
cat > boutique-dev.yaml << 'EOF'
# Service Accounts
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: productcatalogservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: currencyservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cartservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: checkoutservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: paymentservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: emailservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shippingservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: recommendationservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: adservice
  namespace: development
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: redis-cart
  namespace: development
---
# Frontend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: development
spec:
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/connect-service-upstreams: "productcatalogservice.development.k8s-west1:3550,currencyservice.development.k8s-west1:7000,cartservice.development.k8s-west1:7070,recommendationservice.development.k8s-west1:8080,shippingservice.development.k8s-west1:50051,checkoutservice.development.k8s-west1:5050,adservice.development.k8s-west1:9555"
    spec:
      serviceAccountName: frontend
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/frontend:v0.8.0
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "localhost:3550"
        - name: CURRENCY_SERVICE_ADDR
          value: "localhost:7000"
        - name: CART_SERVICE_ADDR
          value: "localhost:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "localhost:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "localhost:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "localhost:5050"
        - name: AD_SERVICE_ADDR
          value: "localhost:9555"
        - name: SHOPPING_ASSISTANT_SERVICE_ADDR
          value: ""
        - name: CYMBAL_BRANDING
          value: "false"
        - name: FRONTEND_MESSAGE
          value: ""
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
# Product Catalog Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productcatalogservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: productcatalogservice
  template:
    metadata:
      labels:
        app: productcatalogservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: productcatalogservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/productcatalogservice:v0.8.0
        ports:
        - containerPort: 3550
        env:
        - name: PORT
          value: "3550"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: productcatalogservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: productcatalogservice
  ports:
  - name: grpc
    port: 3550
    targetPort: 3550
---
# Currency Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: currencyservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: currencyservice
  template:
    metadata:
      labels:
        app: currencyservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: currencyservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/currencyservice:v0.8.0
        ports:
        - name: grpc
          containerPort: 7000
        env:
        - name: PORT
          value: "7000"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: currencyservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: currencyservice
  ports:
  - name: grpc
    port: 7000
    targetPort: 7000
---
# Cart Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cartservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: cartservice
  template:
    metadata:
      labels:
        app: cartservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/connect-service-upstreams: "redis-cart.development.k8s-west1:6379"
    spec:
      serviceAccountName: cartservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/cartservice:v0.8.0
        ports:
        - containerPort: 7070
        env:
        - name: REDIS_ADDR
          value: "localhost:6379"
        resources:
          requests:
            cpu: 200m
            memory: 64Mi
          limits:
            cpu: 300m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: cartservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: cartservice
  ports:
  - name: grpc
    port: 7070
    targetPort: 7070
---
# Checkout Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkoutservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: checkoutservice
  template:
    metadata:
      labels:
        app: checkoutservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/connect-service-upstreams: "productcatalogservice.development.k8s-west1:3550,shippingservice.development.k8s-west1:50051,paymentservice.development.k8s-west1:50051,emailservice.development.k8s-west1:5000,currencyservice.development.k8s-west1:7000,cartservice.development.k8s-west1:7070"
    spec:
      serviceAccountName: checkoutservice
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/checkoutservice:v0.8.0
        ports:
        - containerPort: 5050
        env:
        - name: PORT
          value: "5050"
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "localhost:3550"
        - name: SHIPPING_SERVICE_ADDR
          value: "localhost:50051"
        - name: PAYMENT_SERVICE_ADDR
          value: "localhost:50051"
        - name: EMAIL_SERVICE_ADDR
          value: "localhost:5000"
        - name: CURRENCY_SERVICE_ADDR
          value: "localhost:7000"
        - name: CART_SERVICE_ADDR
          value: "localhost:7070"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: checkoutservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: checkoutservice
  ports:
  - name: grpc
    port: 5050
    targetPort: 5050
---
# Payment Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: paymentservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/paymentservice:v0.8.0
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: paymentservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: paymentservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
# Email Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: emailservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: emailservice
  template:
    metadata:
      labels:
        app: emailservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: emailservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/emailservice:v0.8.0
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: emailservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: emailservice
  ports:
  - name: grpc
    port: 5000
    targetPort: 8080
---
# Shipping Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shippingservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: shippingservice
  template:
    metadata:
      labels:
        app: shippingservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: shippingservice
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/shippingservice:v0.8.0
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: shippingservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: shippingservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
# Recommendation Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommendationservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: recommendationservice
  template:
    metadata:
      labels:
        app: recommendationservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
        consul.hashicorp.com/connect-service-upstreams: "productcatalogservice.development.k8s-west1:3550"
    spec:
      serviceAccountName: recommendationservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/recommendationservice:v0.8.0
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "localhost:3550"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 220Mi
          limits:
            cpu: 200m
            memory: 450Mi
---
apiVersion: v1
kind: Service
metadata:
  name: recommendationservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: recommendationservice
  ports:
  - name: grpc
    port: 8080
    targetPort: 8080
---
# Ad Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adservice
  namespace: development
spec:
  selector:
    matchLabels:
      app: adservice
  template:
    metadata:
      labels:
        app: adservice
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: adservice
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/adservice:v0.8.0
        ports:
        - containerPort: 9555
        env:
        - name: PORT
          value: "9555"
        resources:
          requests:
            cpu: 200m
            memory: 180Mi
          limits:
            cpu: 300m
            memory: 300Mi
---
apiVersion: v1
kind: Service
metadata:
  name: adservice
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: adservice
  ports:
  - name: grpc
    port: 9555
    targetPort: 9555
---
# Redis Cart
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cart
  namespace: development
spec:
  selector:
    matchLabels:
      app: redis-cart
  template:
    metadata:
      labels:
        app: redis-cart
      annotations:
        consul.hashicorp.com/connect-inject: "true"
        consul.hashicorp.com/partition: "k8s-west1"
        consul.hashicorp.com/namespace: "development"
    spec:
      serviceAccountName: redis-cart
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /data
          name: redis-data
        resources:
          limits:
            memory: 256Mi
            cpu: 125m
          requests:
            cpu: 70m
            memory: 200Mi
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis-cart
  namespace: development
spec:
  type: ClusterIP
  selector:
    app: redis-cart
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
EOF

kubectl apply -f boutique-dev.yaml

# If you encounter annotation errors, run this fix:
# sed -i 's/consul.hashicorp.com\/service-partition:/consul.hashicorp.com\/partition:/g' boutique-dev.yaml
# sed -i '/consul.hashicorp.com\/partition:/a\        consul.hashicorp.com/namespace: "development"' boutique-dev.yaml

kubectl wait --for=condition=Ready pod -l app=frontend -n development --timeout=300s
```

**Verification**:
- `kubectl get pods -n development` should show 2/2 ready for all 11 services (frontend, productcatalogservice, currencyservice, cartservice, checkoutservice, paymentservice, emailservice, shippingservice, recommendationservice, adservice, redis-cart)
- `consul catalog services` should list all 11 services registered in Consul
- Check Connect sidecars: `kubectl get pods -n development -o wide` should show 2/2 containers per pod
- **Full functionality test**: Port forward frontend and browse the complete online store

## Step 3: Apply Zero Trust and Fix with Service Intentions

**What we're doing**: First testing that our app works normally, then applying Consul's zero-trust model (default deny all traffic), observing it break, then fixing it with explicit service intentions. This demonstrates the core value of service intentions.

**Expected outcome**: App works → App breaks with zero trust → App works again with proper intentions.

```bash
# Set development context
export CONSUL_HTTP_TOKEN="$DEV_TOKEN"
export CONSUL_PARTITION="k8s-west1"
export CONSUL_NAMESPACE="development"

# Test working app first
kubectl port-forward svc/frontend 8080:80 -n development &
curl -s http://localhost:8080 | grep -q "Online Boutique" && echo "✅ App working"

# Apply zero trust (breaks app)
consul intention create -deny -source "*" -destination "*" -description "Zero trust default deny"
curl -s http://localhost:8080 | grep -q "error\|timeout\|failed" && echo "❌ App broken by zero trust"

# Fix with core service intentions for full boutique functionality
echo "Creating frontend service intentions..."
consul intention create -allow -source "frontend" -destination "productcatalogservice" -description "Frontend needs product catalog" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "frontend" -destination "currencyservice" -description "Frontend needs currency conversion" -meta "environment=development,cts_managed=true" 
consul intention create -allow -source "frontend" -destination "cartservice" -description "Frontend needs cart access" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "frontend" -destination "recommendationservice" -description "Frontend needs recommendations" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "frontend" -destination "checkoutservice" -description "Frontend needs checkout" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "frontend" -destination "shippingservice" -description "Frontend needs shipping info" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "frontend" -destination "adservice" -description "Frontend needs ads" -meta "environment=development,cts_managed=true"

echo "Creating checkout service intentions..."
consul intention create -allow -source "checkoutservice" -destination "productcatalogservice" -description "Checkout needs product validation" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "checkoutservice" -destination "cartservice" -description "Checkout needs cart access" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "checkoutservice" -destination "currencyservice" -description "Checkout needs currency conversion" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "checkoutservice" -destination "paymentservice" -description "Checkout needs payment processing" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "checkoutservice" -destination "emailservice" -description "Checkout needs email notifications" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "checkoutservice" -destination "shippingservice" -description "Checkout needs shipping calculation" -meta "environment=development,cts_managed=true"

echo "Creating backend service intentions..."
consul intention create -allow -source "cartservice" -destination "redis-cart" -description "Cart needs Redis storage" -meta "environment=development,cts_managed=true"
consul intention create -allow -source "recommendationservice" -destination "productcatalogservice" -description "Recommendations need product data" -meta "environment=development,cts_managed=true"

sleep 10
curl -s http://localhost:8080 | grep -q "Online Boutique" && echo "✅ Full app functionality restored with service intentions"
```

**Verification**:
- **Step 1**: Curl should return HTML containing "Online Boutique" with full e-commerce functionality
- **Step 2**: After default deny, curl should timeout or show connection errors, app completely broken
- **Step 3**: After all intentions, app should be fully functional: you can browse products, add to cart, view recommendations, and complete checkout flow
- `consul intention list` should show 13 allow intentions for complete microservices communication
- **Full test**: Browse to http://localhost:8080, add items to cart, proceed through checkout - all features should work

## Step 4: Setup Consul Terraform Sync (CTS)

**What we're doing**: Setting up CTS to watch for service intention changes in production and automatically update infrastructure. This bridges the gap between service mesh policies and underlying infrastructure configuration.

**Expected outcome**: CTS service running and ready to respond to service intention changes.

```bash
# CTS configuration
cat > consul-terraform-sync.hcl << 'EOF'
log_level = "INFO"
port = 8558

consul {
  address = "localhost:8500"
  token = "$(echo $PROD_TOKEN)"
  partition = "k8s-west1"
}

driver "terraform" {
  log = true
  path = "/tmp/cts-terraform"
}

task {
  name = "load-balancer-sync"
  description = "Update load balancer when production intentions change"
  enabled = true
  
  services = ["frontend", "productcatalogservice"]
  
  module = "/path/to/terraform-loadbalancer-module"
  
  condition "consul-kv" {
    path = "cts/production/intentions"
    recurse = true
  }
}
EOF

# Start CTS (background process for demo)
consul-terraform-sync start -config-file=consul-terraform-sync.hcl &
sleep 10
curl -s http://localhost:8558/v1/status | jq '.status' && echo "✅ CTS running"
```

**Verification**:
- CTS should start without errors (check logs if needed)
- `curl http://localhost:8558/v1/status` should return JSON with status information
- You should see "✅ CTS running" message

## Step 5: Promote to Production

**What we're doing**: Taking our tested application from development and promoting it to the production namespace. This simulates the real-world workflow where code moves through environments.

**Expected outcome**: Same application now running in production namespace, ready for production-grade service intentions.

```bash
# Create production namespace
kubectl create namespace production

# Deploy to production
sed 's/namespace: development/namespace: production/g' boutique-dev.yaml | kubectl apply -f -
kubectl wait --for=condition=Ready pod -l app=frontend -n production --timeout=300s

echo "✅ Boutique promoted to production namespace"
```

**Verification**:
- `kubectl get pods -n production` should show frontend and productcatalog pods with 2/2 ready
- `consul catalog services` should now show services in both development and production namespaces
- You should see the success message about promotion

## Step 6: Configure API Gateway

**What we're doing**: Setting up Consul's API Gateway to provide external access to our production services. This creates a controlled entry point that we can secure with service intentions.

**Expected outcome**: API Gateway configured to route external traffic to internal services via service mesh.

```bash
# Set production context
export CONSUL_HTTP_TOKEN="$PROD_TOKEN"
export CONSUL_NAMESPACE="production"

# API Gateway configuration
cat > api-gateway-config.hcl << 'EOF'
Kind = "api-gateway"
Name = "boutique-gateway"
Partition = "k8s-west1"
Namespace = "production"

Listeners = [
  {
    Name = "boutique-listener"
    Port = 8081
    Protocol = "http"
    
    Routes = [
      {
        Name = "boutique-route"
        Match = { HTTP = { PathPrefix = "/boutique/" } }
        Services = [
          {
            Name = "frontend"
            Namespace = "production"
            Partition = "k8s-west1"
          }
        ]
        Filters = { URLRewrite = { PathPrefix = "/" } }
      }
    ]
  }
]
EOF

consul config write api-gateway-config.hcl
echo "✅ API Gateway configured for external access"
```

**Verification**:
- `consul config read -kind api-gateway -name boutique-gateway` should show your gateway configuration
- Gateway should be listening on port 8081
- Routes should be configured to forward `/boutique/` traffic to frontend service

## Step 7: Production Service Intentions with CTS Integration

**What we're doing**: Applying production-grade service intentions that include metadata for CTS automation. These intentions not only control service communication but also trigger infrastructure updates through CTS.

**Expected outcome**: Zero-trust production environment with explicit service communication permissions and automated infrastructure alignment.

```bash
# Apply production zero trust
consul intention create -deny -source "*" -destination "*" -description "Production zero trust"

# Create full production service intentions with CTS metadata
echo "Creating production frontend service intentions..."
consul intention create -allow -source "frontend" -destination "productcatalogservice" -description "Production: Frontend to product catalog" -meta "environment=production,cts_managed=true,destination_port=3550"
consul intention create -allow -source "frontend" -destination "currencyservice" -description "Production: Frontend to currency service" -meta "environment=production,cts_managed=true,destination_port=7000"
consul intention create -allow -source "frontend" -destination "cartservice" -description "Production: Frontend to cart service" -meta "environment=production,cts_managed=true,destination_port=7070"
consul intention create -allow -source "frontend" -destination "recommendationservice" -description "Production: Frontend to recommendations" -meta "environment=production,cts_managed=true,destination_port=8080"
consul intention create -allow -source "frontend" -destination "checkoutservice" -description "Production: Frontend to checkout" -meta "environment=production,cts_managed=true,destination_port=5050"
consul intention create -allow -source "frontend" -destination "shippingservice" -description "Production: Frontend to shipping" -meta "environment=production,cts_managed=true,destination_port=50051"
consul intention create -allow -source "frontend" -destination "adservice" -description "Production: Frontend to ads" -meta "environment=production,cts_managed=true,destination_port=9555"

echo "Creating production checkout service intentions..."
consul intention create -allow -source "checkoutservice" -destination "productcatalogservice" -description "Production: Checkout to product catalog" -meta "environment=production,cts_managed=true,destination_port=3550"
consul intention create -allow -source "checkoutservice" -destination "cartservice" -description "Production: Checkout to cart" -meta "environment=production,cts_managed=true,destination_port=7070"
consul intention create -allow -source "checkoutservice" -destination "currencyservice" -description "Production: Checkout to currency" -meta "environment=production,cts_managed=true,destination_port=7000"
consul intention create -allow -source "checkoutservice" -destination "paymentservice" -description "Production: Checkout to payment - PCI approved" -meta "environment=production,cts_managed=true,destination_port=50051,compliance=pci-dss"
consul intention create -allow -source "checkoutservice" -destination "emailservice" -description "Production: Checkout to email" -meta "environment=production,cts_managed=true,destination_port=5000"
consul intention create -allow -source "checkoutservice" -destination "shippingservice" -description "Production: Checkout to shipping" -meta "environment=production,cts_managed=true,destination_port=50051"

echo "Creating production backend service intentions..."
consul intention create -allow -source "cartservice" -destination "redis-cart" -description "Production: Cart to Redis storage" -meta "environment=production,cts_managed=true,destination_port=6379"
consul intention create -allow -source "recommendationservice" -destination "productcatalogservice" -description "Production: Recommendations to product catalog" -meta "environment=production,cts_managed=true,destination_port=3550"

# Trigger CTS update for production infrastructure
consul kv put "cts/production/intentions/last_update" "$(date -Iseconds)"
consul kv put "cts/production/intentions/services_count" "15"
echo "🔧 CTS triggered - load balancer updating for all production services..."

sleep 30
curl -s http://localhost:8558/v1/status | jq '.tasks[0].status' && echo "✅ CTS execution complete - infrastructure updated for full application"
```

**Verification**:
- `consul intention list` in production namespace should show 15 allow intentions (1 API gateway + 14 internal service communications)
- CTS status should show successful task execution with infrastructure updates for all service ports
- Check intentions metadata: `consul intention list -detailed` should show CTS-related metadata and port information
- **Full production test**: Access via API Gateway should provide complete e-commerce functionality
- **Compliance check**: Payment service intention should show PCI compliance metadata
- **Port verification**: CTS should have updated load balancer for ports: 8080, 3550, 7000, 7070, 5050, 50051, 9555, 5000, 6379

## Step 8: Configure Service Exports

**What we're doing**: Configuring service exports to make selected production services available to other Consul partitions via mesh gateway. This enables controlled cross-partition service sharing.

**Expected outcome**: Production services available for consumption by other partitions through secure mesh gateway connections.

```bash
# Service export configuration
cat > service-exports.hcl << 'EOF'
Kind = "exported-services"
Name = "boutique-exports"
Partition = "k8s-west1"

Services = [
  {
    Name = "frontend"
    Namespace = "production"
    Consumers = [
      { Partition = "analytics-cluster" },
      { Partition = "mobile-backend" }
    ]
  },
  {
    Name = "productcatalogservice"
    Namespace = "production"
    Consumers = [
      { Partition = "analytics-cluster" },
      { Partition = "mobile-backend" },
      { Partition = "partner-integrations" }
    ]
  },
  {
    Name = "currencyservice"
    Namespace = "production"
    Consumers = [
      { Partition = "mobile-backend" },
      { Partition = "partner-integrations" }
    ]
  },
  {
    Name = "recommendationservice"
    Namespace = "production"
    Consumers = [
      { Partition = "analytics-cluster" }
    ]
  }
]

Meta = {
  "cts_managed" = "true"
  "mesh_gateway_integration" = "enabled"
  "cross_partition_firewall" = "required"
}
EOF

consul config write service-exports.hcl
echo "✅ Services exported via mesh gateway"
```

**Verification**:
- `consul config read -kind exported-services -name boutique-exports` should show your export configuration with 4 services
- **Services exported**: frontend, productcatalogservice, currencyservice, recommendationservice
- **Consumer partitions**: analytics-cluster, mobile-backend, partner-integrations
- Mesh gateway should be configured to handle cross-partition traffic for multiple services
- **Perfect for cluster peering demos**: You now have multiple services that can be consumed by other clusters

## Step 9: Verify Complete Setup

**What we're doing**: Final verification that all components are working together - checking service intentions across both namespaces, confirming CTS is operational, and validating that our complete governance workflow is in place.

**Expected outcome**: Complete audit trail showing service intentions, CTS automation, and cross-partition exports all functioning together.

```bash
echo "📊 Demo Summary:"
echo "==============="

# Show development intentions
export CONSUL_NAMESPACE="development"
echo "Development intentions:"
consul intention list

# Show production intentions
export CONSUL_NAMESPACE="production"
echo "Production intentions:"
consul intention list

# Show API Gateway status
consul catalog services | grep api-gateway

# Show CTS status
echo "CTS Status:"
curl -s http://localhost:8558/v1/status | jq '.tasks[] | {name, status}'

echo ""
echo "✅ Complete Demo Achieved:"
echo "- ✅ k8s-west1 admin partition with ACL governance"
echo "- ✅ Development → Production promotion workflow"
echo "- ✅ API Gateway for external access (port 8081)"
echo "- ✅ CTS automation updating load balancer based on intentions"
echo "- ✅ Service exports via mesh gateway"
echo "- ✅ Zero trust with explicit service intentions"
```

**Final Verification Checklist**:
- **Development intentions**: Should see 13 allow intentions covering complete microservices communication
- **Production intentions**: Should see 15 allow intentions (API gateway + full microservices stack)
- **CTS status**: Should show successful task executions with infrastructure updates for 9 different service ports
- **Service exports**: Should show 4 services exported to 3 different partitions (perfect for cluster peering demos)
- **API Gateway**: Should be configured and routing external traffic to fully functional e-commerce application
- **Audit trail**: Complete history of all 28 service communication approvals across both environments

**Success indicators**:
- **Complete e-commerce functionality**: Browse products, add to cart, checkout, payment, shipping, recommendations, ads
- **Zero unauthorized communication**: All service-to-service communication explicitly approved
- **Production-ready**: PCI compliance metadata for payment service, infrastructure automation via CTS
- **Cross-cluster ready**: Multiple services exported and ready for cluster peering demonstrations
- **Full observability**: Every service interaction is governed, logged, and auditable

**Bonus - Cluster Peering Demo Ready**:
- **Frontend service**: Available to analytics-cluster and mobile-backend partitions
- **Product catalog**: Available to analytics, mobile-backend, and partner-integrations  
- **Currency service**: Available to mobile-backend and partner-integrations
- **Recommendations**: Available to analytics-cluster for ML/data science workloads

This gives you a rich environment for demonstrating cross-cluster service sharing scenarios!

## Key Demo Points

1. **Governance**: ACL policies enforce namespace boundaries
2. **Zero Trust**: Default deny with explicit allow intentions
3. **Automation**: CTS watches production intentions and updates infrastructure
4. **External Access**: API Gateway provides controlled entry point
5. **Cross-Partition**: Service exports enable controlled external access
6. **Audit Trail**: All service communication explicitly approved and logged

## Test the Complete Flow

```bash
# Access via API Gateway (external traffic)
curl http://your-api-gateway:8081/boutique/

# CTS monitors and updates load balancer automatically
# When new intentions are created in production
```
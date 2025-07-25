#!/bin/bash
set -e

# Setup Helm values for GKE West1 (k8s-west1 partition)
# This script helps populate the placeholders in values.yaml

echo "🔧 Setting up Helm values for GKE West1 (k8s-west1 partition)..."

# Check if we're in the right directory
if [ ! -f "values.yaml" ]; then
    echo "❌ values.yaml not found. Run this script from the helm directory."
    exit 1
fi

# Get DC1 server IPs from terraform
echo "📍 Getting DC1 server IPs from terraform..."
if [ -d "../../dc1/terraform" ]; then
    cd ../../dc1/terraform
    DC1_SERVER_IPS=$(terraform output -json server_nodes 2>/dev/null | jq -r '.hashi_servers | to_entries[] | .value.public_ip' 2>/dev/null || echo "")
    cd - > /dev/null
fi

# Get GKE cluster endpoint
echo "📍 Getting GKE West1 cluster endpoint..."
if [ -d "../terraform" ]; then
    cd ../terraform
    GKE_ENDPOINT=$(terraform output -raw cluster_endpoint 2>/dev/null || echo "")
    cd - > /dev/null
fi

# Create a backup of the original values.yaml
cp values.yaml values.yaml.backup

echo "🔄 Updating values.yaml with actual values..."

# Update DC1 server IPs if available
if [ ! -z "$DC1_SERVER_IPS" ]; then
    IPS_ARRAY=($DC1_SERVER_IPS)
    if [ ${#IPS_ARRAY[@]} -ge 3 ]; then
        sed -i.tmp "s/REPLACE_WITH_DC1_SERVER_IP_1/${IPS_ARRAY[0]}/g" values.yaml
        sed -i.tmp "s/REPLACE_WITH_DC1_SERVER_IP_2/${IPS_ARRAY[1]}/g" values.yaml
        sed -i.tmp "s/REPLACE_WITH_DC1_SERVER_IP_3/${IPS_ARRAY[2]}/g" values.yaml
        rm values.yaml.tmp
        echo "✅ Updated DC1 server IPs"
    else
        echo "⚠️  Not enough DC1 server IPs found. Update manually."
    fi
else
    echo "⚠️  Could not get DC1 server IPs. Update manually in values.yaml"
    echo "    Use: cd ../../dc1/terraform && terraform output server_nodes"
fi

# Update GKE endpoint if available
if [ ! -z "$GKE_ENDPOINT" ]; then
    sed -i.tmp "s|REPLACE_WITH_GKE_WEST1_API_ENDPOINT|https://$GKE_ENDPOINT|g" values.yaml
    rm values.yaml.tmp
    echo "✅ Updated GKE West1 API endpoint"
else
    echo "⚠️  Could not get GKE endpoint. Update manually in values.yaml"
    echo "    Use: cd ../terraform && terraform output cluster_endpoint"
fi

echo ""
echo "📋 Next steps:"
echo "1. Review values.yaml for any remaining placeholders"
echo "2. Ensure all Kubernetes secrets are created"
echo "3. Create admin partition: consul partition create -name k8s-west1"
echo "4. Deploy Consul: task gke-deploy-consul"
echo ""
echo "🔍 Check for remaining placeholders:"
grep -n "REPLACE_WITH" values.yaml || echo "✅ No placeholders found"
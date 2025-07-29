#!/bin/bash

# Push generated firewall rules to your existing HCP Terraform workspace
WORKSPACE_DIR="/Users/pablod/Documents/Infrastructure/nomad/02-consul-nomad-gcp/nomad-consul-gcp/clusters/gke-southwest/terraform"
GENERATED_FILE="/tmp/firewall-rules.tf"
TARGET_FILE="$WORKSPACE_DIR/cts-firewall-rules.tf"

echo "🔍 CTS detected service changes!"

if [ -f "$GENERATED_FILE" ]; then
    echo "📄 Copying generated firewall rules to HCP workspace..."
    cp "$GENERATED_FILE" "$TARGET_FILE"
    
    echo "📁 Pushing to HCP Terraform workspace..."
    cd "$WORKSPACE_DIR"
    
    # Add the new file to git (if using git)
    git add cts-firewall-rules.tf 2>/dev/null || true
    
    # Trigger terraform plan (this will show in HCP)
    echo "🚀 Triggering terraform plan in HCP workspace..."
    unset TF_WORKSPACE  # Clear conflicting env var
    terraform plan
    
    echo "✅ Done! Check your HCP Terraform workspace for the plan."
    echo "🌐 Workspace: https://app.terraform.io/app/pablogd-hcp-test/workspaces/GKE-southwest"
else
    echo "❌ Generated file not found: $GENERATED_FILE"
fi
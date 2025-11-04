#!/bin/bash
# Script to automatically update external server IPs in values.yaml
# This fetches the current Consul server IPs from GCP and updates the Helm values

set -e

echo "🔍 Fetching Consul server IPs from GCP..."

# Get external IPs from GCP
EXTERNAL_IPS=$(gcloud compute instances list \
  --filter='name~hashi-server' \
  --format='value(EXTERNAL_IP)' \
  --project=hc-d7fbda7b58644c1b8877e930a42 \
  | sort)

if [ -z "$EXTERNAL_IPS" ]; then
  echo "❌ Error: No Consul server IPs found. Check your GCP project and filters."
  exit 1
fi

echo "📋 Found Consul server IPs:"
echo "$EXTERNAL_IPS" | nl

# Convert to YAML array format
YAML_IPS=$(echo "$EXTERNAL_IPS" | awk '{print "    - \"" $0 "\""}')

echo ""
echo "✏️  Updating values.yaml..."

# Backup existing values.yaml
cp values.yaml values.yaml.backup.$(date +%Y%m%d_%H%M%S)

# Create temporary file with updated IPs
cat values.yaml | awk -v ips="$YAML_IPS" '
  /^externalServers:/ { in_external=1 }
  /^  hosts:/ && in_external {
    print $0
    print ips
    in_hosts=1
    next
  }
  /^  [a-zA-Z]/ && in_hosts { in_hosts=0 }
  !in_hosts || !/^    - "/ { print }
  /^[a-zA-Z]/ && !/^externalServers:/ { in_external=0 }
' > values.yaml.tmp

# Replace original file
mv values.yaml.tmp values.yaml

echo "✅ values.yaml updated successfully!"
echo ""
echo "📝 Updated external server configuration:"
echo "externalServers:"
echo "  hosts:"
echo "$YAML_IPS"
echo ""
echo "💾 Backup saved to: values.yaml.backup.$(date +%Y%m%d_%H%M%S)"

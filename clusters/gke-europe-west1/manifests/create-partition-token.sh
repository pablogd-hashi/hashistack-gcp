#!/bin/bash

# Script to create a new admin partition and token for GKE
# Run this on a Consul server with proper ACL permissions

set -e

PARTITION_NAME="gke-europe-west1"
POLICY_NAME="${PARTITION_NAME}-partition-policy"

echo "Creating admin partition: $PARTITION_NAME"

# Create partition policy
cat > /tmp/${POLICY_NAME}.hcl << EOF
partition_prefix "$PARTITION_NAME" {
  policy = "write"
}

namespace_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

key_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}

event_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy = "write"
}

operator = "write"
mesh = "write"
peering = "write"
EOF

# Create the partition policy
echo "Creating partition policy: $POLICY_NAME"
consul acl policy create \
  -name "$POLICY_NAME" \
  -description "Policy for $PARTITION_NAME partition" \
  -rules @/tmp/${POLICY_NAME}.hcl

# Create partition token
echo "Creating partition token..."
consul acl token create \
  -description "Token for $PARTITION_NAME partition" \
  -partition "$PARTITION_NAME" \
  -policy-name "$POLICY_NAME" \
  -format json > /tmp/${PARTITION_NAME}-token.json

# Display token information
echo "Partition token created successfully!"
echo "Token details:"
cat /tmp/${PARTITION_NAME}-token.json | jq -r '"AccessorID: " + .AccessorID'
cat /tmp/${PARTITION_NAME}-token.json | jq -r '"SecretID: " + .SecretID'
cat /tmp/${PARTITION_NAME}-token.json | jq -r '"Partition: " + .Partition'

# Save token for later use
TOKEN_SECRET=$(cat /tmp/${PARTITION_NAME}-token.json | jq -r .SecretID)
echo ""
echo "Save this token for your GKE configuration:"
echo "PARTITION_TOKEN=$TOKEN_SECRET"

# Cleanup
rm -f /tmp/${POLICY_NAME}.hcl /tmp/${PARTITION_NAME}-token.json

echo ""
echo "Next steps:"
echo "1. Update your GKE Consul values to use partition: $PARTITION_NAME"
echo "2. Update the partition token secret with: $TOKEN_SECRET"
echo "3. Redeploy Consul on GKE"
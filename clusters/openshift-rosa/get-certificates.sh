#!/bin/bash
# Script to obtain CA certificates from Consul servers
# Choose your preferred method below

set -e

CERT_DIR="$(dirname "$0")/certificates"
mkdir -p "$CERT_DIR"

echo "🔐 Obtaining Consul CA Certificates"
echo ""
echo "Choose your method:"
echo "  1) SSH (requires SSH key configured)"
echo "  2) Boundary (requires Boundary connection)"
echo "  3) Manual instructions"
echo ""
read -p "Select method (1-3): " METHOD

case $METHOD in
  1)
    echo ""
    echo "📡 Using SSH method..."

    # Get first Consul server IP
    SERVER_IP=$(gcloud compute instances list \
      --filter='name~hashi-server-0' \
      --format='value(EXTERNAL_IP)' \
      --limit=1)

    if [ -z "$SERVER_IP" ]; then
      echo "❌ Error: Could not find Consul server IP"
      exit 1
    fi

    echo "🎯 Connecting to server: $SERVER_IP"

    # Copy CA certificate
    echo "📥 Copying CA certificate..."
    ssh debian@$SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > "$CERT_DIR/consul-agent-ca.pem"

    # Copy CA key
    echo "📥 Copying CA key..."
    ssh debian@$SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > "$CERT_DIR/consul-agent-ca-key.pem"

    echo ""
    echo "✅ Certificates saved to: $CERT_DIR"
    ls -lh "$CERT_DIR"
    ;;

  2)
    echo ""
    echo "📡 Using Boundary method..."
    echo ""
    echo "First, find your target ID:"
    echo "  boundary targets list"
    echo ""
    read -p "Enter Consul server target ID: " TARGET_ID

    if [ -z "$TARGET_ID" ]; then
      echo "❌ Error: Target ID required"
      exit 1
    fi

    export BOUNDARY_ADDR="https://a4a6eb9e-a049-4296-bbf3-833bc6f9b443.boundary.hashicorp.cloud"

    echo "📥 Copying CA certificate..."
    boundary connect ssh -target-id $TARGET_ID -- \
      "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > "$CERT_DIR/consul-agent-ca.pem"

    echo "📥 Copying CA key..."
    boundary connect ssh -target-id $TARGET_ID -- \
      "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > "$CERT_DIR/consul-agent-ca-key.pem"

    echo ""
    echo "✅ Certificates saved to: $CERT_DIR"
    ls -lh "$CERT_DIR"
    ;;

  3)
    echo ""
    echo "📋 Manual Instructions"
    echo ""
    echo "Method 1: SSH Direct"
    echo "--------------------"
    echo "# Get server IP"
    echo 'SERVER_IP=$(gcloud compute instances list --filter="name~hashi-server-0" --format="value(EXTERNAL_IP)" --limit=1)'
    echo ""
    echo "# Copy certificates"
    echo 'ssh debian@$SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem'
    echo 'ssh debian@$SERVER_IP "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem'
    echo ""
    echo "Method 2: SCP"
    echo "-------------"
    echo 'SERVER_IP="34.88.172.144"  # Replace with actual IP'
    echo 'scp debian@$SERVER_IP:/etc/consul.d/tls/consul-agent-ca.pem ./'
    echo 'scp debian@$SERVER_IP:/etc/consul.d/tls/consul-agent-ca-key.pem ./'
    echo ""
    echo "Method 3: Boundary"
    echo "------------------"
    echo "# List targets to find ID"
    echo "boundary targets list"
    echo ""
    echo "# Connect and copy (replace <target-id>)"
    echo 'boundary connect ssh -target-id <target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca.pem" > consul-agent-ca.pem'
    echo 'boundary connect ssh -target-id <target-id> -- "sudo cat /etc/consul.d/tls/consul-agent-ca-key.pem" > consul-agent-ca-key.pem'
    echo ""
    echo "📁 Save certificates to: $CERT_DIR"
    ;;

  *)
    echo "❌ Invalid selection"
    exit 1
    ;;
esac

echo ""
echo "🎉 Done! You can now create the Kubernetes secrets:"
echo ""
echo "oc create secret generic consul-ca-cert \\"
echo "  --from-file=tls.crt=$CERT_DIR/consul-agent-ca.pem \\"
echo "  -n consul"
echo ""
echo "oc create secret generic consul-ca-key \\"
echo "  --from-file=tls.key=$CERT_DIR/consul-agent-ca-key.pem \\"
echo "  -n consul"

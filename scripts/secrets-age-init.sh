#!/usr/bin/env bash
# [MISE] description="Initialize age encryption keys for SOPS"
# [MISE] depends=[]

set -euo pipefail

if [ -f "$KEY_FILE" ]; then
  echo "age key already exists at $KEY_FILE"
  if [ -f "$PUB_FILE" ]; then
    echo "Public key: $(cat "$PUB_FILE")"
  fi
  exit 0
fi

mkdir -p "$KEY_DIR"
echo "Generating age key pair..."

# Generate key and capture output
KEY_OUTPUT=$(age-keygen -o "$KEY_FILE" 2>&1)

# Extract public key from output
PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep "Public key:" | awk '{print $3}')

# Save public key
echo "$PUBLIC_KEY" >"$PUB_FILE"

# Set restrictive permissions
chmod 600 "$KEY_FILE"
chmod 644 "$PUB_FILE"

echo "age key generated successfully!"
echo "  Private key: $KEY_FILE"
echo "  Public key:  $PUB_FILE"
echo ""
echo "Public key value: $PUBLIC_KEY"
echo ""
echo "Add this to your .sops.yaml:"
echo "  age: $PUBLIC_KEY"

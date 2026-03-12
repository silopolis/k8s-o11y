#!/usr/bin/env bash
# [MISE] description="Create encrypted .env.enc file with placeholder secrets"
# [MISE] depends=["secrets-age-init"]

set -euo pipefail

if [ ! -f "$PUB_FILE" ]; then
  echo "age public key not found at $PUB_FILE"
  echo "Running 'mise run secrets-age-init' to generate keys..."
  mise run secrets-age-init
fi

if [ ! -f "$PUB_FILE" ]; then
  echo "Error: Failed to generate age public key"
  exit 1
fi

PUB_KEY=$(<"$PUB_FILE")

if [ ! -f "$SOPS_CONFIG" ]; then
  cat >"$SOPS_CONFIG" <<-EOF
	creation_rules:
  - path_regex: .*\\.env\\.(enc|json|yaml|toml)\$
	    age: $PUB_KEY
	EOF
fi

if [ -f "$ENC_ENV_FILE" ]; then
  echo "Encrypted env file already exists: $ENC_ENV_FILE"
  exit 0
fi

# Create initial secrets in human-readable format (encrypted values only)
mkdir -p "$(dirname "$ENC_ENV_FILE")"
TMP_ENV=$(mktemp "$(dirname "$ENC_ENV_FILE")/.tmp.XXXXXX.env.enc")
cat >"$TMP_ENV" <<'EOF'
# Project Secrets
# This file will be encrypted by SOPS - only values are encrypted, keys remain readable

# Grafana Configuration
GRAFANA_ADMIN_PASSWORD=changeme-strong-password-required
GRAFANA_SECRET_KEY=generate-a-random-secret-key-here

# Talos Configuration
TALOS_ADMIN_PASSWORD=changeme-strong-password-required

# Alertmanager Configuration
ALERTMANAGER_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
EOF

# Encrypt the file
sops --encrypt --input-type dotenv --output-type yaml --in-place "$TMP_ENV"

# Move to final location
mv "$TMP_ENV" "$ENC_ENV_FILE"

echo "Created encrypted env file: $ENC_ENV_FILE"
echo ""
echo "To edit: sops $ENC_ENV_FILE"
echo "To decrypt: sops --decrypt $ENC_ENV_FILE"
echo ""
echo "IMPORTANT: Replace placeholder values with real secrets!"

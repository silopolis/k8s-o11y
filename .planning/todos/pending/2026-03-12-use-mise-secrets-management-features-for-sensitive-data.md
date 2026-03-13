---
created: 2026-03-12T18:41:14.922Z
title: Use mise secrets management features for sensitive data
area: tooling
files:
  - mise.toml
  - .mise/
  - helmfile.yaml
  - values/
---

## Problem

The project currently has no structured approach for managing sensitive data such as:

- **API keys and tokens** for external integrations (Alertmanager receivers, Grafana plugins)
- **Database credentials** if Loki or other components need external storage
- **TLS certificates** and private keys
- **Cloud provider credentials** (if applicable)
- **Grafana admin password** and other component secrets

**Current State:**
- Secrets may be hardcoded in values files (security risk)
- Or manually managed outside version control (maintenance burden)
- No consistent pattern for secret rotation or environment-specific secrets
- No encryption at rest for sensitive configuration

**Risks:**
- Secrets committed to git accidentally
- Difficult to share development environments securely
- Manual secret management is error-prone
- No audit trail for secret access

## Solution

Leverage mise's built-in secrets management capabilities (via 1Password, Vault, or sops):

1. **Choose a secrets backend**
   - **1Password** (recommended for dev teams): Store secrets in 1Password vault
   - **HashiCorp Vault**: Enterprise-grade secrets management
   - **SOPS + age/GPG**: File-based encryption (good for GitOps)
   - **Environment variables**: Simple but less secure

2. **Configure mise secrets**
   Add to `mise.toml`:
   ```toml
   [secrets]
   backend = "1password"  # or "vault", "sops"

   # Define required secrets
   [secrets.GRAFANA_ADMIN_PASSWORD]
   key = "op://vault/item/field"

   [secrets.ALERTMANAGER_SLACK_WEBHOOK]
   key = "op://vault/slack/webhook"
   ```

3. **Integrate with helmfile**
   Use mise environment variables in helmfile:
   ```yaml
   releases:
     - name: kube-prometheus-stack
       values:
         - values/prometheus-stack.yaml
         - values/secrets.yaml  # References env vars populated by mise
   ```

4. **Update deployment workflow**
   - `mise run deploy` automatically fetches secrets
   - No manual environment variable setup required
   - Secrets are never written to disk unencrypted

5. **Documentation**
   - Document secret setup in AGENTS.md
   - Add `.env.example` with placeholder values
   - Include 1Password/Vault setup instructions

## Implementation Phases

**Phase 1:** Basic integration
- Set up 1Password vault or Vault instance
- Configure mise.toml with secrets backend
- Migrate Grafana admin password to secrets

**Phase 2:** Full coverage
- Move all sensitive data to secrets management
- Add secret rotation procedures
- Document secret recovery process

## Benefits

- **Security:** Secrets never in git, encrypted at rest
- **Convenience:** `mise run` fetches secrets automatically
- **Audit:** Track who accessed which secrets when
- **Rotation:** Easy secret rotation without config changes

## References

- mise documentation: Secrets management
- 1Password CLI integration
- HashiCorp Vault documentation
- helmfile environment variable usage

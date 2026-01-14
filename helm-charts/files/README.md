# Local Files Directory

This directory stores configuration files and certificates for local development deployments of the Crucible stack.

## How It Works

When you run `./helm-charts/helm-deploy.sh`, the script automatically:
1. Checks for certificate files in both `.devcontainer/certs` and `.devcontainer/dev-certs` directories
2. **Creates Kubernetes secrets** from your certificate files using `kubectl`
3. Deploys the chart which references these pre-created secrets

## Files in This Directory

- The `certs/` directory is a symlink to `.devcontainer/certs/` for backward compatibility
- Certificates are collected from BOTH `.devcontainer/certs` (proxy/custom CAs) and `.devcontainer/dev-certs` (generated dev certs)
- `crucible-dev.*` certificates are automatically generated in `.devcontainer/dev-certs/` when the devcontainer is created
- Custom CA certificates (like `zscaler-ca.crt`) should be placed in `.devcontainer/certs/`
- The CA ConfigMap will include ALL `.crt` files from both directories

### Configuration Files

crucible-realm.json   - Keycloak realm configuration for Crucible. This is a copy of the version from `Crucible.AppHost/resources/crucible-realm.json` because App URLs need to be different between Aspire and helm.

## Certificate Generation

### Development Certificates (Automatic)

The `crucible-dev.crt` and `crucible-dev.key` certificates are **automatically generated** when the devcontainer is created by the `.devcontainer/postcreate.sh` script. You don't need to generate these manually. These are stored in `.devcontainer/dev-certs/`.

### For Corporate Proxy CA Certificates

If you're behind a corporate proxy, place your corporate CA certificate in `.devcontainer/certs/`:

```bash
# Copy your corporate CA certificate
cp /path/to/corporate-ca.crt .devcontainer/certs/zscaler-ca.crt
```

**Note:** Certificate files with `.crt` and `.key` extensions are gitignored in both directories. The `certs` symlink in this directory IS committed to git.

## Troubleshooting

### Certificates Not Found

Check if certificate files are present in either directory:
```bash
ls -la /workspaces/crucible-development/.devcontainer/certs/
ls -la /workspaces/crucible-development/.devcontainer/dev-certs/
ls -la /workspaces/crucible-development/helm-charts/files/certs/
```

### Verify Secrets Were Created

After running helm-deploy.sh, verify the secrets exist:
```bash
# Check TLS secret
kubectl get secret crucible-cert

# Check CA ConfigMap
kubectl get configmap crucible-ca-cert

# View secret contents
kubectl describe secret crucible-cert
```

### Manual Secret Creation

If needed, you can manually create certificate secrets instead of relying on `helm-deploy.sh` to create them for you:
```bash
# TLS secret (adjust paths as needed)
kubectl create secret tls crucible-cert \
  --cert=.devcontainer/dev-certs/crucible-dev.crt \
  --key=.devcontainer/dev-certs/crucible-dev.key \
  --dry-run=client -o yaml | kubectl apply -f -

# CA ConfigMap (includes all CAs from both directories)
kubectl create configmap crucible-ca-cert \
  --from-file=.devcontainer/dev-certs/crucible-dev.crt \
  --from-file=.devcontainer/certs/zscaler-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

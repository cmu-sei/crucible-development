# Local Files Directory

This directory stores configuration files and certificates for local development deployments of the Crucible stack.

## How It Works

When you run `./helm-charts/helm-deploy.sh`, the script automatically:
1. Checks if this `files/` directory exists and contains certificate files
2. **Creates Kubernetes secrets** from your certificate files using `kubectl`
3. Deploys the chart which references these pre-created secrets

## Files in This Directory

- The `certs/` directory is a symlink to `.devcontainer/certs/` to avoid duplicating certificate files
- `crucible-dev.*` certificates are automatically generated when the devcontainer is created
- Custom CA certificates (like `proxy-ca.crt`) should be placed in `.devcontainer/certs/`
- The CA ConfigMap will include ALL `.crt` files from the certs directory

### Configuration Files

crucible-realm.json   - Keycloak realm configuration for Crucible. This is a copy of the version from `Crucible.AppHost/resources/crucible-realm.json` because App URLs need to be different between Aspire and helm.

## Certificate Generation

### Development Certificates (Automatic)

The `crucible-dev.crt` and `crucible-dev.key` certificates are **automatically generated** when the devcontainer is created by the `.devcontainer/postcreate.sh` script. You don't need to generate these manually.

### For Corporate Proxy CA Certificates

If you're behind a corporate proxy, place your corporate CA certificate in `.devcontainer/certs/`:

```bash
# Copy your corporate CA certificate
cp /path/to/corporate-ca.crt .devcontainer/certs/zscaler-ca.crt
```

**Note:** All certificate files in `.devcontainer/certs/` (except `.crt` extensions) are gitignored. The `certs` symlink in this directory IS committed to git.

## Troubleshooting

### Certificates Not Found

Check if the symlink exists and the certificate files are present:
```bash
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
# TLS secret
kubectl create secret tls crucible-cert \
  --cert=files/certs/crucible-dev.crt \
  --key=files/certs/crucible-dev.key \
  --dry-run=client -o yaml | kubectl apply -f -

# CA ConfigMap
kubectl create configmap crucible-ca-cert \
  --from-file=crucible-dev.crt=files/certs/crucible-dev.crt \
  --from-file=zscaler-ca.crt=files/certs/zscaler-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

# Local Files Directory

This directory stores configuration files and certificates for local development deployments of the Crucible stack.

## How It Works

When you run `./helm-charts/helm-deploy.sh`, the script automatically:
1. Checks for certificate files in both `.devcontainer/certs` and `.devcontainer/dev-certs` directories
2. **Creates Kubernetes secrets** from your certificate files using `kubectl`
3. Deploys the chart which references these pre-created secrets

## Certificate Locations

The deployment script accesses certificates directly from the `.devcontainer` directories:

- **`.devcontainer/dev-certs/`** - Development TLS certificates (`crucible-dev.crt`, `crucible-dev.key`)
  - Automatically generated when the devcontainer is created by `.devcontainer/postcreate.sh`
  - Used for TLS ingress on all Crucible services
- **`.devcontainer/certs/`** - Custom CA certificates (e.g., `zscaler-ca.crt` for corporate proxies)
  - User-provided certificates for special environments
  - Optional, only needed if behind a corporate proxy or using custom CAs

The CA ConfigMap (`crucible-ca-cert`) will include ALL `.crt` files from both directories.

## Configuration Files

- **`crucible-realm.json`** - Keycloak realm configuration for Crucible
  - This is a copy of the version from `Crucible.AppHost/resources/crucible-realm.json`
  - App URLs are different between Aspire and Helm deployments

## Certificate Generation

### Development Certificates (Automatic)

The `crucible-dev.crt` and `crucible-dev.key` certificates are **automatically generated** when the devcontainer is created by the `.devcontainer/postcreate.sh` script. You don't need to generate these manually. These are stored in `.devcontainer/dev-certs/`.

### For Corporate Proxy CA Certificates

If you're behind a corporate proxy, place your corporate CA certificate in `.devcontainer/certs/`:

```bash
# Copy your corporate CA certificate
cp /path/to/corporate-ca.crt .devcontainer/certs/zscaler-ca.crt
```

**Note:** Certificate files with `.crt` and `.key` extensions are gitignored in both `.devcontainer/certs/` and `.devcontainer/dev-certs/` directories.

## Troubleshooting

### Certificates Not Found

Check if certificate files are present in the certificate directories:
```bash
ls -la /workspaces/crucible-development/.devcontainer/dev-certs/
ls -la /workspaces/crucible-development/.devcontainer/certs/
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

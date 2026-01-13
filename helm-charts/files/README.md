# Local Files Directory

This directory stores configuration files and certificates for local development deployments of the Crucible stack.

## How It Works

When you run `./helm-charts/helm-deploy.sh`, the script automatically:
1. Checks if this `files/` directory exists and contains certificate files
2. **Creates Kubernetes secrets** from your certificate files using `kubectl`
3. Deploys the chart which references these pre-created secrets

## Files in This Directory

### Certificate Files

Place certificate files here for TLS and CA trust:

```
/workspaces/crucible-development/helm-charts/files/
├── crucible-dev.crt      # Development TLS certificate
├── crucible-dev.key      # Development TLS private key
├── zscaler-ca.crt        # Corporate proxy CA certificate (if needed)
└── ...                   # Any other CA certificates (.crt, .pem, .cer)
```

**Note**: The CA ConfigMap will include ALL `.crt`, `.pem`, and `.cer` files from this directory.

### Configuration Files

```
/workspaces/crucible-development/helm-charts/files/
└── crucible-realm.json   # Keycloak realm configuration for Crucible
```

## Certificate Generation

### For Self-Signed Development Certificates

```bash
# Generate a self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout crucible-dev.key \
  -out crucible-dev.crt \
  -subj "/CN=crucible.local/O=Development"

# Set appropriate permissions
chmod 600 crucible-dev.key
chmod 644 crucible-dev.crt
```

### For Corporate Proxy CA Certificates

If you're behind a corporate proxy:

```bash
# Copy your corporate CA certificate
cp /path/to/corporate-ca.crt proxy-ca.crt
```

**Note:** All certificates other than `crucible-dev` are gitignored and will not be committed to the repo

## Values File Configuration

Your values file at `/workspaces/crucible-development/helm-charts/crucible-infra.values.yaml` should reference the pre-created secrets:

```yaml
tls:
  create: false  # Don't create - use existing secret created by helm-deploy.sh
  secretName: "crucible-cert"

caCerts:
  create: false  # Don't create - use existing ConfigMap created by helm-deploy.sh
  configMapName: "crucible-ca-cert"
```

**Important:** Set `create: false` because the secrets are created by helm-deploy.sh **before** the chart is deployed.

## Troubleshooting

### Certificates Not Found

Check if the directory exists and contains files:
```bash
ls -la /workspaces/crucible-development/helm-charts/files/
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

If needed, you can manually create the secrets:
```bash
# TLS secret
kubectl create secret tls crucible-cert \
  --cert=files/crucible-dev.crt \
  --key=files/crucible-dev.key \
  --dry-run=client -o yaml | kubectl apply -f -

# CA ConfigMap
kubectl create configmap crucible-ca-cert \
  --from-file=crucible-dev.crt=files/crucible-dev.crt \
  --from-file=zscaler-ca.crt=files/zscaler-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

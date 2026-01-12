# Local Certificates Directory

This directory stores certificate files for local development deployments of the crucible-infra chart.

## How It Works

When you run `./helm-charts/helm-deploy.sh --infra`, the script automatically:
1. Checks if this `certs/` directory exists and contains certificate files
2. **Creates Kubernetes secrets** from your certificate files using `kubectl`
3. Deploys the chart which references these pre-created secrets

## Certificate Files

Place certificate files here. You can add any number of CA certificate files with any names:

```
/workspaces/crucible-development/helm-charts/certs/
├── crucible-dev.crt      # Development TLS certificate
├── crucible-dev.key      # Development TLS private key
├── proxy-ca.crt          # Corporate proxy CA certificate (if needed)
├── internal-ca.pem       # Additional CA certificate (optional)
└── ...                   # Any other CA certificates (.crt, .pem, .cer)
```

**Note**: The CA ConfigMap will include ALL `.crt`, `.pem`, and `.cer` files from this directory.

## If You Need to Generate New Certificates

For development/testing with self-signed certificates:

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

## For Corporate Proxy CA Certificates

If you're behind a corporate proxy (like Zscaler):

```bash
# Copy your corporate CA certificate
cp /path/to/corporate-ca.crt zscaler-ca.crt
```

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
ls -la /workspaces/crucible-development/helm-charts/certs/
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
  --cert=certs/crucible-dev.crt \
  --key=certs/crucible-dev.key \
  --dry-run=client -o yaml | kubectl apply -f -

# CA ConfigMap
kubectl create configmap crucible-ca-cert \
  --from-file=crucible-dev.crt=certs/crucible-dev.crt \
  --from-file=zscaler-ca.crt=certs/zscaler-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
```

# Minikube Deployment

This directory contains scripts and values files for deploying and managing the Crucible stack on Minikube using Helm charts.

After running this script, you will have a full Crucible deployment that uses the values files in this directory and the umbrella charts for [crucible-apps](https://github.com/cmu-sei/helm-charts/tree/main/charts/crucible-apps), [crucible-infra](https://github.com/cmu-sei/helm-charts/tree/main/charts/crucible-infra), and [crucible-monitoring](https://github.com/cmu-sei/helm-charts/tree/main/charts/crucible-monitoring). The script will print URLs to access all of the web applications that are running in Minikube and configure port-forwarding to support browsing those sites from your host. **You will need to configure a hosts file entry on your host in order to browse the sites - configure the `crucible` hostname to resolve to `127.0.0.1` to allow the port-forwarding to handle traffic direction to the minikube ingress.**

## Scripts Overview

### crucible-deploy.sh

Deploys the Crucible stack to Minikube using Helm charts.

**Purpose**: Main deployment script that orchestrates the installation of Crucible infrastructure, applications, and monitoring components to a Minikube cluster.

**Key Features**:
- Deploys four chart releases in order: `crucible-operators` → `crucible-infra` → `crucible-apps` → `crucible-monitoring`
- Manages Kubernetes secrets and ConfigMaps for TLS certificates and Keycloak realm configuration
- Configures CoreDNS for internal hostname resolution
- Sets up port forwarding for accessing web applications from the host
- Supports selective deployment (infrastructure only, apps only, monitoring only, or any combination)
- Handles chart dependency building and updates
- Provides cluster lifecycle management (create, delete, purge)

**Options**:
```
--update-charts    Forces rebuilding Helm chart dependencies
--purge            Deletes and recreates the minikube cluster before deploying
--delete           Deletes and restarts minikube using cached artifacts
--local            Use local chart files instead of the SEI Helm repository
--operators        Deploy crucible-operators chart (can be combined with other flags)
--infra            Deploy crucible-infra chart (can be combined with other flags)
--apps             Deploy crucible-apps chart (can be combined with other flags)
--monitoring       Deploy crucible-monitoring chart (can be combined with other flags)
```

**Default Behavior**: Without any chart selection flags, all four charts are deployed.

**Examples**:
```bash
# Deploy everything (operators + infra + apps + monitoring)
./crucible-deploy.sh

# Deploy only infrastructure
./crucible-deploy.sh --infra

# Deploy infrastructure and applications (skip monitoring)
./crucible-deploy.sh --infra --apps

# Rebuild chart dependencies and deploy
./crucible-deploy.sh --update-charts

# Clean slate deployment (fresh minikube cluster)
./crucible-deploy.sh --purge

```

**Environment Variables**:
- `HELM_DEPLOY_FLAGS` - Additional flags for helm upgrade/install (default: `--server-side=false`)

**What It Does**:
1. **Pre-deployment**:
   - Validates and builds Helm chart dependencies if needed
   - Ensures Minikube cluster is running (starts it if not)
   - Stages custom CA certificates for Minikube nodes

2. **Operator Deployment** (`crucible-operators`):
   - Installs the Keycloak Operator and CloudNative-PG Operator
   - Waits for operators to become available before proceeding

3. **Infrastructure Deployment** (`crucible-infra`):
   - Creates TLS secrets from certificate files in `files/` directory
   - Creates CA certificate ConfigMaps for trust chain
   - Deploys CNPG PostgreSQL cluster, pgAdmin, ingress-nginx, and NFS storage provisioner
   - Waits for CNPG PostgreSQL cluster to reach Ready state
   - Configures CoreDNS with ingress controller IP for hostname resolution

4. **Application Deployment** (`crucible-apps`):
   - Deploys Keycloak (via Keycloak Operator CR), Player, Caster, Alloy, TopoMojo, Steamfitter, CITE, Gallery, Blueprint, Gameboard, and Moodle
   - Auto-generates a Keycloak realm with OIDC client secrets
   - Configures each service with database connections and OAuth integration

5. **Monitoring Deployment** (`crucible-monitoring`):
   - Deploys Prometheus, Grafana, Loki, Tempo, and Grafana Alloy for observability
   - Configures Grafana with Keycloak authentication

6. **Post-deployment**:
   - Sets up port forwarding (host port 443 → ingress controller)
   - Prints web application URLs for easy navigation
   - Displays Keycloak admin and pgAdmin credentials

### build-and-load-image.sh

Builds a Docker image locally and loads it into the Minikube cache.

**Purpose**: Enables rapid development iteration by building application Docker images locally and loading them directly into Minikube without pushing to a remote registry.

**Usage**:
```bash
./build-and-load-image.sh <repo_path> [image_tag]
```

**Arguments**:
- `repo_path` - Path to the source repository that contains a Dockerfile
- `image_tag` - Name:tag to apply when building and loading into Minikube (optional, defaults to `<repo_dir_basename>:local-dev`)

**Environment Variables**:
- `MINIKUBE_PROFILE` - Minikube profile name (default: `minikube`)
- ``CA_CERT_PATHS` - Comma-separated paths to custom CA certificates to trust during build (default: all .crt files from both .devcontainer/certs and .devcontainer/dev-certs)

**What It Does**:
1. Validates that the repository path exists and contains a Dockerfile
2. If a custom CA certificate is specified, creates a temporary Dockerfile that:
   - Extends the original Dockerfile with CA trust stages
   - Copies the CA certificate into the build and production stages
   - Updates CA certificates in both stages
3. Builds the Docker image using BuildKit
4. Loads the built image into Minikube's image cache
5. Outputs Helm values snippet for referencing the local image

**Example**:
```bash
# Build player-api with custom tag
./build-and-load-image.sh /mnt/data/crucible/player-api player-api:my-feature

# Build with default tag
./build-and-load-image.sh /mnt/data/crucible/caster-api

# Output includes a snippet like:
# image:
#   repository: caster-api
#   tag: local-dev
#   pullPolicy: Never
```

**Use Case**: When developing Crucible services, this script allows you to:
- Build changes locally
- Load them into Minikube
- Update your Helm values file with `pullPolicy: Never`
- Redeploy the service with `./crucible-deploy.sh --apps`

### clean-postgres.sh

Ensures all Minikube PostgreSQL data is deleted for a fresh deployment.

**Purpose**: Completely removes PostgreSQL data including StatefulSets, PVCs, PVs, and hostPath storage to guarantee a clean database state for the next deployment.

**Usage**:
```bash
./clean-postgres.sh
```

**Note**: Requires postgres to still be running in Minikube.

**Environment Variables**:
- `CRUCIBLE_RELEASE` - Helm release name for infrastructure (default: `crucible-infra`)
- `CRUCIBLE_NAMESPACE` - Kubernetes namespace (default: `default`)

**What It Does**:
1. Locates the PostgreSQL StatefulSet for the specified release
2. Identifies all PVCs (PersistentVolumeClaims) owned by the StatefulSet
3. Collects PV (PersistentVolume) and hostPath information before deletion
4. Deletes the StatefulSet and waits for all pods to terminate
5. Deletes all associated PVCs
6. Deletes the bound PVs
7. Removes hostPath data from the Minikube node (only for paths matching `/tmp/hostpath-provisioner/*`)
8. Leaves the cluster ready for a fresh Helm deployment with clean PostgreSQL storage

**When to Use**:
- After database schema changes that require migration testing
- When you need to test database initialization scripts
- To resolve persistent database corruption or lock issues
- Before major version upgrades of PostgreSQL
- When database state prevents proper application startup

**Example Workflow**:
```bash
# Clean existing database
./clean-postgres.sh

# Redeploy with fresh database
./crucible-deploy.sh --infra

# Or uninstall first for complete clean slate
./clean-postgres.sh
./crucible-deploy.sh --uninstall && ./crucible-deploy.sh
```

## Additional Resources

- **crucible-infra.values.yaml** - Infrastructure chart values (CNPG PostgreSQL, ingress-nginx, NFS storage)
- **crucible-apps.values.yaml** - Application chart values (Keycloak, microservices)
- **crucible-monitoring.values.yaml** - Monitoring chart values (Prometheus, Grafana, Loki, Tempo, Alloy)

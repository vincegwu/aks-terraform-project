# 💻 Azure Kubernetes Service (AKS) Terraform Project – Developer Guide

This comprehensive guide covers development workflows, CI/CD pipelines, local development setup, and best practices for working with the AKS infrastructure and applications.

---

## 🎯 Overview

The project uses a **two-stage automated CI/CD pipeline** with GitHub Actions:

1. **Infrastructure Deployment** - Deploys Azure resources using Terraform
2. **Application Deployment** - Builds Docker images and deploys to AKS

Developers can work using:
- **GitHub Actions** (recommended for all environments)
- **Local development** (for Dev environment only)

---

## 🚀 Quick Start for Developers

### For Application Development

1. Fork/clone the application repository: `pravinmishraaws/book-review-app`
2. Make changes to backend/frontend code
3. Test locally using Docker Compose
4. Push changes to trigger CI/CD pipeline
5. Monitor deployment in GitHub Actions

### For Infrastructure Changes

1. Clone this repository: `aks-terraform-project`
2. Create feature branch
3. Modify Terraform modules in `modules/` or environment configs in `envs/`
4. Create Pull Request (triggers validation workflow)
5. Merge to `main` (auto-deploys to Dev)
6. Manually promote to Stage/Prod via GitHub Actions

---

## 📋 Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Azure CLI** | Latest | Azure resource management | [Install Guide](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| **kubectl** | ≥1.28 | Kubernetes cluster management | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| **Terraform** | ≥1.7.5 | Infrastructure as Code | [Install Guide](https://www.terraform.io/downloads) |
| **Docker** | Latest | Container building and testing | [Install Guide](https://docs.docker.com/get-docker/) |
| **Git** | Latest | Version control | [Install Guide](https://git-scm.com/downloads) |

### Optional Tools

| Tool | Purpose |
|------|---------|
| **Helm** | Kubernetes package management |
| **k9s** | Terminal UI for Kubernetes |
| **Azure CLI Extensions** | `aks-preview`, `application-insights` |

### Azure Permissions

**For Local Development (Dev only):**
- `Contributor` role on resource group
- `AcrPush` role on ACR
- `Azure Kubernetes Service Cluster User Role` on AKS

**For GitHub Actions (all environments):**
- Service Principal with `Contributor` at subscription level
- See [DEPLOYMENT.md](DEPLOYMENT.md) for secret configuration

---

## 🔄 GitHub Actions CI/CD Pipeline

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     INFRASTRUCTURE PIPELINE                      │
│                (aks-terraform-pipeline.yml)                      │
├─────────────────────────────────────────────────────────────────┤
│ Trigger: Push to main / PR / Manual                             │
│                                                                  │
│ ┌─────────────┐    ┌──────────────┐    ┌──────────────┐       │
│ │  Validate   │ -> │     Plan     │ -> │    Apply     │       │
│ │  Format     │    │   Generate   │    │   Deploy     │       │
│ │  Check      │    │   tfplan     │    │ Infrastructure│       │
│ └─────────────┘    └──────────────┘    └──────┬───────┘       │
└────────────────────────────────────────────────┼───────────────┘
                                                  │ Auto-trigger
                                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION PIPELINE                          │
│                   (app-deployment.yml)                           │
├─────────────────────────────────────────────────────────────────┤
│ Trigger: Auto (on infra success) / Manual                       │
│                                                                  │
│ ┌──────────────────┐           ┌─────────────────┐             │
│ │ Build & Push     │           │  Deploy to AKS  │             │
│ │ - Clone app repo │  ──────>  │  - Get AKS creds│             │
│ │ - Build images   │           │  - Update K8s   │             │
│ │ - Push to ACR    │           │  - Apply configs│             │
│ └──────────────────┘           │  - Expose app   │             │
│                                 └─────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

### Infrastructure Pipeline Details

**File:** `.github/workflows/aks-terraform-pipeline.yml`

**Jobs:**

1. **terraform-validate** (Matrix: dev, stage, prod)
   - Checkout code
   - Setup Terraform 1.7.5
   - Format check: `terraform fmt -check -recursive`
   - Validate: `terraform validate`

2. **terraform-plan**
   - Setup Terraform and Azure authentication
   - Determine environment (auto=dev, manual=selected)
   - Initialize with remote backend (Azure Storage)
   - Generate plan: `terraform plan -var-file=envs/<env>/terraform.tfvars`
   - Upload plan artifact

3. **terraform-apply**
   - Download plan artifact
   - Apply plan: `terraform apply tfplan`
   - Export outputs to JSON (ACR, AKS, MySQL details)
   - Upload state artifact
   - **Trigger application deployment** automatically

**Triggers:**
- **Push to `main`**: Auto-deploys Dev
- **Pull Request**: Validation only (no apply)
- **Manual (`workflow_dispatch`)**: Choose environment

### Application Pipeline Details

**File:** `.github/workflows/app-deployment.yml`

**Configuration:**
```yaml
env:
  FRONTEND_PATH: './book-review-app/frontend'
  BACKEND_PATH: './book-review-app/backend'
  K8S_PATH: './k8s'
```

**Jobs:**

1. **build-and-push-images**
   - Download Terraform outputs from infrastructure run
   - Clone application repo: `pravinmishraaws/book-review-app`
   - Extract ACR details from Terraform outputs
   - Login to Azure and ACR
   - Build Docker images:
     - Backend: `docker build -t <acr>/book-review-backend:<tag> ./backend`
     - Frontend: `docker build -t <acr>/book-review-frontend:<tag> ./frontend`
   - Push images to ACR
   - Verify images in registry

2. **deploy-to-aks**
   - Get AKS credentials using Terraform outputs
   - Update K8s manifests with:
     - ACR image paths
     - MySQL FQDN from Terraform
   - Create Kubernetes namespace: `book-review-<env>`
   - Create secrets (MySQL credentials)
   - Deploy ConfigMaps
   - Deploy backend (deployment + service)
   - Deploy frontend (deployment + LoadBalancer service)
   - Wait for pods to be ready
   - Get and display application URL

**Triggers:**
- **Automatically** by infrastructure pipeline on success
- **Manual (`workflow_dispatch`)** with options:
  - Environment selection
  - Custom image tags
  - Custom app repository/branch

### Running Workflows Manually

#### Deploy Infrastructure

1. Navigate to **Actions** > **Infrastructure Deployment**
2. Click **Run workflow**
3. Select branch: `main`
4. Choose environment: `dev`, `stage`, or `prod`
5. Click **Run workflow**

**What Happens:**
- Validates Terraform code
- Generates and applies plan
- Deploys all Azure resources
- Auto-triggers application deployment

#### Deploy Application Only

1. Navigate to **Actions** > **Application Deployment**
2. Click **Run workflow**
3. Configure:
   - **Environment**: `dev`, `stage`, or `prod`
   - **Frontend tag**: `latest`, `v1.2.3`, or custom
   - **Backend tag**: `latest`, `v1.2.3`, or custom
   - **Run ID**: Leave blank (uses latest infra)
   - **App Repository**: Default or custom fork
   - **App Branch**: Default `main` or feature branch
4. Click **Run workflow**

**Use Cases:**
- Redeploy application with new image tags
- Deploy from feature branch for testing
- Rollback to previous version
- Deploy custom fork of application

---

## 💻 Local Development Workflow

### 1. Initial Setup

```bash
# Clone infrastructure repo
git clone https://github.com/<your-org>/aks-terraform-project.git
cd aks-terraform-project

# Clone application repo (optional, for local development)
git clone https://github.com/pravinmishraaws/book-review-app.git

# Login to Azure
az login
az account set --subscription <subscription-id>

# Configure kubectl (if AKS already deployed)
az aks get-credentials \
  --resource-group cloudproj-dev-rg \
  --name cloudproj-dev-aks
```

### 2. Environment Configuration

#### Remote State Backend

The project uses **Azure Storage** for remote state with locking:

```bash
# Initialize with backend
terraform init \
  -backend-config="resource_group_name=terraform-state-rg" \
  -backend-config="storage_account_name=tfstate1234" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev/terraform.tfstate"
```

**State Files by Environment:**
- Dev: `dev/terraform.tfstate`
- Stage: `stage/terraform.tfstate`
- Prod: `prod/terraform.tfstate`

See [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed backend configuration.

#### Environment Variables

Set these for Terraform Azure provider:

```bash
# Option 1: Use Azure CLI authentication (recommended for local)
az login

# Option 2: Use service principal (for automation)
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"

# Option 3: Set backend access key
export ARM_ACCESS_KEY="<storage-account-key>"
```

### 3. Working with Terraform (Local Dev Only)

⚠️ **Important:** Local Terraform operations should only be used for **Dev environment**. Use GitHub Actions for Stage and Prod.

#### Deploying Infrastructure

```bash
# Initialize backend
terraform init -backend-config="key=dev/terraform.tfstate"

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes
terraform plan -var-file="envs/dev/terraform.tfvars" -out=tfplan

# Review plan carefully, then apply
terraform apply tfplan

# Or use wrapper script (auto-loads correct tfvars)
./scripts/terraform.sh plan
./scripts/terraform.sh apply -auto-approve
```

#### Making Infrastructure Changes

1. **Create feature branch:**
   ```bash
   git checkout -b feature/add-application-gateway
   ```

2. **Make changes** in `modules/` or root `.tf` files

3. **Test changes:**
   ```bash
   terraform fmt -recursive
   terraform validate
   terraform plan -var-file="envs/dev/terraform.tfvars"
   ```

4. **Create Pull Request:**
   - Push branch to GitHub
   - Create PR to `main`
   - GitHub Actions validates code automatically
   - Review validation results

5. **Merge and Deploy:**
   - Merge PR to `main`
   - Auto-deploys to Dev
   - Manually deploy to Stage/Prod via Actions

---

## 🎮 Working with Kubernetes (AKS)

### Connecting to AKS Cluster

#### Option 1: Using Utility Script

```bash
./scripts/get-kubeconfig.sh cloudproj-dev-rg cloudproj-dev-aks
```

#### Option 2: Direct Azure CLI

```bash
az aks get-credentials \
  --resource-group cloudproj-dev-rg \
  --name cloudproj-dev-aks \
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Useful kubectl Commands

#### Viewing Resources

```bash
# Get all resources in namespace
kubectl get all -n book-review-dev

# Get pods with detailed info
kubectl get pods -n book-review-dev -o wide

# Describe pod (for troubleshooting)
kubectl describe pod <pod-name> -n book-review-dev

# View pod logs
kubectl logs -f <pod-name> -n book-review-dev

# View logs for all pods with label
kubectl logs -l app=book-review -n book-review-dev --tail=100 -f

# Get services and external IPs
kubectl get svc -n book-review-dev
```

#### Debugging

```bash
# Execute command in pod
kubectl exec -it <pod-name> -n book-review-dev -- /bin/sh

# Port forward service to local machine
kubectl port-forward svc/book-review-backend 8080:8080 -n book-review-dev

# Get events (shows recent activities/errors)
kubectl get events -n book-review-dev --sort-by='.lastTimestamp'

# Check pod resource usage
kubectl top pods -n book-review-dev
kubectl top nodes
```

#### Managing Deployments

```bash
# Scale deployment
kubectl scale deployment book-review-backend --replicas=3 -n book-review-dev

# Update image
kubectl set image deployment/book-review-backend \
  backend=<acr>.azurecr.io/book-review-backend:v1.2.3 \
  -n book-review-dev

# Rollback deployment
kubectl rollout undo deployment/book-review-backend -n book-review-dev

# Check rollout status
kubectl rollout status deployment/book-review-backend -n book-review-dev

# View rollout history
kubectl rollout history deployment/book-review-backend -n book-review-dev
```

---

## 🐳 Working with Azure Container Registry (ACR)

### Authenticating to ACR

```bash
# Get ACR name from Terraform output
ACR_NAME=$(terraform output -raw acr_name)

# Login to ACR
az acr login --name $ACR_NAME

# Verify login
docker info | grep Username
```

### Building and Pushing Images Locally

```bash
# Clone application repo
cd book-review-app

# Build backend image
docker build -t $ACR_NAME.azurecr.io/book-review-backend:local ./backend

# Build frontend image
docker build -t $ACR_NAME.azurecr.io/book-review-frontend:local ./frontend

# Push images
docker push $ACR_NAME.azurecr.io/book-review-backend:local
docker push $ACR_NAME.azurecr.io/book-review-frontend:local
```

### Managing Images

```bash
# List repositories
az acr repository list --name $ACR_NAME --output table

# List tags for repository
az acr repository show-tags \
  --name $ACR_NAME \
  --repository book-review-backend \
  --output table

# Delete specific tag
az acr repository delete \
  --name $ACR_NAME \
  --image book-review-backend:old-tag \
  --yes

# Pull image for local testing
docker pull $ACR_NAME.azurecr.io/book-review-backend:latest
docker run -p 8080:8080 $ACR_NAME.azurecr.io/book-review-backend:latest
```

### ACR Security

- **RBAC Roles:**
  - `AcrPull` - Read-only access (pull images)
  - `AcrPush` - Push and pull images
  - `AcrDelete` - Delete images
  - `Owner` - Full access

```bash
# Grant ACR push access to user
az role assignment create \
  --assignee <user-email> \
  --role AcrPush \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>
```

---

## 🗄️ Working with MySQL Database

### Database Access (Dev Environment)

**Network Configuration:**
- MySQL resides in **private subnet** with **private endpoint**
- No public access - accessible only from within VNet
- Traffic stays on Azure backbone

**Security:**
- Credentials stored in **Azure Key Vault** and **GitHub Secrets**
- Access restricted by NSG rules
- SSL/TLS enforced for connections

#### Accessing MySQL from AKS Pod

```bash
# Get MySQL FQDN from Terraform outputs
MYSQL_FQDN=$(terraform output -raw mysql_fqdn)

# Run temporary MySQL client pod
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -n book-review-dev \
  -- bash

# Inside the pod
mysql -h $MYSQL_FQDN -u adminuser -p
# Enter password when prompted

# Once connected
SHOW DATABASES;
USE book_review_db;
SHOW TABLES;
SELECT * FROM users LIMIT 10;
EXIT;
```

#### Accessing MySQL from Local Machine

⚠️ **Not recommended for Dev** - Use kubectl port-forward for testing:

```bash
# Port forward through a pod
kubectl run mysql-proxy --image=alpine/socat \
  -n book-review-dev \
  -- tcp-listen:3306,fork,reuseaddr tcp-connect:$MYSQL_FQDN:3306

kubectl port-forward mysql-proxy 3306:3306 -n book-review-dev

# In another terminal
mysql -h 127.0.0.1 -P 3306 -u adminuser -p
```

#### Managing Database

```bash
# Create database
CREATE DATABASE book_review_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Grant permissions
GRANT ALL PRIVILEGES ON book_review_db.* TO 'adminuser'@'%';
FLUSH PRIVILEGES;

# Backup database
kubectl exec -it <backend-pod> -n book-review-dev -- \
  mysqldump -h $MYSQL_FQDN -u adminuser -p book_review_db > backup.sql

# Restore database
kubectl exec -i <backend-pod> -n book-review-dev -- \
  mysql -h $MYSQL_FQDN -u adminuser -p book_review_db < backup.sql
```

---

## 🚀 Application Development Workflow

### Local Development

1. **Clone application repository:**
   ```bash
   git clone https://github.com/pravinmishraaws/book-review-app.git
   cd book-review-app
   ```

2. **Develop locally with Docker Compose:**
   ```bash
   # Start services
   docker-compose up -d
   
   # View logs
   docker-compose logs -f
   
   # Stop services
   docker-compose down
   ```

3. **Make changes** to backend/frontend code

4. **Test changes locally**

5. **Commit and push:**
   ```bash
   git add .
   git commit -m "feat: add user authentication"
   git push origin main
   ```

### Deploying Changes to Dev

**Option 1: Via GitHub Actions (Recommended)**
- Push to `main` branch
- Infrastructure pipeline validates (if needed)
- Application pipeline auto-deploys

**Option 2: Manual Build and Deploy**
```bash
# Get ACR details
ACR_NAME=$(cd ../aks-terraform-project && terraform output -raw acr_name)

# Build and push
az acr login --name $ACR_NAME
docker build -t $ACR_NAME.azurecr.io/book-review-backend:dev-$(git rev-parse --short HEAD) ./backend
docker push $ACR_NAME.azurecr.io/book-review-backend:dev-$(git rev-parse --short HEAD)

# Update deployment
kubectl set image deployment/book-review-backend \
  backend=$ACR_NAME.azurecr.io/book-review-backend:dev-$(git rev-parse --short HEAD) \
  -n book-review-dev

# Watch rollout
kubectl rollout status deployment/book-review-backend -n book-review-dev
```

---

## 🔐 Security Best Practices

### Credentials Management

✅ **DO:**
- Store secrets in Azure Key Vault
- Use GitHub Secrets for CI/CD credentials
- Rotate service principal credentials quarterly
- Use managed identities where possible
- Use least-privilege RBAC roles

❌ **DON'T:**
- Commit secrets to Git (use `.gitignore`)
- Hardcode passwords in code
- Share credentials via email/chat
- Use same credentials across environments

### Network Security

- All resources deployed in private subnets
- NAT Gateway for controlled egress
- NSG rules restrict traffic
- MySQL uses private endpoint only
- AKS uses authorized IP ranges (if configured)

### Access Control

| Environment | Deployment Method | Access Level |
|-------------|-------------------|--------------|
| **Dev** | GitHub Actions or Local | Full access for developers |
| **Stage** | GitHub Actions only | Read-only for developers |
| **Prod** | GitHub Actions only | No developer access |

---

## 📊 Monitoring and Logging

### View Application Logs

```bash
# Application logs
kubectl logs -f deployment/book-review-backend -n book-review-dev
kubectl logs -f deployment/book-review-frontend -n book-review-dev

# System logs
kubectl logs -n kube-system -l component=kube-apiserver

# Events
kubectl get events -n book-review-dev --sort-by='.lastTimestamp' | head -20
```

### Azure Monitor (if enabled)

```bash
# View AKS insights in Azure Portal
az aks show \
  --resource-group cloudproj-dev-rg \
  --name cloudproj-dev-aks \
  --query "addonProfiles.omsAgent"
```

---

## 🛠️ Troubleshooting Guide

### Common Issues

#### Pod CrashLoopBackOff

```bash
# Check pod status
kubectl describe pod <pod-name> -n book-review-dev

# View logs
kubectl logs <pod-name> -n book-review-dev --previous

# Common causes:
# - Wrong image tag
# - Missing environment variables
# - Database connection failure
# - Application error on startup
```

#### ImagePullBackOff

```bash
# Check if image exists in ACR
az acr repository show-tags --name $ACR_NAME --repository book-review-backend

# Verify ACR access
az acr login --name $ACR_NAME

# Check AKS has ACR pull permission
az aks check-acr \
  --resource-group cloudproj-dev-rg \
  --name cloudproj-dev-aks \
  --acr $ACR_NAME.azurecr.io
```

#### Service Not Accessible

```bash
# Check service
kubectl get svc -n book-review-dev

# Check endpoints
kubectl get endpoints -n book-review-dev

# Check LoadBalancer
kubectl describe svc book-review-frontend -n book-review-dev

# If LoadBalancer stuck in pending, check NSG rules
```

#### Database Connection Failures

```bash
# Verify MySQL is running
az mysql flexible-server show \
  --resource-group cloudproj-dev-rg \
  --name cloudproj-dev-mysql-<suffix>

# Check from pod
kubectl exec -it <backend-pod> -n book-review-dev -- \
  ping -c 3 cloudproj-dev-mysql-<suffix>.mysql.database.azure.com

# Verify credentials in secrets
kubectl get secret book-review-secrets -n book-review-dev -o yaml
```

### Getting Help

1. **Check workflow logs** in GitHub Actions
2. **Review pod logs** with kubectl
3. **Check Azure Portal** for resource status
4. **Review Terraform state** for infrastructure issues
5. **Consult documentation:**
   - [DEPLOYMENT.md](DEPLOYMENT.md)
   - [BACKEND_SETUP.md](BACKEND_SETUP.md)
   - [APPLICATION_DEPLOYMENT.md](k8s/APPLICATION_DEPLOYMENT.md)

---

## ✅ Development Best Practices

### Code Quality

- ✅ Run `terraform fmt` before committing
- ✅ Run `terraform validate` to catch errors
- ✅ Use consistent naming conventions
- ✅ Add comments for complex logic
- ✅ Tag all resources appropriately

### Git Workflow

- ✅ Create feature branches for changes
- ✅ Write descriptive commit messages
- ✅ Create PRs for code review
- ✅ Keep commits atomic and focused
- ✅ Never commit secrets or credentials

### Testing

- ✅ Test infrastructure changes in Dev first
- ✅ Validate application locally before deploying
- ✅ Monitor deployments in GitHub Actions
- ✅ Check pod logs after deployment
- ✅ Verify application functionality

### Deployment Strategy

| Change Type | Recommended Approach |
|-------------|---------------------|
| **Infrastructure** | GitHub Actions for all envs |
| **Application code** | GitHub Actions (auto-deploy) |
| **Quick hotfix** | Manual deployment to Dev, then promote |
| **Config changes** | Update ConfigMaps/Secrets via kubectl |
| **Database schema** | Run migrations from backend pod |

### Environment Promotion

```
Dev (auto) → Stage (manual) → Prod (manual + approval)
```

1. **Dev:** Automatically deployed on push to `main`
2. **Stage:** Manual GitHub Actions trigger after Dev validation
3. **Prod:** Manual trigger with additional approval/review

---

## 📚 Additional Resources

### Documentation
- [DEPLOYMENT.md](DEPLOYMENT.md) - Comprehensive deployment guide
- [BACKEND_SETUP.md](BACKEND_SETUP.md) - Remote state configuration
- [BACKEND_QUICKSTART.md](BACKEND_QUICKSTART.md) - Quick start for backend
- [APPLICATION_DEPLOYMENT.md](k8s/APPLICATION_DEPLOYMENT.md) - K8s deployment details
- [Naming.md](Naming.md) - Resource naming conventions

### External Resources
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Kubernetes Service Docs](https://docs.microsoft.com/azure/aks/)
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Docker Documentation](https://docs.docker.com/)

### Useful Commands Cheat Sheet

```bash
# Terraform
terraform fmt -recursive
terraform validate
terraform plan -var-file=envs/dev/terraform.tfvars
terraform apply -var-file=envs/dev/terraform.tfvars
terraform output
terraform state list

# Azure CLI
az login
az account show
az aks get-credentials --resource-group <rg> --name <aks>
az acr login --name <acr>
az acr repository list --name <acr>

# kubectl
kubectl get all -n book-review-dev
kubectl logs -f deployment/<name> -n book-review-dev
kubectl describe pod <pod> -n book-review-dev
kubectl exec -it <pod> -n book-review-dev -- /bin/sh
kubectl port-forward svc/<service> 8080:8080 -n book-review-dev
kubectl scale deployment/<name> --replicas=3 -n book-review-dev

# Docker
docker build -t <image>:<tag> .
docker push <image>:<tag>
docker images
docker ps
docker logs <container>

# Git
git status
git add .
git commit -m "message"
git push origin <branch>
git checkout -b feature/<name>
```

---

## 🎓 Learning Path for New Developers

### Week 1: Setup and Basics
- [ ] Set up local development environment
- [ ] Clone repositories
- [ ] Configure Azure CLI and kubectl
- [ ] Review infrastructure code
- [ ] Explore GitHub Actions workflows

### Week 2: Hands-on Practice
- [ ] Deploy to Dev using GitHub Actions
- [ ] Access AKS cluster with kubectl
- [ ] View application logs
- [ ] Make minor code change and deploy
- [ ] Review monitoring and logs

### Week 3: Advanced Topics
- [ ] Make infrastructure change (add resource)
- [ ] Build Docker images locally
- [ ] Push images to ACR
- [ ] Update Kubernetes manifests
- [ ] Troubleshoot deployment issues

### Week 4: Production Readiness
- [ ] Understand security best practices
- [ ] Learn backup and recovery procedures
- [ ] Practice incident response
- [ ] Deploy to Stage environment
- [ ] Shadow a production deployment

---

This developer guide provides comprehensive information for working with the infrastructure and application pipelines. For deployment procedures, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Remote Backend Setup Guide

This section explains how to configure and use Azure Storage as a remote backend for Terraform state management with state locking.

### Why Remote Backend?

✅ **State Locking**: Prevents concurrent modifications  
✅ **Team Collaboration**: Shared state across team members  
✅ **State History**: Versioning and recovery via blob versioning  
✅ **Security**: Encrypted at rest, access controlled via Azure RBAC  
✅ **Disaster Recovery**: Centralized backup and geo-redundancy options  

### Quick Setup

#### Step 1: Run the Setup Script

```bash
# Run the automated setup script (bash)
./scripts/setup-remote-backend.sh

# Or with custom parameters (positional: resource-group storage-account container location)
./scripts/setup-remote-backend.sh \
  "my-tfstate-rg" \
  "mytfstate1234" \
  "tfstate" \
  "australiacentral"
```

This script will:
- Create Azure Storage Account with security best practices
- Enable blob versioning for state history
- Create containers for state files
- Generate backend configuration files
- Set environment variables for authentication

#### Step 2: Migrate Existing State (if you have local state)

```bash
# Backup your local state first
cp terraform.tfstate terraform.tfstate.local.backup

# Initialize with new backend (will prompt to migrate)
./scripts/terraform.sh init -reconfigure

# Or for specific environment
terraform init -reconfigure -backend-config=backend-configs/dev.tfbackend

# Terraform will ask: "Do you want to copy existing state to the new backend?"
# Answer: yes
```

#### Step 3: Verify Remote State

```bash
# List resources (should work from remote state)
terraform state list

# Check the Azure portal or CLI
az storage blob list \
  --account-name <storage-account-name> \
  --container-name tfstate \
  --output table
```

#### Step 4: Clean Up Local State Files

```bash
# After confirming remote state works, delete local files
rm terraform.tfstate
rm terraform.tfstate.backup
rm -rf terraform.tfstate.d/
```

### Backend Configuration Files

The setup creates environment-specific backend configs:

```
backend-configs/
├── dev.tfbackend       # Development state
├── stage.tfbackend     # Staging state
├── prod.tfbackend      # Production state
└── README.md
```

#### Example: dev.tfbackend
```hcl
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstate1234"
container_name       = "tfstate"
key                  = "dev/terraform.tfstate"
```

### Usage

#### Initialize with Backend

```bash
# Using helper script (auto-detects environment)
./scripts/terraform.sh init

# Manual initialization with specific environment
terraform init -backend-config=backend-configs/dev.tfbackend

# Reconfigure (switch backends or migrate state)
terraform init -reconfigure -backend-config=backend-configs/prod.tfbackend
```

#### Regular Operations

```bash
# Plan (uses remote state automatically)
./scripts/terraform.sh plan -var-file=envs/dev/terraform.tfvars

# Apply
./scripts/terraform.sh apply -var-file=envs/dev/terraform.tfvars

# State commands work with remote state
terraform state list
terraform state show azurerm_kubernetes_cluster.aks
```

### Authentication

#### Option 1: Access Key (Quick Start)

```powershell
# Set in current session
$env:ARM_ACCESS_KEY = "<storage-account-key>"

# Set permanently for user
[Environment]::SetEnvironmentVariable("ARM_ACCESS_KEY", "<key>", "User")
```

```bash
# Bash
export ARM_ACCESS_KEY="<storage-account-key>"
```

Get the key from:
```bash
az storage account keys list \
  --resource-group terraform-state-rg \
  --account-name <storage-account-name> \
  --query "[0].value" -o tsv
```

#### Option 2: Azure AD / Managed Identity (Recommended for Production)

Update `backend.tf`:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate1234"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true  # Use Azure AD instead of access key
  }
}
```

Grant permissions:
```bash
# Get your user object ID
USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign Storage Blob Data Contributor role
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $USER_ID \
  --scope "/subscriptions/<subscription-id>/resourceGroups/terraform-state-rg/providers/Microsoft.Storage/storageAccounts/<storage-account-name>"
```

#### Option 3: Service Principal (CI/CD)

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "terraform-backend-sp" \
  --role "Storage Blob Data Contributor" \
  --scopes "/subscriptions/<subscription-id>/resourceGroups/terraform-state-rg"

# Set in CI/CD pipeline
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

### State Locking

Azure Storage backend provides **automatic state locking** using blob leases:

```bash
# When you run terraform apply, the state file is locked
terraform apply

# If another user tries to run apply simultaneously:
# Error: Error acquiring the state lock
# Lock Info:
#   ID:        <lease-id>
#   Path:      tfstate/terraform.tfstate
#   Operation: OperationTypeApply
#   Who:       user@domain.com
#   Created:   2025-12-04 10:30:00
```

#### Force Unlock (Use with Caution)

```bash
# Only if lock is stuck after a crash
terraform force-unlock <lock-id>
```

### Multi-Environment Setup

#### Separate State Files per Environment

```
Container: tfstate
├── dev/terraform.tfstate
├── stage/terraform.tfstate
└── prod/terraform.tfstate
```

#### Switch Environments

```bash
# Initialize for dev
terraform init -backend-config=backend-configs/dev.tfbackend

# Plan for dev
./scripts/terraform.sh plan -var-file=envs/dev/terraform.tfvars

# Switch to production
terraform init -reconfigure -backend-config=backend-configs/prod.tfbackend

# Plan for production
./scripts/terraform.sh plan -var-file=envs/prod/terraform.tfvars
```

### State Management

#### View State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show azurerm_kubernetes_cluster.aks

# Pull state to local file (for inspection)
terraform state pull > current-state.json
```

#### Backup and Recovery

```bash
# Download specific state version
az storage blob download \
  --account-name <storage-account> \
  --container-name tfstate \
  --name dev/terraform.tfstate \
  --file terraform.tfstate.backup \
  --version-id <version-id>

# List all versions
az storage blob list \
  --account-name <storage-account> \
  --container-name tfstate \
  --include v \
  --query "[?name=='dev/terraform.tfstate'].{Name:name, VersionId:versionId, LastModified:properties.lastModified}" \
  --output table
```

#### Restore from Backup

```bash
# Push a specific version back as current state
terraform state push terraform.tfstate.backup
```

### Security Best Practices

#### Storage Account Configuration

✅ **Enabled by setup script:**
- HTTPS only
- Minimum TLS 1.2
- Blob versioning
- No public access
- Encryption at rest

#### Additional Hardening

```bash
# Enable soft delete (30-day recovery)
az storage account blob-service-properties update \
  --account-name <storage-account> \
  --enable-delete-retention true \
  --delete-retention-days 30

# Enable infrastructure encryption (double encryption)
az storage account update \
  --name <storage-account> \
  --resource-group terraform-state-rg \
  --encryption-key-source Microsoft.Storage \
  --require-infrastructure-encryption

# Restrict network access
az storage account update \
  --name <storage-account> \
  --resource-group terraform-state-rg \
  --default-action Deny

az storage account network-rule add \
  --account-name <storage-account> \
  --resource-group terraform-state-rg \
  --ip-address <your-ip>
```

### CI/CD Integration

#### GitHub Actions Example

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Terraform Init
      run: terraform init -backend-config=backend-configs/dev.tfbackend
      env:
        ARM_ACCESS_KEY: ${{ secrets.TF_STATE_ACCESS_KEY }}
    
    - name: Terraform Plan
      run: terraform plan -var-file=envs/dev/terraform.tfvars
      
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve -var-file=envs/dev/terraform.tfvars
```

#### Azure DevOps Example

```yaml
trigger:
  branches:
    include:
    - main

pool:
  vmImage: 'ubuntu-latest'

variables:
- group: terraform-backend-vars  # Contains ARM_ACCESS_KEY

steps:
- task: TerraformInstaller@0
  inputs:
    terraformVersion: 'latest'

- task: TerraformTaskV2@2
  displayName: 'Terraform Init'
  inputs:
    command: 'init'
    backendServiceArm: 'Azure-ServiceConnection'
    backendAzureRmResourceGroupName: 'terraform-state-rg'
    backendAzureRmStorageAccountName: 'tfstate1234'
    backendAzureRmContainerName: 'tfstate'
    backendAzureRmKey: 'dev/terraform.tfstate'

- task: TerraformTaskV2@2
  displayName: 'Terraform Plan'
  inputs:
    command: 'plan'
    commandOptions: '-var-file=envs/dev/terraform.tfvars'
```

### Troubleshooting Backend Issues

#### Error: Backend configuration changed

```bash
# Reinitialize backend
terraform init -reconfigure
```

#### Error: Failed to acquire state lock

```bash
# Check who has the lock
terraform plan
# Error will show lock info

# Force unlock (only if lock is stuck)
terraform force-unlock <lock-id>
```

#### Error: No valid credential sources

```bash
# Ensure ARM_ACCESS_KEY is set
echo $ARM_ACCESS_KEY

# Or use Azure AD authentication
az login
```

#### State file not found

```bash
# Check if state exists in storage
az storage blob exists \
  --account-name <storage-account> \
  --container-name tfstate \
  --name dev/terraform.tfstate

# Initialize if new environment
terraform init -backend-config=backend-configs/dev.tfbackend
```

### Migration Checklist

- [ ] Run `.\scripts\setup-remote-backend.ps1`
- [ ] Backup local state: `cp terraform.tfstate terraform.tfstate.local.backup`
- [ ] Review generated `backend.tf`
- [ ] Initialize: `terraform init -reconfigure`
- [ ] Confirm migration: Answer "yes" to copy state
- [ ] Verify: `terraform state list`
- [ ] Test: `terraform plan` (should see no changes)
- [ ] Clean up: `rm terraform.tfstate*`
- [ ] Update `.gitignore` (done by script)
- [ ] Share backend config with team
- [ ] Document authentication method for team

### Team Onboarding

Share with new team members:

1. **Storage Account Details:**
   - Resource Group: `terraform-state-rg`
   - Storage Account: `<storage-account-name>`
   - Container: `tfstate`

2. **Authentication:**
   ```powershell
   $env:ARM_ACCESS_KEY = "<get-from-team-lead>"
   ```

3. **Initialize:**
   ```bash
   terraform init -backend-config=backend-configs/dev.tfbackend
   ```

4. **Verify:**
   ```bash
   terraform state list
   ```

### References

- [Terraform Azure Backend Documentation](https://www.terraform.io/language/settings/backends/azurerm)
- [Azure Storage Security Best Practices](https://docs.microsoft.com/azure/storage/common/storage-security-guide)
- [State Locking](https://www.terraform.io/language/state/locking)
- See also: [BACKEND_SETUP.md](BACKEND_SETUP.md) and [BACKEND_QUICKSTART.md](BACKEND_QUICKSTART.md) for complete reference
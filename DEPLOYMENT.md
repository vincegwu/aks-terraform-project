# 🚀 Azure Kubernetes Service (AKS) Terraform Project

## DEPLOYMENT INSTRUCTIONS

This guide provides comprehensive deployment options for the **Dev**, **Stage**, and **Prod** environments. Choose between automated GitHub Actions workflows (recommended) or manual local deployments.

---

## 📋 Deployment Options

### Option A: GitHub Actions (Recommended) 🤖

Automated CI/CD deployment using GitHub Actions workflows for consistent, reproducible deployments.

### Option B: Manual Local Deployment 💻

Direct deployment from your workstation using Terraform CLI and wrapper scripts.

---

## 🤖 Option A: GitHub Actions Deployment

### Prerequisites

* **GitHub Repository** with the project code
* **Azure Service Principal** configured with required permissions
* **GitHub Secrets** configured (see Secret Configuration below)

### Required GitHub Secrets

Configure the following secrets in your GitHub repository (`Settings > Secrets and variables > Actions`):

| Secret Name | Description | Example/Format |
|------------|-------------|----------------|
| `AZURE_CREDENTIALS` | Azure service principal credentials (JSON format) | `{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}` |
| `AZURE_CLIENT_ID` | Azure service principal client ID | `12345678-1234-1234-1234-123456789abc` |
| `AZURE_CLIENT_SECRET` | Azure service principal client secret | `your-client-secret` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `12345678-1234-1234-1234-123456789abc` |
| `AZURE_TENANT_ID` | Azure tenant ID | `12345678-1234-1234-1234-123456789abc` |
| `TF_BACKEND_RESOURCE_GROUP` | Terraform backend resource group | `terraform-state-rg` |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform backend storage account | `tfstate1234` |
| `TF_BACKEND_CONTAINER` | Terraform backend container name | `tfstate` |
| `MYSQL_ADMIN_USERNAME` | MySQL administrator username | `adminuser` |
| `MYSQL_ADMIN_PASSWORD` | MySQL administrator password | `StrongPassword123!` |

### Workflow Chain

The project uses a two-stage automated workflow:

```
Push to main → Infrastructure Deploy → Application Deploy (auto-triggered) → Manual Destroy
```

#### 1. Infrastructure Deployment Workflow

**File:** `.github/workflows/aks-terraform-pipeline.yml`

**Triggers:**
- **Push to `main` branch** (auto-deploys to `dev`)
- **Pull Request** (validation only, no deployment)
- **Manual trigger via `workflow_dispatch`** (choose environment)

**Jobs:**
1. **Terraform Validation** - Format check, init, and validate
2. **Terraform Plan** - Generate execution plan with remote state
3. **Terraform Apply** - Deploy infrastructure and export outputs
4. **Trigger Application Deployment** - Automatically calls app-deployment workflow

**Manual Deployment:**
1. Go to **Actions** tab in GitHub
2. Select **Infrastructure Deployment** workflow
3. Click **Run workflow**
4. Choose environment (`dev`, `stage`, or `prod`)
5. Click **Run workflow** button

**Automatic Deployment:**
- Push changes to `main` branch
- Workflow automatically deploys to `dev` environment
- Application deployment is auto-triggered on success

#### 2. Application Deployment Workflow

**File:** `.github/workflows/app-deployment.yml`

**Triggers:**
- **Automatically triggered** by Infrastructure Deployment on success
- **Manual trigger via `workflow_dispatch`** (for redeployments)

**Configuration:**
- **Application Repository:** `pravinmishraaws/book-review-app` (configurable)
- **Application Branch:** `main` (configurable)
- **Dockerfile Paths:** 
  - Backend: `book-review-app/backend/Dockerfile`
  - Frontend: `book-review-app/frontend/Dockerfile`

**Jobs:**
1. **Build and Push Images**
   - Clones application repository
   - Builds Docker images for frontend and backend
   - Pushes images to Azure Container Registry (ACR)
   - Exports infrastructure details

2. **Deploy to AKS**
   - Gets AKS credentials from Terraform outputs
   - Updates Kubernetes manifests with image tags and MySQL FQDN
   - Creates namespace and secrets
   - Deploys backend and frontend services
   - Exposes frontend via LoadBalancer (gets public IP)

**Manual Application Redeployment:**
1. Go to **Actions** tab in GitHub
2. Select **Application Deployment** workflow
3. Click **Run workflow**
4. Configure:
   - Environment: `dev`, `stage`, or `prod`
   - Frontend image tag: `latest` or custom tag
   - Backend image tag: `latest` or custom tag
   - Application repository (optional): `owner/repo`
   - Application branch (optional): `main`
5. Click **Run workflow**

### Deployment Workflow Results

After successful deployment, check the workflow run logs for:
- ✅ **ACR Login Server:** `<acr-name>.azurecr.io`
- ✅ **AKS Cluster Name:** `cloudproj-<env>-aks`
- ✅ **Resource Group:** `cloudproj-<env>-rg`
- ✅ **MySQL FQDN:** `cloudproj-<env>-mysql-<suffix>.mysql.database.azure.com`
- ✅ **Frontend URL:** `http://<external-ip>` (available after LoadBalancer provisioning)
- ✅ **Backend URL (internal):** `http://book-review-backend:8080`

### Monitoring Deployment

1. **GitHub Actions UI:**
   - View real-time logs for each job
   - Check job status and artifacts

2. **Azure Portal:**
   - Navigate to resource group: `cloudproj-<env>-rg`
   - Verify resources: AKS, ACR, MySQL, VNet, NSGs

3. **kubectl (after deployment):**
   ```bash
   # Get AKS credentials
   az aks get-credentials \
     --resource-group cloudproj-<env>-rg \
     --name cloudproj-<env>-aks
   
   # Check pods
   kubectl get pods -n book-review-<env>
   
   # Get frontend URL
   kubectl get svc book-review-frontend -n book-review-<env>
   ```

---

## 💻 Option B: Manual Local Deployment

### Prerequisites

* **Azure subscription** with required permissions
* **Terraform** (version ≥ 1.7.5)
* **Azure CLI** (authenticated to your target subscription)
* **kubectl** (Kubernetes command-line tool)
* **Docker** (for building and pushing images)

### 1. Azure CLI Authentication

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>

# Verify
az account show
```

### 2. Initialize Terraform with Remote Backend

```bash
# Navigate to project root
cd aks-terraform-project

# Initialize with backend configuration
terraform init \
  -backend-config="resource_group_name=<backend-rg>" \
  -backend-config="storage_account_name=<backend-storage>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev/terraform.tfstate"
```

### 3. Deploy Infrastructure

```bash
# Using wrapper script (auto-loads correct tfvars)
./scripts/terraform.sh plan
./scripts/terraform.sh apply -auto-approve

# Or manual with explicit var file
terraform plan -var-file="envs/dev/terraform.tfvars"
terraform apply -var-file="envs/dev/terraform.tfvars" -auto-approve
```

### 4. Deploy Application Manually

#### Step 1: Get Infrastructure Outputs

```bash
# Get Terraform outputs
terraform output -json > terraform-outputs.json

# Extract values
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
ACR_NAME=$(terraform output -raw acr_name)
AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
MYSQL_FQDN=$(terraform output -raw mysql_fqdn)
```

#### Step 2: Clone Application Repository

```bash
# Clone the book-review-app repository
git clone https://github.com/pravinmishraaws/book-review-app.git

cd book-review-app
```

#### Step 3: Build and Push Docker Images

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Build and push backend
docker build -t $ACR_LOGIN_SERVER/book-review-backend:latest ./backend
docker push $ACR_LOGIN_SERVER/book-review-backend:latest

# Build and push frontend
docker build -t $ACR_LOGIN_SERVER/book-review-frontend:latest ./frontend
docker push $ACR_LOGIN_SERVER/book-review-frontend:latest

# Verify images
az acr repository list --name $ACR_NAME --output table
```

#### Step 4: Deploy to AKS

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

# Create namespace
kubectl create namespace book-review-dev

# Set context to namespace
kubectl config set-context --current --namespace=book-review-dev

# Create secrets
kubectl create secret generic book-review-secrets \
  --from-literal=database_user=<mysql-username> \
  --from-literal=database_password=<mysql-password>

# Update K8s manifests with your values
cd ../aks-terraform-project/k8s

# Update deployments with ACR image paths
sed -i "s|<ACR_NAME>\.azurecr\.io|$ACR_LOGIN_SERVER|g" deployments/*.yaml

# Update configmap with MySQL FQDN
sed -i "s|<MYSQL_FQDN>|$MYSQL_FQDN|g" configmaps/app-config.yaml

# Apply manifests
kubectl apply -f configmaps/app-config.yaml
kubectl apply -f deployments/backend-deployment.yaml
kubectl apply -f services/backend-service.yaml
kubectl apply -f deployments/frontend-deployment.yaml
kubectl apply -f services/frontend-service.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=book-review --timeout=300s

# Get frontend URL
kubectl get svc book-review-frontend
```

---

## 🔍 Verify Deployment

After a successful deployment (`apply`), use the following steps to verify the cluster connectivity and access to core services in the **Dev** environment.

1.  **Fetch Kubeconfig:** Use the utility script to fetch the cluster configuration required for `kubectl` access.

    ```bash
    ./scripts/get-kubeconfig.sh cloudproj-dev-rg cloudproj-dev-aks
    #                        |-----------------| |-------------------|
    #                             resource group      kubernetes cluster
    ```

2.  **Verify Cluster Status:** Confirm that the AKS nodes are healthy and system pods are running.

    ```bash
    kubectl get nodes
    kubectl get pods -A
    ```
3.  **TAG A LOCAL IMAGE FOR TESTING ACR:** Tag an existing local image (placeholder).

    ```bash
    docker pull nginx:latest
    docker tag nginx:latest <acr_login_server>/frontend:dev
    ```

4.  **Login to ACR:** Authenticate to the Azure Container Registry (ACR) to confirm identity access.

    ```bash
    az acr login --name <acr_name>
    ```

5.  **Push the placeholder image:**

    ```bash
    docker push <acr_login_server>/frontend:dev
    ```

6.  **Verify repository and tags in ACR:**

    ```bash
    az acr repository list --name <acr_name> --output table
    az acr repository show-tags --name <acr_name> --repository frontend --output table
    ```
7.  **Test MySQL connection:** Test the connection to MySQL database

    ```bash
    kubectl run mysql-test --rm -it --image=mysql:8.0 --restart=Never -- bash 
    
    # Run the following command inside the MySQL prompt
    mysql -h <mysql_fqdn> -u adminuser -p

    # Once prompted, supply the password: DevStrongPassword123!

    # Once inside the database, RUN:
     SHOW DATABASES;
    ```

### 5.1. Deploy Application Using kubectl CLI

#### Option A: Deploy from Docker Hub (Simple)

```bash
# Deploy nginx web server
kubectl create deployment nginx-app --image=nginx:latest

# Expose it with a LoadBalancer (gets public IP)
kubectl expose deployment nginx-app --type=LoadBalancer --port=80 --target-port=80 --name=nginx-service

# Watch for external IP (takes 2-3 minutes)
kubectl get svc nginx-service -w
```

#### Step 4: Access Your Application

Your configuration supports 3 access methods:

**Method 1: External Access (Public Internet) ✅**

```bash
# Get the LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc sample-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access via browser or curl
curl http://$EXTERNAL_IP

# Or open in browser (Windows)
start http://$EXTERNAL_IP
```

**Method 2: Internal Access (Within Cluster) ✅**

```bash
# Access from another pod in the cluster
kubectl run test-pod --rm -it --image=curlimages/curl -- curl http://sample-app-service
```

**Method 3: Port Forwarding (Local Development) ✅**

```bash
# Forward to your local machine
kubectl port-forward svc/sample-app-service 8080:80

# Access at http://localhost:8080
```

#### Step 5: Manage Your Application

```bash
# Scale your application
kubectl scale deployment sample-app --replicas=5

# Update the application
kubectl set image deployment/sample-app app=nginx:latest

# View logs
kubectl logs -l app=sample-app --tail=50 -f

# Check resource usage
kubectl top pods -l app=sample-app
kubectl top nodes

# Delete the application
kubectl delete -f k8s/sample-app.yaml
# Or
kubectl delete deployment sample-app
kubectl delete service sample-app-service
```

---

## 🚀 Deploy to Stage / Production

### Via GitHub Actions (Recommended)

1. Go to **Actions** tab
2. Select **Infrastructure Deployment**
3. Click **Run workflow**
4. Select environment: `stage` or `prod`
5. Application deployment triggers automatically

### Via Local Deployment

For Stage or Production, use the same manual steps but with different environment:

```bash
# Deploy Stage
terraform init -backend-config="key=stage/terraform.tfstate"
terraform plan -var-file="envs/stage/terraform.tfvars"
terraform apply -var-file="envs/stage/terraform.tfvars"

# Deploy Production
terraform init -backend-config="key=prod/terraform.tfstate"
terraform plan -var-file="envs/prod/terraform.tfvars"
terraform apply -var-file="envs/prod/terraform.tfvars
```

```

⚠️ **Production Warning:** Stage and Prod environments should be deployed via GitHub Actions pipelines for security and auditability.

---

## 🗑️ Destroy Infrastructure

### Via GitHub Actions

A dedicated destroy workflow can be created, or use manual local destroy.

### Via Local Terraform

```bash
# Ensure you're on the correct environment
terraform init -backend-config="key=dev/terraform.tfstate"

# Review what will be destroyed
terraform plan -destroy -var-file="envs/dev/terraform.tfvars"

# Execute destroy
terraform destroy -var-file="envs/dev/terraform.tfvars" -auto-approve

# Or using wrapper script
./scripts/terraform.sh destroy
```

⚠️ **Warning:** This will permanently delete all resources in the selected environment.

---

## 📊 Deployment Summary

### What Gets Deployed

**Infrastructure (Terraform):**
- ✅ Resource Group
- ✅ Virtual Network with subnets (egress, aks, database)
- ✅ NAT Gateway for outbound connectivity
- ✅ Network Security Groups (NSGs)
- ✅ Azure Kubernetes Service (AKS) cluster
- ✅ Azure Container Registry (ACR)
- ✅ Azure MySQL Flexible Server (private endpoint)
- ✅ Azure Key Vault (secrets management)
- ✅ Private DNS zones and links

**Application (Kubernetes):**
- ✅ Backend service (Node.js/Java/Python - from book-review-app repo)
- ✅ Frontend service (React/Angular/HTML - from book-review-app repo)
- ✅ LoadBalancer for public access
- ✅ ConfigMaps and Secrets
- ✅ Health checks and resource limits

### Access Points

After successful deployment:

| Service | Access Method | URL/Endpoint |
|---------|---------------|--------------|
| Frontend | Public LoadBalancer | `http://<external-ip>` |
| Backend | Internal (ClusterIP) | `http://book-review-backend:8080` |
| AKS Dashboard | kubectl proxy | `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/` |
| ACR | Azure CLI | `az acr login --name <acr-name>` |
| MySQL | Private Endpoint | `<mysql-fqdn>:3306` (from within VNet) |

---

## 🛡️ Best Practices

### Security
- ✅ Use GitHub Actions for **Stage** and **Prod** deployments (not local CLI)
- ✅ Never commit secrets to Git (use GitHub Secrets or Azure Key Vault)
- ✅ Rotate service principal credentials regularly
- ✅ Use least-privilege IAM roles
- ✅ Enable Azure Policy and security scanning

### State Management
- ✅ Always use remote backend (Azure Storage) for state
- ✅ Enable state locking to prevent concurrent modifications
- ✅ Enable blob versioning for state file recovery
- ✅ Backup state files regularly

### Deployment Hygiene
- ✅ Always review `terraform plan` before applying
- ✅ Use environment-specific `.tfvars` files
- ✅ Tag all resources with environment, owner, and purpose
- ✅ Document infrastructure changes in Git commit messages
- ✅ Test changes in **Dev** before promoting to **Stage/Prod**

### Monitoring & Observability
- ✅ Enable Azure Monitor for AKS
- ✅ Configure Application Insights
- ✅ Set up log analytics workspace
- ✅ Create alerts for critical metrics
- ✅ Review deployment logs in GitHub Actions

---

## 🔧 Troubleshooting

### Common Issues

**Issue: MySQL InternalServerError during deployment**
- **Cause:** Transient Azure API issue or resource conflict
- **Solution:** Retry the workflow or check if MySQL server already exists in portal

**Issue: Frontend LoadBalancer stuck in "pending"**
- **Cause:** Azure LoadBalancer provisioning takes 2-3 minutes
- **Solution:** Wait or check NSG rules for port 80/443

**Issue: Terraform state lock**
- **Cause:** Previous run didn't complete cleanly
- **Solution:** `terraform force-unlock <lock-id>` (use cautiously)

**Issue: Docker build fails in GitHub Actions**
- **Cause:** Dockerfile not found or application repo inaccessible
- **Solution:** Verify `app_repository` and `app_branch` inputs, check repo permissions

**Issue: kubectl can't connect to AKS**
- **Cause:** Credentials not fetched or expired
- **Solution:** Run `az aks get-credentials` again

### Support Resources
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- See also: [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md), [BACKEND_SETUP.md](BACKEND_SETUP.md)
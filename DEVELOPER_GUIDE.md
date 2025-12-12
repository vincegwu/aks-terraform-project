# 💻 Azure Kubernetes Service (AKS) Terraform Project – Developer Guide

This guide outlines the essential steps for setting up the your local environment and understanding the core tools required to work with the **Dev** AKS cluster and its resources.

---

### 1. Environment Setup

To ensure successful deployment and interaction with the Azure resources, confirm all prerequisites are met:

#### Prerequisites

* **Azure subscription** and necessary permissions to deploy resources.
* **Installed Tools:**
    * **Terraform ($\geq 1.6$):** [https://www.terraform.io/downloads](https://www.terraform.io/downloads)
    * **Azure CLI:** [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
    * **kubectl:** [https://kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/)
* Access to the project repository (`aks-terraform-project/`).
* **Authentication:** Ensure you are logged into Azure CLI (`az login`).

---

### 2. Terraform Workspaces

The project uses Terraform Workspaces to enforce strict isolation between environments. You must select the appropriate workspace before running any deployment commands (`plan`, `apply`, `destroy`).

| Workspace | Environment | Purpose |
| :--- | :--- | :--- |
| `dev` | Development | Primary environment for developers to test features and configuration. |
| `stage` | Staging | Environment for integration testing and pre-production validation. |
| `prod` | Production | Live production environment (highly restricted access). |

* **State Isolation:** Workspaces ensure that the Terraform state is completely separate for each environment, preventing accidental cross-environment changes.
* **Automated Variables:** Use the **workspace-aware wrapper script** (`terraform.sh` or `terraform.ps1`) to automatically load environment-specific variables from the correct `.tfvars` file, avoiding manual input.

#### Selecting a Workspace

```bash
# Select the 'dev' workspace. If it doesn't exist, create it.
terraform workspace select dev || terraform workspace new dev
```

### 3. Deploying Infrastructure (Dev)

This section details the commands for initializing and deploying the **Dev** environment infrastructure.

1.  **Select Dev Workspace:** Ensure you are operating within the dedicated Development workspace.

    ```bash
    terraform workspace select dev || terraform workspace new dev
    ```

2.  **Run Terraform Plan:** Review the plan output to see what resources will be created.

    ```bash
    ./scripts/terraform.sh plan
    ```

3.  **Apply Deployment:** Execute the deployment.

    ```bash
    ./scripts/terraform.sh apply -auto-approve
    ```

> ⚙️ **The wrapper script automatically picks the correct variable file (`envs/dev/terraform.tfvars`), so no variable prompts are required.**

---

### 4. Accessing AKS Cluster

Once the infrastructure is deployed, use the following steps to establish connectivity to the cluster API.

1.  **Fetch Kubeconfig:** Run the utility script to securely retrieve the cluster configuration required for `kubectl`.

    ```bash
    bash scripts/get-kubeconfig.sh cloudproj-dev-rg cloudproj-dev-aks
    ```

2.  **Verify Cluster Connectivity:** Use `kubectl` to confirm that the nodes are ready and system pods are running.

    ```bash
    kubectl get nodes
    kubectl get pods -A
    ```

3.  **Deployment:** Developers can now deploy applications to the **Dev AKS cluster** using standard `kubectl` commands or integrated CI/CD pipelines.

---

### 5. Accessing ACR

To manage container images, developers need to authenticate with the Azure Container Registry (ACR) and use standard Docker commands.

1.  **Login to ACR:** Use the Azure CLI to authenticate your Docker client using the registry name.

    ```bash
    az acr login --name <acr_name>
    ```

2.  **Pull Images:** Once logged in, you can pull images for local testing or reference.

    ```bash
    # Pull the frontend image
    docker pull <mysql_fqdn>/frontend:dev

    ```

> 🔒 **Push permissions (for deploying new images) are strictly controlled via Azure AD Role-Based Access Control (RBAC).**

### 6. Database Access (Dev) 🔒

Access to the Azure MySQL Flexible Server is highly restricted, leveraging a secure, private network configuration.

* **Network Security:** The MySQL server is deployed directly into a **delegated subnet** using VNet integration. This architecture ensures that traffic never leaves the Azure backbone and provides native private connectivity.
* **Access Control:** Developers can only connect from **whitelisted IPs**. In the Dev environment, this often means your workstation's IP or a designated jump host IP must be explicitly allowed in the NSG rules for the `database subnet`.
* **Security:** Database credentials (`username`, `password`) are stored securely in **Azure Key Vault** and should be read dynamically for connection (e.g., using a small script or retrieving them manually for client setup).

#### Test MySQL Connection:

```bash
# Connect using the FQDN retrieved from deployment outputs
kubectl run mysql-test --rm -it --image=mysql:8.0 --restart=Never -- bash 
    
    # Run the following command inside the MySQL prompt
    mysql -h <mysql_fqdn> -u adminuser -p

    # Once prompted, supply the password: DevStrongPassword123!

    # Once inside the database, RUN:
     SHOW DATABASES;
```

### 7. Stage / Production Workflow 🚀

The **Stage** and **Production** environments are exclusively managed by automation to enforce security and consistency.

* **Access Restriction:** **Stage** and **Prod** deployments are handled via **CI/CD pipelines**. Developers **do not get direct `kubectl` access** to these clusters. Access is restricted to service principals used by the pipeline.
* **Deployment Method:** Deployment remains consistent using **Terraform workspaces**.

#### Deploy Stage

```bash
terraform workspace select stage || terraform workspace new stage
./scripts/terraform.sh plan
./scripts/terraform.sh apply -auto-approve
```

#### Deploy Production

```bash
terraform workspace select prod || terraform workspace new prod
./scripts/terraform.sh plan
./scripts/terraform.sh apply -auto-approve
```

⚙️ The wrapper scripts automatically use the correct variable files (envs/stage/terraform.tfvars or envs/prod/terraform.tfvars), ensuring consistency and safety across production environments.


### 8. Switching Between Workspaces 🔄

To ensure all Terraform commands target the correct environment, you must explicitly switch your active workspace.

* **List Workspaces:**
    ```bash
    terraform workspace list
    ```

* **Select Target Workspace:**
    ```bash
    terraform workspace select <workspace_name>
    ```

> ⚙️ This command is crucial. It ensures all subsequent Terraform commands automatically use the correct environment state and variables for the selected environment (`dev`, `stage`, or `prod`).

---

### 9. Best Practices for Developers 🛡️

Adhere to these best practices for safe, secure, and efficient operations:

1.  **Never hardcode credentials;** always use **Azure Key Vault** for secret storage.
2.  Always verify **`terraform plan`** before running **`terraform apply`** to confirm expected changes.
3.  Use the wrapper scripts (`terraform.sh`/`.ps1`) to ensure the **correct `.tfvars` file** is automatically applied.
4.  Avoid modifying **Stage/Prod clusters directly**; all changes should flow through **CI/CD pipelines**.
5.  Follow **naming and tagging conventions** strictly to maintain resource organization and cost management.

---

### 10. Troubleshooting Tips 💡

| Issue | Potential Cause / Action |
| :--- | :--- |
| **Terraform prompts for variables** | Make sure you are using the wrapper script (`terraform.sh`/`.ps1`) or explicitly supplying the correct `tfvars` file via the `-var-file` flag. |
| **Kubeconfig not updating** | Run **`scripts/get-kubeconfig.sh`** after deployment to fetch the latest cluster credentials. |
| **ACR login fails (`az acr login`)** | Ensure your user account or service principal has the proper **Azure AD RBAC permissions** (e.g., `AcrPull`, `AcrPush`) for the registry. |

This guide ensures developers can safely and efficiently work with all environments without manual input prompts, leveraging workspace-aware automation.

---

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
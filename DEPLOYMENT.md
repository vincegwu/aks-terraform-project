# 🚀 Azure Kubernetes Service (AKS) Terraform Project

## DEPLOYMENT INSTRUCTIONS

This guide provides the steps for initializing, deploying, verifying, and cleaning up the infrastructure across **Dev**, **Stage**, and **Prod** environments using the provided Terraform scripts and workspace workflow.

---

### 1. Prerequisites

Ensure you have the following tools installed and configured locally:

* **Azure subscription**
* **Terraform** (version $\geq 1.6$)
* **Azure CLI** (Authenticated to your target subscription)
* **kubectl** (Kubernetes command-line tool)

---

### 2. Initialize Terraform

Navigate to the root directory of the project (`aks-terraform-project/`) and initialize the backend and provider plugins.

```bash
terraform init
```

### 3. Select or Create Workspace

Use **Terraform Workspaces** to isolate the state for each environment. You must select the target workspace before running `plan` or `apply`.

```bash
# List all available workspaces
terraform workspace list

# Select the 'dev' workspace. If it doesn't exist, create it.
terraform workspace new dev || terraform workspace select dev

```

### 4. Deploy Using Wrapper Script

The wrapper scripts (`terraform.ps1` or `terraform.sh`) automatically load the correct **.tfvars** file based on the currently selected workspace, eliminating manual variable input.

#### 🖥️ PowerShell (Windows)

```powershell
.\scripts\terraform.ps1 plan
.\scripts\terraform.ps1 apply
```

#### 🐧 Bash / Linux / macOS
```powershell
./scripts/terraform.sh plan
./scripts/terraform.sh apply
```

💡 The script automatically loads the correct ".tfvars" file based on the workspace.

Here is the content for the "Verify Deployment" section, correctly formatted in Markdown, which is suitable for your `DEPLOYMENT.md` file:


### 5. Verify Deployment

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

3.  **Login to ACR:** Authenticate to the Azure Container Registry (ACR) to confirm identity access.

    ```bash
    az acr login --name cloudprojdevacr
    ```

4.  **Test Image Pull (Post-Build):** Run this command after building your application image to ensure the cluster can access the registry.

    ```bash
    docker pull cloudprojdevacr.azurecr.io/frontend:dev
    ```

 ### 6. Deploy Stage / Prod

Repeat the deployment steps for Stage and Production environments. Ensure you switch the active **Terraform Workspace** before running the plan and apply commands for each target environment.

#### Deploy Stage

```bash
terraform workspace select stage || terraform workspace new stage
./scripts/terraform.sh plan
./scripts/terraform.sh apply
```

#### Deploy Production

```bash
terraform workspace select prod || terraform workspace new prod
./scripts/terraform.sh plan
./scripts/terraform.sh apply
```
⚠️ Stage and Prod environments are highly restricted. They should typically be deployed via automated CI/CD pipelines using service principals, NOT via direct developer workstation access.


### 7. Clean-up (Optional)

To destroy all deployed infrastructure and avoid incurring further Azure costs, use the `destroy` command via the wrapper script.

1.  **Select Target Environment:** Switch to the workspace you wish to destroy.

    ```bash
    terraform workspace select dev
    ```

2.  **Execute Destroy:** The script will automatically load the correct variables and prompt you to confirm the destruction of all resources defined in that workspace state.

    ```bash
    ./scripts/terraform.sh destroy
    ```

*Repeat the `select` and `destroy` steps for the **Stage** and **Prod** workspaces if required.*

### 8. Best Practices 🛡️

Following these practices ensures a secure, maintainable, and repeatable deployment process:

* Always use **Terraform workspaces** for environment isolation ( Dev, Stage, Prod ).
* Avoid **hardcoding credentials** in configuration files; use **Azure Key Vault** for secure secret storage and dynamic retrieval.
* Verify **NSG (Network Security Group) and UDR (User-Defined Route)** rules after deployment to ensure secure network flow matches the traffic matrix.
* Always perform a careful review of the comprehensive **`terraform plan`** output before executing **`terraform apply`**.

This robust setup ensures fully automated, repeatable deployments without prompting for variables manually.
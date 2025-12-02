# K8S Internal Developer Platform — Infrastructure (AKS) — Terraform

# K8S Internal Developer Platform — Infrastructure (AKS) — Terraform

## Project Overview

This project provisions an AKS cluster with supporting infrastructure using Terraform, including:

* Multi-environment support: Dev, Stage, Prod
* Secure networking: 1 public + 2 private subnets per environment
* Azure MySQL Flexible Server with private endpoint
* Azure Container Registry (ACR)
* Azure Key Vault for secrets
* CI/CD-friendly setup with workspaces

---

Principles:

* Never hardcode values: use variables and `envs/*/terraform.tfvars`.
* Support multiple regions & subscriptions: pass `subscription_id` and `location` per environment.
* Secrets in Azure Key Vault.
* ACR access granted to AKS via role assignment.
* Dev access limited to whitelisted IPs; Stage/Prod access via CI/CD.

## Project Structure

```
aks-terraform-project/
├─ modules/
│  ├─ network/
│  ├─ aks/
│  ├─ mysql/
│  ├─ acr/
│  └─ keyvault/
├─ envs/
│  ├─ dev/
│  ├─ stage/
│  └─ prod/
├─ scripts/
│  ├─ get-kubeconfig.sh
│  ├─ terraform.ps1
│  └─ terraform.sh
├─ providers.tf
├─ variables.tf
├─ main.tf
├─ outputs.tf
├─ README.md
├─ DEVELOPER_GUIDE.md
└─ DEPLOYMENT.md
```

---



## Automatic Environment Variable Workflow

1. Terraform Workspaces isolate Dev, Stage, Prod
2. Wrapper scripts automatically load the correct `terraform.tfvars` file based on the selected workspace.

### Example Usage:

```bash
terraform workspace list
terraform workspace select dev || terraform workspace new dev

./scripts/terraform.sh plan
./scripts/terraform.sh apply -auto-approve
```

* `dev` → `envs/dev/terraform.tfvars`
* `stage` → `envs/stage/terraform.tfvars`
* `prod` → `envs/prod/terraform.tfvars`

This eliminates all interactive variable prompts.

---

## **Naming Conventions & Tagging Standards**

> **This section defines the official naming rules used across all Terraform modules in this project.**

### 1. General Naming Guidelines

| Rule                  | Details                                                      |
| --------------------- | ------------------------------------------------------------ |
| Prefix                | `project-environment` (example: `cloudproj-dev`)             |
| Separator             | Hyphens (`-`) only                                           |
| Resource suffix       | Add resource type at end (`-vnet`, `-nsg`, `-aks`, `-mysql`) |
| Lowercase             | All names must be lowercase                                  |
| No special characters | Only letters, numbers, hyphens                               |

**Examples:**

* `cloudproj-dev-vnet`
* `cloudproj-prod-mysql`
* `cloudproj-stage-aks`
* `cloudproj-dev-kv`
* `cloudprojdevacr` (ACR requires no hyphens)

---

### 2. Resource-Specific Naming

#### **2.1 Resource Groups**

`<project>-<environment>-rg`

* Example: `cloudproj-dev-rg`

#### **2.2 Virtual Networks**

`<project>-<environment>-vnet`

#### **2.3 Subnets**

Subnet keys: `egress`, `aks`, `database`

NSG naming:
`<project>-<environment>-<subnet>-nsg`

Optional route tables:
`<project>-<environment>-private-rt-<number>`

#### **2.4 NSGs**

Example:
`cloudproj-dev-aks-nsg`

#### **2.5 AKS Cluster**

```
Name: <project>-<environment>-aks
DNS Prefix: <project>-<environment>-aks
Node Pool: default
```

#### **2.6 Azure MySQL Flexible Server**

```
Name: <project>-<environment>-mysql
Private Endpoint: <project>-<environment>-db-pe
Private Service Connection: <project>-<environment>-db-psc
```

#### **2.7 Azure Container Registry (ACR)**

```
<project><environment>acr
```

(No hyphens allowed.)

#### **2.8 Azure Key Vault**

```
<project>-<environment>-kv
```

---

### 3. Environment Naming

| Environment | Workspace | tfvars file                   |
| ----------- | --------- | ----------------------------- |
| Development | `dev`     | `envs/dev/terraform.tfvars`   |
| Staging     | `stage`   | `envs/stage/terraform.tfvars` |
| Production  | `prod`    | `envs/prod/terraform.tfvars`  |

All resources must include environment code.

---

### 4. Tagging Standards

| Tag Key       | Description    | Example            |
| ------------- | -------------- | ------------------ |
| `environment` | Dev/Stage/Prod | dev                |
| `project`     | Project name   | cloudproj          |
| `owner`       | Team           | devops             |
| `cost_center` | Optional       | ops-team-01        |
| `purpose`     | Optional       | backend / database |

Tags must be applied consistently across all modules.

---

### 5. Resource Names Across Environments

| Resource Type    | Dev                   | Stage                   | Prod                   |
| ---------------- | --------------------- | ----------------------- | ---------------------- |
| Resource Group   | cloudproj-dev-rg      | cloudproj-stage-rg      | cloudproj-prod-rg      |
| VNet             | cloudproj-dev-vnet    | cloudproj-stage-vnet    | cloudproj-prod-vnet    |
| NSGs             | cloudproj-dev-aks-nsg | cloudproj-stage-aks-nsg | cloudproj-prod-aks-nsg |
| AKS              | cloudproj-dev-aks     | cloudproj-stage-aks     | cloudproj-prod-aks     |
| MySQL            | cloudproj-dev-mysql   | cloudproj-stage-mysql   | cloudproj-prod-mysql   |
| Private Endpoint | cloudproj-dev-db-pe   | cloudproj-stage-db-pe   | cloudproj-prod-db-pe   |
| ACR              | cloudprojdevacr       | cloudprojstageacr       | cloudprojprodacr       |
| Key Vault        | cloudproj-dev-kv      | cloudproj-stage-kv      | cloudproj-prod-kv      |

---

## Outputs

* VNet ID, Subnet IDs, NSGs, UDRs
* AKS cluster name & kubeconfig
* MySQL FQDN & private endpoint
* ACR login server

---

## Additional Documentation

* **DEPLOYMENT.md** – Full deployment steps
* **DEVELOPER_GUIDE.md** – Cluster access, ACR usage, MySQL access, best practices

---



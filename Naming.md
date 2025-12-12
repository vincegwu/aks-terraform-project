# **AKS Terraform Project – Naming Conventions & Tagging Standards**

## **1\. Purpose**

This document defines the naming conventions and tagging standards for all resources within the AKS Terraform project. Consistent naming ensures:

* Easier resource identification and management

* Environment segregation (Dev, Stage, Prod)

* Governance, cost tracking, and automation readiness

* Reusability across modules

---

## **2\. General Naming Guidelines**

| Rule | Details |
| ----- | ----- |
| Prefix | project-environment (e.g., cloudproj-dev) |
| Separator | Use `-` between components (project-env-resource) |
| Resource Type Suffix | Add resource type identifier at the end (-vnet, \-nsg, \-aks, \-mysql) |
| Lowercase | All names should be lowercase to comply with Azure naming rules |
| No special characters | Only letters, numbers, and hyphens; avoid underscores |

**Example:**

* `cloudproj-dev-vnet` → Virtual Network for dev

* `cloudproj-prod-mysql` → MySQL server in prod

* `cloudproj-stage-aks` → AKS cluster in stage

* `cloudproj-dev-kv` → Key Vault for dev

* `cloudprojdevacr` → ACR for dev (no hyphens to comply with Azure registry rules)

---

## **3\. Resource-Specific Naming Conventions**

### **3.1 Resource Groups**

`<project>-<environment>-rg`  
 Example: `cloudproj-dev-rg`

### **3.2 Virtual Networks**

`<project>-<environment>-vnet`  
 Example: `cloudproj-stage-vnet`

### **3.3 Subnets**

Use keys from tfvars: `egress`, `aks`, `database`

* NSG association uses: `<project>-<environment>-<subnet>-nsg`

* Optional Route Tables for private subnets: `<project>-<environment>-private-rt-<number>`

### **3.4 Network Security Groups (NSGs)**

`<project>-<environment>-<subnet>-nsg`  
 Example: `cloudproj-dev-aks-nsg`

### **3.5 Azure Kubernetes Service (AKS)**

* Name: `<project>-<environment>-aks`

* DNS Prefix: `<project>-<environment>-aks`

* Node Pool Name: `default`

* Tags: `environment`, `project`

### 

### **3.6 Azure MySQL Flexible Server**

* Name: `<project>-<environment>-mysql`

* Deployment: VNet-integrated via delegated database subnet

* Tags: `environment`, `project`

* Credentials stored in Key Vault (never hardcoded)

### **3.7 Azure Container Registry (ACR)**

* Name: `<project><environment>acr<unique-sufix>` (no hyphen for Azure registry)

* Tags: `environment`, `project`

### **3.8 Azure Key Vault**

* Name: `<project>-<environment>-kv-<unique-suffix>`

* Tags: `environment`, `project`

---

## **4\. Environment Naming**

| Environment | Workspace | tfvars file |
| ----- | ----- | ----- |
| Development | dev | envs/dev/terraform.tfvars |
| Staging | stage | envs/stage/terraform.tfvars |
| Production | prod | envs/prod/terraform.tfvars |

All resource names should include the environment code (`dev`, `stage`, `prod`) for clarity.

---

## **5\. Tagging Standards**

| Tag Key | Description | Example |
| ----- | ----- | ----- |
| environment | Identifies the environment | dev / stage / prod |
| project | Project name | cloudproj |
| owner | Responsible team or individual | devops |
| cost\_center | Optional cost tracking tag | ops-team-01 |
| purpose | Optional tag for resource role | frontend / backend / database |

* Tags are applied at resource creation and inherited where supported.

* All module outputs should respect tag propagation.

---

## **6\. Folder & Module Naming**

| Folder/Module | Purpose |
| ----- | ----- |
| modules/network | VNet, subnets, NSGs, optional UDRs |
| modules/aks | AKS cluster deployment |
| modules/mysql | MySQL server with VNet integration |
| modules/acr | Azure Container Registry |
| modules/keyvault | Key Vault for secrets |
| envs/ | Environment-specific tfvars |
| scripts | Helper scripts (`terraform.sh`, `get-kubeconfig.sh,`terraform.ps1) |

* Keep lowercase folder names and descriptive names per module.

---

## **7\. Best Practices**

* Use Terraform workspaces for environment isolation.

* Never hardcode credentials; always use Key Vault.

* Verify all `terraform plan` outputs before applying changes.

* Use tags consistently for cost tracking and governance.

* Follow naming patterns strictly to avoid collision or confusion.

* Use wrapper scripts to automatically load environment-specific tfvars.

---

## **8\. Resource Names Across Environments**

| Resource Type | Dev Name | Stage Name | Prod Name |
| ----- | ----- | ----- | ----- |
| Resource Group | cloudproj-dev-rg | cloudproj-stage-rg | cloudproj-prod-rg |
| Virtual Network (VNet) | cloudproj-dev-vnet | cloudproj-stage-vnet | cloudproj-prod-vnet |
| Subnet: egress | egress | egress | egress |
| Subnet: aks | aks | aks | aks |
| Subnet: database | database | database | database |
| NSG: egress | cloudproj-dev-egress-nsg | cloudproj-stage-egress-nsg | cloudproj-prod-egress-nsg |
| NSG: aks | cloudproj-dev-aks-nsg | cloudproj-stage-aks-nsg | cloudproj-prod-aks-nsg |
| NSG: database | cloudproj-dev-database-nsg | cloudproj-stage-database-nsg | cloudproj-prod-database-nsg |
| Route Table (private) | cloudproj-dev-private-rt-1 | cloudproj-stage-private-rt-1 | cloudproj-prod-private-rt-1 |
| AKS Cluster | cloudproj-dev-aks | cloudproj-stage-aks | cloudproj-prod-aks |
| AKS Node Pool (default) | default (inside cluster) | default | default |
| MySQL Flexible Server | cloudproj-dev-mysql | cloudproj-stage-mysql | cloudproj-prod-mysql |
| Azure Container Registry (ACR) | cloudprojdevacr | cloudprojstageacr | cloudprojprodacr |
| Key Vault | cloudproj-dev-kv | cloudproj-stage-kv | cloudproj-prod-kv |


# Deployment Guide - Private AKS Configuration

## Overview
With the security hardening applied, deployment processes require adjustments to work with the private cluster configuration. This guide explains the changes and provides solutions.

## What Changed

### 1. Private AKS Cluster
- **Impact:** API server only accessible from private network
- **Affects:** kubectl commands, CI/CD pipelines
- **Solution:** Deploy from within Azure VNet or via VPN/Bastion

### 2. Azure AD Authentication Required
- **Impact:** Local admin accounts disabled
- **Affects:** `az aks get-credentials --admin` no longer works
- **Solution:** Use Azure AD authentication (standard `get-credentials`)

### 3. Private ACR (if enabled)
- **Impact:** Registry only accessible via private endpoint
- **Affects:** Image push from external systems
- **Solution:** Use Azure-hosted runners or IP allowlisting

## Deployment Options

### Option 1: Azure DevOps Pipeline (Recommended)

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'your-service-connection'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        # Get AKS credentials (Azure AD auth)
        az aks get-credentials --resource-group $(resourceGroup) --name $(clusterName)
        
        # Deploy application
        kubectl apply -f k8s/

  - task: Docker@2
    inputs:
      containerRegistry: 'your-acr-connection'
      command: 'buildAndPush'
      repository: 'your-app'
      tags: '$(Build.BuildId)'
```

### Option 2: GitHub Actions

```yaml
name: Deploy to AKS

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Set AKS Context
        uses: azure/aks-set-context@v3
        with:
          resource-group: 'your-rg'
          cluster-name: 'your-cluster'
      
      - name: Deploy to Kubernetes
        run: |
          kubectl apply -f k8s/deployments/
          kubectl apply -f k8s/services/
```

**Note:** GitHub-hosted runners can access private clusters via Azure AD authentication, but cannot push to private ACR without additional configuration.

### Option 3: Azure Bastion/Jump Box

Deploy from a VM within the Azure VNet:

```bash
# 1. SSH to jump box in the VNet
ssh admin@jump-box

# 2. Install kubectl
az aks install-cli

# 3. Get credentials
az login
az aks get-credentials --resource-group myRG --name myCluster

# 4. Deploy
kubectl apply -f k8s/
```

### Option 4: VPN Connection

If you have VPN access to the Azure VNet:

```bash
# 1. Connect to VPN

# 2. Get credentials (first time)
az aks get-credentials --resource-group myRG --name myCluster

# 3. Authenticate via browser (Azure AD)
kubectl get nodes  # Triggers Azure AD auth

# 4. Deploy normally
kubectl apply -f k8s/
```

## Troubleshooting

### "Unable to connect to the server"

**Cause:** Trying to access private cluster from public internet

**Solution:**
- Deploy from within VNet (Bastion, VM, Azure-hosted agent)
- Use VPN to connect to VNet
- Temporarily enable public access (not recommended):
  ```bash
  # In terraform, set:
  enable_private_aks_cluster = false
  ```

### "error: You must be logged in to the server (Unauthorized)"

**Cause:** Local admin accounts disabled

**Solution:**
```bash
# Remove old credentials
kubectl config delete-context <old-context>

# Get new credentials (Azure AD)
az aks get-credentials --resource-group myRG --name myCluster

# Authenticate
kubectl get nodes  # Opens browser for Azure AD login
```

### "unauthorized: authentication required" (ACR)

**Cause:** Private ACR not accessible from deployment location

**Solutions:**

1. **For AKS pulling images:** Should work automatically (same VNet)
   ```bash
   # Verify AKS can access ACR
   az aks check-acr --resource-group myRG --name myCluster --acr myacr.azurecr.io
   ```

2. **For pushing images from CI/CD:**
   - Use Azure-hosted CI/CD agents
   - OR add allowlist IP in ACR (temporary):
     ```hcl
     # In modules/acr/variables.tf - add:
     variable "allowed_ip_ranges" {
       type    = list(string)
       default = ["YOUR_CI_CD_IP/32"]
     }
     ```

## Quick Reference

| Task | Command |
|------|---------|
| Get credentials | `az aks get-credentials --resource-group <rg> --name <cluster>` |
| Check cluster access | `kubectl get nodes` |
| Check ACR access | `az aks check-acr --resource-group <rg> --name <cluster> --acr <acr-name>.azurecr.io` |
| View current context | `kubectl config current-context` |
| Deploy application | `kubectl apply -f k8s/` |

## Application Deployment (k8s Manifests)

✅ **No changes required to your Kubernetes manifests**

Your existing k8s files work exactly the same:
- [k8s/deployments/backend-deployment.yaml](k8s/deployments/backend-deployment.yaml)
- [k8s/deployments/frontend-deployment.yaml](k8s/deployments/frontend-deployment.yaml)
- [k8s/services/backend-service.yaml](k8s/services/backend-service.yaml)
- [k8s/services/frontend-service.yaml](k8s/services/frontend-service.yaml)
- [k8s/configmaps/app-config.yaml](k8s/configmaps/app-config.yaml)

Just ensure you're deploying them from an authorized location.

## Temporary Public Access (Emergency Use Only)

If you need immediate deployment and can't set up private access:

**In `envs/dev/terraform.tfvars`:**
```hcl
# WARNING: Reduces security posture
create_private_endpoints   = false
enable_private_aks_cluster = false
```

Then redeploy infrastructure:
```bash
terraform plan
terraform apply
```

**⚠️ Re-enable security after deployment!**

## Best Practices

1. **Use Azure-hosted CI/CD runners** for automated deployments
2. **Set up VPN** for developer access from local machines
3. **Use Azure Bastion** for secure jump box access
4. **Never disable security** for convenience - find the proper access method
5. **Test deployments** in dev environment before production

## Additional Resources

- [Azure AD integration for AKS](https://learn.microsoft.com/en-us/azure/aks/azure-ad-integration-cli)
- [Private AKS clusters](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
- [ACR authentication with AKS](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration)

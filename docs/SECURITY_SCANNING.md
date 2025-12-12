# Security Scanning with Checkov

## Overview

This project uses [Checkov](https://www.checkov.io/) to scan Terraform code for security vulnerabilities and misconfigurations before deployment.

## How It Works

1. **Automated Scanning**: Every push and pull request triggers Checkov
2. **Severity-Based Blocking**: HIGH and CRITICAL findings block deployment
3. **Reporting**: Security reports are generated and uploaded as artifacts
4. **PR Comments**: Scan results are automatically posted to pull requests

## Running Checkov Locally

### Installation
```bash
# Using pip
pip install checkov
```

### Scan Your Code
```bash
# Scan entire project
checkov --directory . --framework terraform

# Check only HIGH/CRITICAL issues
checkov --directory . --check HIGH,CRITICAL --framework terraform
```

## Common Security Issues and Fixes

### 1. Unencrypted Storage
**Issue**: `CKV_AZURE_33` - Storage account does not use encryption

**Fix**:
```hcl
resource "azurerm_storage_account" "example" {
  enable_https_traffic_only = true
  min_tls_version          = "TLS1_2"
}
```

### 2. Missing Network Policies
**Issue**: `CKV_AZURE_7` - AKS cluster lacks network policy

**Fix**:
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}
```

### 3. Public IP Addresses
**Issue**: `CKV_AZURE_168` - AKS nodes have public IPs

**Fix**:
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  default_node_pool {
    enable_node_public_ip = false
  }
  private_cluster_enabled = true
}
```

### 4. Missing RBAC
**Issue**: `CKV_AZURE_6` - RBAC not enabled

**Fix**:
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  role_based_access_control_enabled = true
}
```

## Suppressing Checks

Add to `.checkov.baseline.yml`:
```yaml
suppressions:
  - check: CKV_AZURE_33
    file_path: modules/storage/main.tf
    reason: "Dev environment exception with approval"
```

## Severity Levels

| Level    | Action          |
|----------|-----------------|
| CRITICAL | **Blocks merge**|
| HIGH     | **Blocks merge**|
| MEDIUM   | Warning         |
| LOW      | Info            |

## Resources

- [Checkov Documentation](https://www.checkov.io/docs)
- [Azure Security Baseline](https://learn.microsoft.com/en-us/security/benchmark/azure/)

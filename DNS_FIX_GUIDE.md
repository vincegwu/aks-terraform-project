# MySQL Private Endpoint DNS Resolution Fix

## Problem
AKS cluster could not resolve or reach the MySQL database when using Private Endpoints, causing application timeouts via Ingress.

## Root Causes
1. **Private Endpoint Subnet Placement**: Private endpoint was in the database subnet, requiring cross-subnet routing
2. **DNS Resolution Order**: DNS zone link needed explicit dependency to ensure proper creation order
3. **Network Connectivity**: AKS pods needed direct access to the private endpoint

## Changes Applied

### 1. **Moved Private Endpoint to AKS Subnet**
   - **Before**: Private endpoint in `database` subnet
   - **After**: Private endpoint in `aks` subnet
   - **Why**: AKS pods can directly access private endpoints in their own subnet without complex routing

### 2. **Enhanced DNS Configuration**
   - Added explicit `depends_on` to ensure DNS zone is created and linked before private endpoint
   - DNS zone link now properly configures VNet DNS resolution for AKS
   - Private DNS zone group automatically registers the private endpoint IP

### 3. **Dependency Chain**
   ```
   MySQL Server → Private DNS Zone → DNS Zone VNet Link → Private Endpoint.
   ```

## How It Works Now

### With Private Endpoints Enabled (Production)
1. MySQL server is created without public access
2. Private DNS zone `privatelink.mysql.database.azure.com` is created
3. DNS zone is linked to the VNet (enables AKS DNS resolution)
4. Private endpoint is created in the AKS subnet with DNS zone group
5. AKS pods resolve `<servername>.mysql.database.azure.com` to the private IP
6. Traffic flows: **AKS Pod → Private Endpoint (same subnet) → MySQL Server**

### DNS Resolution Flow
```
Application requests: cloudproj-dev-mysql-01b0dd.mysql.database.azure.com
                                    ↓
AKS CoreDNS forwards to Azure DNS (168.63.129.16)
                                    ↓
Azure DNS checks linked Private DNS Zones
                                    ↓
Returns private IP: 10.10.2.x (in AKS subnet)
                                    ↓
Application connects to private endpoint
                                    ↓
Private endpoint forwards to MySQL server
```

### Without Private Endpoints (Development)
- MySQL has public endpoint with firewall rule for Azure services
- No DNS changes needed
- Direct public connection with authentication

## Network Security

### NSG Rules (Still in Place)
- Database subnet NSG allows traffic from AKS subnet (port 3306)
- This protects the MySQL control plane even though private endpoint is in AKS subnet

### Private Endpoint Security
- Private endpoint acts as a network interface in the AKS subnet
- All traffic is internal to the VNet
- No public internet exposure

## Deployment Steps

### 1. Apply Terraform Changes
```bash
# For production environment
cd c:\Users\HP\Downloads\aks-terraform-project
terraform init
terraform plan -var-file="envs/prod/terraform.tfvars"
terraform apply -var-file="envs/prod/terraform.tfvars"
```

### 2. Verify DNS Resolution from AKS
```bash
# Get AKS credentials
az aks get-credentials --resource-group cloudproj-prod-rg --name cloudproj-prod-aks

# Test DNS resolution from a pod
kubectl run -it --rm dns-test --image=busybox --restart=Never -- nslookup cloudproj-prod-mysql.mysql.database.azure.com

# Expected output: Private IP in 10.30.2.0/24 range (AKS subnet)
```

### 3. Test Database Connectivity
```bash
# Deploy a MySQL client pod
kubectl run -it --rm mysql-client --image=mysql:8.0 --restart=Never -- \
  mysql -h cloudproj-prod-mysql.mysql.database.azure.com \
        -u adminuser \
        -p \
        -D book_review_db

# Should connect successfully
```

### 4. Update ConfigMap
Ensure the ConfigMap has the correct MySQL hostname:
```yaml
database_host: "cloudproj-prod-mysql.mysql.database.azure.com"
```

### 5. Redeploy Application
```bash
# Restart backend deployment to pick up new network configuration
kubectl rollout restart deployment/book-review-backend -n book-review-dev
kubectl rollout status deployment/book-review-backend -n book-review-dev
```

## Verification Checklist

- [ ] Terraform apply completes without errors
- [ ] Private DNS zone is created: `privatelink.mysql.database.azure.com`
- [ ] DNS zone is linked to VNet
- [ ] Private endpoint is in AKS subnet
- [ ] DNS resolves to private IP (10.x.x.x)
- [ ] Backend pods can connect to MySQL
- [ ] Application responds via Ingress
- [ ] No timeout errors in logs

## Troubleshooting

### Issue: DNS still resolves to public IP
**Solution**: 
```bash
# Check DNS zone link
az network private-dns link vnet list \
  --resource-group cloudproj-prod-rg \
  --zone-name privatelink.mysql.database.azure.com

# Should show VNet link with "provisioningState": "Succeeded"
```

### Issue: Connection timeouts
**Solution**:
```bash
# Check private endpoint status
az network private-endpoint show \
  --name cloudproj-prod-db-pe \
  --resource-group cloudproj-prod-rg \
  --query "provisioningState"

# Check NSG rules aren't blocking traffic
az network nsg rule list \
  --resource-group cloudproj-prod-rg \
  --nsg-name cloudproj-prod-aks-nsg \
  --query "[?direction=='Outbound']"
```

### Issue: Private endpoint not in DNS zone
**Solution**:
```bash
# Check DNS zone group
az network private-endpoint dns-zone-group show \
  --endpoint-name cloudproj-prod-db-pe \
  --resource-group cloudproj-prod-rg \
  --name mysql-dns-zone-group

# Should show the private DNS zone association
```

## Additional Notes

- **AKS CoreDNS**: Automatically configured to use Azure DNS (168.63.129.16)
- **Private DNS Zone**: Only accessible from linked VNets
- **High Availability**: Private endpoint supports zone redundancy
- **Security**: No public internet exposure with private endpoints

## References
- [Azure Private Endpoint DNS Configuration](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)
- [Azure MySQL Flexible Server Private Link](https://learn.microsoft.com/azure/mysql/flexible-server/concepts-networking-private-link)
- [AKS Networking Best Practices](https://learn.microsoft.com/azure/aks/concepts-network)

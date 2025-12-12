# 📚 Book Review Application Deployment Guide

This guide provides step-by-step instructions for deploying a book review application (frontend + backend) to your AKS cluster provisioned by Terraform.

---

## 📋 Prerequisites

Before deploying, ensure you have:

1. **AKS cluster provisioned** via Terraform (see main [DEPLOYMENT.md](../DEPLOYMENT.md))
2. **Azure Container Registry (ACR)** created and accessible
3. **MySQL database** provisioned with proper credentials
4. **kubectl** configured with AKS cluster access
5. **Azure CLI** authenticated to your subscription
6. **Docker** installed for building container images

### 🔐 Security Requirements

**IMPORTANT: Never commit secrets to Git!**
- Database passwords should come from Azure Key Vault or GitHub Secrets
- The `.gitignore` file is configured to exclude sensitive files
- Use `kubectl create secret` commands instead of YAML files for secrets
- In CI/CD, secrets are injected from GitHub repository secrets

---

## 🏗️ Architecture Overview

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│  LoadBalancer Service (Public IP)  │
└──────────────┬──────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   Frontend Pods (React/Vue/etc)    │
│   - Port: 80                       │
│   - Replicas: 2                    │
└──────────────┬─────────────────────┘
               │
               │ Internal HTTP
               ▼
┌────────────────────────────────────┐
│   Backend Pods (API)               │
│   - Port: 8080                     │
│   - Replicas: 2                    │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   Azure MySQL Flexible Server      │
│   - Private Endpoint               │
└────────────────────────────────────┘
```

---

## 🚀 Deployment Steps

### Step 1: Prepare Your Application Code

Ensure your application has the following structure:

```
book-review-app/
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
└── backend/
    ├── Dockerfile
    ├── requirements.txt (Python) or package.json (Node.js)
    └── src/
```

#### Example Backend Dockerfile (Node.js)

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8080
CMD ["npm", "start"]
```

#### Example Frontend Dockerfile (React)

```dockerfile
FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

### Step 2: Get Infrastructure Details

First, retrieve the necessary infrastructure details from your Terraform outputs:

```bash
# Navigate to Terraform project directory
cd ~/Downloads/aks-terraform-project

# Select the environment workspace (e.g., dev)
terraform workspace select dev

# Get outputs
terraform output

# Capture specific values
export ACR_NAME=$(terraform output -raw acr_name)
export ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
export MYSQL_FQDN=$(terraform output -raw mysql_fqdn)
export AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
export RESOURCE_GROUP=$(terraform output -raw resource_group_name)
```

---

### Step 3: Configure kubectl Access

Get AKS credentials to configure kubectl:

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

# Verify connection
kubectl get nodes
kubectl cluster-info
```

---

### Step 4: Build and Push Container Images

#### Login to Azure Container Registry

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Verify login
echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

#### Build and Push Backend Image

```bash
# Navigate to backend directory
cd /path/to/your/book-review-app/backend

# Build the image
docker build -t $ACR_LOGIN_SERVER/book-review-backend:latest .

# Tag with version (optional)
docker tag $ACR_LOGIN_SERVER/book-review-backend:latest \
           $ACR_LOGIN_SERVER/book-review-backend:v1.0.0

# Push to ACR
docker push $ACR_LOGIN_SERVER/book-review-backend:latest
docker push $ACR_LOGIN_SERVER/book-review-backend:v1.0.0

# Verify the image
az acr repository show-tags --name $ACR_NAME --repository book-review-backend
```

#### Build and Push Frontend Image

```bash
# Navigate to frontend directory
cd /path/to/your/book-review-app/frontend

# Build the image
docker build -t $ACR_LOGIN_SERVER/book-review-frontend:latest .

# Tag with version (optional)
docker tag $ACR_LOGIN_SERVER/book-review-frontend:latest \
           $ACR_LOGIN_SERVER/book-review-frontend:v1.0.0

# Push to ACR
docker push $ACR_LOGIN_SERVER/book-review-frontend:latest
docker push $ACR_LOGIN_SERVER/book-review-frontend:v1.0.0

# Verify the image
az acr repository show-tags --name $ACR_NAME --repository book-review-frontend
```

---

### Step 5: Configure Kubernetes Manifests

Navigate to the k8s directory and update the configuration files:

```bash
cd ~/Downloads/aks-terraform-project/k8s
```

#### Update ConfigMap with Real Values

Edit `configmaps/app-config.yaml`:

```bash
# Replace <MYSQL_FQDN> with actual MySQL server FQDN
sed -i "s/<MYSQL_FQDN>/$MYSQL_FQDN/g" configmaps/app-config.yaml

# For Windows PowerShell:
# (Get-Content configmaps/app-config.yaml) -replace '<MYSQL_FQDN>', $env:MYSQL_FQDN | Set-Content configmaps/app-config.yaml
```

#### Update Deployment Files with ACR Name

```bash
# Update backend deployment
sed -i "s/<ACR_NAME>/$ACR_NAME/g" deployments/backend-deployment.yaml

# Update frontend deployment
sed -i "s/<ACR_NAME>/$ACR_NAME/g" deployments/frontend-deployment.yaml

# For Windows PowerShell:
# (Get-Content deployments/backend-deployment.yaml) -replace '<ACR_NAME>', $env:ACR_NAME | Set-Content deployments/backend-deployment.yaml
# (Get-Content deployments/frontend-deployment.yaml) -replace '<ACR_NAME>', $env:ACR_NAME | Set-Content deployments/frontend-deployment.yaml
```

---

### Step 6: Create Kubernetes Secrets

Create secrets for database credentials (don't commit these to Git):

```bash
# Option 1: Create from literals (recommended)
kubectl create secret generic book-review-secrets \
  --from-literal=database_user=adminuser \
  --from-literal=database_password=<YOUR_MYSQL_PASSWORD>

# Option 2: Retrieve from Azure Key Vault and create secret
export MYSQL_PASSWORD=$(az keyvault secret show \
  --vault-name <keyvault-name> \
  --name mysql-admin-password \
  --query value -o tsv)

kubectl create secret generic book-review-secrets \
  --from-literal=database_user=adminuser \
  --from-literal=database_password=$MYSQL_PASSWORD

# Verify secret creation
kubectl get secret book-review-secrets
```

---

### Step 7: Initialize Database Schema

Before deploying the application, initialize the database:

```bash
# Run a temporary MySQL pod
kubectl run mysql-client --rm -it --image=mysql:8.0 --restart=Never -- bash

# Inside the pod, connect to MySQL
mysql -h $MYSQL_FQDN -u adminuser -p

# Create the database
CREATE DATABASE IF NOT EXISTS bookreview;
USE bookreview;

# Create tables (example)
CREATE TABLE IF NOT EXISTS books (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  author VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reviews (
  id INT AUTO_INCREMENT PRIMARY KEY,
  book_id INT NOT NULL,
  reviewer_name VARCHAR(255) NOT NULL,
  rating INT CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

# Exit
EXIT;
exit
```

---

### Step 8: Deploy Application to Kubernetes

Deploy the application components in order:

```bash
# 1. Apply ConfigMap
kubectl apply -f configmaps/app-config.yaml

# 2. Verify secret exists
kubectl get secret book-review-secrets

# 3. Deploy backend
kubectl apply -f deployments/backend-deployment.yaml
kubectl apply -f services/backend-service.yaml

# 4. Wait for backend pods to be ready
kubectl wait --for=condition=ready pod -l component=backend --timeout=120s

# 5. Deploy frontend
kubectl apply -f deployments/frontend-deployment.yaml
kubectl apply -f services/frontend-service.yaml

# 6. Wait for frontend pods to be ready
kubectl wait --for=condition=ready pod -l component=frontend --timeout=120s
```

---

### Step 9: Verify Deployment

Check the status of your deployment:

```bash
# View all resources
kubectl get all -l app=book-review

# Check pod status
kubectl get pods -l app=book-review

# View pod logs
kubectl logs -l component=backend --tail=50
kubectl logs -l component=frontend --tail=50

# Describe pods for troubleshooting
kubectl describe pods -l component=backend
kubectl describe pods -l component=frontend

# Check services
kubectl get svc
```

---

### Step 10: Access Your Application

Get the external IP address for the frontend service:

```bash
# Wait for external IP to be assigned (takes 2-3 minutes)
kubectl get svc book-review-frontend -w

# Once EXTERNAL-IP is assigned, get it:
export FRONTEND_IP=$(kubectl get svc book-review-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Application URL: http://$FRONTEND_IP"

# Test the application
curl http://$FRONTEND_IP

# Open in browser (Windows)
start http://$FRONTEND_IP

# Open in browser (Linux/macOS)
xdg-open http://$FRONTEND_IP  # Linux
open http://$FRONTEND_IP      # macOS
```

---

## 🔍 Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check if images are pulled
kubectl get pods -o wide
```

### Cannot Pull Images from ACR

```bash
# Verify ACR access from AKS
az aks check-acr --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --acr $ACR_NAME

# Verify ACR role assignment
az role assignment list --scope $(az acr show --name $ACR_NAME --query id -o tsv)
```

### Database Connection Issues

```bash
# Test MySQL connectivity from a pod
kubectl run mysql-test --rm -it --image=mysql:8.0 --restart=Never -- bash
mysql -h <MYSQL_FQDN> -u adminuser -p

# Check if MySQL firewall allows AKS subnet
az mysql flexible-server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --name <mysql-server-name>
```

### Service Not Getting External IP

```bash
# Check service status
kubectl describe svc book-review-frontend

# Verify LoadBalancer events
kubectl get events --sort-by='.lastTimestamp'

# Check if Azure Load Balancer is created
az network lb list --resource-group MC_${RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_<region>
```

---

## 🔄 Update Application

To deploy a new version:

```bash
# Build and push new images with version tag
docker build -t $ACR_LOGIN_SERVER/book-review-backend:v1.1.0 ./backend
docker push $ACR_LOGIN_SERVER/book-review-backend:v1.1.0

# Update the deployment
kubectl set image deployment/book-review-backend \
  backend=$ACR_LOGIN_SERVER/book-review-backend:v1.1.0

# Monitor rollout
kubectl rollout status deployment/book-review-backend

# Rollback if needed
kubectl rollout undo deployment/book-review-backend
```

---

## 🧹 Cleanup

To remove the application from the cluster:

```bash
# Delete all book-review resources
kubectl delete -f k8s/services/
kubectl delete -f k8s/deployments/
kubectl delete -f k8s/configmaps/app-config.yaml
kubectl delete secret book-review-secrets

# Or delete by label
kubectl delete all -l app=book-review
```

---

## 📊 Monitoring and Scaling

### View Resource Usage

```bash
# CPU and memory usage
kubectl top pods -l app=book-review
kubectl top nodes

# Detailed pod metrics
kubectl describe pods -l app=book-review
```

### Scale Deployments

```bash
# Scale backend
kubectl scale deployment book-review-backend --replicas=3

# Scale frontend
kubectl scale deployment book-review-frontend --replicas=4

# Auto-scaling (HPA)
kubectl autoscale deployment book-review-backend \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

---

## 🔐 Security Best Practices

1. **Never commit secrets to Git** - Use Kubernetes secrets or Azure Key Vault
2. **Use private endpoints** - MySQL should only be accessible from AKS
3. **Enable RBAC** - Restrict access to Kubernetes resources
4. **Scan images** - Use `az acr task` or Defender for Containers
5. **Use managed identities** - Enable workload identity for Azure services
6. **Network policies** - Restrict pod-to-pod communication if needed

```bash
# Example: Scan image for vulnerabilities
az acr task create \
  --registry $ACR_NAME \
  --name security-scan \
  --image book-review-backend:{{.Run.ID}} \
  --cmd "{{.Values.image}}" \
  --commit-trigger-enabled false
```

---

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## 🆘 Support

If you encounter issues:

1. Check pod logs: `kubectl logs <pod-name>`
2. Describe pod: `kubectl describe pod <pod-name>`
3. Check events: `kubectl get events --sort-by='.lastTimestamp'`
4. Review [DEPLOYMENT.md](../DEPLOYMENT.md) for infrastructure issues
5. Verify network connectivity between components

---

**Happy Deploying! 🚀**

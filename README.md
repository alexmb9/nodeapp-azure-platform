# NodeApp Azure Platform

Node.js application infrastructure on Azure with hub-and-spoke architecture and automated CI/CD. Built in under 3 days.

<br/>

---

<br/>

## Project Setup (Windows)

### 1. Install Terraform

Download from [terraform.io/downloads](https://www.terraform.io/downloads)

Extract to `C:\terraform` and add to PATH:
1. Open **System Properties** → **Environment Variables**
2. Under **System variables**, select **Path** → **Edit** → **New**
3. Add `C:\terraform`
4. Click **OK** and restart terminal

**Verify:**
```bash
terraform version
```

### 2. Install Azure CLI

Download and run: [aka.ms/installazurecliwindows](https://aka.ms/installazurecliwindows)

**Verify:**
```bash
az --version
```

### 3. Clone Repository

```bash
cd ~/projects/repos
git clone https://github.com/alexmb9/nodeapp-azure-platform.git
cd nodeapp-azure-platform
```

### 4. Azure Login

```bash
az login
az account set --subscription "<your-subscription-id>"
az account show
```

<br/>

---

<br/>

## Terraform Configuration

### Initialize Shared Hub

```bash
cd terraform/shared-hub
terraform init
terraform validate
```

### Initialize App Module

```bash
cd terraform/app-ne
terraform init -backend-config=env/prod/backend.tfvars
terraform validate
```

<br/>

---

<br/>

## Local Development

### Run Terraform Plan

```bash
# Shared hub
cd terraform/shared-hub
terraform plan -var-file=env/prod/terraform.tfvars

# App
cd terraform/app-ne
terraform plan -var-file=env/prod/terraform.tfvars -var="sql_admin_password=YOUR_PASSWORD"
```

Review the output carefully before applying any changes.

<br/>

---

<br/>

## GitHub Actions

### Deploying Changes

1. **Check changes, stage, and commit:**
   ```bash
   git status
   git diff
   git add .
   git commit -m "Your meaningful message"
   git push origin main
   ```

2. **Run the plan workflow:**
   - Go to GitHub → Actions
   - Click "Run workflow"
   - Select action: `plan`
   - Validate the output

3. **Deploy (once validated):**
   - Go to GitHub → Actions
   - Click "Run workflow"
   - Select action: `apply`

4. **Validate deployment:**
   - Check all stages passed in GitHub Actions
   - Verify resources in Azure Portal

5. **If deployment fails:**
   - Automatic rollback will trigger
   - A GitHub issue will be created to log the event

<br/>

---

<br/>

## Troubleshooting

### Terraform Errors

**"Resource already exists"**
```bash
terraform import azurerm_resource_group.app /subscriptions/<subscription-id>/resourceGroups/rg-nodeapp-prod-ne
```

**"State lock error"**
```bash
terraform force-unlock <LOCK_ID>
```

**"Backend initialization required"**
```bash
terraform init -reconfigure -backend-config=env/prod/backend.tfvars
```

**Git Bash path issues (MissingSubscription error)**
```bash
# Prefix Azure CLI commands with:
MSYS_NO_PATHCONV=1 az role assignment create ...
```

### Azure CLI Errors

**"Subscription not found"**
```bash
az login
az account set --subscription "<subscription-id>"
```

**"Authorization failed"**

Contact Azure admin to grant Contributor + User Access Administrator roles.

### GitHub Actions Errors

**"Backend blob not found"**
```bash
az storage container create \
  --name tfstate \
  --account-name sttfstatesharedambprod \
  --auth-mode login
```

**"Plan failed - permissions error"**
```bash
az role assignment create \
  --assignee <service-principal-id> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>
```

**"RoleAssignmentExists"**

Delete the conflicting role assignment manually in Azure Portal or via CLI:
```bash
MSYS_NO_PATHCONV=1 az role assignment delete \
  --assignee <principal-id> \
  --role "Key Vault Administrator" \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-shared-hub-prod/providers/Microsoft.KeyVault/vaults/kv-shared-hub-prod-ne01
```

<br/>

---

<br/>

## Useful Commands

### Terraform
```bash
terraform init                                           # Initialize
terraform plan -var-file=env/prod/terraform.tfvars     # Plan changes
terraform apply -var-file=env/prod/terraform.tfvars    # Apply changes
terraform validate                                       # Validate syntax
terraform fmt -recursive                                 # Format code
terraform state list                                     # List resources
terraform output                                         # Show outputs
```

### Azure CLI
```bash
az login                                                 # Login to Azure
az account set --subscription "<subscription-id>"       # Set subscription
az group list -o table                                   # List resource groups
az resource list --resource-group <rg-name> -o table    # List resources
az webapp show --name <app-name> --resource-group <rg>  # View App Service
```

### Git
```bash
git status                                               # Check status
git add .                                                # Stage all changes
git commit -m "message"                                  # Commit
git push origin main                                     # Push to GitHub
```

<br/>

---

<br/>

## Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [GitHub Actions Docs](https://docs.github.com/en/actions)

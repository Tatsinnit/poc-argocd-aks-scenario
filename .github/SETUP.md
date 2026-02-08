# GitHub Actions Setup Guide

This guide explains how to set up GitHub Actions for continuous integration and deployment.

## 🔐 Choose Your Authentication Method

GitHub Actions needs to authenticate with Azure to push images to ACR and manage resources.

**Important:** Both methods use an Azure AD App Registration and Service Principal. The difference is HOW they authenticate:

### Recommended: Workload Identity Federation (OIDC) ⭐

**What it is:**
- Creates a Service Principal with **federated credentials** (no password)
- GitHub sends a token that Azure validates
- Trust relationship instead of secrets

**Why OIDC?**
- 🔒 **Most Secure** - No secrets stored in GitHub
- ⚡ **Zero Maintenance** - Automatic token rotation (tokens last ~1 hour)
- 📊 **Better Auditing** - Federated identity logs
- ✅ **Microsoft Recommended** - Industry best practice

**Required GitHub Secrets:** 3 IDs (not actual secrets)
- `AZURE_CLIENT_ID` - Service Principal's Application ID
- `AZURE_TENANT_ID` - Your Azure AD Tenant ID  
- `AZURE_SUBSCRIPTION_ID` - Your Azure Subscription ID

**Authentication Type:** Service Principal with Federated Credential

### Alternative: Service Principal with Client Secret (Legacy)

**What it is:**
- Creates a Service Principal with a **client secret** (password)
- Secret is stored in GitHub and sent on every authentication
- Long-lived credential (1-2 years)

**When to use:**
- Quick testing/demos only
- Legacy systems that don't support OIDC
- Temporary environments

**Required Secrets:** 1 JSON with credentials
- `AZURE_CREDENTIALS` (contains clientId + clientSecret)

**Authentication Type:** Service Principal with Client Secret

⚠️ **Security Risk:** Long-lived secrets stored in GitHub

---

### Comparison Table

| Aspect | OIDC (Federated) | Client Secret |
|--------|------------------|---------------|
| **Authentication** | Service Principal + Federated Credential | Service Principal + Password |
| **Secrets in GitHub** | ❌ None (only IDs) | ✅ 1 (client secret) |
| **Token Lifetime** | ~1 hour | 1-2 years |
| **Credential Rotation** | ✅ Automatic | ❌ Manual |
| **Security Level** | 🔒 Highest | ⚠️ Lower |
| **Setup Complexity** | Medium | Simple |

---

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository:

### 1. ACR_NAME

Your Azure Container Registry name.

**How to get it:**
```bash
az acr list --resource-group rg-argocd-demo --query '[0].name' -o tsv
```

**Add to GitHub:**
1. Go to your repository on GitHub
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `ACR_NAME`
5. Value: `<your-acr-name>` (e.g., `acrargocdemo12345`)

### 2. Azure Authentication

**⭐ RECOMMENDED: Workload Identity Federation (OIDC) - Most Secure**

This method uses federated credentials with **no secrets stored in GitHub**.

> **📝 Note:** OIDC still creates a Service Principal, but instead of using a password (client secret), 
> it uses a **federated credential** - a trust relationship between GitHub and Azure. 
> GitHub sends a short-lived token (valid ~1 hour) that Azure validates against this trust relationship.
> No long-lived secrets are stored anywhere!

#### Setup OIDC Authentication

**Step 1: Create Azure AD Application & Service Principal**
```bash
# Set variables
APP_NAME="github-actions-argocd-demo"
REPO_OWNER="<your-github-username>"  # e.g., "johndoe"
REPO_NAME="<your-repo-name>"         # e.g., "poc-argocd-aks-scenario"

# Create the Azure AD application
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
echo "Application ID: $APP_ID"

# Create service principal
az ad sp create --id $APP_ID

# Get the Object ID of the service principal
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)
echo "Service Principal Object ID: $SP_OBJECT_ID"
```

**Step 2: Configure Federated Credentials**
```bash
# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-main-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${REPO_OWNER}/${REPO_NAME}:ref:refs/heads/main\",
    \"description\": \"GitHub Actions - Main Branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Optional: Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${REPO_OWNER}/${REPO_NAME}:pull_request\",
    \"description\": \"GitHub Actions - Pull Requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

**Step 3: Assign Azure Permissions**
```bash
# Get subscription and resource group IDs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG_ID=$(az group show --name rg-argocd-demo --query id -o tsv)

# Assign contributor role to the resource group
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope $RG_ID

echo "✅ OIDC setup complete!"
```

**Step 4: Add GitHub Secrets**

Add these three secrets to your GitHub repository (Settings → Secrets → Actions):

1. **AZURE_CLIENT_ID**
   ```bash
   echo $APP_ID
   ```

2. **AZURE_TENANT_ID**
   ```bash
   az account show --query tenantId -o tsv
   ```

3. **AZURE_SUBSCRIPTION_ID**
   ```bash
   az account show --query id -o tsv
   ```

**Step 5: Update Workflow File**

The workflow in `.github/workflows/build-push.yaml` needs to be updated to use OIDC:

```yaml
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      id-token: write      # Required for OIDC
      contents: write
    
    steps:
      - name: Azure Login with OIDC
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

### Alternative: Service Principal (Legacy - Less Secure)

⚠️ **Not recommended**: Requires storing long-lived secrets in GitHub.

<details>
<summary>Click to expand legacy service principal method</summary>

**Create service principal:**
```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RG_ID=$(az group show --name rg-argocd-demo --query id -o tsv)

az ad sp create-for-rbac \
  --name "github-actions-argocd-demo" \
  --role contributor \
  --scopes $RG_ID \
  --sdk-auth
```

**Add to GitHub as `AZURE_CREDENTIALS` secret** (entire JSON output).

**Use in workflow:**
```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

</details>

**Add to GitHub:**
1. Copy the entire JSON output
2. Go to repository Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `AZURE_CREDENTIALS`
5. Paste the entire JSON as the value

### 3. GITHUB_TOKEN (Automatic)

This is automatically provided by GitHub Actions. No setup needed.

## Workflow Configuration

### Update Repository URL

Edit the following files and replace `<your-username>/<your-repo>` with your actual GitHub repository:

1. [.github/workflows/build-push.yaml](.github/workflows/build-push.yaml)
2. [argocd/applications/sample-app-dev.yaml](argocd/applications/sample-app-dev.yaml)
3. [argocd/applications/sample-app-prod.yaml](argocd/applications/sample-app-prod.yaml)

Example:
```yaml
# Before
repoURL: https://github.com/<your-username>/<your-repo>.git

# After
repoURL: https://github.com/johndoe/poc-argocd-aks-scenario.git
```

## Workflow Triggers

The workflow runs on:

### Automatic Triggers
- **Push to main:** Builds and deploys to production
- **Push to develop:** Builds and deploys to dev
- **Pull Request to main:** Builds only (no deployment)

### Manual Trigger
- **Workflow Dispatch:** Manually trigger from GitHub Actions tab
  - Select environment (dev/prod)
  - Useful for testing or emergency deployments

## Workflow Steps

1. **Checkout Code** - Gets the latest code
2. **Setup Node.js** - Prepares build environment
3. **Install Dependencies** - Runs `npm ci`
4. **Run Tests** - Executes `npm test`
5. **Generate Version** - Creates semantic version tag
6. **Azure Login** - Authenticates with Azure
7. **Build Docker Image** - Creates container image
8. **Push to ACR** - Uploads image to Azure Container Registry
9. **Update Manifests** - Modifies Kubernetes YAML with new image tag
10. **Commit Changes** - Pushes updated manifests back to Git
11. **Create Release** - Tags the release in GitHub

## Testing the Workflow

### Test Locally

Before pushing, test the Docker build:

```bash
cd app
docker build -t test-app .
docker run -p 3000:3000 test-app
curl http://localhost:3000/health
```

### Trigger Workflow

```bash
# Make a change to the app
cd app/src
echo "// Test change" >> server.js

# Commit and push
git add .
git commit -m "Test: trigger CI/CD pipeline"
git push origin main
```

### Monitor Workflow

1. Go to GitHub → Actions tab
2. Click on the workflow run
3. Watch each step execute
4. Check for any errors

## Troubleshooting

### Authentication Failed

**Error:** `Failed to authenticate with Azure`

**Solution:**
- Verify `AZURE_CREDENTIALS` secret is correct
- Check service principal hasn't expired
- Ensure service principal has correct permissions

### Cannot Push to ACR

**Error:** `unauthorized: authentication required`

**Solution:**
```bash
# Verify ACR exists
az acr show --name $ACR_NAME

# Check role assignments
az role assignment list --scope /subscriptions/<sub-id>/resourceGroups/rg-argocd-demo
```

### Image Push Timeout

**Error:** `timeout while pushing to ACR`

**Solution:**
- Check network connectivity
- Verify ACR is in the same region
- Consider increasing timeout in workflow

### Git Push Failed

**Error:** `refusing to allow a GitHub App to create or update workflow`

**Solution:**
1. Go to repository Settings → Actions → General
2. Under "Workflow permissions", select:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests
3. Save

## Advanced Configuration

### Add Environment Protection

For production deployments:

1. Go to repository Settings → Environments
2. Create environment: `prod`
3. Add protection rules:
   - ✅ Required reviewers
   - ✅ Wait timer
   - ✅ Branch restrictions (only `main`)

### Customize Version Format

Edit the version step in [.github/workflows/build-push.yaml](.github/workflows/build-push.yaml):

```yaml
# Semantic versioning
VERSION="v1.2.3-${SHORT_SHA}"

# Date-based versioning
VERSION="$(date +%Y.%m.%d)-${SHORT_SHA}"

# Build number based
VERSION="v1.0.${GITHUB_RUN_NUMBER}"
```

### Add Slack Notifications

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Security Best Practices

### Authentication & Authorization

1. **✅ Use OIDC (OpenID Connect)** - Recommended over service principals
   - No secrets stored in GitHub
   - Short-lived tokens (auto-rotated)
   - Better audit trail
   - Reduced attack surface

2. **Scope permissions appropriately**
   ```bash
   # Good: Scoped to resource group
   az role assignment create --assignee $APP_ID --role Contributor --scope $RG_ID
   
   # Avoid: Subscription-wide access (unless necessary)
   az role assignment create --assignee $APP_ID --role Contributor --scope /subscriptions/$SUB_ID
   ```

3. **Use custom roles** for least privilege
   ```bash
   # Create custom role with only required permissions
   az role definition create --role-definition '{
     "Name": "ACR Push & AKS Deploy",
     "Description": "Can push to ACR and deploy to AKS",
     "Actions": [
       "Microsoft.ContainerRegistry/registries/push/write",
       "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action"
     ],
     "AssignableScopes": ["/subscriptions/'$SUBSCRIPTION_ID'"]
   }'
   ```

4. **Enable branch protection** on main/production branches
   - Require pull request reviews
   - Require status checks to pass
   - Restrict who can push

5. **Use GitHub Environments** for production
   - Add required reviewers
   - Set deployment branches (only `main`)
   - Add wait timers for safety

### Code Security

6. **Run security scans** in pipeline
   - **Trivy** for container image scanning
   - **Snyk** for dependency vulnerabilities
   - **CodeQL** for code analysis

7. **Never commit secrets** to Git
   - Use `.gitignore` properly
   - Use GitHub Secrets for sensitive data
   - Consider **Azure Key Vault** for app secrets

8. **Scan images before deployment**
   ```yaml
   - name: Scan image with Trivy
     uses: aquasecurity/trivy-action@master
     with:
       image-ref: ${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ steps.version.outputs.version }}
       format: 'sarif'
       exit-code: '1'  # Fail on HIGH/CRITICAL
   ```

### Operational Security

9. **Enable audit logging**
   - Azure Activity Log
   - GitHub Actions logs
   - ArgoCD audit logs

10. **Rotate OIDC federated credentials** annually
    ```bash
    # List federated credentials
    az ad app federated-credential list --id $APP_ID
    
    # Delete old credentials
    az ad app federated-credential delete --id $APP_ID --federated-credential-id <cred-id>
    ```

11. **Monitor for anomalies**
    - Failed authentication attempts
    - Unusual deployment patterns
    - Unauthorized access attempts

12. **Use signed commits** (optional but recommended)
    ```bash
    git config --global commit.gpgsign true
    git config --global user.signingkey <your-gpg-key>
    ```

### Comparison: OIDC vs Service Principal

| Aspect | OIDC (Recommended) | Service Principal |
|--------|-------------------|-------------------|
| **Secrets in GitHub** | ❌ None | ✅ Client Secret stored |
| **Token Lifetime** | ⏱️ Minutes | 🕐 Years (until rotated) |
| **Rotation** | ✅ Automatic | ❌ Manual |
| **Audit Trail** | ✅ Better | ⚠️ Limited |
| **Setup Complexity** | ⚠️ Medium | ✅ Simple |
| **Security** | 🔒 Highest | ⚠️ Lower |
| **Cost** | 💰 Free | 💰 Free |

### Recommended Security Checklist

- [ ] Use OIDC authentication (not service principal)
- [ ] Scope permissions to resource group only
- [ ] Enable branch protection on main
- [ ] Require PR reviews for production
- [ ] Add required reviewers for prod deployments
- [ ] Scan container images for vulnerabilities
- [ ] Enable GitHub code scanning (CodeQL)
- [ ] Never commit secrets to Git
- [ ] Use environment-specific secrets
- [ ] Enable audit logging
- [ ] Rotate credentials regularly (if using service principals)
- [ ] Monitor failed authentication attempts

## Next Steps

- Enable branch protection rules
- Set up code scanning (CodeQL)
- Add integration tests
- Configure deployment gates
- Set up monitoring alerts

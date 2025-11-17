# Azure Budget Tracking Setup

This guide explains how to set up Azure credentials so the budget badge in your UTS RAG app can display your current Azure spending.

## What You'll See

Once configured, the bottom of your sidebar menu will show:
- **Remaining budget** in USD
- **Visual progress bar** (green → yellow → red as you approach your limit)
- **Percentage used** and total budget
- Auto-refreshes every minute

## Prerequisites

You need an Azure subscription with the following information:
- Subscription ID
- Tenant ID
- Client ID (Service Principal)
- Client Secret

## Step 1: Get Your Subscription and Tenant IDs

```bash
# Login to Azure CLI
az login

# Get your subscription ID and tenant ID
az account show --query '{subscriptionId:id, tenantId:tenantId}' -o json
```

## Step 2: Create a Service Principal

Create a service principal with the necessary permissions to read cost data:

```bash
# Create service principal with Reader role on subscription
az ad sp create-for-rbac --name "UTS-Budget-Reader" \
  --role "Cost Management Reader" \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# This will output something like:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",      # This is your CLIENT_ID
#   "displayName": "UTS-Budget-Reader",
#   "password": "xxxxxxxxxxxxxxxxxxxxx",                  # This is your CLIENT_SECRET
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"     # This is your TENANT_ID
# }
```

**Important:** Save the `password` (client secret) immediately - you won't be able to see it again!

## Step 3: Add Credentials to Your .env File

Add these credentials to your `.env` file in the UTS root directory:

```bash
# Azure Cost Management
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-app-id
AZURE_CLIENT_SECRET=your-client-secret
```

## Step 4: (Optional) Create a Budget in Azure

If you haven't already, you can create a budget in the Azure portal:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Cost Management + Billing**
3. Click **Budgets**
4. Click **+ Add** to create a new budget
5. Set your budget amount (e.g., $100 for student accounts)
6. Configure alerts if desired

The app will detect your configured budget automatically. If no budget is set, it will default to $100.

## Step 5: Restart Your Backend

After adding the credentials, restart your backend server:

```bash
# If using the start_dev.rb script
ruby stop_dev.rb
ruby start_dev.rb

# Or manually restart the backend
cd app/backend
bundle exec rackup -o 0.0.0.0 -p 4000
```

## Troubleshooting

### Budget Badge Shows $0/$100
- Check that all four Azure credentials are set in your `.env` file
- Verify the service principal has the "Cost Management Reader" role
- Check the backend logs for authentication errors

### Permission Denied Errors
```bash
# Add the Cost Management Reader role explicitly
az role assignment create \
  --assignee YOUR_CLIENT_ID \
  --role "Cost Management Reader" \
  --scope /subscriptions/YOUR_SUBSCRIPTION_ID
```

### Still Not Working?
Check the backend logs:
```bash
tail -f app/logs/backend.log
```

Look for messages starting with `⚠️ Azure Cost Service Error`

## Security Notes

- **Never commit** your `.env` file to git
- The `.env` file should be in your `.gitignore`
- The client secret is sensitive - treat it like a password
- The service principal only has read access to cost data (not your resources)

## API Rate Limits

The frontend refreshes budget data every 60 seconds. Azure Cost Management API has the following limits:
- **100 calls per hour** for most operations
- Budget data is updated by Azure every 8-24 hours

The app caches data on the backend to minimize API calls.

## Testing Without Azure Credentials

If you don't set up the credentials, the app will show a default fallback:
- Budget: $100
- Spent: $0
- This allows development without Azure access

## Additional Resources

- [Azure Cost Management REST API](https://learn.microsoft.com/en-us/rest/api/cost-management/)
- [Azure Service Principals](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli)
- [Azure RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#cost-management-reader)


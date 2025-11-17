# 🌍 Azure Regions for Student Subscriptions

## ✅ Regions That Typically Work

Based on Azure for Students subscription policies, these regions usually work:

### Recommended (Try First)
1. **centralus** - ⭐ Best choice for students
2. **westus2** - ⭐ Reliable alternative
3. **eastus** - Good option

### European Students
4. **northeurope** - Recommended for EU
5. **westeurope** - Alternative EU
6. **uksouth** - UK students

### Asian Students
7. **southeastasia** - Southeast Asia
8. **eastasia** - East Asia
9. **japaneast** - Japan

### Other Options
10. **canadacentral** - Canadian students

## 🚀 How to Specify Region

### Option 1: Environment Variable (Easiest)

```bash
# Before running the deployment
export AZURE_LOCATION=centralus

# Then deploy
./rag_deploy
```

### Option 2: Edit env.template

```bash
# Create your .env file
cp env.template .env

# Edit it
vim .env

# Set the region
AZURE_LOCATION=centralus

# Deploy using the script
ruby deploy.rb deploy
```

### Option 3: Let the Script Handle It

If you don't specify a region and it fails, the script will:
1. Detect the region restriction error
2. Show you available regions
3. Let you choose one
4. Automatically recreate in the new region

## 🎯 Current Default

The deployment now defaults to **centralus** (changed from australiaeast).

## ❌ Regions That DON'T Work for Students

- ❌ australiaeast (restricted)
- ❌ australiasoutheast (restricted)
- ❌ brazilsouth (often restricted)
- ❌ southafricanorth (often restricted)
- ❌ Most premium/specialized regions

## 💡 Pro Tip: Test First

Before deploying everything, test if a region works:

```bash
# Try creating a simple resource group
az group create --name test-rg --location centralus

# If it works:
✅ Good to use this region!

# If it fails with RequestDisallowedByAzure:
❌ Try a different region

# Clean up
az group delete --name test-rg --yes
```

## 🚀 Quick Fix for Your Current Situation

You have `rg-rag-system` in `australiaeast` that failed. Here's what to do:

### Option A: Delete and Retry with centralus

```bash
# Delete the failed resource group
./rag_deploy
# Choose: 3. Selective Delete
# Select: 1 (rg-rag-system)
# Type: DELETE

# Then deploy again (will use centralus by default now)
./rag_deploy
# Choose: 1. Deploy Infrastructure
```

### Option B: Specify Region Explicitly

```bash
# Set region before deploying
export AZURE_LOCATION=centralus
./rag_deploy
```

### Option C: Let Error Handler Fix It

```bash
# Just deploy - when it fails, it will ask you to choose a region
./rag_deploy
# It will fail on australiaeast
# Then show you a list of regions
# You choose one
# It recreates automatically
```

---

**Recommended:** Use Option A - delete the old RG, then deploy with centralus! 🚀


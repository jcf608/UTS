# 📖 Usage Guide - RAG Deploy CLI

## 🎯 Two Ways to Delete Resources

### Option 3: Selective Delete (Cherry-Pick) 🎯

**Use when:** You want to delete specific resources while keeping others.

```bash
./rag_deploy

# You'll see:
1. 🚀 Deploy Infrastructure
2. 📊 Check Status
3. 🎯 Selective Delete          ← Choose this!
4. 🗑️  Destroy All Infrastructure
5. 👋 Exit

Choose action (1-5): 3
```

**What happens:**
1. Shows ALL your resource groups
2. Shows ALL resources inside each group (indented)
3. You select what to delete by typing numbers
4. Requires typing "DELETE" to confirm
5. **Waits for deletion to complete** before finishing

**Example tree view:**
```
🌳 Resource Tree

[1] 📁 Resource Group: rg-rag-system
    [2] 📦 ragstoragee55bfb3c (storageAccounts)
    [3] 📦 rag-search-service (searchServices)
    [4] 📦 rag-openai-service (accounts)

[5] 📁 Resource Group: rg-test
    [6] 📦 test-vm (virtualMachines)

Enter selection: 2 3
```

**Selection examples:**
- `2` - Delete only the storage account
- `2 3 4` - Delete storage, search, and openai
- `1` - Delete entire rg-rag-system (and everything inside)
- `5` - Delete entire rg-test
- `all` - Delete EVERYTHING (dangerous!)
- Just press ENTER - Cancel

### Option 4: Destroy All Infrastructure 🗑️

**Use when:** You want to delete the entire resource group created by the deployment.

```bash
./rag_deploy

Choose action (1-5): 4
```

**What happens:**
1. Requires typing "destroy" to confirm
2. Deletes the entire `rg-rag-system` resource group
3. **Waits for deletion to complete** (5-10 minutes)
4. Confirms when done

**This deletes:**
- ✅ The entire resource group
- ✅ All resources inside it
- ✅ Everything created by the deployment

## 🎭 Comparison

| Feature | Selective Delete (3) | Destroy All (4) |
|---------|---------------------|-----------------|
| **See all resources** | ✅ Yes - tree view | ❌ No |
| **Choose what to delete** | ✅ Yes - pick specific items | ❌ No - deletes everything |
| **Delete entire RGs** | ✅ Yes - select RG number | ✅ Yes - deletes configured RG |
| **Delete individual resources** | ✅ Yes | ❌ No |
| **Confirmation required** | ✅ Type "DELETE" | ✅ Type "destroy" |
| **Wait for completion** | ✅ Yes | ✅ Yes |
| **See what you're deleting** | ✅ Yes - shows preview | ❌ No |

## 💡 When to Use Each

### Use Selective Delete (3) when:
- ✅ Testing and want to remove test resources
- ✅ Want to keep data but remove expensive services
- ✅ Have multiple resource groups to manage
- ✅ Need fine-grained control
- ✅ Want to see everything before deleting

### Use Destroy All (4) when:
- ✅ Done with the project completely
- ✅ Starting fresh deployment
- ✅ Know you want to delete everything
- ✅ Only have one resource group to worry about

## 🚀 Complete Workflow Example

### Scenario: Clean up but keep your data

```bash
./rag_deploy

# 1. Choose Azure
Choose provider (1-3): 1

# 2. Choose Selective Delete
Choose action (1-5): 3

# 3. Authenticate
Use this account? (Y/n): y

# 4. See your resources
[1] 📁 Resource Group: rg-rag-system
    [2] 📦 ragstoragee55bfb3c (storageAccounts)
    [3] 📦 rag-search-service (searchServices)
    [4] 📦 rag-openai-service (accounts)

# 5. Delete only AI services (keep storage with data)
Enter selection: 3 4

# 6. Confirm what will be deleted
⚠️  The following will be DELETED:
  🗑️  Resource: rag-search-service (in rg-rag-system)
  🗑️  Resource: rag-openai-service (in rg-rag-system)

# 7. Type DELETE to confirm
Type "DELETE" to confirm: DELETE

# 8. Watch deletion
🗑️  Deleting rag-search-service...
   ✅ Deleted rag-search-service
🗑️  Deleting rag-openai-service...
   ✅ Deleted rag-openai-service

✅ Deletion complete!
```

**Result:** Your storage account (with all your documents) is safe, but expensive AI services are removed!

## 🔧 Both Options Now Use Wait Mode

Both deletion methods now **wait for completion** instead of returning immediately:

- ✅ **Selective Delete**: Waits for each resource deletion
- ✅ **Destroy All**: Waits for resource group deletion (~5-10 minutes)

No more `--no-wait` flag - you'll get confirmation when deletion actually completes!

---

**The selective delete feature IS there - it's option 3!** Try it now:

```bash
./rag_deploy
# Select: 3. Selective Delete
```


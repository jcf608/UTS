# 📝 Changelog - RAG Deploy CLI

## Version 2.0 - Enhanced Deployment Experience

### 🎯 Major Features Added

#### 1. **Pre-Flight Region Validation** ✅
- **What:** Checks if region supports ALL required services BEFORE creating anything
- **Why:** Prevents wasting time creating resources that will fail
- **How:** Validates Storage, AI Search, and OpenAI availability

**New Workflow:**
```
1. Authenticate
2. Check if region supports:
   ✅ Storage Accounts
   ✅ AI Search
   ✅ OpenAI
3. If any service is missing → offer compatible regions
4. Only then create resources
```

**Benefits:**
- ✅ No failed deployments due to region restrictions
- ✅ No orphaned resource groups
- ✅ Saves time - validates before creating
- ✅ Shows you compatible regions automatically

#### 2. **Looping Menu System** ✅
- **What:** CLI loops back to menu after each operation
- **Why:** Perform multiple actions without restarting
- **How:** Changed from `exec()` to `system()` and added loop

**New Workflow:**
```
1. Select provider once (Azure/AWS/GCP)
2. Loop:
   - Choose action (Deploy/Status/Selective Delete/Destroy/Exit)
   - Execute action
   - Return to menu
3. Exit when ready
```

**Benefits:**
- ✅ No need to restart CLI for each operation
- ✅ Can deploy, check status, then delete in one session
- ✅ Better user experience

#### 3. **Selective Delete Feature** ✅
- **What:** Interactive tree view to cherry-pick resources for deletion
- **Why:** Fine-grained control over what gets deleted
- **How:** Shows resource groups with indented resources, multi-select

**Features:**
- Shows ALL resource groups in subscription
- Shows ALL resources inside each group (indented)
- Multi-select: `2 3 4` or `1` or `all`
- Confirmation required: Type "DELETE"
- Wait mode: Waits for deletion to complete

**Use Cases:**
- Remove expensive AI services, keep data
- Delete test resources, keep production
- Delete entire resource groups
- Granular cleanup

#### 4. **Wait Mode for Deletions** ✅
- **What:** All delete operations wait for completion
- **Why:** Know when deletion actually finishes
- **How:** Removed `--no-wait` flag

**Changes:**
- Selective Delete: Waits for each resource
- Destroy All: Waits for resource group deletion (5-10 min)

### 🐛 Bug Fixes

#### Fixed: `gets` vs `$stdin.gets`
- **Issue:** Ruby's `gets` reads from ARGV files when command-line args present
- **Fix:** Changed all `gets` → `$stdin.gets` (13 instances)
- **Impact:** All interactive prompts now work correctly

#### Fixed: Missing `securerandom` Require
- **Issue:** `SecureRandom` not loaded, causing NameError
- **Fix:** Added `require 'securerandom'`
- **Impact:** Storage account names generate correctly

#### Fixed: Default Region for Students
- **Issue:** Default `australiaeast` restricted for student accounts
- **Fix:** Changed default to `centralus`
- **Impact:** Better success rate for student subscriptions

#### Fixed: Error Output in Exceptions
- **Issue:** Command failures didn't include output in error
- **Fix:** Include full output in raised exception
- **Impact:** Better error messages for debugging

### 📊 Menu Structure Changes

**Before (v1.0):**
```
1. Deploy Infrastructure
2. Check Status
3. Destroy Infrastructure
4. Exit
```

**After (v2.0):**
```
1. Deploy Infrastructure
2. Check Status
3. Selective Delete          ← NEW!
4. Destroy All Infrastructure
5. Exit
```

### 🎯 Deployment Flow Changes

**Before (v1.0):**
```
1. Authenticate
2. Create Resource Group
3. Try to create Storage
4. ❌ FAIL on region restriction
5. Handle error, retry
```

**After (v2.0):**
```
1. Authenticate
2. Validate Region Capabilities
   - Check Storage availability
   - Check AI Search availability
   - Check OpenAI availability
3. If any missing → choose compatible region
4. Create Resource Group (in validated region)
5. ✅ Create Storage (guaranteed to work)
6. ✅ Create all other resources
```

### 📝 Documentation Added

- `USAGE_GUIDE.md` - Comparison of delete options
- `REGIONS_FOR_STUDENTS.md` - Region recommendations
- `CHANGELOG.md` - This file
- Updated `CLI_DEMO.md` - Selective delete examples
- Updated `QUICKSTART.md` - New features
- Updated `README.md` - Complete documentation

### 🚀 Migration Guide

If you were using v1.0:

**No changes needed!** The CLI is backward compatible:
- Same command: `./rag_deploy`
- Same basic workflow
- New features are additions, not breaking changes

### 🎯 Next Steps for Users

1. **Clean up failed deployments:**
   ```bash
   ./rag_deploy
   # Choose: 3. Selective Delete
   # Delete old resource groups
   ```

2. **Deploy with validated region:**
   ```bash
   ./rag_deploy
   # Choose: 1. Deploy
   # Region will be validated before creating anything
   ```

3. **Use looping menu:**
   - Deploy infrastructure
   - Check status
   - Use selective delete for cleanup
   - All in one session!

---

## Version 1.0 - Initial Release

- Basic deployment workflow
- Provider selection (Azure only)
- Authentication flow
- Resource creation
- Simple destroy (entire RG)

---

**Current Version:** 2.0
**Last Updated:** November 17, 2025


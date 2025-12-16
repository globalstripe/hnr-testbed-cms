# Webiny Environment Detection Issue

## The Problem

When running `yarn webiny info`:
- Shows only 2 environments (dev and stage)
- Says "no stacks deployed" for those environments
- Doesn't show pre-prod environment in the list
- But `yarn webiny info --env preprod` works fine

## Root Cause

### Issue 1: Empty Stacks in Pulumi Registry

The `dev` environment has a problem:
- ✅ State file exists in S3: `organization/core/dev.json` (has 12 resources)
- ❌ Pulumi stack shows 0 resources when queried
- This happens because Pulumi created empty stacks that aren't reading the actual state files

### Issue 2: Pre-prod State Files Not in S3

The `pre-prod` environment:
- ✅ Stacks exist in Pulumi registry with resources:
  - `organization/core/pre-prod` (12 resources)
  - `organization/api/pre-prod` (99 resources)
  - `organization/admin/pre-prod` (8 resources)
  - `organization/website/pre-prod` (40 resources)
- ❌ No state files in S3 yet
- Webiny detects environments by scanning S3 state files, so pre-prod doesn't appear

## How Webiny Detects Environments

Webiny's `info` command:
1. Scans S3 (or local `.pulumi/`) for state files
2. Extracts environment names from file paths
3. For each environment found, tries to read stack information
4. If stacks show 0 resources, it says "no stacks deployed"

## Solutions

### Solution 1: Fix Dev Environment (Restore State)

The dev environment state files are in S3 but Pulumi isn't reading them. You need to:

1. Delete the empty stacks
2. Let Webiny recreate them (it should read from S3 state files)

Or manually import the state (we tried this before but it had issues).

### Solution 2: Wait for Pre-prod State Files

Pre-prod state files should be written to S3 when:
- Deployment fully completes
- All apps finish deploying
- Pulumi operations complete

Check if they appear:
```bash
aws s3 ls s3://pulumi-state-773984399528/organization/ --profile testbed --recursive | grep pre-prod
```

### Solution 3: Force State File Write

If pre-prod state files don't appear, you can:
1. Run a small update to trigger state write:
   ```bash
   yarn webiny deploy apps/core --env preprod
   ```
2. Or manually copy state from Pulumi to S3 (if you can export it)

## Current Status

### Environments in S3:
- ✅ `dev` - State files exist (but Pulumi reads as empty)
- ✅ `stage` - State files exist
- ❌ `pre-prod` - No state files in S3 yet

### Environments in Pulumi Registry:
- ⚠️ `dev` - Stack exists but shows 0 resources
- ❓ `stage` - Not checked
- ✅ `pre-prod` - Stacks exist with resources (12, 99, 8, 40)

## Verification Commands

```bash
# Check what environments Webiny sees (from S3)
aws s3 ls s3://pulumi-state-773984399528/organization/ \
  --profile testbed --recursive | \
  awk '{print $4}' | cut -d'/' -f3 | cut -d'.' -f1 | sort | uniq

# Check Pulumi stacks
export PULUMI_BACKEND_URL="s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env | cut -d'=' -f2-)
pulumi stack ls --all

# Check if state files have resources
aws s3 cp s3://pulumi-state-773984399528/organization/core/dev.json - \
  --profile testbed | jq '.checkpoint.latest.resources | length'
```

## Expected Behavior

After fixing:
- `yarn webiny info` should show all 3 environments
- Each environment should show deployment details
- Pre-prod should appear once state files are in S3


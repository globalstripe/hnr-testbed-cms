# How to Check Where Pulumi State is Stored

This guide explains how to verify where your Pulumi state files are stored - either locally or in S3.

## Quick Overview

- **S3 Backend**: State files stored in `s3://pulumi-state-773984399528/organization/{app}/{env}.json`
- **Local Backend**: State files stored in `.pulumi/apps/{app}/.pulumi/stacks/{app}/{env}.json`

## Step 1: Check Your Configuration

First, check if S3 backend is configured in your `.env` file:

```bash
grep "^PULUMI_BACKEND_URL" .env
```

### Results:

- **If you see**: `PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?...`
  - ✅ State is configured to use **S3 backend**
  - State files should be in S3

- **If you see**: `#PULUMI_BACKEND_URL=...` or nothing
  - ⚠️ State is using **local backend** (default)
  - State files are in `.pulumi/` directory

## Step 2: Check Local State Files

To check if state files exist locally:

```bash
# Check for a specific environment
find .pulumi -name "*pre-prod*" -type f

# Or check for all environments
find .pulumi -name "*.json" -path "*/stacks/*" -type f
```

### Expected Local Paths:
```
.pulumi/apps/core/.pulumi/stacks/core/pre-prod.json
.pulumi/apps/api/.pulumi/stacks/api/pre-prod.json
.pulumi/apps/admin/.pulumi/stacks/admin/pre-prod.json
.pulumi/apps/website/.pulumi/stacks/website/pre-prod.json
```

## Step 3: Check S3 State Files

To check if state files exist in S3:

```bash
# Check for a specific environment
aws s3 ls s3://pulumi-state-773984399528/organization/ \
  --profile testbed --recursive | grep pre-prod

# List all state files in S3
aws s3 ls s3://pulumi-state-773984399528/organization/ \
  --profile testbed --recursive
```

### Expected S3 Paths:
```
s3://pulumi-state-773984399528/organization/core/pre-prod.json
s3://pulumi-state-773984399528/organization/api/pre-prod.json
s3://pulumi-state-773984399528/organization/admin/pre-prod.json
s3://pulumi-state-773984399528/organization/website/pre-prod.json
```

## Step 4: Check Pulumi Stack Registry

To see what stacks Pulumi knows about and their backend:

```bash
# Set environment variables
export PULUMI_BACKEND_URL="s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env | cut -d'=' -f2-)

# List all stacks
pulumi stack ls --all

# Filter for specific environment
pulumi stack ls --all | grep pre-prod
```

This shows:
- Stack names (e.g., `organization/core/pre-prod`)
- Last update time
- Resource count

## Step 5: Use the Automated Check Script

We've created a script that checks all locations automatically:

```bash
./check-state-location.sh pre-prod
```

This script will:
1. Check your `.env` configuration
2. Look for local state files
3. Look for S3 state files
4. Check Pulumi stack registry
5. Provide a summary

## Understanding the Results

### Scenario 1: State in S3 ✅
- `.env` has `PULUMI_BACKEND_URL` set to S3
- Files found in S3: `organization/{app}/{env}.json`
- No files in local `.pulumi/` directory
- **Result**: State is correctly stored in S3

### Scenario 2: State Local ⚠️
- `.env` has `PULUMI_BACKEND_URL` commented out
- Files found in `.pulumi/apps/`
- No files in S3
- **Result**: State is stored locally (not in S3)

### Scenario 3: State in Both (Migration in Progress)
- Files exist in both locations
- **Result**: You're in the middle of migration or have backups

### Scenario 4: No State Files Found
- Stacks exist in Pulumi registry but no state files
- **Possible reasons**:
  - Deployment is still in progress (state files written at the end)
  - State files haven't been created yet
  - Permissions issue preventing write to S3

## Troubleshooting

### State Files Not Appearing in S3

1. **Wait for deployment to complete**
   - State files are written at the end of Pulumi operations
   - Check again after deployment finishes

2. **Verify AWS credentials**
   ```bash
   aws sts get-caller-identity --profile testbed
   ```

3. **Check S3 bucket permissions**
   ```bash
   aws s3api head-bucket --bucket pulumi-state-773984399528 --profile testbed
   ```

4. **Check if state files are being written**
   - Look for errors in deployment logs
   - Check Pulumi output for backend errors

### State Files in Wrong Location

If state files are in the wrong location:

1. **To switch from local to S3**:
   - Uncomment `PULUMI_BACKEND_URL` in `.env`
   - Run deployment (state will migrate to S3)

2. **To switch from S3 to local**:
   - Comment out `PULUMI_BACKEND_URL` in `.env`
   - State will be read/written locally

## Quick Reference Commands

```bash
# Check configuration
grep "^PULUMI_BACKEND_URL" .env

# Check local state
find .pulumi -name "*{env}*" -type f

# Check S3 state
aws s3 ls s3://pulumi-state-773984399528/organization/ \
  --profile testbed --recursive | grep {env}

# Check Pulumi stacks
export PULUMI_BACKEND_URL="s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
pulumi stack ls --all | grep {env}

# Use automated script
./check-state-location.sh {env}
```

Replace `{env}` with your environment name (e.g., `dev`, `pre-prod`, `stage`, `prod`).

## State File Format

State files are JSON files containing:
- Stack name
- Resource definitions
- Outputs
- Secrets (encrypted)
- Metadata

Example stack names:
- `organization/core/dev`
- `organization/api/pre-prod`
- `organization/admin/stage`
- `organization/website/prod`

## Additional Resources

- [PULUMI.md](./PULUMI.md) - Complete Pulumi S3 backend setup documentation
- [MIGRATION-SOLUTION.md](./MIGRATION-SOLUTION.md) - Guide for migrating state to S3


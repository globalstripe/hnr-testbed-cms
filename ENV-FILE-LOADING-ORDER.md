# Webiny Environment File Loading Order

## The Issue You Encountered

You created `.env-prod` (with a **hyphen**), but Webiny looks for `.env.prod` (with a **dot**).

This caused:
- Webiny to not find the environment-specific file
- Falling back to base `.env` file
- If base `.env` didn't have `WEBINY_PULUMI_BACKEND` set, Webiny tried to use local state
- Production deployments are blocked from using local state (safety feature)

## Correct File Naming

Webiny uses **dots** (`.`) to separate environment names:

| Command | File Name Webiny Looks For |
|---------|---------------------------|
| `--env prod` | `.env.prod` |
| `--env pre-prod` | `.env.pre-prod` |
| `--env dev` | `.env.dev` |
| `--env stage` | `.env.stage` |

**Important**: The environment name in the file must match **exactly** what you use in the `--env` flag.

## Loading Order

When you run `yarn webiny deploy --env prod`, Webiny loads variables in this order:

1. **`.env`** (base file - always loaded first)
2. **`.env.prod`** (environment-specific - overrides base `.env`)
3. **App-specific files** (e.g., `apps/core/.env.prod`)

**Later files override earlier ones**, so `.env.prod` will override values from `.env`.

## Why Your Deployment Failed

### Scenario 1: File Named Wrong
- You had: `.env-prod` (hyphen)
- Webiny looked for: `.env.prod` (dot)
- Result: File not found → fell back to `.env`
- If `.env` didn't have `WEBINY_PULUMI_BACKEND` → tried to use local state
- Production blocks local state → error

### Scenario 2: Variable Commented Out
- File exists: `.env.prod` ✅
- But `WEBINY_PULUMI_BACKEND` is commented out in `.env.prod`
- Base `.env` also doesn't have it (or it's commented)
- Result: No S3 backend configured → tries local state → blocked

## Solution

### 1. Correct File Names

```bash
# ✅ Correct
.env.prod          # for --env prod
.env.pre-prod      # for --env pre-prod
.env.dev           # for --env dev

# ❌ Wrong
.env-prod        # Webiny won't find this
.env_pre-prod     # Wrong separator
```

### 2. Ensure Variables Are Set

Your `.env.prod` should have:
```bash
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
```

**Not commented out!**

### 3. Base .env Strategy

You have two options:

**Option A: Set in base `.env` (shared across all environments)**
```bash
# .env (base)
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
```
- All environments use S3
- Simple, but less flexible

**Option B: Set per environment (recommended for production)**
```bash
# .env (base) - no backend set, or commented out
# WEBINY_PULUMI_BACKEND=s3://...

# .env.prod (production-specific)
WEBINY_PULUMI_BACKEND=s3://pulumi-state-prod-bucket
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks-prod

# .env.pre-prod (pre-prod-specific)
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
```
- Each environment can have its own bucket
- More secure for production

## Production Safety Feature

Webiny has a safety feature that **blocks production deployments from using local state**:

```
webiny error: Please confirm you want to use local Pulumi state files 
with your production deployment by appending --allow-local-state-files
```

This happens when:
- `WEBINY_PULUMI_BACKEND` is not set (or commented out)
- Webiny tries to use local `.pulumi/` folder
- Production environment detected
- Deployment is blocked for safety

**Solution**: Always set `WEBINY_PULUMI_BACKEND` in your `.env.prod` file.

## Verification

After fixing, verify the configuration:

```bash
# Check file exists with correct name
ls -la .env.prod

# Check variable is set (not commented)
grep "^WEBINY_PULUMI_BACKEND" .env.prod

# Test deployment
yarn webiny deploy --env prod --no-package-versions-check
```

## Current Status

✅ **Fixed**: `.env-prod` renamed to `.env.prod`
✅ **Verified**: `.env.prod` has `WEBINY_PULUMI_BACKEND` set
✅ **Result**: Production deployments should now use S3 backend

## Best Practice

For production environments, always:
1. Use `.env.prod` (with dot, not hyphen)
2. Set `WEBINY_PULUMI_BACKEND` to S3 (never use local state)
3. Use a separate S3 bucket for production
4. Use separate AWS account for production (if possible)


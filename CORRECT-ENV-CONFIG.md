# Correct .env Configuration for Webiny S3 Backend

## The Issue

You were using `PULUMI_BACKEND_URL`, but **Webiny uses `WEBINY_PULUMI_BACKEND`** instead.

According to the [Webiny documentation](https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files), Webiny has its own environment variable for configuring the Pulumi backend.

## Correct Configuration

Update your `.env` file with the following:

```bash
# Webiny S3 Backend Configuration
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528

# Pulumi DynamoDB State Locking (for concurrent deployment safety)
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks

# Pulumi Secrets Configuration (keep your existing values)
PULUMI_SECRETS_PROVIDER=passphrase
PULUMI_CONFIG_PASSPHRASE=491d6b80617ad9662f797d6e83f8ceff

# Comment out or remove - Webiny doesn't use this
# PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed
```

## Key Points

### 1. WEBINY_PULUMI_BACKEND
- **Required**: This is what Webiny uses to configure the S3 backend
- **Format**: Simple S3 URI - `s3://bucket-name`
- **No query parameters**: Webiny handles region/profile internally

### 2. PULUMI_S3_BACKEND_DYNAMODB_TABLE
- **Keep this**: It's a standard Pulumi environment variable
- **Purpose**: Enables DynamoDB state locking to prevent concurrent deployment conflicts
- **Value**: `pulumi-locks` (your existing table)
- **Status**: ✅ Table exists and is active

### 3. PULUMI_BACKEND_URL
- **Remove/Comment out**: Webiny doesn't recognize this variable
- **Why**: Webiny has its own backend configuration mechanism
- **Impact**: This is why pre-prod didn't use S3 - Webiny ignored this variable

## How It Works

1. **Webiny reads `WEBINY_PULUMI_BACKEND`** and configures Pulumi to use S3
2. **Pulumi reads `PULUMI_S3_BACKEND_DYNAMODB_TABLE`** for state locking
3. **State files are stored in**: `s3://pulumi-state-773984399528/organization/{app}/{env}.json`
4. **Locks are managed in**: DynamoDB table `pulumi-locks`

## After Updating

1. **Future deployments will use S3**:
   ```bash
   yarn webiny deploy --env preprod
   ```

2. **State files will appear in S3**:
   ```bash
   aws s3 ls s3://pulumi-state-773984399528/organization/ --profile testbed --recursive | grep preprod
   ```

3. **Webiny will detect environments from S3**:
   ```bash
   yarn webiny info
   # Should now show preprod in the list
   ```

## Verification

After updating `.env`, test it:

```bash
# 1. Verify variables are set
grep "^WEBINY_PULUMI_BACKEND" .env
grep "^PULUMI_S3_BACKEND_DYNAMODB_TABLE" .env

# 2. Deploy a small change to test
yarn webiny deploy apps/core --env preprod

# 3. Check if state file is in S3
aws s3 ls s3://pulumi-state-773984399528/organization/core/ --profile testbed --recursive | grep preprod
```

## Why This Matters

- **Without `WEBINY_PULUMI_BACKEND`**: Webiny uses local backend (`.pulumi/` folder)
- **With `WEBINY_PULUMI_BACKEND`**: Webiny uses S3 backend
- **With `PULUMI_S3_BACKEND_DYNAMODB_TABLE`**: Prevents concurrent deployment conflicts

## Reference

- [Webiny State Files Documentation](https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files)


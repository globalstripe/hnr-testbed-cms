# Fix: WEBINY_PULUMI_BACKEND URL Format

## The Problem

Your current `.env` has:
```bash
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed
```

But Webiny is:
1. **Appending `/apps/core`** to the URL, making it:
   ```
   s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed/apps/core
   ```

2. **Misinterpreting the profile parameter** as `testbed/apps/core` instead of just `testbed`

This causes the error:
```
failed to get shared config profile, testbed/apps/core
```

## The Solution

According to the [Webiny documentation](https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files), `WEBINY_PULUMI_BACKEND` should be **just the bucket URI**, with **no query parameters**.

### Correct Format

Update your `.env` file:

```bash
# Webiny S3 Backend - SIMPLE FORMAT, NO QUERY PARAMETERS
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528

# Pulumi DynamoDB State Locking
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks

# Pulumi Secrets
PULUMI_SECRETS_PROVIDER=passphrase
PULUMI_CONFIG_PASSPHRASE=491d6b80617ad9662f797d6e83f8ceff
```

### Why This Works

1. **Webiny handles region/profile internally** - It uses your AWS configuration (credentials, region, profile) from:
   - AWS credentials file (`~/.aws/credentials`)
   - AWS config file (`~/.aws/config`)
   - Environment variables (`AWS_PROFILE`, `AWS_REGION`)

2. **No query parameters needed** - Webiny constructs the full Pulumi backend URL internally

3. **AWS Profile** - Set via `AWS_PROFILE` environment variable or AWS config, not in the backend URL

## Setting AWS Profile for Webiny

Since you're using the `testbed` profile, you have a few options:

### Option 1: Set AWS_PROFILE Environment Variable

Add to your `.env`:
```bash
AWS_PROFILE=testbed
```

### Option 2: Use AWS Default Profile

Make `testbed` your default profile in `~/.aws/config`:
```ini
[default]
region = eu-west-1
# ... your testbed credentials
```

### Option 3: Set in Shell Before Running

```bash
export AWS_PROFILE=testbed
yarn webiny deploy --env pre-prod
```

## Complete .env Configuration

```bash
# AWS Configuration
AWS_REGION=eu-west-1
AWS_PROFILE=testbed

# Webiny S3 Backend (SIMPLE - just bucket URI)
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528

# Pulumi DynamoDB State Locking
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks

# Pulumi Secrets
PULUMI_SECRETS_PROVIDER=passphrase
PULUMI_CONFIG_PASSPHRASE=491d6b80617ad9662f797d6e83f8ceff
```

## After Fixing

1. **Update `.env`** with the simple format (no query parameters)

2. **Set AWS profile** (via `AWS_PROFILE` in `.env` or shell)

3. **Try deploying again**:
   ```bash
   yarn webiny deploy --env pre-prod --no-package-versions-check
   ```

4. **Verify it works** - The backend URL should now be just the bucket, and Webiny won't append `/apps/core` incorrectly

## Why Query Parameters Don't Work

Webiny's internal code constructs the Pulumi backend URL by:
1. Taking `WEBINY_PULUMI_BACKEND` 
2. Appending app-specific paths (like `/apps/core`)
3. Passing it to Pulumi

When you include query parameters, Webiny treats them as part of the path, causing:
- `/apps/core` to be appended after `?profile=testbed`
- Pulumi to interpret `testbed/apps/core` as a profile name

The solution is to keep `WEBINY_PULUMI_BACKEND` simple and let Webiny/AWS handle region and profile separately.


# Environment-Specific .env Files in Webiny

## Overview

Yes! Webiny supports environment-specific `.env` files. This allows you to have different configurations for each environment (dev, stage, pre-prod, prod, etc.).

## How It Works

When you run a Webiny command with `--env <environment>`, Webiny looks for environment-specific configuration files in this order:

1. **`.env.<environment>`** - Environment-specific file (e.g., `.env.pre-prod`, `.env.dev`)
2. **`.env`** - Default/fallback file (loaded for all environments)
3. **App-specific files** - `.env` files in individual app directories

### Example

When you run:
```bash
yarn webiny deploy --env pre-prod
```

Webiny will look for:
1. `.env.pre-prod` (environment-specific)
2. `.env` (default - always loaded)
3. `apps/core/.env.pre-prod` (app-specific)
4. `apps/core/.env` (app-specific default)

## File Naming Convention

Environment-specific files use the format:
```
.env.<environment-name>
```

Examples:
- `.env.dev` - for dev environment
- `.env.stage` - for stage environment  
- `.env.pre-prod` - for pre-prod environment
- `.env.prod` - for production environment

**Note**: The environment name in the file must match exactly what you use in the `--env` flag.

## Use Cases

### 1. Different AWS Profiles per Environment

```bash
# .env (default - shared config)
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks

# .env.dev (dev-specific)
AWS_PROFILE=dev-account
AWS_REGION=us-east-1

# .env.pre-prod (pre-prod-specific)
AWS_PROFILE=preprod-account
AWS_REGION=eu-west-1

# .env.prod (production-specific)
AWS_PROFILE=prod-account
AWS_REGION=eu-west-1
```

### 2. Different S3 Buckets per Environment

```bash
# .env.dev
WEBINY_PULUMI_BACKEND=s3://pulumi-state-dev-773984399528

# .env.pre-prod
WEBINY_PULUMI_BACKEND=s3://pulumi-state-preprod-773984399528

# .env.prod
WEBINY_PULUMI_BACKEND=s3://pulumi-state-prod-773984399528
```

### 3. Environment-Specific Secrets

```bash
# .env.dev
PULUMI_CONFIG_PASSPHRASE=dev-passphrase-123

# .env.pre-prod
PULUMI_CONFIG_PASSPHRASE=preprod-passphrase-456

# .env.prod
PULUMI_CONFIG_PASSPHRASE=prod-passphrase-789
```

### 4. Different Regions per Environment

```bash
# .env.dev
AWS_REGION=us-east-1

# .env.pre-prod
AWS_REGION=eu-west-1

# .env.prod
AWS_REGION=eu-west-1
```

## Configuration Priority

Variables are loaded in this order (later ones override earlier ones):

1. `.env` (base configuration)
2. `.env.<environment>` (environment-specific overrides)
3. App-specific `.env` files
4. Command-line environment variables

## Example Setup

### Base `.env` file (shared across all environments):
```bash
# Shared configuration
PULUMI_SECRETS_PROVIDER=passphrase
DEBUG=false

# Default AWS settings (can be overridden per environment)
AWS_REGION=eu-west-1
```

### `.env.pre-prod` file (pre-prod specific):
```bash
# Pre-prod specific overrides
AWS_PROFILE=testbed
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
PULUMI_CONFIG_PASSPHRASE=your-preprod-passphrase
```

### `.env.prod` file (production specific):
```bash
# Production specific overrides
AWS_PROFILE=production-account
WEBINY_PULUMI_BACKEND=s3://pulumi-state-prod-bucket
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks-prod
PULUMI_CONFIG_PASSPHRASE=your-prod-passphrase
```

## Benefits

1. **Separation of Concerns**: Keep environment-specific configs separate
2. **Security**: Different secrets/passphrases per environment
3. **Flexibility**: Different AWS accounts/regions per environment
4. **Organization**: Clear which config applies to which environment
5. **Version Control**: Can commit `.env.example` files, keep actual secrets out

## Best Practices

1. **Never commit `.env` files with secrets** to version control
2. **Use `.env.example`** files to document required variables
3. **Keep shared config in `.env`**, overrides in `.env.<env>`
4. **Use different passphrases** for each environment
5. **Use separate AWS accounts** for production environments

## Creating Environment-Specific Files

You can create them manually:

```bash
# Copy base .env as template
cp .env .env.pre-prod

# Edit with environment-specific values
# Then update the values for pre-prod
```

Or create from scratch:

```bash
# Create .env.pre-prod
cat > .env.pre-prod <<EOF
# Pre-prod Environment Configuration
AWS_PROFILE=testbed
AWS_REGION=eu-west-1
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
PULUMI_SECRETS_PROVIDER=passphrase
PULUMI_CONFIG_PASSPHRASE=your-preprod-passphrase
EOF
```

## Debugging

To see which files Webiny is loading:

```bash
yarn webiny deploy --env pre-prod --debug
```

Look for lines like:
```
webiny debug: No environment file found on /Users/.../.env.pre-prod.
webiny debug: Successfully loaded environment variables from /Users/.../.env.
```

This tells you:
- Which environment-specific files it's looking for
- Which files it successfully loaded

## Current Status

Based on your debug output:
```
webiny debug: No environment file found on /Users/cclark/webiny-latest/hnr-testbed/.env.pre-prod.
```

This means:
- ✅ Webiny is correctly looking for `.env.pre-prod`
- ⚠️ The file doesn't exist yet (which is fine - it will use `.env` as fallback)
- ✅ Your base `.env` file is being loaded successfully

## Recommendation

For your setup, you could create `.env.pre-prod` with:

```bash
# .env.pre-prod
AWS_PROFILE=testbed
AWS_REGION=eu-west-1
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
```

This keeps pre-prod configuration separate and makes it clear which settings apply to which environment.

## Reference

- [Webiny Environment Variables Documentation](https://www.webiny.com/docs/core-development-concepts/basics/environment-variables)
- [Webiny Environments Guide](https://www.webiny.com/docs/core-development-concepts/ci-cd/environments)


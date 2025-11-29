# Pulumi State Management with S3 Backend

This document explains the Pulumi state storage setup for this Webiny CMS project, including how state is stored in S3 and how to manage it.

## Overview

By default, Webiny stores Pulumi state files locally in the `.pulumi` directory. For production deployments and team collaboration, it's recommended to use a remote backend. This project is configured to use **Amazon S3** as the Pulumi state backend, with **DynamoDB** for state locking to prevent concurrent update conflicts.

## Architecture

- **S3 Bucket**: `pulumi-state-773984399528` (eu-west-1)
  - Stores all Pulumi state files
  - Versioning enabled for state history
  - Server-side encryption enabled (AES256)
  - Public access blocked for security

- **DynamoDB Table**: `pulumi-locks` (eu-west-1)
  - Provides state locking mechanism
  - Prevents concurrent updates from corrupting state
  - Pay-per-request billing mode

- **AWS Account**: 773984399528
- **AWS Profile**: testbed
- **Region**: eu-west-1

## Setup Commands

The following commands were used to set up the S3 backend infrastructure:

### 1. Create S3 Bucket

```bash
aws s3api create-bucket \
  --bucket pulumi-state-773984399528 \
  --region eu-west-1 \
  --profile testbed \
  --create-bucket-configuration LocationConstraint=eu-west-1
```

**Note**: The bucket name `pulumi-state` was not available globally, so we used `pulumi-state-773984399528` which includes the AWS account ID to ensure uniqueness.

### 2. Enable Versioning

Versioning allows you to recover previous versions of state files if needed:

```bash
aws s3api put-bucket-versioning \
  --bucket pulumi-state-773984399528 \
  --versioning-configuration Status=Enabled \
  --profile testbed
```

### 3. Enable Server-Side Encryption

Encrypts state files at rest:

```bash
aws s3api put-bucket-encryption \
  --bucket pulumi-state-773984399528 \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --profile testbed
```

### 4. Block Public Access

Ensures state files are not publicly accessible:

```bash
aws s3api put-public-access-block \
  --bucket pulumi-state-773984399528 \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile testbed
```

### 5. Create DynamoDB Table for State Locking

Prevents concurrent Pulumi operations from corrupting state:

```bash
aws dynamodb create-table \
  --table-name pulumi-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1 \
  --profile testbed
```

## Backend URL Configuration

The Pulumi S3 backend URL format is:

```
s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed&dynamodbTable=pulumi-locks
```

### Parameters Explained

- `s3://pulumi-state-773984399528` - The S3 bucket name
- `region=eu-west-1` - AWS region where the bucket is located
- `awssdk=v2` - AWS SDK version to use
- `profile=testbed` - AWS CLI profile to use for authentication
- `dynamodbTable=pulumi-locks` - DynamoDB table for state locking

## Configuring Pulumi to Use S3 Backend

### Option 1: Environment Variable

Add to your `.env` file:

```bash
PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed&dynamodbTable=pulumi-locks
```

### Option 2: Per-Stack Configuration

For each app (core, api, admin, website), you can configure the backend by navigating to the app's Pulumi directory and running:

```bash
pulumi login s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed&dynamodbTable=pulumi-locks
```

### Option 3: Webiny Configuration

Webiny projects may require additional configuration. Check the Webiny documentation for backend configuration options specific to your version.

## State File Structure

State files are organized by application and environment:

```
.pulumi/
└── apps/
    ├── core/
    │   └── .pulumi/
    │       └── stacks/
    │           └── core/
    │               ├── dev.json
    │               └── stage.json
    ├── api/
    │   └── .pulumi/
    │       └── stacks/
    │           └── api/
    │               ├── dev.json
    │               └── stage.json
    ├── admin/
    │   └── .pulumi/
    │       └── stacks/
    │           └── admin/
    │               ├── dev.json
    │               └── stage.json
    └── website/
        └── .pulumi/
            └── stacks/
                └── website/
                    ├── dev.json
                    └── stage.json
```

When using S3 backend, these state files will be stored in the S3 bucket instead of locally.

## Migrating Existing State

To migrate existing local state to S3:

1. **Export current state** (for each stack):
   ```bash
   pulumi stack export --file state-export.json
   ```

2. **Configure S3 backend** (see options above)

3. **Import state to S3 backend**:
   ```bash
   pulumi stack import --file state-export.json
   ```

**Note**: The migration script `migrate-pulumi-to-s3.sh` was created to help automate this process, but manual migration may be required depending on your Webiny version and configuration.

## Verifying Backend Configuration

To verify that Pulumi is using the S3 backend:

```bash
pulumi whoami --verbose
```

This will display the current backend URL.

## IAM Permissions Required

The AWS credentials/profile used must have the following permissions:

### S3 Permissions
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:ListBucket`

### DynamoDB Permissions
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:DeleteItem`
- `dynamodb:DescribeTable`

Example IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::pulumi-state-773984399528",
        "arn:aws:s3:::pulumi-state-773984399528/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:eu-west-1:773984399528:table/pulumi-locks"
    }
  ]
}
```

## Benefits of S3 Backend

1. **Centralized State**: All team members can access the same state
2. **Versioning**: S3 versioning provides state history
3. **Backup**: State files are automatically backed up in S3
4. **Locking**: DynamoDB prevents concurrent update conflicts
5. **Security**: Encryption at rest and access controls
6. **Scalability**: No local storage limitations

## Troubleshooting

### Backend Not Found
If Pulumi cannot find the backend, verify:
- AWS credentials are configured correctly
- The profile name matches (`testbed`)
- The bucket exists and is accessible
- Region is correct (`eu-west-1`)

### Lock Errors
If you encounter lock errors:
- Check DynamoDB table exists and is active
- Verify IAM permissions for DynamoDB
- Manually remove locks if needed (use with caution)

### Migration Issues
If state migration fails:
- Ensure local state files are valid
- Check S3 bucket permissions
- Verify backend URL format is correct

## Additional Resources

- [Webiny State Files Documentation](https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files)
- [Pulumi S3 Backend Documentation](https://www.pulumi.com/docs/intro/concepts/state/#using-amazon-s3)
- [Pulumi State Management Best Practices](https://www.pulumi.com/docs/intro/concepts/state/)

## Maintenance

### Checking Bucket Status
```bash
aws s3api head-bucket --bucket pulumi-state-773984399528 --profile testbed
```

### Listing State Files
```bash
aws s3 ls s3://pulumi-state-773984399528 --profile testbed --recursive
```

### Checking DynamoDB Table
```bash
aws dynamodb describe-table --table-name pulumi-locks --region eu-west-1 --profile testbed
```

### Viewing Bucket Versioning
```bash
aws s3api get-bucket-versioning --bucket pulumi-state-773984399528 --profile testbed
```


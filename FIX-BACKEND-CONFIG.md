# Fix: Webiny S3 Backend Configuration

## The Problem

You've been using `PULUMI_BACKEND_URL` in your `.env` file, but **Webiny doesn't recognize this variable**. 

According to the [Webiny documentation](https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files), Webiny uses `WEBINY_PULUMI_BACKEND` instead.

That's why:
- Pre-prod deployment didn't use S3 (it used local backend)
- State files aren't in S3 for pre-prod
- Webiny isn't detecting pre-prod in the environment list

## The Solution

### Update Your `.env` File

Replace or add the following in your `.env` file:

**Remove/Comment out:**
```bash
# PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed
```

**Add:**
```bash
WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528
```

**Keep (for DynamoDB state locking):**
```bash
PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks
```

### Important Notes

1. **Simpler Format**: Webiny's `WEBINY_PULUMI_BACKEND` uses a simpler format - just the S3 bucket URI
   - ✅ Correct: `WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528`
   - ❌ Wrong: `WEBINY_PULUMI_BACKEND=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed`

2. **Region**: The bucket should be in the same region as your deployment (eu-west-1)

3. **AWS Profile**: Webiny will use your default AWS credentials or the profile specified in your AWS configuration

4. **DynamoDB Locking**: 
   - ✅ **Keep** `PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks` 
   - This is a standard Pulumi environment variable that Webiny will pass through to Pulumi
   - Your DynamoDB table `pulumi-locks` is already created and active
   - This prevents concurrent deployments from corrupting state

### After Updating

1. **Future deployments will use S3**:
   ```bash
   yarn webiny deploy --env preprod
   ```

2. **State files will be stored in S3**:
   ```
   s3://pulumi-state-773984399528/organization/{app}/preprod.json
   ```

3. **Webiny will detect the environment**:
   ```bash
   yarn webiny info
   # Should now show preprod in the list
   ```

## Migration Note

The state files you already have in S3 (dev, stage) were created when we manually uploaded them. Going forward, with `WEBINY_PULUMI_BACKEND` set correctly, Webiny will automatically use S3 for all deployments.

## Verify Configuration

After updating `.env`, verify it works:

```bash
# Check the variable is set
grep "^WEBINY_PULUMI_BACKEND" .env

# Deploy something small to test
yarn webiny deploy apps/core --env preprod

# Check if state file appears in S3
aws s3 ls s3://pulumi-state-773984399528/organization/ --profile testbed --recursive | grep preprod
```

## Reference

- [Webiny State Files Documentation](https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files)


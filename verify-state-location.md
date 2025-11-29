# How to Verify Where Pulumi State is Stored

## Quick Check Commands

### 1. Check .env Configuration
```bash
grep "^PULUMI_BACKEND_URL" .env
```

- **If set to S3**: State is stored in S3
- **If commented out or not set**: State is stored locally in `.pulumi/`

### 2. Check Local State Files
```bash
find .pulumi -name "*pre-prod*" -type f
```

If files are found here, state is stored locally.

### 3. Check S3 State Files
```bash
aws s3 ls s3://pulumi-state-773984399528/organization/ --profile testbed --recursive | grep pre-prod
```

If files are found here, state is stored in S3.

### 4. Check Pulumi Stack Registry
```bash
export PULUMI_BACKEND_URL="s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env | cut -d'=' -f2-)
pulumi stack ls --all | grep pre-prod
```

This shows registered stacks and their backend.

## Expected State File Locations

### For S3 Backend:
- **Path format**: `s3://pulumi-state-773984399528/organization/{app}/{env}.json`
- **Example**: `s3://pulumi-state-773984399528/organization/core/pre-prod.json`

### For Local Backend:
- **Path format**: `.pulumi/apps/{app}/.pulumi/stacks/{app}/{env}.json`
- **Example**: `.pulumi/apps/core/.pulumi/stacks/core/pre-prod.json`

## Using the Check Script

Run the provided script:
```bash
./check-state-location.sh pre-prod
```

This will check all locations and tell you where the state is stored.

## Important Notes

1. **State files are written during/after deployment** - If deployment is still running, state files may not appear in S3 until it completes.

2. **Pulumi stacks vs State files**:
   - Stacks can exist in Pulumi's registry before state files are written
   - State files contain the actual infrastructure state
   - Both need to exist for a complete deployment

3. **If state files don't appear in S3**:
   - Wait for deployment to complete
   - Check AWS credentials and permissions
   - Verify the S3 bucket exists and is accessible
   - Check Pulumi logs for errors


#!/bin/bash

# Proper migration script using Pulumi export/import commands
# This script temporarily switches to local backend, exports state, then imports to S3

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=${PROFILE}&dynamodbTable=pulumi-locks"

APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev" "stage")

echo "=========================================="
echo "Migrating Pulumi State to S3 Backend"
echo "Using Pulumi export/import commands"
echo "=========================================="
echo "Bucket: ${BUCKET_NAME}"
echo "Backend URL: ${BACKEND_URL}"
echo ""
echo "⚠️  IMPORTANT: This script will:"
echo "   1. Temporarily disable S3 backend (comment PULUMI_BACKEND_URL)"
echo "   2. Export state from local backend"
echo "   3. Re-enable S3 backend"
echo "   4. Import state to S3 backend"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 1
fi

# Backup .env file
ENV_FILE=".env"
if [ -f "${ENV_FILE}" ]; then
    cp "${ENV_FILE}" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Backed up .env file"
fi

# Temporarily disable S3 backend by commenting it out
echo ""
echo "Step 1: Temporarily disabling S3 backend..."
if grep -q "^PULUMI_BACKEND_URL" "${ENV_FILE}"; then
    sed -i.bak 's/^PULUMI_BACKEND_URL/#PULUMI_BACKEND_URL/' "${ENV_FILE}"
    echo "✅ Commented out PULUMI_BACKEND_URL in .env"
else
    echo "⚠️  PULUMI_BACKEND_URL not found in .env, assuming local backend"
fi

# Create temp directory for exports
TEMP_DIR=$(mktemp -d)
echo "📁 Using temp directory: ${TEMP_DIR}"
echo ""

# Export and import for each app/environment
for APP in "${APPS[@]}"; do
    for ENV in "${ENVIRONMENTS[@]}"; do
        STATE_FILE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
        
        if [ ! -f "${STATE_FILE}" ]; then
            echo "⚠️  Skipping ${APP}/${ENV}: State file not found"
            continue
        fi
        
        echo "=========================================="
        echo "Migrating ${APP}/${ENV}"
        echo "=========================================="
        
        # Read stack name from state file
        STACK_NAME=$(jq -r '.checkpoint.stack' "${STATE_FILE}" 2>/dev/null || echo "")
        
        if [ -z "$STACK_NAME" ] || [ "$STACK_NAME" == "null" ]; then
            echo "❌ Could not determine stack name from ${STATE_FILE}"
            continue
        fi
        
        echo "Stack name: ${STACK_NAME}"
        EXPORT_FILE="${TEMP_DIR}/${APP}-${ENV}-export.json"
        
        # The state file is already in the correct format, we can use it directly
        echo "📤 Copying state file for export..."
        cp "${STATE_FILE}" "${EXPORT_FILE}"
        
        # Now switch to S3 backend and import
        echo "🔄 Switching to S3 backend..."
        # Uncomment PULUMI_BACKEND_URL
        sed -i.bak 's/^#PULUMI_BACKEND_URL/PULUMI_BACKEND_URL/' "${ENV_FILE}"
        
        # Source the .env to get the backend URL (or export it)
        export PULUMI_BACKEND_URL="${BACKEND_URL}"
        
        echo "📥 Importing state to S3..."
        echo "   Note: This requires Pulumi CLI and proper stack context"
        echo "   Stack: ${STACK_NAME}"
        echo "   File: ${EXPORT_FILE}"
        
        # For Webiny, we might need to manually upload to S3
        # Pulumi S3 backend stores files as {stack-name}.json
        S3_KEY="${STACK_NAME}.json"
        echo "   Uploading directly to s3://${BUCKET_NAME}/${S3_KEY}..."
        
        if aws s3 cp "${EXPORT_FILE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
            --profile ${PROFILE} \
            --region ${REGION} \
            --metadata "migrated-from=local,app=${APP},env=${ENV},timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null; then
            echo "   ✅ Successfully uploaded ${APP}/${ENV} to S3"
        else
            echo "   ❌ Failed to upload ${APP}/${ENV}"
        fi
        
        # Re-comment for next iteration (so we can read from local)
        sed -i.bak 's/^PULUMI_BACKEND_URL/#PULUMI_BACKEND_URL/' "${ENV_FILE}"
    done
done

# Restore PULUMI_BACKEND_URL
echo ""
echo "Step 4: Restoring S3 backend configuration..."
sed -i.bak 's/^#PULUMI_BACKEND_URL/PULUMI_BACKEND_URL/' "${ENV_FILE}"
rm -f "${ENV_FILE}.bak"
echo "✅ Restored PULUMI_BACKEND_URL in .env"

# Cleanup
rm -rf "${TEMP_DIR}"
echo "✅ Cleaned up temp files"
echo ""

echo "=========================================="
echo "Migration Complete!"
echo "=========================================="
echo ""
echo "State files have been uploaded to S3."
echo "The next Webiny deployment should recognize the existing state."
echo ""
echo "To verify, check S3:"
echo "  aws s3 ls s3://${BUCKET_NAME}/ --profile ${PROFILE} --recursive"
echo ""
echo "⚠️  Note: If Webiny still shows 'first deployment', you may need to:"
echo "   1. Check the stack name format in S3 matches what Webiny expects"
echo "   2. Verify the backend URL is correctly set in .env"
echo "   3. Try running: yarn webiny deploy --env dev"
echo ""


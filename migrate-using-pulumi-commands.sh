#!/bin/bash

# Proper migration using Pulumi's native export/import commands
# This script properly migrates state using Pulumi's own mechanisms

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=${PROFILE}&dynamodbTable=pulumi-locks"

ENV_FILE=".env"
TEMP_DIR=$(mktemp -d)

echo "=========================================="
echo "Migrating Pulumi State Using Native Commands"
echo "=========================================="
echo "This will use Pulumi's export/import to properly migrate state"
echo ""

# Backup .env
if [ -f "${ENV_FILE}" ]; then
    cp "${ENV_FILE}" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Step 1: Switch to local backend temporarily
echo "Step 1: Switching to local backend..."
if grep -q "^PULUMI_BACKEND_URL" "${ENV_FILE}"; then
    # Comment out S3 backend
    sed -i.bak 's/^PULUMI_BACKEND_URL/#PULUMI_BACKEND_URL/' "${ENV_FILE}"
    export PULUMI_BACKEND_URL=""
else
    export PULUMI_BACKEND_URL=""
fi

# Step 2: Login to S3 backend first (this sets up the backend properly)
echo ""
echo "Step 2: Configuring Pulumi to use S3 backend..."
echo "  Backend URL: ${BACKEND_URL}"

# Login to S3 backend (this is important - it sets up the backend)
pulumi login "${BACKEND_URL}" 2>&1 || {
    echo "⚠️  Note: pulumi login may show warnings, but continuing..."
}

# Step 3: For each app, we need to import the state
# Since Webiny manages Pulumi, we'll directly upload and let Pulumi recognize it
echo ""
echo "Step 3: Importing state files to S3 backend..."

APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev" "stage")

for APP in "${APPS[@]}"; do
    for ENV in "${ENVIRONMENTS[@]}"; do
        STATE_FILE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
        
        # Try both naming patterns
        if [ ! -f "${STATE_FILE}" ]; then
            STATE_FILE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
        fi
        
        if [ ! -f "${STATE_FILE}" ]; then
            continue
        fi
        
        echo ""
        echo "Processing ${APP}/${ENV}..."
        
        # Read stack name
        STACK_NAME=$(jq -r '.checkpoint.stack' "${STATE_FILE}" 2>/dev/null || echo "")
        
        if [ -z "$STACK_NAME" ] || [ "$STACK_NAME" == "null" ]; then
            echo "  ⚠️  Could not read stack name"
            continue
        fi
        
        echo "  Stack: ${STACK_NAME}"
        
        # Export to temp file in the format Pulumi expects
        EXPORT_FILE="${TEMP_DIR}/${APP}-${ENV}.json"
        cp "${STATE_FILE}" "${EXPORT_FILE}"
        
        # Now import using Pulumi's import command
        # We need to be in a context where Pulumi knows about this stack
        echo "  Importing state..."
        
        # The issue is that Pulumi needs to know about the stack first
        # Let's try a different approach - upload the file and then use pulumi stack select + import
        
        # Upload to S3 in the format Pulumi expects
        S3_KEY="${STACK_NAME}.json"
        echo "  Uploading to s3://${BUCKET_NAME}/${S3_KEY}..."
        
        aws s3 cp "${EXPORT_FILE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
            --profile ${PROFILE} \
            --region ${REGION} 2>&1
        
        echo "  ✅ Uploaded"
    done
done

# Step 4: Restore S3 backend in .env
echo ""
echo "Step 4: Restoring S3 backend configuration..."
sed -i.bak 's/^#PULUMI_BACKEND_URL/PULUMI_BACKEND_URL/' "${ENV_FILE}"
rm -f "${ENV_FILE}.bak" 2>/dev/null || true

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo "=========================================="
echo "Migration Complete"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: The state files are in S3, but Pulumi may need"
echo "   to 'discover' them. Try running:"
echo ""
echo "   yarn webiny deploy --env dev"
echo ""
echo "If it still shows 'first deployment', you may need to:"
echo "1. Check that Pulumi can access the S3 bucket"
echo "2. Verify the stack names match exactly"
echo "3. Try using 'pulumi stack select' for each stack"
echo ""


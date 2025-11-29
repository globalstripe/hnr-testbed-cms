#!/bin/bash

# Script to migrate existing Pulumi state from local storage to S3 backend
# This script copies the existing state files directly to S3 in the format Pulumi expects

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev" "stage")

echo "=========================================="
echo "Migrating Pulumi State to S3 Backend"
echo "=========================================="
echo "Bucket: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo "Profile: ${PROFILE}"
echo ""

# Verify bucket exists
echo "Verifying S3 bucket exists..."
if ! aws s3api head-bucket --bucket ${BUCKET_NAME} --profile ${PROFILE} 2>/dev/null; then
    echo "❌ Error: S3 bucket ${BUCKET_NAME} does not exist or is not accessible"
    exit 1
fi
echo "✅ S3 bucket verified"
echo ""

# Migrate state for each app and environment
for APP in "${APPS[@]}"; do
    echo "=========================================="
    echo "Processing app: ${APP}"
    echo "=========================================="
    
    APP_PULUMI_DIR=".pulumi/apps/${APP}/.pulumi"
    
    if [ ! -d "${APP_PULUMI_DIR}" ]; then
        echo "⚠️  Skipping ${APP}: .pulumi directory not found"
        echo ""
        continue
    fi
    
    for ENV in "${ENVIRONMENTS[@]}"; do
        STATE_FILE="${APP_PULUMI_DIR}/stacks/${APP}/${ENV}.json"
        
        if [ ! -f "${STATE_FILE}" ]; then
            echo "⚠️  State file not found: ${STATE_FILE}"
            continue
        fi
        
        echo "  Migrating ${APP}/${ENV}..."
        
        # Read the stack name from the state file
        STACK_NAME=$(jq -r '.checkpoint.stack' "${STATE_FILE}" 2>/dev/null || echo "")
        
        if [ -z "$STACK_NAME" ] || [ "$STACK_NAME" == "null" ]; then
            echo "    ⚠️  Could not read stack name from state file, using default format"
            STACK_NAME="organization/${APP}/${ENV}"
        fi
        
        echo "    Stack name: ${STACK_NAME}"
        
        # Pulumi S3 backend stores state files with the stack name as the key
        # Format: {stack-name}.json
        # Replace slashes with dashes or keep as-is depending on Pulumi version
        S3_KEY="${STACK_NAME}.json"
        
        echo "    Uploading to s3://${BUCKET_NAME}/${S3_KEY}..."
        
        # Upload state file to S3
        if aws s3 cp "${STATE_FILE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
            --profile ${PROFILE} \
            --region ${REGION} \
            --metadata "migrated-from=local,app=${APP},env=${ENV}" 2>/dev/null; then
            echo "    ✅ Successfully migrated ${APP}/${ENV}"
        else
            echo "    ❌ Failed to migrate ${APP}/${ENV}"
            echo "    Continuing with next stack..."
        fi
    done
    echo ""
done

echo "=========================================="
echo "Migration Complete!"
echo "=========================================="
echo ""
echo "State files have been copied to S3."
echo "The next Webiny deployment should recognize the existing state."
echo ""
echo "To verify, check S3:"
echo "  aws s3 ls s3://${BUCKET_NAME}/ --profile ${PROFILE} --recursive"
echo ""


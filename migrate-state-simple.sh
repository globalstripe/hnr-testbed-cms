#!/bin/bash

# Simple script to migrate Pulumi state files directly to S3
# This copies the state files to S3 using the stack name as the key

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"

APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev" "stage")

echo "=========================================="
echo "Migrating Pulumi State to S3"
echo "=========================================="
echo "Bucket: s3://${BUCKET_NAME}"
echo ""

# Verify bucket
if ! aws s3api head-bucket --bucket ${BUCKET_NAME} --profile ${PROFILE} 2>/dev/null; then
    echo "❌ Error: Cannot access bucket ${BUCKET_NAME}"
    exit 1
fi

echo "✅ Bucket verified"
echo ""

# Migrate each state file
MIGRATED=0
FAILED=0

for APP in "${APPS[@]}"; do
    for ENV in "${ENVIRONMENTS[@]}"; do
        STATE_FILE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
        
        if [ ! -f "${STATE_FILE}" ]; then
            continue
        fi
        
        # Get stack name from state file
        STACK_NAME=$(jq -r '.checkpoint.stack' "${STATE_FILE}" 2>/dev/null || echo "")
        
        if [ -z "$STACK_NAME" ] || [ "$STACK_NAME" == "null" ]; then
            echo "⚠️  ${APP}/${ENV}: Could not read stack name"
            ((FAILED++))
            continue
        fi
        
        # Pulumi S3 backend uses stack name as the key
        S3_KEY="${STACK_NAME}.json"
        
        echo "Migrating ${APP}/${ENV}..."
        echo "  Stack: ${STACK_NAME}"
        echo "  S3 Key: ${S3_KEY}"
        
        if aws s3 cp "${STATE_FILE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
            --profile ${PROFILE} \
            --region ${REGION} \
            --metadata "app=${APP},env=${ENV}" 2>&1; then
            echo "  ✅ Success"
            ((MIGRATED++))
        else
            echo "  ❌ Failed"
            ((FAILED++))
        fi
        echo ""
    done
done

echo "=========================================="
echo "Migration Summary"
echo "=========================================="
echo "✅ Migrated: ${MIGRATED}"
echo "❌ Failed: ${FAILED}"
echo ""

if [ ${MIGRATED} -gt 0 ]; then
    echo "✅ State files have been uploaded to S3"
    echo ""
    echo "Next steps:"
    echo "1. Verify files in S3:"
    echo "   aws s3 ls s3://${BUCKET_NAME}/ --profile ${PROFILE} --recursive"
    echo ""
    echo "2. Try deploying again:"
    echo "   yarn webiny deploy --env dev"
    echo ""
    echo "⚠️  Note: If Webiny still shows 'first deployment', the stack name"
    echo "   format in S3 might not match what Webiny expects. Check the"
    echo "   Webiny documentation for the exact format."
fi


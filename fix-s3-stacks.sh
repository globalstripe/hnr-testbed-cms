#!/bin/bash

# Script to fix S3 stacks by deleting empty stacks and ensuring state files are correct

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=testbed"

export PULUMI_BACKEND_URL="${BACKEND_URL}"
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env | cut -d'=' -f2-)

echo "=========================================="
echo "Fixing S3 Stacks - Ensuring State is Correct"
echo "=========================================="
echo ""

APPS=("core" "api" "admin" "website")
ENV="dev"

for APP in "${APPS[@]}"; do
    STACK_NAME="organization/${APP}/${ENV}"
    S3_KEY="${STACK_NAME}.json"
    LOCAL_STATE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
    
    echo "Processing: ${STACK_NAME}"
    
    # Check if local state has resources
    if [ -f "${LOCAL_STATE}" ]; then
        RESOURCE_COUNT=$(jq '.checkpoint.latest.resources | length' "${LOCAL_STATE}" 2>/dev/null || echo "0")
        echo "  Local state has ${RESOURCE_COUNT} resources"
        
        if [ "${RESOURCE_COUNT}" -gt "0" ]; then
            # Ensure S3 has the correct state
            echo "  📤 Ensuring S3 has correct state..."
            aws s3 cp "${LOCAL_STATE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
                --profile ${PROFILE} \
                --region ${REGION} 2>&1 | grep -E "(upload|error)" || echo "  ✅ State file updated in S3"
        fi
    fi
    
    # Verify S3 state
    echo "  🔍 Verifying S3 state..."
    S3_RESOURCE_COUNT=$(aws s3 cp "s3://${BUCKET_NAME}/${S3_KEY}" - --profile ${PROFILE} 2>/dev/null | jq '.checkpoint.latest.resources | length' 2>/dev/null || echo "0")
    echo "  S3 state has ${S3_RESOURCE_COUNT} resources"
    
    if [ "${S3_RESOURCE_COUNT}" -eq "0" ]; then
        echo "  ⚠️  WARNING: S3 state file has 0 resources!"
        echo "  This means Pulumi will see an empty stack"
    fi
    
    echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "The state files in S3 should now have the correct resources."
echo ""
echo "However, if Pulumi created empty stacks, you may need to:"
echo "1. Delete the empty stacks: pulumi stack rm <stack-name>"
echo "2. Or let Webiny recreate them on next deploy"
echo ""
echo "Try running: yarn webiny info --env dev"
echo ""


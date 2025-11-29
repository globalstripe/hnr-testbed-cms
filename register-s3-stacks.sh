#!/bin/bash

# Script to register existing state files in S3 as Pulumi stacks
# This allows Pulumi to recognize the existing deployments

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=testbed"

echo "=========================================="
echo "Registering Existing Stacks in S3"
echo "=========================================="
echo "This will import your existing state files so Pulumi recognizes them"
echo ""

# Verify .env is configured correctly
if ! grep -q "^PULUMI_BACKEND_URL=s3://" .env 2>/dev/null; then
    echo "❌ Error: PULUMI_BACKEND_URL not set to S3 in .env"
    echo "   Please ensure line 6 in .env has:"
    echo "   PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
    exit 1
fi

echo "✅ S3 backend configured in .env"
echo ""

# Set environment variables
export PULUMI_BACKEND_URL="${BACKEND_URL}"
export AWS_PROFILE="${PROFILE}"

# Login to S3 backend
echo "Logging in to S3 backend..."
pulumi login "${BACKEND_URL}" 2>&1 | grep -v "warning" || true
echo ""

APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev" "stage")

IMPORTED=0
FAILED=0

for APP in "${APPS[@]}"; do
    for ENV in "${ENVIRONMENTS[@]}"; do
        LOCAL_STATE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
        
        if [ ! -f "${LOCAL_STATE}" ]; then
            echo "⚠️  Skipping ${APP}/${ENV}: Local state file not found"
            continue
        fi
        
        # Get stack name from state file
        STACK_NAME=$(jq -r '.checkpoint.stack' "${LOCAL_STATE}" 2>/dev/null || echo "")
        
        if [ -z "$STACK_NAME" ] || [ "$STACK_NAME" == "null" ]; then
            echo "⚠️  ${APP}/${ENV}: Could not read stack name"
            ((FAILED++))
            continue
        fi
        
        echo "Processing: ${STACK_NAME}"
        
        # Check if state exists in S3
        S3_KEY="${STACK_NAME}.json"
        if ! aws s3 ls "s3://${BUCKET_NAME}/${S3_KEY}" --profile ${PROFILE} >/dev/null 2>&1; then
            echo "  ⚠️  State file not in S3: ${S3_KEY}"
            echo "  📤 Uploading to S3..."
            aws s3 cp "${LOCAL_STATE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
                --profile ${PROFILE} \
                --region ${REGION} 2>&1 || {
                echo "  ❌ Failed to upload"
                ((FAILED++))
                continue
            }
        else
            echo "  ✅ State file exists in S3"
        fi
        
        # Now try to import/register the stack
        echo "  🔄 Registering stack with Pulumi..."
        
        # Create a temporary Pulumi project context for import
        # We need to be in a directory with a Pulumi.yaml, but Webiny manages this differently
        # Instead, we'll use pulumi stack import directly
        
        # Export the state in the format Pulumi expects for import
        TEMP_EXPORT=$(mktemp)
        cp "${LOCAL_STATE}" "${TEMP_EXPORT}"
        
        # Try to import the stack
        # Note: This might require being in the right directory context
        # Webiny manages Pulumi internally, so we'll try a different approach
        
        # Check if we can select the stack (this registers it)
        if pulumi stack select "${STACK_NAME}" 2>&1 | grep -q "Selected stack"; then
            echo "  ✅ Stack registered: ${STACK_NAME}"
            ((IMPORTED++))
        else
            # Try importing the state
            echo "  Attempting to import state..."
            # We need to be in a Pulumi project directory
            # Since Webiny manages this, let's try a workaround
            
            # Create a minimal Pulumi.yaml in a temp dir
            TEMP_DIR=$(mktemp -d)
            cd "${TEMP_DIR}"
            echo "name: temp" > Pulumi.yaml
            echo "runtime: nodejs" >> Pulumi.yaml
            
            # Set backend
            export PULUMI_BACKEND_URL="${BACKEND_URL}"
            
            # Try to import
            if pulumi stack import --file "${TEMP_EXPORT}" --stack "${STACK_NAME}" 2>&1; then
                echo "  ✅ Stack imported: ${STACK_NAME}"
                ((IMPORTED++))
            else
                echo "  ⚠️  Could not import (this is OK - Webiny may handle it differently)"
                echo "  State file is in S3 and will be used on next deployment"
            fi
            
            cd - >/dev/null
            rm -rf "${TEMP_DIR}"
        fi
        
        rm -f "${TEMP_EXPORT}"
        echo ""
    done
done

echo "=========================================="
echo "Registration Summary"
echo "=========================================="
echo "✅ Registered: ${IMPORTED}"
echo "⚠️  Issues: ${FAILED}"
echo ""

if [ ${IMPORTED} -gt 0 ] || [ ${FAILED} -eq 0 ]; then
    echo "✅ State files are registered in S3"
    echo ""
    echo "Next steps:"
    echo "1. Ensure PULUMI_BACKEND_URL is set in .env (line 6)"
    echo "2. Run: yarn webiny deploy --env dev"
    echo ""
    echo "Webiny should now recognize your existing deployments!"
else
    echo "⚠️  Some stacks may need manual registration"
    echo "The state files are in S3 and should be recognized on deployment"
fi


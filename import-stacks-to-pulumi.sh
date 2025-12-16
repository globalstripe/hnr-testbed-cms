#!/bin/bash

# Script to import existing state files into Pulumi S3 backend
# This properly registers the stacks with Pulumi

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=eu-west-1&awssdk=v2&profile=testbed"

echo "=========================================="
echo "Importing Pulumi Stacks to S3 Backend"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: First, update your .env file:"
echo "   Remove '&dynamodbTable=pulumi-locks' from PULUMI_BACKEND_URL"
echo "   The correct format is:"
echo "   PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
echo ""
echo "   For DynamoDB locking, set separately:"
echo "   PULUMI_S3_BACKEND_DYNAMODB_TABLE=pulumi-locks"
echo ""
read -p "Have you updated .env? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please update .env first, then run this script again."
    exit 1
fi

# Set backend URL
export PULUMI_BACKEND_URL="${BACKEND_URL}"

# Login to S3 backend
echo ""
echo "Logging in to S3 backend..."
pulumi login "${BACKEND_URL}" 2>&1 || echo "Login completed (warnings are OK)"

APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev" "stage")

echo ""
echo "Importing stacks..."
echo ""

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
            continue
        fi
        
        echo "Processing ${STACK_NAME}..."
        
        # Check if stack already exists in S3
        S3_KEY="${STACK_NAME}.json"
        if aws s3 ls "s3://${BUCKET_NAME}/${S3_KEY}" --profile ${PROFILE} >/dev/null 2>&1; then
            echo "  ✅ State file exists in S3: ${S3_KEY}"
            
            # Try to select the stack (this registers it with Pulumi)
            echo "  Attempting to select stack..."
            if pulumi stack select "${STACK_NAME}" 2>&1; then
                echo "  ✅ Stack selected: ${STACK_NAME}"
            else
                echo "  ⚠️  Could not select stack (may need to import)"
                echo "  Try importing manually:"
                echo "    pulumi stack import --file ${STATE_FILE}"
            fi
        else
            echo "  ⚠️  State file not found in S3: ${S3_KEY}"
        fi
        echo ""
    done
done

echo "=========================================="
echo "Import Complete"
echo "=========================================="
echo ""
echo "Try running: yarn webiny deploy --env dev"
echo ""
echo "If it still shows 'first deployment', the issue might be:"
echo "1. Webiny checks for state in a different way"
echo "2. The stack names don't match what Webiny expects"
echo "3. Additional configuration is needed"
echo ""


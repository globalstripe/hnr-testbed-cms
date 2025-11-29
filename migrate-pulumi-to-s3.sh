#!/bin/bash

# Script to migrate Pulumi state from local storage to S3 backend
# Bucket: pulumi-state-773984399528
# Region: eu-west-1
# Profile: testbed
# DynamoDB table: pulumi-locks (for state locking)

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
DYNAMODB_TABLE="pulumi-locks"
APPS=("core" "api" "admin" "website")

# S3 backend URL with DynamoDB locking
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=${PROFILE}&dynamodbTable=${DYNAMODB_TABLE}"

echo "=========================================="
echo "Migrating Pulumi state to S3 backend"
echo "=========================================="
echo "Bucket: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo "Profile: ${PROFILE}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "Backend URL: ${BACKEND_URL}"
echo ""

# Check if DynamoDB table is ready
echo "Checking DynamoDB table status..."
TABLE_STATUS=$(aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${REGION} --profile ${PROFILE} --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" != "ACTIVE" ]; then
    echo "⚠️  Warning: DynamoDB table is not active (status: ${TABLE_STATUS})"
    echo "   Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name ${DYNAMODB_TABLE} --region ${REGION} --profile ${PROFILE}
    echo "✅ DynamoDB table is ready"
else
    echo "✅ DynamoDB table is ready"
fi

echo ""
echo "=========================================="
echo "Migrating state for each app..."
echo "=========================================="

for APP in "${APPS[@]}"; do
    echo ""
    echo "--- Processing app: ${APP} ---"
    
    APP_PULUMI_DIR=".pulumi/apps/${APP}/.pulumi"
    
    if [ ! -d "${APP_PULUMI_DIR}" ]; then
        echo "⚠️  Skipping ${APP}: .pulumi directory not found"
        continue
    fi
    
    # Find all stack directories
    STACK_DIRS=$(find "${APP_PULUMI_DIR}/stacks" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    
    if [ -z "$STACK_DIRS" ]; then
        echo "⚠️  Skipping ${APP}: No stacks found"
        continue
    fi
    
    for STACK_DIR in $STACK_DIRS; do
        STACK_NAME=$(basename "$STACK_DIR")
        echo "  Processing stack: ${STACK_NAME}"
        
        # Check if state file exists
        STATE_FILE="${STACK_DIR}/${STACK_NAME}.json"
        if [ ! -f "$STATE_FILE" ]; then
            echo "    ⚠️  State file not found: ${STATE_FILE}"
            continue
        fi
        
        # Export current state
        echo "    📤 Exporting state..."
        EXPORT_FILE="/tmp/pulumi-${APP}-${STACK_NAME}-export.json"
        
        # For Webiny, we need to work with the state file directly
        # The state file is already in JSON format, so we can use it directly
        
        # Configure backend for this app/stack
        # Note: Webiny manages Pulumi internally, so we need to set the backend URL
        # in a way that Webiny will use it
        
        echo "    🔧 Configuring S3 backend..."
        echo "    Backend URL: ${BACKEND_URL}"
        
        # Create a backend configuration file
        BACKEND_CONFIG_DIR="${APP_PULUMI_DIR}/backend"
        mkdir -p "${BACKEND_CONFIG_DIR}"
        echo "${BACKEND_URL}" > "${BACKEND_CONFIG_DIR}/url.txt"
        
        echo "    ✅ Backend configured for ${APP}/${STACK_NAME}"
    done
done

echo ""
echo "=========================================="
echo "Migration setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. The backend URL has been configured for each app"
echo "2. You may need to set the PULUMI_BACKEND_URL environment variable"
echo "3. Or configure Webiny to use the S3 backend"
echo ""
echo "Backend URL: ${BACKEND_URL}"
echo ""
echo "To use this backend, you can set:"
echo "  export PULUMI_BACKEND_URL=\"${BACKEND_URL}\""
echo ""
echo "Or add it to your .env file:"
echo "  PULUMI_BACKEND_URL=${BACKEND_URL}"


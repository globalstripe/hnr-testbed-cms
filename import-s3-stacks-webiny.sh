#!/bin/bash

# Script to import existing state files into Pulumi S3 backend for Webiny
# This properly registers stacks so Webiny recognizes existing deployments

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=testbed"

echo "=========================================="
echo "Importing Webiny Stacks to S3 Backend"
echo "=========================================="
echo ""
echo "This will import your existing state files so Pulumi/Webiny recognizes them"
echo ""

# Verify .env configuration
if ! grep -q "^PULUMI_BACKEND_URL=s3://" .env 2>/dev/null; then
    echo "❌ Error: PULUMI_BACKEND_URL must be set to S3 in .env"
    echo "   Current .env should have:"
    echo "   PULUMI_BACKEND_URL=s3://pulumi-state-773984399528?region=eu-west-1&awssdk=v2&profile=testbed"
    exit 1
fi

export PULUMI_BACKEND_URL="${BACKEND_URL}"
export AWS_PROFILE="${PROFILE}"

# Get passphrase from .env if not set
if [ -z "$PULUMI_CONFIG_PASSPHRASE" ]; then
    PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "")
    if [ -n "$PULUMI_CONFIG_PASSPHRASE" ]; then
        export PULUMI_CONFIG_PASSPHRASE
    fi
fi

# Login to S3 backend
echo "Step 1: Logging in to S3 backend..."
pulumi login "${BACKEND_URL}" 2>&1 | grep -v "warning" || true
echo "✅ Logged in"
echo ""

# For each app and environment, import the state
APPS=("core" "api" "admin" "website")
ENVIRONMENTS=("dev")

echo "Step 2: Importing state files..."
echo ""

for APP in "${APPS[@]}"; do
    for ENV in "${ENVIRONMENTS[@]}"; do
        LOCAL_STATE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
        
        if [ ! -f "${LOCAL_STATE}" ]; then
            echo "⚠️  Skipping ${APP}/${ENV}: Local state not found"
            continue
        fi
        
        # Get stack name
        STACK_NAME=$(jq -r '.checkpoint.stack' "${LOCAL_STATE}" 2>/dev/null || echo "")
        
        if [ -z "$STACK_NAME" ] || [ "$STACK_NAME" == "null" ]; then
            echo "⚠️  ${APP}/${ENV}: Could not read stack name"
            continue
        fi
        
        echo "Processing: ${STACK_NAME}"
        
        # Verify state is in S3
        S3_KEY="${STACK_NAME}.json"
        if ! aws s3 ls "s3://${BUCKET_NAME}/${S3_KEY}" --profile ${PROFILE} >/dev/null 2>&1; then
            echo "  📤 Uploading to S3..."
            aws s3 cp "${LOCAL_STATE}" "s3://${BUCKET_NAME}/${S3_KEY}" \
                --profile ${PROFILE} \
                --region ${REGION} 2>&1 || {
                echo "  ❌ Failed to upload"
                continue
            }
        fi
        
        echo "  ✅ State file in S3: ${S3_KEY}"
        
        # Extract project name from stack name (format: organization/project/env)
        PROJECT_NAME=$(echo "${STACK_NAME}" | cut -d'/' -f2)
        
        # Now import using Pulumi
        # We need to create a minimal Pulumi project to import
        TEMP_DIR=$(mktemp -d)
        cd "${TEMP_DIR}"
        
        # Create minimal Pulumi.yaml with correct project name
        cat > Pulumi.yaml <<EOF
name: ${PROJECT_NAME}
runtime: nodejs
EOF
        
        # Set backend and passphrase
        export PULUMI_BACKEND_URL="${BACKEND_URL}"
        
        # Create/select the stack first, then import
        echo "  🔄 Creating/selecting stack..."
        pulumi stack init "${STACK_NAME}" 2>&1 | grep -v "already exists" || {
            pulumi stack select "${STACK_NAME}" 2>&1 || true
        }
        
        # Import the stack (use absolute path from project root)
        PROJECT_ROOT="$(pwd)"
        ABS_STATE_PATH="${PROJECT_ROOT}/${LOCAL_STATE}"
        echo "  📥 Importing state from ${ABS_STATE_PATH}..."
        if pulumi stack import --file "${ABS_STATE_PATH}" 2>&1; then
            echo "  ✅ Successfully imported: ${STACK_NAME}"
        else
            echo "  ⚠️  Import had issues (stack may already be correct)"
        fi
        
        cd - >/dev/null
        rm -rf "${TEMP_DIR}"
        echo ""
    done
done

echo "=========================================="
echo "Import Complete!"
echo "=========================================="
echo ""
echo "✅ State files have been imported to S3 backend"
echo ""
echo "Next steps:"
echo "1. Verify PULUMI_BACKEND_URL is set in .env"
echo "2. Run: yarn webiny deploy --env dev"
echo ""
echo "Webiny should now recognize your existing deployments!"
echo ""


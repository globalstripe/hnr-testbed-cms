#!/bin/bash

# Final script to properly import state from S3 into Pulumi stacks
# This downloads state from S3 and imports it

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=testbed"

export PULUMI_BACKEND_URL="${BACKEND_URL}"
export AWS_PROFILE="${PROFILE}"
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env | cut -d'=' -f2-)

PROJECT_ROOT="$(pwd)"

echo "=========================================="
echo "Importing State from S3 to Pulumi Stacks"
echo "=========================================="
echo ""

# Login
pulumi login "${BACKEND_URL}" 2>&1 | grep -v "warning" || true

APPS=("core" "api" "admin" "website")
ENV="dev"

for APP in "${APPS[@]}"; do
    STACK_NAME="organization/${APP}/${ENV}"
    S3_KEY="${STACK_NAME}.json"
    LOCAL_STATE=".pulumi/apps/${APP}/.pulumi/stacks/${APP}/${ENV}.json"
    
    echo "Processing: ${STACK_NAME}"
    
    # Use local state file if it exists, otherwise download from S3
    ABS_LOCAL_STATE="${PROJECT_ROOT}/${LOCAL_STATE}"
    if [ -f "${ABS_LOCAL_STATE}" ]; then
        STATE_FILE="${ABS_LOCAL_STATE}"
        echo "  Using local state file"
    else
        # Download from S3
        TEMP_STATE=$(mktemp)
        aws s3 cp "s3://${BUCKET_NAME}/${S3_KEY}" "${TEMP_STATE}" --profile ${PROFILE} 2>&1 || {
            echo "  ⚠️  Could not download from S3"
            continue
        }
        STATE_FILE="${TEMP_STATE}"
        echo "  Downloaded from S3"
    fi
    
    # Extract project name
    PROJECT_NAME=$(echo "${STACK_NAME}" | cut -d'/' -f2)
    
    # Create temp Pulumi project
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"
    
    cat > Pulumi.yaml <<EOF
name: ${PROJECT_NAME}
runtime: nodejs
EOF
    
    # Select the stack
    echo "  Selecting stack..."
    pulumi stack select "${STACK_NAME}" 2>&1 || {
        echo "  ⚠️  Could not select stack"
        cd - >/dev/null
        rm -rf "${TEMP_DIR}"
        [ -n "${TEMP_STATE}" ] && rm -f "${TEMP_STATE}" || true
        continue
    }
    
    # Import the state
    echo "  Importing state..."
    if pulumi stack import --file "${STATE_FILE}" 2>&1; then
        echo "  ✅ Successfully imported state for ${STACK_NAME}"
    else
        echo "  ⚠️  Import failed (state may already be correct)"
    fi
    
    cd - >/dev/null
    rm -rf "${TEMP_DIR}"
    [ -n "${TEMP_STATE}" ] && rm -f "${TEMP_STATE}" || true
    echo ""
done

echo "=========================================="
echo "Import Complete!"
echo "=========================================="
echo ""
echo "Verifying stacks..."
pulumi stack ls --all
echo ""
echo "✅ Done! Now try: yarn webiny deploy --env dev"
echo ""


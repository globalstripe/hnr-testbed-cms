#!/bin/bash

# Delete empty stacks so Pulumi can discover the actual state files

set -e

BUCKET_NAME="pulumi-state-773984399528"
REGION="eu-west-1"
PROFILE="testbed"
BACKEND_URL="s3://${BUCKET_NAME}?region=${REGION}&awssdk=v2&profile=testbed"

export PULUMI_BACKEND_URL="${BACKEND_URL}"
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env | cut -d'=' -f2-)

echo "=========================================="
echo "Deleting Empty Stacks"
echo "=========================================="
echo "This will delete the empty stacks so Pulumi can discover"
echo "the actual state files we uploaded to S3"
echo ""

APPS=("core" "api" "admin" "website")
ENV="dev"

for APP in "${APPS[@]}"; do
    STACK_NAME="organization/${APP}/${ENV}"
    PROJECT_NAME="${APP}"
    
    echo "Processing: ${STACK_NAME}"
    
    # Create temp Pulumi project
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"
    
    cat > Pulumi.yaml <<EOF
name: ${PROJECT_NAME}
runtime: nodejs
EOF
    
    # Delete the stack
    echo "  Deleting empty stack..."
    if pulumi stack rm "${STACK_NAME}" --yes 2>&1; then
        echo "  ✅ Deleted empty stack"
    else
        echo "  ⚠️  Could not delete (may not exist or may have resources)"
    fi
    
    cd - >/dev/null
    rm -rf "${TEMP_DIR}"
    echo ""
done

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "Empty stacks have been deleted."
echo "The state files with resources are still in S3."
echo ""
echo "Now when you run 'yarn webiny info --env dev',"
echo "Pulumi should discover the state files from S3."
echo ""


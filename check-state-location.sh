#!/bin/bash

# Script to check where Pulumi state files are stored for a given environment

set -e

ENV="${1:-dev}"
BUCKET_NAME="pulumi-state-773984399528"
PROFILE="testbed"

echo "=========================================="
echo "Checking State Location for: ${ENV}"
echo "=========================================="
echo ""

# Check .env configuration
echo "1. Checking .env configuration..."
if grep -q "^PULUMI_BACKEND_URL=s3://" .env 2>/dev/null; then
    BACKEND_URL=$(grep "^PULUMI_BACKEND_URL=" .env | cut -d'=' -f2-)
    echo "   ✅ PULUMI_BACKEND_URL is set to: ${BACKEND_URL}"
    echo "   → State should be stored in S3"
    USING_S3=true
elif grep -q "^#PULUMI_BACKEND_URL" .env 2>/dev/null || ! grep -q "PULUMI_BACKEND_URL" .env 2>/dev/null; then
    echo "   ⚠️  PULUMI_BACKEND_URL is commented out or not set"
    echo "   → State will be stored locally in .pulumi/"
    USING_S3=false
else
    echo "   ⚠️  Could not determine backend configuration"
    USING_S3=false
fi
echo ""

# Check local state files
echo "2. Checking local state files (.pulumi/):"
LOCAL_FILES=$(find .pulumi -name "*${ENV}*" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "${LOCAL_FILES}" -gt "0" ]; then
    echo "   Found ${LOCAL_FILES} local state file(s):"
    find .pulumi -name "*${ENV}*" -type f 2>/dev/null | sed 's/^/      /'
else
    echo "   No local state files found for ${ENV}"
fi
echo ""

# Check S3 state files
echo "3. Checking S3 state files:"
if [ "${USING_S3}" = true ]; then
    S3_FILES=$(aws s3 ls "s3://${BUCKET_NAME}/organization/" --profile ${PROFILE} --recursive 2>/dev/null | grep "${ENV}" | wc -l | tr -d ' ' || echo "0")
    if [ "${S3_FILES}" -gt "0" ]; then
        echo "   Found ${S3_FILES} state file(s) in S3:"
        aws s3 ls "s3://${BUCKET_NAME}/organization/" --profile ${PROFILE} --recursive 2>/dev/null | grep "${ENV}" | awk '{print "      " $4}'
    else
        echo "   No state files found in S3 for ${ENV}"
    fi
else
    echo "   Skipping S3 check (not configured)"
fi
echo ""

# Check Pulumi stacks
echo "4. Checking Pulumi stack registry:"
export PULUMI_BACKEND_URL="${BACKEND_URL:-}" 2>/dev/null || true
export PULUMI_CONFIG_PASSPHRASE=$(grep "^PULUMI_CONFIG_PASSPHRASE=" .env 2>/dev/null | cut -d'=' -f2- || echo "")
if [ -n "${PULUMI_BACKEND_URL}" ]; then
    STACKS=$(pulumi stack ls --all 2>/dev/null | grep -i "${ENV}" || echo "")
    if [ -n "${STACKS}" ]; then
        echo "   Found stacks:"
        echo "${STACKS}" | sed 's/^/      /'
    else
        echo "   No stacks found for ${ENV}"
    fi
else
    echo "   Skipping stack check (backend not configured)"
fi
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
if [ "${USING_S3}" = true ]; then
    echo "✅ State should be stored in S3: s3://${BUCKET_NAME}/organization/"
    echo ""
    echo "To verify, check:"
    echo "  aws s3 ls s3://${BUCKET_NAME}/organization/ --profile ${PROFILE} --recursive | grep ${ENV}"
else
    echo "⚠️  State is stored locally in: .pulumi/apps/*/.pulumi/stacks/"
    echo ""
    echo "To migrate to S3, uncomment PULUMI_BACKEND_URL in .env"
fi
echo ""


#!/bin/bash
# Eris LLM Security Scan Runner
# This script is executed by the GitHub Action to run Red Team security tests

set -e

echo "🛡️  Eris LLM Security Scan"
echo "=========================="
echo ""

# Validate required inputs
if [ -z "$ERIS_API_URL" ]; then
    echo "❌ Error: ERIS_API_URL is required"
    exit 1
fi

if [ -z "$ERIS_API_KEY" ]; then
    echo "❌ Error: ERIS_API_KEY is required"
    exit 1
fi

if [ -z "$LLM_PROVIDER" ]; then
    echo "❌ Error: LLM_PROVIDER is required (openai, gemini, anthropic)"
    exit 1
fi

if [ -z "$LLM_API_KEY" ]; then
    echo "❌ Error: LLM_API_KEY is required"
    exit 1
fi

# Set defaults
VULNERABILITY_THRESHOLD=${VULNERABILITY_THRESHOLD:-30}
FAIL_ON_CRITICAL=${FAIL_ON_CRITICAL:-true}

echo "📊 Configuration:"
echo "   API URL: ${ERIS_API_URL}"
echo "   LLM Provider: ${LLM_PROVIDER}"
echo "   Model: ${LLM_MODEL:-default}"
echo "   Vulnerability Threshold: ${VULNERABILITY_THRESHOLD}%"
echo "   Attack Categories: ${ATTACK_CATEGORIES:-all}"
echo ""

# Step 1: Create or get LLM credential
echo "🔑 Setting up LLM credential..."

CREDENTIAL_RESPONSE=$(curl -s -X POST "${ERIS_API_URL}/api/llm/credentials" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ERIS_API_KEY}" \
    -d "{
        \"name\": \"github-action-test\",
        \"provider\": \"${LLM_PROVIDER}\",
        \"api_key\": \"${LLM_API_KEY}\",
        \"model\": \"${LLM_MODEL:-}\"
    }" 2>/dev/null)

# Extract credential ID
CREDENTIAL_ID=$(echo "$CREDENTIAL_RESPONSE" | jq -r '.id // .credential.id // empty' 2>/dev/null)

if [ -z "$CREDENTIAL_ID" ]; then
    # Try to get existing credential by name
    echo "   Checking for existing credential..."
    CREDS_LIST=$(curl -s "${ERIS_API_URL}/api/llm/credentials" \
        -H "Authorization: Bearer ${ERIS_API_KEY}" 2>/dev/null)
    
    CREDENTIAL_ID=$(echo "$CREDS_LIST" | jq -r '.credentials[] | select(.name=="github-action-test") | .id' 2>/dev/null | head -1)
    
    if [ -z "$CREDENTIAL_ID" ]; then
        echo "❌ Error: Could not create or find LLM credential"
        echo "Response: $CREDENTIAL_RESPONSE"
        exit 1
    fi
fi

echo "   ✓ Credential ID: ${CREDENTIAL_ID:0:8}..."
echo ""

# Step 2: Build scan request
echo "🔄 Starting Red Team security scan..."

SCAN_BODY="{\"credential_id\": \"$CREDENTIAL_ID\""

if [ -n "$ATTACK_CATEGORIES" ]; then
    # Convert comma-separated to JSON array
    CATEGORIES_JSON=$(echo "$ATTACK_CATEGORIES" | tr ',' '\n' | jq -R . | jq -s .)
    SCAN_BODY="${SCAN_BODY}, \"categories\": $CATEGORIES_JSON"
fi

SCAN_BODY="${SCAN_BODY}}"

# Run the scan
SCAN_RESPONSE=$(curl -s -X POST "${ERIS_API_URL}/api/red-team/scan" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ERIS_API_KEY}" \
    -d "$SCAN_BODY" \
    --max-time 300 2>/dev/null)

# Check for errors
if echo "$SCAN_RESPONSE" | jq -e '.detail' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$SCAN_RESPONSE" | jq -r '.detail')
    echo "❌ Error: $ERROR_MSG"
    exit 1
fi

# Extract results
VULNERABILITY_SCORE=$(echo "$SCAN_RESPONSE" | jq -r '.vulnerability_score // 0')
RISK_RATING=$(echo "$SCAN_RESPONSE" | jq -r '.risk_rating // "Unknown"')
SUCCESSFUL_ATTACKS=$(echo "$SCAN_RESPONSE" | jq -r '.successful_attacks // 0')
TOTAL_ATTACKS=$(echo "$SCAN_RESPONSE" | jq -r '.total_attacks // 0')
ERROR_ATTACKS=$(echo "$SCAN_RESPONSE" | jq -r '.error_attacks // 0')

echo ""
echo "📈 Scan Results:"
echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Vulnerability Score: ${VULNERABILITY_SCORE}%"
echo "   Risk Rating: ${RISK_RATING}"
echo "   Successful Attacks: ${SUCCESSFUL_ATTACKS}/${TOTAL_ATTACKS}"
echo "   Errors: ${ERROR_ATTACKS}"
echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show category breakdown
echo "📊 Category Breakdown:"
echo "$SCAN_RESPONSE" | jq -r '.category_breakdown[] | "   \(.category): \(.successful)/\(.total) vulnerable"' 2>/dev/null || echo "   (no breakdown available)"
echo ""

# Check for critical vulnerabilities
CRITICAL_HITS=$(echo "$SCAN_RESPONSE" | jq '[.attack_results[] | select(.success == true and .severity == "critical")] | length' 2>/dev/null || echo "0")

# Set GitHub Actions outputs
echo "vulnerability_score=${VULNERABILITY_SCORE}" >> $GITHUB_OUTPUT 2>/dev/null || true
echo "risk_rating=${RISK_RATING}" >> $GITHUB_OUTPUT 2>/dev/null || true
echo "successful_attacks=${SUCCESSFUL_ATTACKS}" >> $GITHUB_OUTPUT 2>/dev/null || true
echo "total_attacks=${TOTAL_ATTACKS}" >> $GITHUB_OUTPUT 2>/dev/null || true
echo "passed=false" >> $GITHUB_OUTPUT 2>/dev/null || true

# Check fail conditions
FAILED=false
FAIL_REASON=""

# Check for critical vulnerabilities
if [ "$FAIL_ON_CRITICAL" = "true" ] && [ "$CRITICAL_HITS" -gt 0 ]; then
    FAILED=true
    FAIL_REASON="Critical vulnerabilities found: ${CRITICAL_HITS}"
fi

# Check vulnerability threshold
ABOVE_THRESHOLD=$(echo "$VULNERABILITY_SCORE > $VULNERABILITY_THRESHOLD" | bc -l 2>/dev/null || echo "0")
if [ "$ABOVE_THRESHOLD" = "1" ]; then
    FAILED=true
    FAIL_REASON="Vulnerability score ${VULNERABILITY_SCORE}% exceeds threshold of ${VULNERABILITY_THRESHOLD}%"
fi

# Print summary and exit
if [ "$FAILED" = "true" ]; then
    echo "❌ FAILED: $FAIL_REASON"
    echo "passed=false" >> $GITHUB_OUTPUT 2>/dev/null || true
    
    # Print vulnerable attacks for debugging
    echo ""
    echo "🔓 Vulnerabilities Found:"
    echo "$SCAN_RESPONSE" | jq -r '.attack_results[] | select(.success == true) | "   [\(.severity)] \(.attack_name): \(.success_reason // "N/A")"' 2>/dev/null || true
    
    exit 1
else
    echo "✅ PASSED: Vulnerability score ${VULNERABILITY_SCORE}% is within threshold of ${VULNERABILITY_THRESHOLD}%"
    echo "passed=true" >> $GITHUB_OUTPUT 2>/dev/null || true
    exit 0
fi

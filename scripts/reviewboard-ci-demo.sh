#!/bin/bash
# ============================================================
# Review Board + CI/CD Integration Demo Script
# ============================================================
# This script demonstrates the full workflow:
# 1. Developer makes a code change
# 2. Posts it to Review Board for review
# 3. CI runs automatically and reports results to Review Board
# 4. Reviewer sees CI results + code diff
# 5. Reviewer approves ("Ship It!")
# 6. Developer merges → main pipeline triggers
# ============================================================

set -e

REVIEWBOARD_URL="http://localhost:8083"
RBT_PATH="/Users/pnallamilli/Library/Python/3.13/bin"
export PATH="$PATH:$RBT_PATH"

echo "============================================"
echo "  Review Board + CI/CD Integration Demo"
echo "============================================"
echo ""

# Step 1: Check Review Board is running
echo "[Step 1] Checking Review Board is running..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${REVIEWBOARD_URL}/api/)
if [ "$HTTP_CODE" != "200" ]; then
    echo "  ❌ Review Board is not running at ${REVIEWBOARD_URL}"
    echo "  Start it with: podman start db memcached reviewboard rb-nginx"
    exit 1
fi
echo "  ✅ Review Board is running (HTTP ${HTTP_CODE})"
echo ""

# Step 2: Show current status
echo "[Step 2] Current Review Board status..."
echo "  URL: ${REVIEWBOARD_URL}"
echo "  Repository: CRD-POC"
echo ""
rbt status 2>/dev/null || echo "  No pending review requests"
echo ""

# Step 3: Run local CI checks (same as what GitHub Actions would run)
echo "[Step 3] Running CI checks locally..."
echo ""

echo "  [3a] Running Maven tests..."
if mvn clean test -q 2>/dev/null; then
    TEST_STATUS="PASSED ✅"
else
    TEST_STATUS="FAILED ❌"
fi
echo "  Tests: ${TEST_STATUS}"

echo "  [3b] Checking code style..."
STYLE_ISSUES=$(find src -name "*.java" -exec grep -l "	" {} \; 2>/dev/null | wc -l | tr -d ' ')
if [ "$STYLE_ISSUES" -gt "0" ]; then
    STYLE_STATUS="WARNING ⚠️ (${STYLE_ISSUES} files with tabs)"
else
    STYLE_STATUS="PASSED ✅"
fi
echo "  Style: ${STYLE_STATUS}"

echo "  [3c] Checking Dockerfile..."
if [ -f Dockerfile ]; then
    DOCKER_STATUS="FOUND ✅"
else
    DOCKER_STATUS="MISSING ❌"
fi
echo "  Dockerfile: ${DOCKER_STATUS}"
echo ""

# Step 4: Update Review Board with CI status via API
echo "[Step 4] Posting CI results to Review Board..."

# Get the latest review request ID
REVIEW_ID=$(curl -s -u admin:admin "${REVIEWBOARD_URL}/api/review-requests/?counts-only=1" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('count', 0))
" 2>/dev/null)

if [ "$REVIEW_ID" -gt "0" ]; then
    # Get the actual latest review request
    LATEST_RR=$(curl -s -u admin:admin "${REVIEWBOARD_URL}/api/review-requests/" | python3 -c "
import sys, json
data = json.load(sys.stdin)
rrs = data.get('review_requests', [])
if rrs:
    print(rrs[0]['id'])
else:
    print(0)
" 2>/dev/null)
    
    if [ "$LATEST_RR" -gt "0" ]; then
        # Post a review with CI results
        curl -s -u admin:admin \
            -X POST \
            -d "body_top=**Automated CI Check Results:**%0A%0A- Tests: ${TEST_STATUS}%0A- Code Style: ${STYLE_STATUS}%0A- Dockerfile: ${DOCKER_STATUS}%0A%0A_This review was posted automatically by CI._" \
            -d "public=true" \
            "${REVIEWBOARD_URL}/api/review-requests/${LATEST_RR}/reviews/" > /dev/null 2>&1
        
        echo "  ✅ CI results posted to review request #${LATEST_RR}"
        echo "  View at: ${REVIEWBOARD_URL}/r/${LATEST_RR}/"
    fi
else
    echo "  ⚠️ No review requests found. Post one with: rbt post"
fi
echo ""

# Step 5: Show the integration flow
echo "============================================"
echo "  Integration Flow Summary"
echo "============================================"
echo ""
echo "  DEVELOPER WORKFLOW:"
echo "  1. git checkout -b feature/my-change"
echo "  2. [make code changes]"
echo "  3. git commit -m 'my change'"
echo "  4. rbt post                          → Creates Review Request"
echo "  5. [CI runs automatically]           → Posts results to RB"
echo "  6. [Reviewer approves: Ship It!]"
echo "  7. git checkout main && git merge feature/my-change"
echo "  8. git push origin main              → Triggers GitHub Actions pipeline"
echo "  9. [GitHub Actions: build, test, push Docker image]"
echo " 10. [ArgoCD: auto-sync to Kubernetes]"
echo ""
echo "  WHAT EACH TOOL DOES:"
echo "  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐"
echo "  │ Review Board │───▶│GitHub Actions │───▶│   ArgoCD     │"
echo "  │ Code Review  │    │  CI/CD Build  │    │  K8s Deploy  │"
echo "  │ (Pre-merge)  │    │ (Post-merge)  │    │  (GitOps)    │"
echo "  └──────────────┘    └──────────────┘    └──────────────┘"
echo ""
echo "============================================"
echo "  Demo Complete!"
echo "============================================"

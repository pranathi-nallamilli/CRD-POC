#!/bin/bash
# Quick Test: Verify Complete Automation Flow
# Run this BEFORE your manager demo to ensure everything works

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Testing Complete Automation Flow${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Step 1: Check current state
echo -e "${YELLOW}Step 1: Checking current application state...${NC}"
CURRENT_MSG=$(curl -s http://localhost:8081/ | jq -r '.message')
echo "Current message: ${CURRENT_MSG}"
CURRENT_IMAGE=$(kubectl get deployment java-demo-app -n java-app -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "Current image: ${CURRENT_IMAGE}"
echo ""

# Step 2: Make a test change
echo -e "${YELLOW}Step 2: Creating test code change...${NC}"
TIMESTAMP=$(date +%s)
NEW_MESSAGE="🧪 Test Automation - Run ${TIMESTAMP}"

# Backup original file
cp src/main/java/com/example/demo/DemoApplication.java src/main/java/com/example/demo/DemoApplication.java.backup

# Make the change
sed -i '' "s/Hello from Java Demo App!/${NEW_MESSAGE}/" src/main/java/com/example/demo/DemoApplication.java

echo "Changed message to: ${NEW_MESSAGE}"
echo ""

# Step 3: Commit and push
echo -e "${YELLOW}Step 3: Committing and pushing to GitHub...${NC}"
git add src/main/java/com/example/demo/DemoApplication.java
git commit -m "test: Automated flow test ${TIMESTAMP}"
git push origin main

echo -e "${GREEN}✅ Pushed to GitHub${NC}"
echo ""

# Step 4: Watch GitHub Actions
echo -e "${YELLOW}Step 4: GitHub Actions should now be running${NC}"
echo "Open: https://github.com/pranathi-nallamilli/CRD-POC/actions"
echo ""
echo "You should see a workflow running with 4 jobs:"
echo "  1. Build and Test"
echo "  2. Build and Push Docker Image"
echo "  3. Update Deployment Manifest"
echo "  4. Trigger ArgoCD Sync"
echo ""
echo -e "${BLUE}Waiting 30 seconds for workflow to start...${NC}"
sleep 30

# Step 5: Monitor the deployment
echo -e "${YELLOW}Step 5: Monitoring for deployment updates...${NC}"
echo "Watching pods for changes (Ctrl+C to stop)..."
echo ""

# Watch for new image tag
echo "Checking for manifest update in GitHub..."
for i in {1..20}; do
    NEW_IMAGE=$(kubectl get deployment java-demo-app -n java-app -o jsonpath='{.spec.template.spec.containers[0].image}')
    if [ "$NEW_IMAGE" != "$CURRENT_IMAGE" ]; then
        echo -e "${GREEN}✅ New image detected: ${NEW_IMAGE}${NC}"
        break
    fi
    echo "  Attempt $i/20: No change yet (still ${CURRENT_IMAGE})"
    sleep 15
done

# Step 6: Verify new version
echo ""
echo -e "${YELLOW}Step 6: Verifying deployment...${NC}"
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=java-demo-app -n java-app --timeout=300s

echo ""
echo "Testing application..."
sleep 10  # Give load balancer time to update

NEW_MSG=$(curl -s http://localhost:8081/ | jq -r '.message')
echo "New message: ${NEW_MSG}"
echo ""

# Step 7: Results
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Results${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

if [[ "$NEW_MSG" == *"${TIMESTAMP}"* ]]; then
    echo -e "${GREEN}✅ SUCCESS! Complete automation working!${NC}"
    echo ""
    echo "What happened:"
    echo "  1. ✅ Code pushed to GitHub"
    echo "  2. ✅ GitHub Actions built Docker image"
    echo "  3. ✅ GitHub Actions updated manifest"
    echo "  4. ✅ ArgoCD detected change"
    echo "  5. ✅ Kubernetes deployed new version"
    echo "  6. ✅ Application serving new code"
    echo ""
    echo -e "${GREEN}You're ready for the manager demo!${NC}"
else
    echo -e "${RED}⚠️  Automation may still be in progress${NC}"
    echo ""
    echo "Current message: ${CURRENT_MSG}"
    echo "Expected: Should contain ${TIMESTAMP}"
    echo ""
    echo "This could mean:"
    echo "  - Pipeline is still running (check GitHub Actions)"
    echo "  - ArgoCD hasn't synced yet (check ArgoCD UI)"
    echo "  - Pods are still rolling out (check: kubectl get pods -n java-app)"
    echo ""
    echo "Manual checks:"
    echo "  GitHub Actions: https://github.com/pranathi-nallamilli/CRD-POC/actions"
    echo "  ArgoCD UI: https://localhost:8443"
    echo "  Pods: kubectl get pods -n java-app -w"
fi

# Step 8: Restore original
echo ""
read -p "Restore original code? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mv src/main/java/com/example/demo/DemoApplication.java.backup src/main/java/com/example/demo/DemoApplication.java
    git add src/main/java/com/example/demo/DemoApplication.java
    git commit -m "test: Restore original message"
    git push origin main
    echo -e "${GREEN}✅ Original code restored and pushed${NC}"
else
    echo "Keeping test code. You can manually restore from backup:"
    echo "  mv src/main/java/com/example/demo/DemoApplication.java.backup src/main/java/com/example/demo/DemoApplication.java"
fi

echo ""
echo -e "${BLUE}Test complete!${NC}"

#!/bin/bash
# Monitor the complete GitOps automation flow

echo "🚀 Monitoring Complete GitOps Flow"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initial state
echo -e "${BLUE}📊 Initial State:${NC}"
CURRENT_MSG=$(curl -s http://localhost:8081/ | jq -r '.message')
echo "   Message: ${CURRENT_MSG}"

CURRENT_IMAGE=$(kubectl get deployment java-demo-app -n default -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "   Image: ${CURRENT_IMAGE}"
echo ""

echo -e "${YELLOW}⏳ Waiting for GitHub Actions to complete (this takes ~5-7 minutes)...${NC}"
echo "   You can watch: https://github.com/pranathi-nallamilli/CRD-POC/actions"
echo ""

# Monitor deployment image changes
echo -e "${BLUE}🔍 Monitoring for changes (checking every 15 seconds)...${NC}"
echo ""

COUNTER=0
MAX_CHECKS=40  # 10 minutes max

while [ $COUNTER -lt $MAX_CHECKS ]; do
    # Check if image changed
    NEW_IMAGE=$(kubectl get deployment java-demo-app -n default -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    
    if [ "$NEW_IMAGE" != "$CURRENT_IMAGE" ]; then
        echo -e "${GREEN}✅ NEW IMAGE DETECTED!${NC}"
        echo "   Old: ${CURRENT_IMAGE}"
        echo "   New: ${NEW_IMAGE}"
        echo ""
        echo -e "${YELLOW}⏳ Waiting for pods to update...${NC}"
        
        # Wait for rollout
        kubectl rollout status deployment/java-demo-app -n default --timeout=5m
        
        # Test new message
        sleep 10
        NEW_MSG=$(curl -s http://localhost:8081/ | jq -r '.message')
        
        echo ""
        echo -e "${GREEN}=================================="
echo "🎉 DEPLOYMENT COMPLETE!"
        echo "==================================${NC}"
        echo ""
        echo "Old Message: ${CURRENT_MSG}"
        echo -e "${GREEN}New Message: ${NEW_MSG}${NC}"
        echo ""
        
        # Show ArgoCD status
        echo -e "${BLUE}ArgoCD Status:${NC}"
        kubectl get application java-demo-app -n argocd
        echo ""
        
        # Show pods
        echo -e "${BLUE}Running Pods:${NC}"
        kubectl get pods -n default
        echo ""
        
        exit 0
    fi
    
    # Progress indicator
    ELAPSED=$((COUNTER * 15))
    echo "   Check $((COUNTER + 1))/$MAX_CHECKS - Elapsed: ${ELAPSED}s - Image: $(echo $NEW_IMAGE | cut -d':' -f2)"
    
    sleep 15
    COUNTER=$((COUNTER + 1))
done

echo ""
echo -e "${YELLOW}⚠️  Timeout reached (10 minutes)${NC}"
echo "   Check GitHub Actions: https://github.com/pranathi-nallamilli/CRD-POC/actions"
echo "   Check ArgoCD UI: https://localhost:8443"

# Complete AWS EKS Setup Guide
## Deploy Java Demo App with ArgoCD on EKS

**Prerequisites:**
- AWS Account with admin/PowerUser access
- AWS CLI installed
- kubectl installed
- eksctl installed

---

## Part 1: Install Required Tools

### 1.1 Install AWS CLI (if not already installed)

```bash
# macOS
brew install awscli

# Verify
aws --version
```

### 1.2 Install eksctl

```bash
# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Verify
eksctl version
```

### 1.3 Install kubectl (if not already installed)

```bash
# macOS
brew install kubectl

# Verify
kubectl version --client
```

---

## Part 2: Configure AWS Credentials

### 2.1 Configure AWS CLI

```bash
# Configure with your AWS credentials
aws configure

# Enter:
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: us-east-1 (or your preferred region)
# Default output format: json
```

### 2.2 Verify Access

```bash
# Check your identity
aws sts get-caller-identity

# Should show:
# {
#   "UserId": "AIDA...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/your-name"
# }
```

---

## Part 3: Create EKS Cluster

### 3.1 Create Cluster Configuration File

```bash
# Create cluster config
cat > eks-cluster-config.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: java-demo-cluster
  region: us-east-1
  version: "1.28"

managedNodeGroups:
  - name: java-demo-nodes
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 4
    volumeSize: 20
    ssh:
      allow: false
    labels:
      role: worker
    tags:
      Environment: demo
      Project: java-demo-app
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        externalDNS: true
        certManager: true
        appMesh: true
        ebs: true
        fsx: true
        efs: true
        albIngress: true
        xRay: true
        cloudWatch: true

# Enable IRSA (IAM Roles for Service Accounts)
iam:
  withOIDC: true

# CloudWatch logging
cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
EOF
```

### 3.2 Create the Cluster

```bash
# This takes 15-20 minutes
eksctl create cluster -f eks-cluster-config.yaml

# Watch progress
eksctl create cluster -f eks-cluster-config.yaml --verbose 4
```

**Expected output:**
```
[✔]  EKS cluster "java-demo-cluster" in "us-east-1" region is ready
```

### 3.3 Verify Cluster

```bash
# Check cluster
eksctl get cluster

# Get kubeconfig
aws eks update-kubeconfig --region us-east-1 --name java-demo-cluster

# Verify connection
kubectl get nodes

# Should show 2 nodes:
# NAME                         STATUS   ROLES    AGE
# ip-192-168-xx-xx.ec2...     Ready    <none>   5m
# ip-192-168-xx-xx.ec2...     Ready    <none>   5m
```

---

## Part 4: Install ArgoCD on EKS

### 4.1 Create ArgoCD Namespace

```bash
kubectl create namespace argocd
```

### 4.2 Install ArgoCD

```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready (2-3 minutes)
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Verify all pods are running
kubectl get pods -n argocd

# Should show all pods Running:
# argocd-application-controller-0
# argocd-applicationset-controller-xxx
# argocd-dex-server-xxx
# argocd-notifications-controller-xxx
# argocd-redis-xxx
# argocd-repo-server-xxx
# argocd-server-xxx
```

### 4.3 Expose ArgoCD Server with LoadBalancer

```bash
# Change service type to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for ELB to be provisioned (2-3 minutes)
kubectl get svc argocd-server -n argocd -w

# Get the LoadBalancer URL
export ARGOCD_URL=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "ArgoCD URL: https://${ARGOCD_URL}"
```

### 4.4 Get ArgoCD Admin Password

```bash
# Get initial password
export ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Password: ${ARGOCD_PASSWORD}"

# Save these for later
echo "=== ArgoCD Login Info ==="
echo "URL: https://${ARGOCD_URL}"
echo "Username: admin"
echo "Password: ${ARGOCD_PASSWORD}"
```

### 4.5 Install ArgoCD CLI

```bash
# macOS
brew install argocd

# Login via CLI
argocd login ${ARGOCD_URL} \
  --username admin \
  --password ${ARGOCD_PASSWORD} \
  --insecure

# Change password (recommended)
argocd account update-password
```

---

## Part 5: Deploy Your Application

### 5.1 Create Application Namespace

```bash
kubectl create namespace java-app
```

### 5.2 Deploy ArgoCD Application

```bash
# Apply your ArgoCD application definition
kubectl apply -f k8s/argocd-application.yaml

# Verify application created
kubectl get application -n argocd

# Should show:
# NAME            SYNC STATUS   HEALTH STATUS
# java-demo-app   Synced        Healthy
```

### 5.3 Watch ArgoCD Sync

```bash
# Watch via kubectl
kubectl get application java-demo-app -n argocd -w

# Or watch via ArgoCD CLI
argocd app get java-demo-app --watch

# Or open ArgoCD UI
# Go to: https://${ARGOCD_URL}
# Login and click on java-demo-app
```

### 5.4 Verify Application Deployment

```bash
# Check pods
kubectl get pods -n java-app

# Should show 3 running pods:
# NAME                            READY   STATUS    RESTARTS   AGE
# java-demo-app-xxxxxxxxx-xxxxx   1/1     Running   0          2m
# java-demo-app-xxxxxxxxx-xxxxx   1/1     Running   0          2m
# java-demo-app-xxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check service
kubectl get svc -n java-app

# Check deployment
kubectl get deployment java-demo-app -n java-app
```

---

## Part 6: Expose Your Application

### Option A: LoadBalancer (Simplest for Demo)

```bash
# Change service type to LoadBalancer
kubectl patch svc java-demo-app -n java-app \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for ELB (2-3 minutes)
kubectl get svc java-demo-app -n java-app -w

# Get the URL
export APP_URL=$(kubectl get svc java-demo-app -n java-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://${APP_URL}"

# Test the application
curl http://${APP_URL}/
curl http://${APP_URL}/health
curl http://${APP_URL}/info
```

### Option B: Ingress with ALB (Production-Ready)

```bash
# Install AWS Load Balancer Controller first
# (See Part 7 for full setup)

# Then create ingress:
cat > k8s/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: java-demo-app
  namespace: java-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: java-demo-app
            port:
              number: 80
EOF

kubectl apply -f k8s/ingress.yaml
```

---

## Part 7: Test End-to-End GitOps Flow

### 7.1 Make a Code Change

```bash
# Edit your application
vim src/main/java/com/example/demo/DemoApplication.java

# Change the message:
response.put("message", "Hello from AWS EKS!");

# Commit and push
git add .
git commit -m "Update message for EKS deployment"
git push origin main
```

### 7.2 Watch the Automation

**In GitHub Actions:**
```bash
# Open: https://github.com/pranathi-nallamilli/CRD-POC/actions
# Watch the workflow run through all 4 jobs
```

**In ArgoCD:**
```bash
# Watch ArgoCD detect the change
argocd app get java-demo-app --watch

# Or in ArgoCD UI
# Go to: https://${ARGOCD_URL}
# Watch the sync happen automatically
```

**In Kubernetes:**
```bash
# Watch pods update
kubectl get pods -n java-app -w

# You'll see:
# - New pods created
# - Old pods terminated
# - Rolling update in action
```

### 7.3 Verify the Update

```bash
# Test the new version
curl http://${APP_URL}/ | jq

# Should show:
# {
#   "message": "Hello from AWS EKS!",
#   "timestamp": "...",
#   "version": "1.0.0"
# }
```

---

## Part 8: Monitor and Observe

### 8.1 View Logs

```bash
# Application logs
kubectl logs -f -n java-app -l app=java-demo-app

# ArgoCD logs
kubectl logs -f -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### 8.2 Check Resource Usage

```bash
# CPU and memory
kubectl top nodes
kubectl top pods -n java-app

# Cluster info
kubectl cluster-info
```

### 8.3 ArgoCD Application Details

```bash
# Get app info
argocd app get java-demo-app

# Get app history
argocd app history java-demo-app

# Get app manifest
argocd app manifests java-demo-app
```

---

## Part 9: Configure Auto-Scaling (Optional)

### 9.1 Horizontal Pod Autoscaler (Already Configured)

```bash
# Check HPA
kubectl get hpa -n java-app

# Describe HPA
kubectl describe hpa java-demo-app -n java-app
```

### 9.2 Cluster Autoscaler

```bash
# Already enabled in eksctl config (iam.withAddonPolicies.autoScaler: true)

# Install cluster-autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Edit deployment to add cluster name
kubectl -n kube-system edit deployment cluster-autoscaler

# Add this under containers.command:
# - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/java-demo-cluster
```

---

## Part 10: Security Best Practices

### 10.1 Use Secrets Manager for Sensitive Data

```bash
# Instead of GitHub Secrets, use AWS Secrets Manager
# Store Docker Hub credentials:
aws secretsmanager create-secret \
  --name docker-hub-credentials \
  --secret-string '{"username":"pranathinallamilli","password":"<token>"}'

# Use External Secrets Operator to sync to Kubernetes
```

### 10.2 Enable Pod Security Standards

```bash
# Label namespace
kubectl label namespace java-app \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### 10.3 Network Policies

```bash
# Create network policy
cat > k8s/network-policy.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: java-demo-app
  namespace: java-app
spec:
  podSelector:
    matchLabels:
      app: java-demo-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector: {}
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF

kubectl apply -f k8s/network-policy.yaml
```

---

## Part 11: Cost Optimization

### 11.1 Check Current Costs

```bash
# Get cluster info
eksctl get cluster java-demo-cluster

# Node group details
eksctl get nodegroup --cluster java-demo-cluster
```

**Expected Monthly Costs (Estimate):**
- 2 × t3.medium nodes: ~$60/month ($0.0416/hour each)
- ELB (Classic): ~$18/month
- EBS volumes (40GB total): ~$4/month
- Data transfer: ~$5-10/month
- **Total: ~$87-92/month**

### 11.2 Reduce Costs

```bash
# Use Spot instances (60-70% cheaper)
# Edit eks-cluster-config.yaml:
# instancesDistribution:
#   instanceTypes: ["t3.medium", "t3a.medium"]
#   onDemandBaseCapacity: 0
#   onDemandPercentageAboveBaseCapacity: 0
#   spotAllocationStrategy: lowest-price

# Or scale down when not in use
eksctl scale nodegroup --cluster java-demo-cluster \
  --name java-demo-nodes --nodes 1 --nodes-min 1 --nodes-max 1
```

---

## Part 12: Cleanup (When Done)

### 12.1 Delete Application

```bash
# Delete ArgoCD application
kubectl delete application java-demo-app -n argocd

# Delete app namespace
kubectl delete namespace java-app
```

### 12.2 Delete ArgoCD

```bash
kubectl delete namespace argocd
```

### 12.3 Delete EKS Cluster

```bash
# This deletes everything: nodes, VPC, subnets, security groups
eksctl delete cluster --name java-demo-cluster --region us-east-1

# Takes 5-10 minutes
# Verify deletion
eksctl get cluster
```

**⚠️ Important:** Always delete clusters when not in use to avoid charges!

---

## Complete Setup Script

**Save this as `setup-eks.sh`:**

```bash
#!/bin/bash
set -e

echo "=== AWS EKS Setup for Java Demo App ==="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Create EKS cluster
echo -e "${BLUE}Step 1: Creating EKS cluster (15-20 min)...${NC}"
eksctl create cluster -f eks-cluster-config.yaml

# 2. Install ArgoCD
echo -e "${BLUE}Step 2: Installing ArgoCD...${NC}"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 3. Expose ArgoCD
echo -e "${BLUE}Step 3: Exposing ArgoCD...${NC}"
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 60

# 4. Get ArgoCD credentials
echo -e "${BLUE}Step 4: Retrieving ArgoCD credentials...${NC}"
export ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

# 5. Create app namespace
echo -e "${BLUE}Step 5: Creating application namespace...${NC}"
kubectl create namespace java-app

# 6. Deploy application
echo -e "${BLUE}Step 6: Deploying application via ArgoCD...${NC}"
kubectl apply -f k8s/argocd-application.yaml

# 7. Expose application
echo -e "${BLUE}Step 7: Exposing application...${NC}"
kubectl patch svc java-demo-app -n java-app -p '{"spec": {"type": "LoadBalancer"}}'
sleep 60

export APP_URL=$(kubectl get svc java-demo-app -n java-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Summary
echo -e "${GREEN}"
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo "ArgoCD URL: https://${ARGOCD_URL}"
echo "ArgoCD Username: admin"
echo "ArgoCD Password: ${ARGOCD_PASSWORD}"
echo ""
echo "Application URL: http://${APP_URL}"
echo ""
echo "Test commands:"
echo "  curl http://${APP_URL}/"
echo "  curl http://${APP_URL}/health"
echo "========================================"
echo -e "${NC}"
```

---

## Troubleshooting

### Issue: Pods stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n java-app

# Check node capacity
kubectl describe nodes

# Solution: Scale up nodes
eksctl scale nodegroup --cluster java-demo-cluster \
  --name java-demo-nodes --nodes 3
```

### Issue: ImagePullBackOff

```bash
# Check exact error
kubectl describe pod <pod-name> -n java-app

# Verify image exists in Docker Hub
docker pull pranathinallamilli/java-demo-app:main-<sha>

# Solution: Use correct tag or 'latest'
kubectl set image deployment/java-demo-app \
  java-app=pranathinallamilli/java-demo-app:latest -n java-app
```

### Issue: ArgoCD not syncing

```bash
# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Force sync
argocd app sync java-demo-app

# Or delete and recreate
kubectl delete application java-demo-app -n argocd
kubectl apply -f k8s/argocd-application.yaml
```

---

## Next Steps After Setup

1. **Set up monitoring:** Install Prometheus + Grafana
2. **Configure alerting:** Set up CloudWatch alarms
3. **Add HTTPS:** Use AWS Certificate Manager + ALB
4. **Set up CI/CD for infrastructure:** Use Terraform or CDK
5. **Implement blue-green deployments:** Use ArgoCD Rollouts
6. **Add database:** RDS PostgreSQL/MySQL
7. **Implement backup:** Velero for cluster backups

---

**You're ready to deploy to AWS EKS! Save this guide and run through it when you get AWS access! 🚀**

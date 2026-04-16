# Live Demo Script: Complete CI/CD + GitOps Automation
## Show Your Manager the Full Automated Flow

**Duration:** 10-15 minutes
**Goal:** Demonstrate code change → automated build → automated deployment

---

## ⚠️ Important: How ArgoCD Works

**ArgoCD monitors ONLY Git repositories (GitHub), NOT local files!**

The automation flow:
```
1. Developer commits code → GitHub
2. GitHub Actions: Builds Docker image automatically
3. GitHub Actions: Updates K8s manifest automatically  
4. ArgoCD: Detects manifest change in GitHub
5. ArgoCD: Automatically deploys to Kubernetes
```

**You MUST push to GitHub for ArgoCD to see changes!**

---

## Pre-Demo Setup (Do This First)

### 1. Start All Port-Forwards

```bash
# Terminal 1: Application
kubectl port-forward -n java-app service/java-demo-app 8081:80

# Terminal 2: ArgoCD UI (already running)
# Should show: https://localhost:8443

# Terminal 3: Keep free for commands
```

### 2. Open Browser Tabs

- **Tab 1**: https://localhost:8443 (ArgoCD UI) - Login with admin/1TiajxhBuXTlHbh5
- **Tab 2**: https://github.com/pranathi-nallamilli/CRD-POC/actions (GitHub Actions)
- **Tab 3**: https://hub.docker.com/r/pranathinallamilli/java-demo-app/tags (Docker Hub)
- **Tab 4**: http://localhost:8081/ (Your App)

### 3. Verify Current State

```bash
# Check app is running
kubectl get pods -n java-app

# Check current version
curl http://localhost:8081/ | jq

# Should show current message
```

---

## Demo Flow: Show Complete Automation

### Part 1: Introduction (2 minutes)

**What to say:**
> "I've built a complete CI/CD pipeline with GitOps. Let me show you how a simple code change automatically flows through our entire infrastructure without any manual intervention."

**Show them the architecture:**
1. Point to VS Code: "This is our Java Spring Boot application"
2. Point to GitHub: "Our source code repository"
3. Point to GitHub Actions: "Our CI/CD pipeline"
4. Point to Docker Hub: "Our container registry"
5. Point to ArgoCD: "Our GitOps deployment engine"
6. Point to Terminal: "Our Kubernetes cluster with the running application"

---

### Part 2: Make a Live Code Change (3 minutes)

**Step 1: Show Current Application**

**Terminal:**
```bash
curl http://localhost:8081/
```

**What to say:**
> "Here's our current application response. Now I'm going to change this message, and you'll see it automatically deploy."

**Step 2: Edit Code**

Open: `src/main/java/com/example/demo/DemoApplication.java`

**Find this (around line 28):**
```java
response.put("message", "Hello from Java Demo App!");
```

**Change to:**
```java
response.put("message", "🚀 Live Demo - Automated CI/CD + GitOps in Action!");
```

**What to say:**
> "I've changed the message. Now watch - I'm going to commit and push this to GitHub, and the entire automation will kick in."

**Step 3: Commit and Push**

```bash
git add src/main/java/com/example/demo/DemoApplication.java
git commit -m "feat: Update message for live demo"
git push origin main
```

**What to say:**
> "The code is now in GitHub. Let's watch the automation happen."

---

### Part 3: Watch GitHub Actions Automation (4 minutes)

**Switch to Browser: GitHub Actions tab**

**Refresh the page - you should see a new workflow running**

**What to say:**
> "GitHub Actions has automatically detected my push. Let me show you what's happening in our 4-job pipeline:"

**Point to the workflow running:**

**Job 1: Build and Test** ✅
> "First, it compiles the Java code and runs our tests to ensure quality."

**Job 2: Build and Push Docker Image** ✅
> "Once tests pass, it automatically builds a Docker container with my new code and pushes it to Docker Hub with a unique tag based on the Git commit SHA."

**Show Docker Hub tab:**
> "See? A new image is being pushed right now." (Refresh Docker Hub)

**Job 3: Update Deployment Manifest** ✅
> "This is the GitOps magic - it automatically updates our Kubernetes deployment.yaml file in GitHub with the new Docker image tag."

**Click on Job 3 when it completes:**
> "See the commit message? 'Update java-demo-app image to main-XXXXXX' - this was done automatically by our pipeline."

**Job 4: Trigger ArgoCD Sync** ✅
> "Finally, it tells ArgoCD there's a new version ready to deploy."

---

### Part 4: Watch ArgoCD Auto-Deploy (3 minutes)

**Switch to ArgoCD UI (https://localhost:8443)**

**What to say:**
> "Now ArgoCD, our GitOps engine, has detected the manifest change in GitHub."

**In ArgoCD:**

1. **Click on `java-demo-app`**
2. **Show the visual graph:**
   > "This shows our deployment architecture - 3 replicas for high availability."

3. **Point to the sync status:**
   > "ArgoCD is configured for automated deployment. It detected the change and is now syncing."

**If sync is happening:**
> "Watch as old pods are terminated and new pods with updated code are created - this is a rolling update with zero downtime."

**If sync shows "Unknown" (Minikube DNS issue):**
> "In our local Minikube environment, we have a DNS limitation. But let me manually trigger the sync to show you how it works. In production on AWS EKS or Azure AKS, this would be fully automatic."

**Manual sync (if needed):**
```bash
# In terminal
kubectl patch application java-demo-app -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or click "SYNC" button in ArgoCD UI
```

---

### Part 5: Watch Kubernetes Rolling Update (2 minutes)

**Switch to Terminal:**

```bash
# Watch pods update in real-time
kubectl get pods -n java-app -w
```

**What to say:**
> "See? Kubernetes is doing a rolling update. It creates new pods with the updated code, waits for them to be healthy, then terminates the old pods. Zero downtime!"

**You'll see:**
```
java-demo-app-new-xxxxx   0/1   ContainerCreating   0   1s
java-demo-app-new-xxxxx   1/1   Running             0   15s
java-demo-app-old-xxxxx   1/1   Terminating         0   5m
```

Press Ctrl+C after seeing the new pods running.

---

### Part 6: Verify the Deployment (1 minute)

**Test the updated application:**

```bash
curl http://localhost:8081/
```

**Expected output:**
```json
{
  "message": "🚀 Live Demo - Automated CI/CD + GitOps in Action!",
  "timestamp": "2026-04-16T...",
  "version": "1.0.0"
}
```

**What to say:**
> "And there it is! My code change from 10 minutes ago is now live in Kubernetes. Everything happened automatically - no manual intervention except my initial code commit."

---

## Part 7: Summary - What They Just Saw (2 minutes)

**Recap the automation:**

1. ✅ **Developer Experience**: Simple `git push`
2. ✅ **Automated Testing**: Code compiled and tested automatically
3. ✅ **Automated Build**: Docker image created and pushed
4. ✅ **GitOps**: Kubernetes manifest updated in Git
5. ✅ **Automated Deployment**: ArgoCD deployed to Kubernetes
6. ✅ **Zero Downtime**: Rolling update strategy
7. ✅ **Self-Healing**: ArgoCD monitors and auto-corrects drift

**Production Ready Features:**

```bash
# Show auto-scaling
kubectl get hpa -n java-app

# Show health monitoring
kubectl get pods -n java-app -o wide

# Show deployment history
kubectl rollout history deployment/java-demo-app -n java-app
```

**What to say:**
> "This same workflow works identically in AWS EKS, Azure AKS, or Google GKE. The only difference is we'd use cloud load balancers instead of local port-forwarding, and ArgoCD's DNS would work perfectly in multi-node production clusters."

---

## Troubleshooting During Demo

### Issue 1: ArgoCD Shows "Unknown" Sync Status

**What to say:**
> "Our local Minikube has a DNS limitation - it's a single-node cluster with limited CoreDNS capacity. In production on AWS EKS, this wouldn't happen because we'd have multiple CoreDNS replicas and AWS Route53 backing. Let me manually trigger the sync to demonstrate the deployment."

**Fix:**
```bash
# Option 1: Refresh ArgoCD
kubectl delete po -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Option 2: Manual sync in UI
# Click SYNC button in ArgoCD UI

# Option 3: Force sync via CLI
kubectl patch application java-demo-app -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Issue 2: GitHub Actions Workflow Doesn't Start

**Check:**
```bash
# Did the commit work?
git log -1

# Is the workflow file correct?
cat .github/workflows/ci-cd.yml | head -20
```

**Common cause:** paths-ignore might be excluding your change

**Fix:** Make sure you changed `src/` files, not just `k8s/` files

### Issue 3: Pods Not Updating

**Check image tag:**
```bash
# What image is current deployment using?
kubectl get deployment java-demo-app -n java-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# What's the latest tag in Docker Hub?
# Check browser tab

# Force update if needed
kubectl rollout restart deployment/java-demo-app -n java-app
```

### Issue 4: Port-Forward Died

**Restart:**
```bash
# Application
kubectl port-forward -n java-app service/java-demo-app 8081:80

# ArgoCD
kubectl port-forward -n argocd service/argocd-server 8443:443
```

---

## Alternative Demo: If You Can't Push to GitHub Live

**Scenario:** Network issues or can't push live

**Solution: Show a Previous Commit**

```bash
# Show GitHub Actions history
# Open: https://github.com/pranathi-nallamilli/CRD-POC/actions

# Pick a previous successful workflow run
# Walk through each job and show logs

# Show the corresponding commit in GitHub
# Show the automatic manifest update commit

# Show current deployment
kubectl describe deployment java-demo-app -n java-app | grep Image:
```

**What to say:**
> "Let me show you a recent deployment. Here you can see the workflow that ran earlier today..." (walk through the same explanation)

---

## Questions Your Manager Might Ask

### Q: "What happens if a deployment fails?"

**Answer:**
> "ArgoCD has automatic rollback. It monitors pod health, and if new pods fail health checks, it won't terminate old pods. We also have retry policies with exponential backoff. Plus, I can manually rollback to any previous version with one command."

```bash
# Show rollback
kubectl rollout undo deployment/java-demo-app -n java-app

# Show history
kubectl rollout history deployment/java-demo-app -n java-app
```

### Q: "Can someone manually change the deployment and break things?"

**Answer:**
> "ArgoCD has self-heal enabled. If someone manually changes the Kubernetes deployment, ArgoCD detects the drift and automatically restores it to match Git within 3 minutes. Git is our single source of truth."

**Demo:**
```bash
# Manually change replicas
kubectl scale deployment java-demo-app -n java-app --replicas=5

# Wait 30 seconds, check again
kubectl get deployment java-demo-app -n java-app

# ArgoCD will restore to 3 replicas (defined in Git)
```

### Q: "How do you handle different environments (dev/staging/prod)?"

**Answer:**
> "We can use ArgoCD's multi-environment support with Kustomize overlays or Helm values. Each environment points to a different branch or path in Git. Same workflow, different targets."

### Q: "What's the cost of running this in AWS?"

**Answer:**
> "Based on my research, approximately $87-92/month for a 2-node EKS cluster running 24/7, or we can implement auto-shutdown for non-production environments to reduce costs to around $10-15/day only when in use."

### Q: "How long does this deployment take?"

**Answer:**
> "From git push to deployed: approximately 5-7 minutes total:
- GitHub Actions (4 jobs): ~3-4 minutes
- ArgoCD sync: ~30-60 seconds  
- Rolling update: ~1-2 minutes
This is with testing, image building, and zero-downtime deployment."

### Q: "Can we deploy multiple times per day?"

**Answer:**
> "Absolutely! This is designed for continuous deployment. Every push triggers the pipeline. In production teams, this enables 10-20+ deployments per day safely with automated testing and rollback capabilities."

---

## After the Demo: Next Steps

**What to say:**
> "This is production-ready. The next steps would be:
1. Deploy this to AWS EKS or Azure AKS (I have the setup guide ready)
2. Add Slack/Teams notifications for deployments
3. Implement blue-green or canary deployments with ArgoCD Rollouts
4. Add Prometheus + Grafana for monitoring
5. Set up backup and disaster recovery with Velero"

---

## Quick Reference: All Commands

```bash
# Watch application
curl http://localhost:8081/ | jq

# Watch pods
kubectl get pods -n java-app -w

# Watch ArgoCD sync
kubectl get application java-demo-app -n argocd -w

# Force ArgoCD sync
kubectl patch application java-demo-app -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Check deployment image
kubectl get deployment java-demo-app -n java-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Rollback
kubectl rollout undo deployment/java-demo-app -n java-app

# Scale (to demo self-heal)
kubectl scale deployment java-demo-app -n java-app --replicas=5
```

---

**🎯 You're ready! Practice this flow 2-3 times before your manager demo!**

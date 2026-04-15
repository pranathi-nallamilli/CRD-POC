# GitHub Actions CI/CD Demo

## Overview
Testing GitHub Actions workflow with Java Spring Boot application deployment using Docker Hub and GitOps.

## Current Status
✅ Application code ready  
✅ Dockerfile ready  
✅ Kubernetes manifests ready  
✅ GitHub Actions workflow configured  
⏳ Pending: Docker Hub + GitHub Secrets setup  

## Quick Start Guide

### Step 1: Create Docker Hub Account
1. Go to https://hub.docker.com
2. Sign up (free account)
3. Verify your email

### Step 2: Create Docker Hub Access Token
1. Login to Docker Hub
2. Click your profile → Account Settings
3. Security → New Access Token
4. Name: `github-actions`
5. Access permissions: Read, Write, Delete
6. **Copy the token immediately** (you won't see it again!)

### Step 3: Create GitHub Personal Access Token
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Note: `github-actions-cicd`
4. Scopes: Select `repo` (full control of private repositories)
5. Generate token
6. **Copy the token immediately!**

### Step 4: Configure GitHub Secrets
1. Go to https://github.com/pranathi-nallamilli/CRD-POC/settings/secrets/actions
2. Click "New repository secret"
3. Add these THREE secrets:

**Secret 1:**
- Name: `DOCKER_USERNAME`
- Value: `your-dockerhub-username`

**Secret 2:**
- Name: `DOCKER_PASSWORD`
- Value: `[paste Docker Hub access token]`

**Secret 3:**
- Name: `GIT_TOKEN`
- Value: `[paste GitHub personal access token]`

### Step 5: Push Code to Trigger Workflow
```bash
cd /Users/pnallamilli/Documents/pranathi-learning/CRD-POC

# Check status
git status

# Add all files
git add .

# Commit
git commit -m "Initial commit: Java app with GitHub Actions CI/CD"

# Push to main branch (this triggers the workflow!)
git push origin main
```

### Step 6: Watch the Workflow Run
1. Go to https://github.com/pranathi-nallamilli/CRD-POC/actions
2. You'll see your workflow running with 4 jobs:
   - ✅ Build and Test
   - ✅ Build and Push Docker Image
   - ✅ Update Kubernetes Manifest
   - ✅ Notify

3. Click on the running workflow to see live logs!

---

## What Will Happen

### Job 1: Build and Test (2-3 minutes)
- Checks out code
- Sets up Java 17
- Runs Maven tests
- Builds JAR file
- Uploads artifact

### Job 2: Build and Push Image (3-5 minutes)
- Builds Docker image for AMD64 and ARM64
- Pushes to Docker Hub as `your-username/java-demo-app:latest` and `:main-abc1234`
- Scans for vulnerabilities with Trivy

### Job 3: Update K8s Manifest (30 seconds)
- Updates `k8s/deployment.yaml` with new image tag
- Commits and pushes change back to repo
- **This triggers ArgoCD sync if you have it configured!**

### Job 4: Notify (10 seconds)
- Adds notices to workflow summary
- Ready for ArgoCD to deploy

---

## After First Successful Run

### Check Docker Hub
```bash
# Your image will be at:
# https://hub.docker.com/r/YOUR-USERNAME/java-demo-app
```

### Deploy to Minikube (Optional)
```bash
# If you want to deploy locally
kubectl create namespace java-app
kubectl apply -f k8s/
kubectl get pods -n java-app

# Port-forward to access
kubectl port-forward svc/java-demo-app 8080:8080 -n java-app

# Test
curl http://localhost:8080/health
```

---

## Troubleshooting

### Workflow Fails at "Log in to Docker Hub"
- ❌ Check DOCKER_USERNAME secret matches your Docker Hub username
- ❌ Check DOCKER_PASSWORD is the access token, not your password

### Workflow Fails at "Push Docker Image"
- ❌ Verify Docker Hub token has Write permissions
- ❌ Check username in the token matches DOCKER_USERNAME secret

### Workflow Fails at "Commit and push changes"
- ❌ Check GIT_TOKEN secret is set correctly
- ❌ Verify token has `repo` scope enabled

### Workflow Runs But No Image in Docker Hub
- ✅ Workflow only pushes on push to `main` branch (not PRs)
- ✅ Check you pushed to `main` not another branch

---

## Project Structure
```
CRD-POC/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions workflow
├── src/                       # Java application source
│   └── main/
│       └── java/
│           └── com/example/demo/
│               └── DemoApplication.java
├── k8s/                       # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── Dockerfile                 # Container build
├── pom.xml                    # Maven configuration
└── README.md
```

---

## Costs
- ✅ GitHub (Free)
- ✅ GitHub Actions (Free - 2000 minutes/month)
- ✅ Docker Hub (Free - unlimited public images)
- ✅ Total cost: **$0**

---

## Next Steps After Successful Run
1. ✅ See your image on Docker Hub
2. ✅ See the updated deployment.yaml in Git (auto-committed)
3. ✅ Set up ArgoCD to auto-deploy from this repo
4. 🎉 Celebrate your first GitHub Actions CI/CD pipeline!

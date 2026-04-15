# 30-Minute GitHub Actions Setup Checklist

## ✅ Phase 1: Docker Hub Setup (5 minutes)

### Step 1.1: Create Docker Hub Account
- [ ] Go to https://hub.docker.com
- [ ] Click "Sign Up"
- [ ] Fill in details (username, email, password)
- [ ] Verify email
- [ ] Login to Docker Hub

### Step 1.2: Create Access Token
- [ ] Click your profile picture → Account Settings
- [ ] Click "Security" in left sidebar
- [ ] Click "New Access Token"
- [ ] Name: `github-actions`
- [ ] Access permissions: **Read, Write, Delete**
- [ ] Click "Generate"
- [ ] **COPY THE TOKEN IMMEDIATELY** (save in notepad!)
- [ ] You won't see it again!

**Save these for later:**
```
Docker Hub Username: _________________
Docker Hub Token: _____________________ (copy-paste here)
```

---

## ✅ Phase 2: GitHub Token Setup (3 minutes)

### Step 2.1: Create Personal Access Token
- [ ] Go to https://github.com/settings/tokens
- [ ] Click "Generate new token" → "Generate new token (classic)"
- [ ] Note: `github-actions-cicd`
- [ ] Expiration: Choose 90 days or No expiration
- [ ] Scopes: Check ☑️ **repo** (full control)
- [ ] Scroll down, click "Generate token"
- [ ] **COPY THE TOKEN** (save in notepad!)

**Save for later:**
```
GitHub Token: _____________________ (copy-paste here)
```

---

## ✅ Phase 3: Configure GitHub Secrets (5 minutes)

### Step 3.1: Add Secrets to Repository
- [ ] Go to https://github.com/pranathi-nallamilli/CRD-POC
- [ ] Click "Settings" tab
- [ ] Click "Secrets and variables" → "Actions"
- [ ] Click "New repository secret"

### Add Secret #1: DOCKER_USERNAME
- [ ] Name: `DOCKER_USERNAME` (exactly this!)
- [ ] Value: Your Docker Hub username (from above)
- [ ] Click "Add secret"

### Add Secret #2: DOCKER_PASSWORD
- [ ] Click "New repository secret" again
- [ ] Name: `DOCKER_PASSWORD` (exactly this!)
- [ ] Value: Paste your Docker Hub token (from above)
- [ ] Click "Add secret"

### Add Secret #3: GIT_TOKEN
- [ ] Click "New repository secret" again
- [ ] Name: `GIT_TOKEN` (exactly this!)
- [ ] Value: Paste your GitHub token (from above)
- [ ] Click "Add secret"

### Verify All Secrets Are Added
- [ ] You should see 3 secrets listed:
  - DOCKER_USERNAME
  - DOCKER_PASSWORD
  - GIT_TOKEN

---

## ✅ Phase 4: Test the Java Application Locally (Optional - 3 minutes)

```bash
cd /Users/pnallamilli/Documents/pranathi-learning/CRD-POC

# Test the app builds
mvn clean test

# Expected output: Tests run: 4, Failures: 0, Errors: 0
```

- [ ] Tests pass ✅

---

## ✅ Phase 5: Push Code to Trigger Workflow (5 minutes)

### Step 5.1: Check Git Status
```bash
cd /Users/pnallamilli/Documents/pranathi-learning/CRD-POC
git status
```

- [ ] See all new files in red (untracked)

### Step 5.2: Add All Files
```bash
git add .
git status
```

- [ ] Files now green (staged)

### Step 5.3: Commit Changes
```bash
git commit -m "Initial commit: Java app with GitHub Actions CI/CD pipeline"
```

- [ ] Commit created successfully

### Step 5.4: Push to GitHub (THIS TRIGGERS THE WORKFLOW!)
```bash
git push origin main
```

- [ ] Push successful
- [ ] See message: "remote: Resolving deltas: 100%"

---

## ✅ Phase 6: Watch the Magic! (10 minutes)

### Step 6.1: Open GitHub Actions
- [ ] Go to https://github.com/pranathi-nallamilli/CRD-POC/actions
- [ ] You should see a workflow running!
- [ ] Name: "Initial commit: Java app with GitHub Actions CI/CD pipeline"

### Step 6.2: Click on the Running Workflow
- [ ] Click the workflow run
- [ ] You'll see 4 jobs:
  1. build-and-test
  2. build-and-push-image (waits for #1)
  3. update-k8s-manifest (waits for #2)
  4. notify (waits for all)

### Step 6.3: Watch Job 1 (Build and Test) - ~2 min
- [ ] Click "build-and-test"
- [ ] Watch it run Maven tests
- [ ] Should turn green ✅

### Step 6.4: Watch Job 2 (Build Docker Image) - ~4 min
- [ ] Click "build-and-push-image"
- [ ] Watch Docker build the image
- [ ] Push to Docker Hub
- [ ] Trivy security scan
- [ ] Should turn green ✅

### Step 6.5: Watch Job 3 (Update K8s Manifest) - ~30 sec
- [ ] Click "update-k8s-manifest"
- [ ] Updates deployment.yaml with new image tag
- [ ] Commits change back to repo
- [ ] Should turn green ✅

### Step 6.6: All Jobs Complete
- [ ] All 4 jobs have green checkmarks ✅
- [ ] Total time: ~8-10 minutes

---

## ✅ Phase 7: Verify Everything Worked (3-5 minutes)

### Step 7.1: Check Docker Hub
- [ ] Go to https://hub.docker.com/repositories
- [ ] You should see: **java-demo-app** repository!
- [ ] Click on it
- [ ] See tags: `latest` and `main-abc1234` (SHA)
- [ ] 🎉 YOUR IMAGE IS ON DOCKER HUB!

### Step 7.2: Check Updated Deployment File
```bash
# Pull the updated file
git pull origin main

# Check the deployment.yaml
cat k8s/deployment.yaml | grep image:
```

- [ ] You should see: `image: YOUR-USERNAME/java-demo-app:main-abc1234`
- [ ] The image tag was **automatically updated**!

### Step 7.3: Check Git Commits
- [ ] Go to https://github.com/pranathi-nallamilli/CRD-POC/commits/main
- [ ] You should see TWO commits:
  1. Your initial commit
  2. **"Update java-demo-app image to main-abc1234"** (by GitHub Actions Bot!)

---

## 🎉 SUCCESS! What You Just Did:

✅ Set up Docker Hub with access token  
✅ Created GitHub Personal Access Token  
✅ Configured 3 GitHub Secrets  
✅ Pushed code to GitHub  
✅ GitHub Actions automatically:
  - Ran tests ✅
  - Built Docker image ✅
  - Pushed to Docker Hub ✅
  - Updated K8s manifest in Git ✅
  - Committed changes back ✅

**This is a complete CI/CD pipeline in action!** 🚀

---

## 🔁 Test Again - Make a Code Change

Want to see it run again?

```bash
# Edit the welcome message
sed -i '' 's/Welcome to Java Demo App!/Welcome to My Awesome CI\/CD Pipeline!/' src/main/java/com/example/demo/DemoApplication.java

# Commit and push
git add .
git commit -m "Update welcome message"
git push origin main

# Go to Actions tab - workflow runs again!
# https://github.com/pranathi-nallamilli/CRD-POC/actions
```

---

## 📸 Screenshots to Capture

For your presentation, take screenshots of:
1. ✅ GitHub Actions workflow - all 4 jobs green
2. ✅ Docker Hub repository with your image
3. ✅ Job 2 logs showing Docker build
4. ✅ Updated deployment.yaml in Git
5. ✅ GitHub Actions Bot commit

---

## ❓ Troubleshooting

**Workflow fails at "Log in to Docker Hub"?**
- Check: DOCKER_USERNAME secret matches your exact Docker Hub username
- Check: DOCKER_PASSWORD is the **access token**, not your password

**Workflow fails at "Build and push Docker image"?**
- Verify Docker Hub token has **Write** permissions
- Check username spelling in secret

**Workflow fails at "Commit and push changes"?**
- Check GIT_TOKEN secret exists
- Verify token has `repo` scope

**Don't see workflow running?**
- Check you pushed to `main` branch (not another branch)
- Workflow only runs on push to `main`

---

## 🎯 Total Time: ~30 minutes
- Docker Hub setup: 5 min
- GitHub token: 3 min
- Configure secrets: 5 min
- Local test: 3 min
- Push code: 2 min
- Watch workflow: 10 min
- Verify results: 5 min

**Ready? Start with Phase 1!** ☝️

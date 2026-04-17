# CI/CD Pipeline with GitOps - Two Approaches
## Java Spring Boot | GitHub Actions | ArgoCD | Kubernetes

**Repository:** https://github.com/pranathi-nallamilli/CRD-POC  
**Docker Hub:** https://hub.docker.com/r/pranathinallamilli/java-demo-app

---

## Application Overview

| Component | Detail |
|-----------|--------|
| Language | Java 17 (Temurin) |
| Framework | Spring Boot 3.2.0 |
| Build Tool | Maven 3.9+ |
| Endpoints | `GET /` (message), `GET /health`, `GET /info` |
| Replicas | 3 pods (HA with rolling updates) |
| Resources | 256Mi–512Mi memory, 250m–500m CPU per pod |
| Cluster | kind (3-node: 1 control-plane + 2 workers) |

---

## Why kind Instead of Minikube?

We initially tried Minikube, but ArgoCD's `repo-server` kept crashing (CrashLoopBackOff) because it couldn't reach GitHub to clone the repo. We switched to kind and everything worked immediately.

**Root Cause: DNS Resolution**

| | Minikube | kind |
|---|---|---|
| **Architecture** | Runs inside a VM (box inside a box) | Containers directly on host network |
| **DNS path** | Pod → CoreDNS → VM resolver → ??? | Pod → CoreDNS → container runtime → host DNS |
| **External DNS (github.com)** | Often broken on macOS (stale VM resolver) | Works (inherits host's internet directly) |
| **macOS + Podman** | Extra isolation layer breaks DNS | Flat network, DNS flows through |

**Simple analogy:** Minikube is like making a phone call through two walls — the signal gets lost. kind is like making the call in the same room — clear connection.

**What happened:** ArgoCD `repo-server` needs to clone your GitHub repo. Inside Minikube's VM, DNS couldn't resolve `github.com`, so the clone failed repeatedly. kind nodes are just containers on the same network as your laptop, so DNS works out of the box.

> **Tip:** If you must use Minikube, you can fix DNS with: `minikube ssh -- "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"` — but kind is the better choice for local K8s on macOS.

---

## Two CI/CD Approaches

| | Approach 1 (Current) | Approach 2 (Production) |
|---|---|---|
| **Name** | Pipeline-Driven Manifest Update | ArgoCD Image Updater + Cosign |
| **Pipeline Jobs** | 4 jobs (Build → Docker → Update Manifest → Notify) | 2 jobs (Build → Docker+Sign) |
| **Who updates K8s manifest?** | GitHub Actions Job 3 (sed + git push) | ArgoCD Image Updater (auto-detects new tag) |
| **Image Security** | Trivy scan only | Trivy scan + **Cosign signing** + **Kyverno verification** |
| **Git Token needed?** | Yes (GIT_TOKEN to push manifest) | No (no git write access needed) |
| **Infinite loop risk?** | Yes (needs `paths-ignore` workaround) | No (pipeline never touches manifests) |
| **Best for** | Learning, demos, simple setups | Production, client environments, enterprise |

---

## Approach 1: Pipeline-Driven Manifest Update (Current Demo)

### Architecture - Approach 1

```
┌───────────────────────────────────────────────────────────┐
│                    GITHUB REPOSITORY                      │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │Source Code │  │  Dockerfile  │  │ K8s Manifests│       │
│  │ (Java 17)  │  │ Multi-stage  │  │   (GitOps)   │       │
│  └────────────┘  └──────────────┘  └──────────────┘       │
└───────────────────────────────────────────────────────────┘
                          │
                          │ git push (triggers)
                          ▼
┌───────────────────────────────────────────────────────────┐
│            GITHUB ACTIONS (4-JOB PIPELINE)                │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Job 1:   │─▶│ Job 2:   │─▶│ Job 3:   │─▶│ Job 4:   │   │
│  │Build/Test│  │Docker    │  │Update    │  │ Notify   │   │
│  │ Maven    │  │Build+Push│  │Manifest  │  │          │   │
│  └──────────┘  └─────┬────┘  └─────┬────┘  └──────────┘   │
│                      │             │                      │
│                      ▼             ▼                      │
│               Push Image    git push deployment.yaml      │
└───────────────────────────────────────────────────────────┘
                      │              │
                      ▼              ▼
             ┌──────────────┐  ┌──────────────────┐
             │  DOCKER HUB  │  │  Git Repo         │
             │  (image tag) │  │  (updated manifest)│
             └──────────────┘  └────────┬───────────┘
                                        │
                                        ▼
                               ┌─────────────────┐
                               │    ArgoCD       │
                               │ Polls Git (3min)│
                               │ Detects change  │
                               │ Syncs to K8s    │
                               └────────┬────────┘
                                        │
                                        ▼
┌───────────────────────────────────────────────────────────┐
│       KUBERNETES CLUSTER (kind - 3 Node)                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │  Pod 1   │   │  Pod 2   │   │  Pod 3   │               │
│  │ Running ✓│   │ Running ✓│   │ Running ✓│               │
│  └──────────┘   └──────────┘   └──────────┘               │
│              ┌────────────────────┐                       │
│              │ Service (ClusterIP)│                       │
│              │  Port: 80 → 8080  │                        │ 
│              └────────────────────┘                       │
└───────────────────────────────────────────────────────────┘
```

### Pipeline Jobs (Approach 1)

**Job 1: Build & Test** — Maven clean test → Build JAR → Upload artifact  
**Job 2: Docker Build & Push** — Multi-stage build → Tag `main-<sha>` → Push to Docker Hub → Trivy scan  
**Job 3: Update Manifest** — `sed` updates image tag in deployment.yaml → git push back to repo  
**Job 4: Notify** — Report status via GitHub Script API  

**Key config:** `paths-ignore: k8s/deployment.yaml` prevents Job 3's git push from re-triggering the pipeline.

### Prerequisites (Approach 1)

```bash
# Tools required
brew install kind kubectl podman

# Cluster setup (no cloud access needed — using kind locally)
export KIND_EXPERIMENTAL_PROVIDER=podman
kind create cluster --config kind-cluster-config.yaml
# Creates: 3-node cluster (1 control-plane + 2 workers)

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Deploy ArgoCD Application
kubectl apply -f k8s/argocd-application.yaml

# Get ArgoCD admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### GitHub Secrets Required (Approach 1)

```
GitHub → Repository → Settings → Secrets → Actions:

  DOCKER_USERNAME  = pranathinallamilli
  DOCKER_PASSWORD  = <Docker Hub access token>
  GIT_TOKEN        = <GitHub PAT with repo write access>
```

### Fully Automated GitOps Deployment (Verified Working)

**Setup:**
- kind cluster (3-node: 1 control-plane + 2 workers) via Podman
- ArgoCD installed with all pods healthy (including repo-server)
- ArgoCD Application configured with automated sync policy
- GitHub polling every 3 minutes (default)

**Verified Automation Flow:**
1. Developer pushes code to GitHub
2. GitHub Actions (automatic):
   - Job 1: Build & Test (Maven)
   - Job 2: Build & Push Docker Image (Docker Hub)
   - Job 3: Update k8s/deployment.yaml with new image tag (short SHA)
   - Job 4: Notify deployment status
3. ArgoCD (automatic within 3 minutes):
   - Polls GitHub, detects manifest change
   - Auto-syncs to Kubernetes
   - Rolling update: new pods created, old pods terminated
4. Application serves new code ✅

**Proven Test Results:**
- Changed message in `DemoApplication.java` → Pushed to GitHub → GitHub Actions ran 4 jobs → ArgoCD detected deployment.yaml change in GitHub → ArgoCD auto-synced → Kubernetes rolled out new pods → `curl http://localhost:8081/` returned new message
- **Zero manual intervention after git push!**

**ArgoCD Configuration (argocd-application.yaml):**
```yaml
syncPolicy:
  automated:
    prune: true       # Delete removed resources
    selfHeal: true    # Auto-correct manual changes
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

### Access the Application
```bash
# App
kubectl port-forward -n default service/java-demo-app 8081:80
curl http://localhost:8081/

# ArgoCD UI
kubectl port-forward -n argocd service/argocd-server 8443:443
# https://localhost:8443 (admin / <password>)
```

### Approach 1 Limitations

| Limitation | Impact |
|---|---|
| GIT_TOKEN required | Extra secret to manage, security risk if leaked |
| Infinite loop risk | Needs `paths-ignore` workaround; fragile |
| Pipeline writes to Git | Violates GitOps principle (CI shouldn't modify source of truth) |
| No image signing | Can't verify who built the image |
| No admission control | K8s accepts ANY image, even malicious ones |
| Tight coupling | Pipeline must know manifest structure and path |

---

## Approach 2: ArgoCD Image Updater + Cosign (Production & Client Environments)

### Architecture - Approach 2

```
┌───────────────────────────────────────────────────────────┐
│                    GITHUB REPOSITORY                      │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │Source Code │  │  Dockerfile  │  │ K8s Manifests│       │
│  │ (Java 17)  │  │ Multi-stage  │  │   (GitOps)   │       │
│  └────────────┘  └──────────────┘  └──────────────┘       │
└───────────────────────────────────────────────────────────┘
                          │
                          │ git push (triggers)
                          ▼
┌───────────────────────────────────────────────────────────┐
│          GITHUB ACTIONS (2-JOB PIPELINE)                  │
│                                                           │
│  ┌──────────┐   ┌─────────────────────────┐               │
│  │ Job 1:   │──▶│ Job 2:                  │               │
│  │Build/Test│   │ Docker Build + Push     │               │
│  │ Maven    │   │ + Trivy Scan            │               │
│  └──────────┘   │ + Cosign Sign ✅        │               │
│                 └────────────┬────────────┘               │
│                              │                            │
│                      Push Image + Signature               │
└──────────────────────┬────────────────────────────────────┘
                       │
                       ▼
              ┌──────────────────┐
              │   DOCKER HUB     │
              │  image:main-sha  │
              │  + Cosign sig    │
              └────────┬─────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
┌──────────────────┐     ┌──────────────────────┐
│ ArgoCD Image     │     │      ArgoCD          │
│ Updater          │     │   (GitOps sync)      │
│ - Watches Docker │     │   - Monitors Git     │
│   Hub for new    │     │   - Syncs manifests  │
│   tags           │     │   - Self-heals       │
│ - Updates image  │     └──────────┬───────────┘
│   annotation     │                │
└────────┬─────────┘                │
         │                          │
         └──────────┬───────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────────────┐
│  KUBERNETES CLUSTER (kind local / EKS/AKS/GKE in prod)    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐      │
│  │  Kyverno (Admission Controller)                 │      │
│  │  "Is this image signed by our Cosign key?" 🔐   │      │
│  │     YES → Allow pod to run ✅                   │      │
│  │     NO  → REJECT pod! Block deployment ❌       │      │
│  └─────────────────────────────────────────────────┘      │
│                                                           │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │  Pod 1   │   │  Pod 2   │   │  Pod 3   │               │
│  │ Verified✓│   │ Verified✓│   │ Verified✓│               │
│  └──────────┘   └──────────┘   └──────────┘               │ 
│              ┌────────────────────┐                       │
│              │ Service (LoadBalancer)│                    │
│              │  Public URL        │                       │
│              └────────────────────┘                       │
└───────────────────────────────────────────────────────────┘
```

### How Cosign + Kyverno Eliminate Malicious Images

**The Problem:** Without signing, if an attacker gains Docker Hub access, they can push a malicious image with a legitimate-looking tag. ArgoCD or Image Updater will deploy it — no questions asked.

**How Cosign Solves It:**
```
Cosign = Digital Signature for Docker Images

Your CI pipeline has a PRIVATE KEY (kept in GitHub Secrets).
After building the image, the pipeline SIGNS it with this key.
The signature is stored alongside the image in Docker Hub.

Even if an attacker pushes a fake image to Docker Hub,
they CAN'T sign it — they don't have the private key.
```

**How Kyverno Solves It:**
```
Kyverno = Security Guard at the Kubernetes Door

Before ANY pod starts in your cluster, Kyverno checks:
  "Is this image signed by our trusted Cosign key?"

  ✅ Signed by our key   →  Allow deployment
  ❌ Not signed / wrong key  →  REJECT! Pod blocked from running.

Result: Even if Docker Hub is compromised, unsigned images
        can NEVER run in your cluster.
```

**Attack Scenario Comparison:**

| Attack | Without Cosign+Kyverno | With Cosign+Kyverno |
|--------|----------------------|---------------------|
| Attacker pushes malicious image to Docker Hub | ❌ Deployed to production | ✅ Blocked by Kyverno (no signature) |
| Attacker replaces `latest` tag | ❌ Deployed on next sync | ✅ Blocked (signature mismatch) |
| Compromised CI pipeline in another repo | ❌ Could deploy bad images | ✅ Blocked (wrong signing key) |
| Supply chain attack on base image | ❌ Silently deployed | ✅ Blocked (final image unsigned) |

### Why Approach 2 is Better for Production

| Benefit | Explanation |
|---|---|
| **No GIT_TOKEN needed** | Pipeline doesn't write to Git; eliminates a security secret |
| **No infinite loop risk** | Pipeline never modifies manifests; no `paths-ignore` needed |
| **Separation of concerns** | CI builds images, ArgoCD handles deployment entirely |
| **Image verification** | Cosign ensures only YOUR pipeline's images can be deployed |
| **Admission control** | Kyverno blocks all unsigned/untrusted images at the K8s API level |
| **Simpler pipeline** | 2 jobs instead of 4; less code to maintain |
| **Faster pipeline** | No Job 3 (manifest update) or Job 4 (notify); saves ~30 seconds |
| **Audit trail** | Image Updater writes Git commits with image change details |

### Where Do Git Credentials Live?

Both approaches need a Git token to update manifests — but the token lives in **different places**:

| | Token stored in | Who controls it | Risk if compromised |
|---|---|---|---|
| **Approach 1** | GitHub Actions Secrets (cloud) | GitHub (3rd party) | Attacker can modify your repo from CI |
| **Approach 2** | Kubernetes Secret (your cluster) | You | Token stays inside your infrastructure |

**How it works in Approach 2:**
- ArgoCD Image Updater runs **inside your K8s cluster** (argocd namespace)
- It reuses **ArgoCD's existing repo credentials** (already stored as K8s Secrets)
- GitHub Actions pipeline is **read-only** (`contents: read`) — no GIT_TOKEN needed
- To enable write-back, add repo credentials to ArgoCD:

```bash
# ArgoCD stores this in a Kubernetes Secret — inside YOUR cluster, not GitHub
argocd repo add https://github.com/pranathi-nallamilli/CRD-POC.git \
  --username pranathi-nallamilli \
  --password <GitHub-PAT>
```

**Result:** The Git write credential never leaves your cluster boundary.

### Prerequisites (Approach 2 — using kind, no cloud access needed)

```bash
# Tools required
brew install kind kubectl podman cosign

# Cluster setup (same kind cluster — works for both approaches)
export KIND_EXPERIMENTAL_PROVIDER=podman
kind create cluster --config kind-cluster-config.yaml
# Creates: 3-node cluster (1 control-plane + 2 workers)

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Install ArgoCD Image Updater (v0.14.0 — 'stable' URL returns 404)
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v0.14.0/manifests/install.yaml

# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.0/install.yaml

# Add repo credentials to ArgoCD (needed for Image Updater git write-back)
kubectl create secret generic repo-crd-poc -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/pranathi-nallamilli/CRD-POC.git \
  --from-literal=username=pranathi-nallamilli \
  --from-literal=password=<GitHub-PAT>
kubectl label secret repo-crd-poc -n argocd argocd.argoproj.io/secret-type=repository

# Deploy ArgoCD Application (with Image Updater annotations)
kubectl apply -f k8s/platform/argocd-application-v2.yaml

# Apply Kyverno signature verification policy
kubectl apply -f k8s/platform/kyverno-verify-images.yaml
```

> **Note:** We use kind locally since we don't have cloud access. In production, replace kind with EKS/AKS/GKE. The setup steps for ArgoCD, Image Updater, Cosign, and Kyverno remain the same.

### Important: Kustomize Required for Image Updater

ArgoCD Image Updater **only works with Kustomize or Helm** apps — it skips plain "Directory" type apps. We added `k8s/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
images:
  - name: docker.io/pranathinallamilli/java-demo-app
    newTag: main-123a8b4
```

Image Updater creates a `.argocd-source-java-demo-app.yaml` file in the `k8s/` directory to override the image tag:
```yaml
# Auto-generated by ArgoCD Image Updater
kustomize:
  images:
  - docker.io/pranathinallamilli/java-demo-app:main-577ac0f
```

### Fully Automated Deployment — Approach 2 (Verified Working)

**Verified end-to-end on kind cluster:**
1. `git push` → GitHub Actions ran **2 jobs** (Build+Test → Docker+Sign)
2. Cosign signed image `main-577ac0f` — verified with `cosign verify`
3. Image Updater detected new tag on Docker Hub → committed `.argocd-source-java-demo-app.yaml` to Git
4. ArgoCD synced → Kubernetes deployed 3 pods with signed image
5. Kyverno **BLOCKED** unsigned image `main-26ef708` → `"no signatures found"`
6. Kyverno **ALLOWED** signed image `main-577ac0f` → pod runs ✅
7. `curl http://localhost:8083/` → returned app response
8. **Zero manual intervention after git push!**

---

## Setup Guide: Approach 2 (Step-by-Step)

### Step 1: Generate Cosign Key Pair

```bash
# Install Cosign
brew install cosign

# Generate key pair (save the password securely!)
cosign generate-key-pair

# This creates:
#   cosign.key  (PRIVATE - keep secret, add to GitHub Secrets)
#   cosign.pub  (PUBLIC  - store in K8s cluster for Kyverno)
```

### Step 2: Add Secrets to GitHub

```
GitHub → Repository → Settings → Secrets → Actions:

  COSIGN_PRIVATE_KEY  = <contents of cosign.key>
  COSIGN_PASSWORD     = <password you set during keygen>
  DOCKER_USERNAME     = pranathinallamilli
  DOCKER_PASSWORD     = <Docker Hub access token>
```

### Step 3: Updated GitHub Actions Pipeline (2 Jobs Only)

```yaml
# .github/workflows/ci-cd-signed.yml (Approach 2 - Production)
# Old ci-cd.yml is disabled (branch changed to 'disabled-old-approach')
name: Java CI/CD Pipeline (Signed Images)

on:
  push:
    branches: [ main ]
    # NOTE: No paths-ignore needed! Pipeline never touches manifests.
  pull_request:
    branches: [ main ]

permissions:
  contents: read    # Read only! No write access needed.
  id-token: write   # For Cosign OIDC (optional keyless mode)

env:
  DOCKER_IMAGE: ${{ secrets.DOCKER_USERNAME }}/java-demo-app

jobs:
  # Job 1: Build and Test (same as before)
  build-and-test:
    name: Build and Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven
      - run: mvn clean test
      - run: mvn clean package -DskipTests
      - uses: actions/upload-artifact@v4
        with:
          name: app-jar
          path: target/*.jar

  # Job 2: Build, Push, Scan, and SIGN
  docker-build-sign:
    name: Build, Push & Sign Docker Image
    needs: build-and-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Generate image tags
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_IMAGE }}
          tags: |
            type=sha,prefix=main-
            type=raw,value=latest

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ${{ steps.meta.outputs.tags }}

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.DOCKER_IMAGE }}:latest
          format: table
          exit-code: '1'          # FAIL pipeline if CRITICAL/HIGH CVEs found
          severity: CRITICAL,HIGH

      # === COSIGN SIGNING (the key addition) ===
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image with Cosign
        env:
          COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
        run: |
          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
          IMAGE="${{ env.DOCKER_IMAGE }}:main-${SHORT_SHA}"
          
          # Sign the image (--yes skips confirmation prompt)
          cosign sign --key env://COSIGN_PRIVATE_KEY --yes "${IMAGE}"
          
          # Also sign latest tag
          cosign sign --key env://COSIGN_PRIVATE_KEY --yes \
            "${{ env.DOCKER_IMAGE }}:latest"
          
          echo "✅ Image signed: ${IMAGE}"

      # NO Job 3! No manifest update needed.
      # NO Job 4! ArgoCD Image Updater handles deployment.
```

### Step 4: Install ArgoCD Image Updater

```bash
# Install Image Updater (use specific version — 'stable' URL returns 404)
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v0.14.0/manifests/install.yaml

# Verify it's running
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# Add repo credentials for git write-back
kubectl create secret generic repo-crd-poc -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/pranathi-nallamilli/CRD-POC.git \
  --from-literal=username=pranathi-nallamilli \
  --from-literal=password=<GitHub-PAT>
kubectl label secret repo-crd-poc -n argocd argocd.argoproj.io/secret-type=repository
```

### Step 5: Configure ArgoCD Application with Image Updater Annotations

```yaml
# k8s/argocd-application.yaml (updated for Image Updater)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: java-demo-app
  namespace: argocd
  annotations:
    # Tell Image Updater to watch this image
    argocd-image-updater.argoproj.io/image-list: app=docker.io/pranathinallamilli/java-demo-app
    # Only use tags matching main-* pattern
    argocd-image-updater.argoproj.io/app.update-strategy: newest-build
    argocd-image-updater.argoproj.io/app.allow-tags: regexp:^main-[a-f0-9]{7}$
    # Write changes back to Git (optional but recommended)
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  project: default
  source:
    repoURL: https://github.com/pranathi-nallamilli/CRD-POC.git
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Step 6: Install & Configure Kyverno (Admission Controller)

```bash
# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.0/install.yaml

# Verify
kubectl get pods -n kyverno
```

```yaml
# k8s/kyverno-verify-images.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-cosign-signatures
spec:
  validationFailureAction: Enforce    # REJECT unsigned images
  background: false
  rules:
    - name: verify-image-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "docker.io/pranathinallamilli/java-demo-app:*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |
                      -----BEGIN PUBLIC KEY-----
                      <paste contents of cosign.pub here>
                      -----END PUBLIC KEY-----
```

```bash
# Apply the policy
kubectl apply -f k8s/kyverno-verify-images.yaml

# Test: unsigned image will be REJECTED
kubectl run test --image=pranathinallamilli/java-demo-app:latest
# Error: image verification failed: signature not found
```

### Step 7: Verify Everything Works

```bash
# 1. Push a code change
git add . && git commit -m "test signed pipeline" && git push

# 2. Watch GitHub Actions (only 2 jobs now)
#    Job 1: Build & Test
#    Job 2: Build, Push & Sign

# 3. Check signature was stored
cosign verify --key cosign.pub pranathinallamilli/java-demo-app:main-<sha>

# 4. ArgoCD Image Updater detects new tag (within 2 minutes)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=20

# 5. ArgoCD syncs the new image to Kubernetes
kubectl get application java-demo-app -n argocd

# 6. Kyverno verified the signature before allowing pods
kubectl get events --field-selector reason=PolicyApplied

# 7. Verify the app
curl http://localhost:8081/
```

---

## Security Architecture: 5 Layers of Protection

| Layer | Tool | What It Does | When |
|-------|------|-------------|------|
| 1. Build | Trivy | Scans image for CVEs — **fails pipeline** if CRITICAL/HIGH found (exit-code: 1). Image stays unsigned → Kyverno blocks it. | During CI pipeline |
| 2. Sign | Cosign | Creates cryptographic signature for image | After Docker push |
| 3. Registry | Docker Hub IAM | Controls who can push/pull images | Always |
| 4. Verify | Kyverno | Rejects unsigned images at K8s API level | Before pod creation |
| 5. Runtime | ArgoCD self-heal | Reverts manual changes to desired state | Continuous |

**Result:** Even if Docker Hub is fully compromised, unsigned images cannot run in your cluster.

---

## Deployment Architecture - 3 Pods

### Why 3 Replicas?
- **High Availability:** 1 pod crash → 2 still serve traffic
- **Zero Downtime:** Rolling updates replace pods one at a time
- **Load Distribution:** Round-robin across all pods

### Rolling Update Strategy
```
maxUnavailable: 1, maxSurge: 1
→ Always at least 2 pods serving during updates
```

---

## Pipeline & Cost Comparison

| Metric | Approach 1 | Approach 2 |
|--------|-----------|-----------|
| Pipeline jobs | 4 | 2 |
| Pipeline time | ~4-5 min | ~3-4 min |
| GitHub Secrets required | 3 (DOCKER_USER, DOCKER_PASS, GIT_TOKEN) | 4 (DOCKER_USER, DOCKER_PASS, COSIGN_KEY, COSIGN_PASS) |
| Git write access | Yes (risky) | No |
| Image signing | No | Yes (Cosign) |
| Admission control | No | Yes (Kyverno) |
| GitHub Actions cost | $0 (free tier) | $0 (free tier) |
| Docker Hub cost | $0 (public) | $0 (public) |
| K8s cluster (local) | $0 (kind) | $0 (kind) |
| K8s cluster (prod) | ~$73/mo (EKS/AKS) | ~$73/mo (EKS/AKS) |
| Extra tools cost | $0 | $0 (Cosign, Kyverno, Image Updater are free) |

---

### Cleanup
```bash
kind delete cluster --name java-demo-cluster
```

---

## Cloud/Production: One-Time Setup Per Cluster

All the setup we did for kind (ArgoCD, Image Updater, Kyverno, Cosign, repo credentials) is **one-time per cluster**. Same steps apply to EKS/AKS/GKE.

| Step | Frequency | How in Production |
|------|-----------|-------------------|
| Generate Cosign key pair | **Once ever** (same keys for all clusters) | Store in Vault/Secret Manager |
| GitHub Secrets (COSIGN_KEY, DOCKER creds) | **Once per repo** | Already done |
| Install ArgoCD | Once per cluster | `helm install argocd argo/argo-cd -n argocd` |
| Install Image Updater | Once per cluster | `helm install image-updater argocd-image-updater/argocd-image-updater -n argocd` |
| Install Kyverno | Once per cluster | `helm install kyverno kyverno/kyverno -n kyverno` |
| ArgoCD repo credentials | Once per cluster | K8s Secret (automated via IaC/Terraform) |
| Kyverno signing policy | Once per cluster | Applied via GitOps (ArgoCD syncs it) |
| ArgoCD Application YAML | Once per app | Applied via GitOps |

**In production**, you'd use Helm charts instead of raw YAML manifests for installing ArgoCD, Image Updater, and Kyverno:

```bash
# One-time cluster bootstrap (Helm — production standard)
helm install argocd argo/argo-cd -n argocd --create-namespace
helm install image-updater argocd-image-updater/argocd-image-updater -n argocd
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl apply -f k8s/platform/   # policies + app configs
```

**After that, every new deployment is just a `git push`** — the pipeline builds, signs, and Image Updater + ArgoCD handle the rest. You never touch the cluster manually again.

---

## Summary

| | Approach 1 (Demo) | Approach 2 (Production) |
|---|---|---|
| Pipeline | 4 jobs, writes to Git | 2 jobs, read-only |
| Security | Trivy scan | Trivy + Cosign + Kyverno |
| Deployment | Pipeline pushes manifest | Image Updater auto-detects |
| Complexity | More pipeline code | More K8s components |
| **Recommendation** | Learning & demos | Production & client environments |

**Both approaches achieve the same goal: code push → automatic deployment.**  
Approach 2 adds **image signing**, **admission control**, and **cleaner separation of concerns** — making it the right choice for production and client-facing environments where security and auditability matter.

---

## Resources

- Repository: https://github.com/pranathi-nallamilli/CRD-POC
- Docker Hub: https://hub.docker.com/r/pranathinallamilli/java-demo-app
- Workflow Runs: https://github.com/pranathi-nallamilli/CRD-POC/actions

---

**End of Presentation**

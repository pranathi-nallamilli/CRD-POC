# GitHub Actions CI/CD Pipeline Demo
## Java Spring Boot Application with GitOps

**Repository:** https://github.com/pranathi-nallamilli/CRD-POC  
**Docker Hub:** https://hub.docker.com/r/pranathinallamilli/java-demo-app

---

## Project Setup

### Prerequisites Configured

**1. GitHub Repository**
- Repository: https://github.com/pranathi-nallamilli/CRD-POC
- Branch: `main` (protected)
- Workflow file: `.github/workflows/ci-cd.yml`

**2. Docker Hub Account**
- Account: `pranathinallamilli`
- Repository: `java-demo-app` (public)
- Access Token: Created for GitHub Actions authentication

**3. GitHub Secrets (Security)**
- `DOCKER_USERNAME`: Docker Hub username
- `DOCKER_PASSWORD`: Docker Hub access token (not account password)
- `GIT_TOKEN`: GitHub Personal Access Token for manifest updates

**4. Local Environment**
- Java 17 (Temurin distribution)
- Maven 3.9+
- **kind** (Kubernetes IN Docker) - 3-node cluster via Podman
- kubectl CLI
- ArgoCD installed and fully syncing with GitHub

---

## Application Overview

### Java Spring Boot REST API

**Technology Stack:**
- Java: 17
- Framework: Spring Boot 3.2.0
- Build Tool: Maven
- Packaging: JAR (executable)

**Endpoints:**
- `GET /` → Welcome message with timestamp
- `GET /health` → Application health status
- `GET /info` → Application metadata

**Deployment Configuration:**
- Replicas: 3 pods (high availability)
- Resources: 256Mi-512Mi memory, 250m-500m CPU per pod
- Health Probes: Liveness and Readiness checks
- Namespace: `default`
- Cluster: kind (3-node: 1 control-plane + 2 workers)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    GITHUB REPOSITORY                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Source Code  │  │  Dockerfile  │  │ K8s Manifests│      │
│  │  (Java 17)   │  │  Multi-stage │  │  (GitOps)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────────────────────────────────────────────┘
                           │
                           │ git push (triggers)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              GITHUB ACTIONS CI/CD PIPELINE                   │
│                                                               │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐          │
│  │  Job 1:    │──▶│  Job 2:    │──▶│  Job 3:    │          │
│  │ Build/Test │   │Build/Push  │   │Update K8s  │          │
│  │  Maven     │   │   Docker   │   │ Manifests  │          │
│  └────────────┘   └────────────┘   └────────────┘          │
│                           │                                   │
│                           │ Push Image                        │
│                           ▼                                   │
│                  ┌──────────────┐                            │
│                  │  DOCKER HUB  │                            │
│                  │ Multi-arch   │                            │
│                  │ AMD64/ARM64  │                            │
│                  └──────────────┘                            │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Pull Image
                           ▼
┌─────────────────────────────────────────────────────────────┐
│       KUBERNETES CLUSTER (kind - 3 Node Local Cluster)      │
│                                                               │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │  Pod 1       │   │  Pod 2       │   │  Pod 3       │    │
│  │ java-demo    │   │ java-demo    │   │ java-demo    │    │
│  │  Running ✓   │   │  Running ✓   │   │  Running ✓   │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│                                                               │
│               ┌────────────────────┐                         │
│               │  Service (ClusterIP)│                        │
│               │  Port: 80 → 8080   │                         │
│               └────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

---

## CI/CD Pipeline - 4 Automated Jobs

### Job 1: Build and Test
**Tool:** Maven 3.9 with Java 17  
**Actions:**
- Checkout source code from GitHub
- Setup JDK 17 (Temurin distribution) with Maven cache
- Run unit tests (`mvn clean test`)
- Build executable JAR (`mvn clean package`)
- Upload JAR artifact (retained for 7 days)

**Result:** If any test fails, pipeline stops immediately

---

### Job 2: Build and Push Docker Image
**Tool:** Docker Buildx with multi-platform support  
**Actions:**
- Build multi-stage Dockerfile (builder → runtime)
- Create two image tags:
  - `latest` (convenience tag)
  -`main-<sha>` (immutable, traceable to Git commit)
- Build for multiple architectures: `linux/amd64`, `linux/arm64`
- Push images to Docker Hub
- Scan image with Trivy for security vulnerabilities

**Key Features:**
- Multi-stage build (reduces final image size by ~70%)
- Multi-architecture support (AMD64 + ARM64)
- SHA-based tagging for traceability
- Security scanning before deployment

---

### Job 3: Update Kubernetes Manifests (GitOps)
**Tool:** Git with sed for manifest updates  
**Actions:**
- Checkout repository with write access (GitHub Personal Access Token)
- Update `k8s/deployment.yaml` with new SHA-tagged image
- Commit changes as "GitHub Actions Bot"
- Push updated manifest back to repository
- Create commit comment with deployment info

**GitOps Benefits:**
- Full audit trail of all deployments
- Git as single source of truth
- Easy rollbacks (revert Git commit)
- Prevents infinite loops with `paths-ignore` configuration

---

### Job 4: Notify Deployment Status  
**Tool:** GitHub Script API  
**Actions:**
- Check status of all previous jobs
- Create deployment notice in GitHub Actions UI
- Report pipeline completion

**Extensible:** Can be configured to send notifications to Slack, Teams, or other systems

---

## Tools and Technologies Used

### Development & Build
- **Java 17** (Temurin distribution)
- **Spring Boot 3.2.0** (Web framework)
- **Maven 3.9+** (Build tool and dependency management)

### Containerization
- **Docker** (Container runtime)
- **Docker Buildx** (Multi-platform builds)
- **Multi-stage Dockerfile** (Optimized image size)

### CI/CD Platform
- **GitHub Actions** (Workflow automation)
- **GitHub Secrets** (Secure credential management)
- **Docker Hub** (Container registry)

### Security
- **Trivy** (Vulnerability scanner)
- **GitHub Personal Access Token** (Authentication)
- **Docker Hub Access Token** (Non-password authentication)

### Kubernetes & GitOps
- **kind** (Kubernetes IN Docker - 3-node local cluster via Podman)
- **kubectl** (Kubernetes CLI)
- **ArgoCD** (GitOps continuous delivery - fully syncing with GitHub)
- **Podman** (Container runtime for kind)

---

## Security Best Practices Implemented

### Secrets Management
✅ GitHub Secrets for all credentials (Docker Hub, Git tokens)  
✅ Access tokens used instead of passwords  
✅ Secrets never exposed in logs or commit history  

### Container Security
✅ Multi-stage builds (minimal runtime dependencies)  
✅ JRE-only final image (no build tools in production)  
✅ Trivy vulnerability scanning on every build  
✅ Scan for CRITICAL and HIGH severity issues  

### Access Control
✅ GitHub workflow permissions explicitly defined  
✅ Minimal required permissions (contents: write, pull-requests: write)  
✅ Personal Access Tokens with limited scope  

### Kubernetes Security
✅ Resource limits prevent resource exhaustion  
✅ Health probes ensure pod health  
✅ Non-root container user (configured in Dockerfile)  
✅ Namespace isolation (`java-app` namespace)  

---

## Fully Automated GitOps Deployment (Verified Working)

### ArgoCD Auto-Sync: Active and Working ✅

**Setup:**
- **kind** cluster (3-node: 1 control-plane + 2 workers) via Podman
- ArgoCD installed with all pods healthy (including repo-server)
- ArgoCD Application configured with automated sync policy
- GitHub polling every 3 minutes (default)

**Verified Automation Flow:**

```
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
```

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

**Proven Test Results:**
- Changed message in DemoApplication.java
- Pushed to GitHub → GitHub Actions ran 4 jobs
- ArgoCD detected deployment.yaml change in GitHub
- ArgoCD auto-synced → Kubernetes rolled out new pods
- `curl http://localhost:8081/` returned new message
- **Zero manual intervention after git push!**

### Why kind Instead of Minikube

| Feature | Minikube (Previous) | kind (Current) |
|---------|--------------------|-----------------|
| ArgoCD repo-server | ❌ CrashLoopBackOff | ✅ Running |
| ArgoCD Sync Status | ❌ Unknown (DNS timeout) | ✅ Synced + Healthy |
| GitHub Connectivity | ❌ DNS resolution failed | ✅ Working |
| Nodes | 1 (single node) | 3 (production-like) |
| Pod Distribution | All on 1 node | Spread across workers |
| Resource Isolation | VM overhead | Container-based (lighter) |
| Startup Time | ~3-5 minutes | ~2 minutes |

**kind Cluster Configuration:**
```yaml
nodes:
  - role: control-plane  # Runs API server, scheduler, etcd
  - role: worker         # Runs application pods
  - role: worker         # Runs application pods
```

---

## Deployment Architecture - 3 Pods Explained

### Why 3 Replicas?

**High Availability:**
- If 1 pod crashes → 2 still serve traffic
- Zero downtime during rolling updates
- Tolerates node failures

**Load Distribution:**
- Kubernetes Service distributes traffic round-robin across all 3 pods
- Each pod can handle requests independently
- No shared state (stateless application)

**Rolling Updates:**
```
Strategy: RollingUpdate
maxUnavailable: 1
maxSurge: 1
```

Update process:
1. Start new Pod-1 → Wait for ready → Kill old Pod-1
2. Start new Pod-2 → Wait for ready → Kill old Pod-2  
3. Start new Pod-3 → Wait for ready → Kill old Pod-3

Result: _Always at least 2 pods serving traffic during updates_

### Pod Independence
- Each pod runs the same application code
- No communication between pods
- Kubernetes Service provides single entry point
- All 3 respond to same requests identically

---

## Cost and Performance Metrics

### Pipeline Efficiency
| Metric | Value |
|--------|-------|
| Total pipeline time | 4-5 minutes |
| Build + Test | ~1.5 minutes |
| Docker build & push | ~2.5 minutes |
| Manifest update | ~15 seconds |
| Notification | ~8 seconds |

### Container Optimization
| Metric | Value |
|--------|-------|
| Builder stage | ~650 MB |
| Final image | ~200 MB |
| Size reduction | ~70% |
| Architectures | 2 (AMD64, ARM64) |

### Deployment Configuration
| Component | Configuration |
|-----------|---------------|
| Replicas | 3 pods |
| Memory per pod | 256Mi request, 512Mi limit |
| CPU per pod | 250m request, 500m limit |
| Health checks | Liveness + Readiness |
| Autoscaling | 2-5 pods (CPU-based) |

### Cost Breakdown
| Service | Current Cost | Production Cost |
|---------|-------------|----------------|
| GitHub Actions | $0 | $0 (free tier) |
| Docker Hub | $0 | $0 (public repo) |
| Minikube/AKS | $0 | ~$73/month |
| Container Registry | N/A | ~$5/month (ACR Basic) |
| **Total** | **$0/month** | **~$78/month** |

---

## Key Demonstration Points

### 1. Full CI Automation
- Every `git push` triggers automated pipeline
- Tests run before build
- Failed tests stop deployment immediately
- No manual intervention required

### 2. Multi-Architecture Support  
- Single workflow builds for Intel (AMD64) and ARM (ARM64)
- Developers with Apple Silicon Macs get native ARM images
- Cloud providers offer cheaper ARM instances (AWS Graviton)
- Docker automatically pulls correct architecture

### 3. GitOps Principles
- Git repository is single source of truth
- All deployments tracked in Git history
- Easy rollbacks (revert Git commit)
- Full audit trail of what was deployed when

### 4. Production-Ready Configuration
- Health probes prevent broken pod deployment
- Resource limits prevent resource starvation
- Horizontal Pod Autoscaler handles traffic spikes
- Security scanning before deployment

### 5. Immutable Tags
- SHA-tagged images never change
- `main-abc123` always refers to exact same image
- Easy to identify which Git commit created which image
- Reliable rollbacks to known-good versions

---

## Local vs Production Comparison

### Current Setup (kind - Local Demo) ✅ FULLY AUTOMATED
| Component | Status | Notes |
|-----------|--------|-------|
| GitHub Actions CI | ✅ Fully Automated | Runs on every push |
| Docker Hub | ✅ Fully Automated | Multi-arch images pushed |
| Kubernetes Manifests | ✅ Fully Automated | Updated by workflow (short SHA tags) |
| ArgoCD Sync | ✅ Fully Automated | Polls GitHub every 3 min, auto-syncs |
| Deployment to K8s | ✅ Fully Automated | ArgoCD applies changes, rolling update |

### Production Setup (AKS/EKS/GKE)
| Component | Status | Notes |
|-----------|--------|-------|
| GitHub Actions CI | ✅ Fully Automated | Same workflow |
| Docker Hub | ✅ Fully Automated | Same configuration |
| Kubernetes Manifests | ✅ Fully Automated | Same workflow |
| ArgoCD | ✅ Fully Automated | Auto-sync + webhook (instant) |
| Deployment to K8s | ✅ Fully Automated | ArgoCD applies changes |
| Load Balancer | ✅ Cloud-managed | AWS ELB / Azure LB (public URL) |

**Local and Production are now identical!** The only difference is cloud provides a public URL via LoadBalancer instead of port-forward.

---

## Summary

This demo showcases a **fully automated** modern CI/CD pipeline with GitOps:

✅ **Automated CI:** Testing, building, scanning, and tagging on every commit  
✅ **Automated CD:** ArgoCD auto-syncs GitHub changes to Kubernetes  
✅ **Containerization:** Multi-stage, multi-architecture Docker images  
✅ **GitOps:** Manifest updates committed to Git, ArgoCD deploys automatically  
✅ **Security:** Trivy vulnerability scanning and secrets management  
✅ **Production-Ready:** Health checks, resource limits, autoscaling  
✅ **Self-Healing:** ArgoCD auto-corrects manual drift within minutes  
✅ **Cost-Effective:** $0 for CI/CD infrastructure (GitHub Actions + Docker Hub)  
✅ **Multi-Node Cluster:** 3-node kind cluster (production-like topology)

**Current State:** End-to-end fully automated (CI + CD + GitOps)  
**Proven:** Code change → git push → GitHub Actions → ArgoCD → Kubernetes → Live (zero manual steps)  
**Next Step:** Deploy to AWS EKS or Azure AKS for cloud LoadBalancer and public URL

---

## How to Run the Demo

### Prerequisites
```bash
brew install kind kubectl
```

### Start the Cluster
```bash
# Create kind cluster (uses Podman)
export KIND_EXPERIMENTAL_PROVIDER=podman
kind create cluster --config kind-cluster-config.yaml

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Deploy ArgoCD Application
kubectl apply -f k8s/argocd-application.yaml

# Get ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### Access Points
```bash
# Application
kubectl port-forward -n default service/java-demo-app 8081:80
curl http://localhost:8081/

# ArgoCD UI
kubectl port-forward -n argocd service/argocd-server 8443:443
# Open: https://localhost:8443 (admin / <password>)
```

### Test Full Automation
```bash
# 1. Change code
sed -i '' 's/old message/new message/' src/main/java/com/example/demo/DemoApplication.java

# 2. Update test to match
# Edit src/test/java/com/example/demo/DemoApplicationTests.java

# 3. Push (triggers everything automatically)
git add src/ && git commit -m "Update message" && git push origin main

# 4. Wait ~7 minutes, then verify
curl http://localhost:8081/  # Shows new message!
```

### Cleanup
```bash
kind delete cluster --name java-demo-cluster
```

---

## Resources

- Repository: https://github.com/pranathi-nallamilli/CRD-POC
- Docker Hub: https://hub.docker.com/r/pranathinallamilli/java-demo-app
- Workflow Runs: https://github.com/pranathi-nallamilli/CRD-POC/actions

---

**End of Presentation**

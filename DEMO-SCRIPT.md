# Live Demo Script — Zero Touch Deployment
## CI/CD with GitOps, Image Signing & Admission Control

**Duration:** ~15 minutes  
**Audience:** Manager / Review Board  
**Goal:** Show that a `git push` triggers a fully automated pipeline → signed image → auto-deploy to Kubernetes — zero manual steps.

---

## Pre-Demo Checklist (Do This Before the Meeting)

```bash
# 1. Ensure kind cluster is running
kubectl get nodes
# Expected: 3 nodes (1 control-plane + 2 workers)

# 2. Verify all platform pods are healthy
kubectl get pods -n argocd         # ArgoCD + Image Updater
kubectl get pods -n kyverno        # Kyverno admission controller
kubectl get pods -n default        # App pods (3 replicas)

# 3. Start port-forwards
kubectl port-forward svc/argocd-server -n argocd 8443:443 &
kubectl port-forward svc/java-demo-app -n default 8083:80 &

# 4. Open these tabs in your browser:
#    Tab 1: ArgoCD UI       → https://localhost:8443 (admin / <password>)
#    Tab 2: GitHub Actions   → https://github.com/pranathi-nallamilli/CRD-POC/actions
#    Tab 3: Docker Hub       → https://hub.docker.com/r/pranathinallamilli/java-demo-app/tags

# 5. Verify current app works
curl -s http://localhost:8083/ | python3 -m json.tool
```

---

## Part 1: Set the Stage (2 min)

### What to SAY:

> "I'm going to show you a fully automated CI/CD pipeline with GitOps. The only thing a developer does is push code. Everything else — building, testing, Docker image creation, security scanning, image signing, deployment, and verification — happens automatically. Zero manual steps."

### What to SHOW:

**Terminal — current running app:**
```bash
curl -s http://localhost:8083/ | python3 -m json.tool
```
> "Here's our Spring Boot API running in Kubernetes with 3 replicas. Note the current version."

**ArgoCD UI (Tab 1):**
> "This is ArgoCD — our GitOps controller. It monitors our Git repo and automatically syncs any changes to the cluster. The app is currently Synced and Healthy."
>
> Point at: green Synced badge, Healthy status, 3 pods in the tree view.

**Quick architecture overview:**
> "Here's the flow:
> 1. Developer pushes code → GitHub Actions builds, tests, pushes Docker image, and **signs** it with Cosign
> 2. ArgoCD Image Updater watches Docker Hub — detects the new image tag automatically
> 3. ArgoCD syncs the change to Kubernetes
> 4. **Kyverno** (our admission controller) checks: is this image signed by our key? Only signed images can run.
> 5. If everything checks out → pods roll out with zero downtime."

---

## Part 2: Make a Code Change (1 min)

### What to SAY:

> "Now I'll make a simple code change and push it. Watch how everything flows automatically."

### What to DO:

Open `src/main/java/com/example/demo/DemoApplication.java` in VS Code.

Change the version message (e.g., v5.0 → v6.0):
```java
return Map.of(
    "message", "Zero Touch Deployment - v6.0!",
    "version", "6.0.0",
    "timestamp", java.time.Instant.now().toString()
);
```

Update the test to match in `src/test/java/com/example/demo/DemoApplicationTests.java`:
```java
assertThat(body).contains("Zero Touch Deployment - v6.0!");
```

Push the change:
```bash
git add src/ && git commit -m "feat: Zero Touch Deployment v6.0" && git push origin main
```

> "Code pushed. From this point on, I don't touch anything. Let's watch the automation."

---

## Part 3: Watch the Pipeline (3-4 min)

### What to SHOW:

**GitHub Actions (Tab 2) — refresh the page:**

> "The push triggered our GitHub Actions pipeline. It has **2 jobs**:"

**Job 1 — Build & Test:**
> "First it builds the Java app with Maven and runs unit tests. If tests fail, the pipeline stops. No image gets built."

**Job 2 — Docker Build, Push, Scan & Sign:**
> "Job 2 builds a multi-architecture Docker image (AMD64 + ARM64), pushes it to Docker Hub, then:
> - **Trivy** scans for CVEs. If it finds CRITICAL or HIGH vulnerabilities, the pipeline fails and the image is **never signed** — which means Kyverno will block it.
> - **Cosign** signs the image with our private key. This signature is stored alongside the image on Docker Hub."

**While waiting, explain the security:**
> "Why does signing matter? If someone gains access to our Docker Hub and pushes a malicious image, it won't have our signature. Kyverno will reject it at the Kubernetes API level — the malicious image can **never** run in our cluster."

**Docker Hub (Tab 3) — refresh after pipeline completes:**
> "Here's Docker Hub. You can see 3 artifacts per build:
> 1. `main-<sha>` — the commit-tagged image (multi-arch: AMD64 + ARM64)
> 2. `latest` — convenience tag pointing to the newest build
> 3. `.sig` — the Cosign signature stored as an OCI artifact"

---

## Part 4: Watch Image Updater + ArgoCD (2-3 min)

### What to SAY:

> "Now the cluster-side automation kicks in. **ArgoCD Image Updater** runs inside our cluster and polls Docker Hub every 2 minutes."

### What to SHOW:

**Terminal — Image Updater logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=5 | grep -E "Setting new|updated|result"
```

> "Image Updater detected the new tag and committed it to Git. It writes to a special `.argocd-source` file — this is the GitOps write-back."

**ArgoCD UI (Tab 1) — watch for sync:**
> "ArgoCD detects the Git change and auto-syncs. Watch the status change..."
>
> Point at: Syncing → Synced, pods rolling out in the tree view.

> "Notice the rolling update — new pods come up, old pods terminate. At least 2 pods serve traffic at all times."

If ArgoCD hasn't auto-detected yet (3-min poll interval), click **Refresh** in the ArgoCD UI:
> "ArgoCD polls Git every 3 minutes by default. I'll click Refresh to speed it up for the demo."

---

## Part 5: Verify the Deployment (2 min)

### What to SHOW:

**Terminal — check pods:**
```bash
kubectl get pods -n default -l app=java-demo-app -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.conditions[?(@.type=="Ready")].status'
```
> "All 3 pods are running the new image — all Ready."

**Terminal — restart port-forward and test:**
```bash
pkill -f "port-forward.*8083" 2>/dev/null; sleep 1
kubectl port-forward svc/java-demo-app 8083:80 -n default &
sleep 2
curl -s http://localhost:8083/ | python3 -m json.tool
```
> "And there it is — version 6.0 is live. From `git push` to production with zero manual intervention."

---

## Part 6: Security Demo — Kyverno Blocking (2 min, Optional)

### What to SAY:

> "Let me show you what happens if someone tries to deploy an unsigned image."

### What to DO:

```bash
kubectl run hacker-pod --image=nginx:latest -n default
```

> "Rejected. Kyverno checked: is this image signed by our Cosign key? No → blocked."

```bash
kubectl run hacker-pod2 --image=pranathinallamilli/java-demo-app:some-fake-tag -n default 2>&1
```

> "Even using our Docker Hub repo name — if the tag isn't signed, Kyverno blocks it. This is admission control at the Kubernetes API level."

> "In a real attack scenario: even if Docker Hub is compromised and an attacker pushes a malicious image with a legitimate-looking tag, it won't have our private key's signature — and Kyverno will reject it."

---

## Part 7: Wrap Up (1 min)

### What to SAY:

> "To summarize the entire flow:
>
> **Developer:** `git push`  
> **GitHub Actions:** Build → Test → Docker Build → Trivy Scan → Cosign Sign  
> **Image Updater:** Detects new tag → commits to Git  
> **ArgoCD:** Syncs to Kubernetes → Rolling update  
> **Kyverno:** Verifies signature → Allows/blocks pod  
>
> All of this is **zero-touch after the initial cluster setup**. The setup (ArgoCD, Image Updater, Kyverno, Cosign, credentials) is one-time per cluster. Same steps work on EKS, AKS, GKE — we're using kind locally because we don't have cloud access."

> "The pipeline is 2 jobs instead of 4. No Git tokens in the CI pipeline. The pipeline is **read-only** — it never writes back to the repo. Image Updater handles that from inside the cluster."

---

## Quick Recovery Commands (If Something Goes Wrong During Demo)

```bash
# If port-forward dies
pkill -f "port-forward.*8083" 2>/dev/null
pkill -f "port-forward.*8443" 2>/dev/null
kubectl port-forward svc/argocd-server -n argocd 8443:443 &
kubectl port-forward svc/java-demo-app -n default 8083:80 &

# If ArgoCD is slow to detect new commit — trigger manual refresh via API
ARGOCD_TOKEN=$(curl -sk -X POST https://localhost:8443/api/v1/session \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"<argocd-password>"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
curl -sk -H "Authorization: Bearer $ARGOCD_TOKEN" \
  "https://localhost:8443/api/v1/applications/java-demo-app?refresh=hard" > /dev/null

# If pods are stuck
kubectl rollout status deployment/java-demo-app -n default --timeout=120s

# Full status check
kubectl get application java-demo-app -n argocd -o jsonpath='Sync: {.status.sync.status}, Health: {.status.health.status}' && echo ""
kubectl get pods -n default -l app=java-demo-app
curl -s http://localhost:8083/ | python3 -m json.tool
```

---

## Talking Points for Q&A

| Question | Answer |
|----------|--------|
| Why kind and not EKS? | No cloud access in this setup. kind runs locally on Podman. Same ArgoCD/Kyverno/Image Updater setup works on any K8s cluster. |
| What if Trivy finds CVEs? | Pipeline fails → image is never signed → Kyverno blocks it. Double safety net. |
| Why Trivy after Docker push? | `docker buildx` multi-arch builds push directly to registry. Trivy needs the final multi-arch manifest to scan accurately. If Trivy fails → image stays unsigned → Kyverno blocks deployment. |
| What if Docker Hub is compromised? | Attacker can push images but can't sign them (no private key). Kyverno rejects unsigned images. |
| What if ArgoCD is slow? | Default Git poll is 3 min. Image Updater polls Docker Hub every 2 min. In production, you can configure webhooks for instant detection. |
| Why 3 replicas? | High availability. Rolling updates replace pods one at a time (maxUnavailable: 1). At least 2 pods always serve traffic. |
| What's the Service type? | ClusterIP (cluster-internal). We use `kubectl port-forward` for local access. In production, use an Ingress controller or LoadBalancer. |
| Is this production-ready? | The pipeline, signing, and admission control are production patterns. Replace kind with EKS/AKS/GKE, add Ingress, use Helm for platform components. |
| What about rollback? | ArgoCD tracks Git history. Revert the commit → ArgoCD auto-syncs the old version. Self-heal prevents manual drift. |

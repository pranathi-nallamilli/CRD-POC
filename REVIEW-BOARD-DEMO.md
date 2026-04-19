# Review Board + CI/CD Integration Demo

## What is Review Board?

Review Board is a **self-hosted code review tool** (not a vulnerability scanner). It provides a web-based interface for reviewing code changes before they are merged, similar to GitHub Pull Request reviews but as a standalone platform.

- **Website:** https://www.reviewboard.org
- **License:** Open Source (MIT)
- **Latest Version:** 7.0.6

| Feature | Review Board | GitHub PRs |
|---------|-------------|------------|
| Code diff view | Yes | Yes |
| Inline comments | Yes | Yes |
| Approval workflow | "Ship It!" | "Approve" |
| CI integration | Via API | Native (Actions) |
| Self-hosted | Required | Optional (Enterprise) |
| Pre-commit review | Yes (designed for this) | Yes (via PRs) |
| Cost | Free (self-hosted) | Free (public repos) |

---

## Architecture (Local Setup)

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│   Browser    │────▶│  Nginx:8084  │────▶│ Review Board:8080│
│ localhost:8084    │  (static files │     │  (Django/Python)  │
└─────────────┘     │   + proxy)    │     └────────┬─────────┘
                    └──────────────┘              │
                                          ┌───────┴───────┐
                                          │               │
                                   ┌──────┴──┐    ┌───────┴────┐
                                   │Postgres │    │ Memcached  │
                                   │  :5432  │    │  :11211    │
                                   └─────────┘    └────────────┘
```

All containers run on Podman network `reviewboard-net`.

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| db | postgres:15 | 5432 | Database |
| memcached | memcached:latest | 11211 | Caching |
| reviewboard | beanbag/reviewboard:latest | 8080 | Review Board app |
| rb-nginx | nginx:latest | 8084→80 | Web frontend |

---

## Setup Steps

### Prerequisites
- Podman (v5.6.0+)
- Python 3.13+ with pip
- Java 17+, Maven 3.9+

### 1. Create Podman Network
```bash
podman network create reviewboard-net
```

### 2. Start PostgreSQL
```bash
podman run -d --name db --network reviewboard-net \
  -e POSTGRES_USER=reviewboard \
  -e POSTGRES_PASSWORD=reviewboard123 \
  -e POSTGRES_DB=reviewboard \
  postgres:15
```

### 3. Start Memcached
```bash
podman run -d --name memcached --network reviewboard-net memcached:latest
```

### 4. Start Review Board
```bash
podman run -d --name reviewboard --network reviewboard-net \
  -e DATABASE_TYPE=postgresql \
  -e DATABASE_SERVER=db \
  -e DATABASE_USERNAME=reviewboard \
  -e DATABASE_PASSWORD=reviewboard123 \
  -e DATABASE_NAME=reviewboard \
  -e MEMCACHED_SERVER=memcached:11211 \
  -e DOMAIN=localhost:8084 \
  -v ~/reviewboard-site:/site \
  beanbag/reviewboard:latest
```

### 5. Start Nginx
Create `~/reviewboard-config/nginx.conf`:
```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/reviewboard/htdocs;

    location / {
        proxy_pass http://reviewboard:8080;
        proxy_redirect off;
        proxy_set_header Host localhost:8084;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Port 8084;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header X-Forwarded-Ssl off;
        client_max_body_size 10m;
    }

    location /media/ {
        alias /var/www/reviewboard/htdocs/media/;
        expires max;
        add_header Cache-Control public;
    }

    location /static/ {
        alias /var/www/reviewboard/htdocs/static/;
        expires max;
        add_header Cache-Control public;
    }
}
```

```bash
podman run -d --name rb-nginx --network reviewboard-net \
  -p 8084:80 \
  -v ~/reviewboard-config/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -v ~/reviewboard-site/htdocs/static:/var/www/reviewboard/htdocs/static:ro \
  -v ~/reviewboard-site/htdocs/media:/var/www/reviewboard/htdocs/media:ro \
  nginx:latest
```

### 6. Configure Review Board
1. Open http://localhost:8084 — login as `admin` / `admin`
2. Go to Admin → Repositories → Add Repository
   - Name: `CRD-POC`
   - Hosting Service: GitHub
   - Repository Plan: Public
   - Account: your GitHub username
   - API Token: your GitHub PAT
   - Repository Name: `CRD-POC`

### 7. Install RBTools CLI
```bash
pip3 install RBTools
export PATH="$PATH:$HOME/Library/Python/3.13/bin"
```

### 8. Configure `.reviewboardrc` in repo root
```
REVIEWBOARD_URL = "http://localhost:8083"
REPOSITORY = "CRD-POC"
BRANCH = "main"
TRACKING_BRANCH = "origin/main"
```

> **Note:** `.reviewboardrc` uses port 8083 (direct backend) for the CLI because the Nginx proxy adds the port to API URLs which the CLI handles differently than the browser.

### 9. Create Users
- `admin` / `admin` — owner, posts review requests
- `reviewer1` / `reviewer1` — reviewer, approves with Ship It

Set reviewer1 password via container:
```bash
podman exec reviewboard bash -c 'DJANGO_SETTINGS_MODULE=reviewboard.settings \
  PYTHONPATH=/site/conf python3 -c "
import os, sys
os.environ[\"DJANGO_SETTINGS_MODULE\"] = \"reviewboard.settings\"
os.environ[\"HOME\"] = \"/site\"
sys.path.insert(0, \"/site/conf\")
import django; django.setup()
from django.contrib.auth.models import User
u = User.objects.get(username=\"reviewer1\")
u.set_password(\"reviewer1\")
u.save()
"'
```

---

## Demo Workflow (End-to-End)

### Step 1: Make a Code Change
```bash
git checkout feature/test-review
# Edit DemoApplication.java — change message and version
# Edit DemoApplicationTests.java — update test assertion
```

### Step 2: Run Tests Locally
```bash
mvn clean test
# Tests run: 4, Failures: 0, Errors: 0 — BUILD SUCCESS
```

### Step 3: Commit and Push
```bash
git add -A
git commit -m "feat: Final demo - update message and version to 1.2.0"
git push origin feature/test-review
```

### Step 4: Post Review Request
```bash
rbt post --server http://localhost:8084 \
  --username admin --password admin \
  --summary "Final Demo: Update message and version to 1.2.0" \
  --description "Updated app message and bumped version. Tests updated to match." \
  --target-people reviewer1 \
  --publish HEAD
# → Review request #6 posted at http://localhost:8084/r/6/
```

### Step 5: CI Posts Results to Review Board
```bash
REVIEWBOARD_URL="http://localhost:8084" bash scripts/reviewboard-ci-demo.sh
```
This runs Maven tests, code style checks, Dockerfile validation, and posts results as a review comment via the Review Board API.

### Step 6: Reviewer Approves (Ship It!)
1. Log out of `admin` in browser
2. Log in as `reviewer1` / `reviewer1`
3. Go to http://localhost:8084/r/6/
4. Click **Review → Ship It!** → OK

> **Important:** The owner cannot Ship It their own review — a different user must approve. This is by design (you shouldn't approve your own code).

### Step 7: Close as Submitted
Log back in as `admin`, click **Close → Submitted** on the review request.

---

## CI/CD Integration

### Local CI Script
`scripts/reviewboard-ci-demo.sh` simulates what a CI pipeline does:
1. Runs `mvn clean test`
2. Checks code style (tab characters)
3. Validates Dockerfile exists
4. Posts results to Review Board via API:
```bash
curl -u admin:admin -X POST \
  "${REVIEWBOARD_URL}/api/review-requests/${RR_ID}/reviews/" \
  -d "body_top=CI Results: Tests PASSED, Style PASSED, Dockerfile FOUND" \
  -d "public=true"
```

### GitHub Actions Workflow
`.github/workflows/review-board-ci.yml` — triggers on PRs to `main`:
- Runs unit tests
- Checks code style
- Posts results as a PR comment

### Integration Flow
```
Developer                Review Board              GitHub Actions         ArgoCD
   │                         │                          │                   │
   ├─ code change ──────────▶│                          │                   │
   ├─ rbt post ─────────────▶│ Review Request           │                   │
   │                         │◀── CI results ───────────┤ (runs tests)      │
   │                         │                          │                   │
   │              reviewer1 ─┤ Ship It! ✅              │                   │
   │                         │                          │                   │
   ├─ git merge main ───────▶│ Close: Submitted         │                   │
   ├─ git push ─────────────────────────────────────────▶│ build+push image │
   │                         │                          │──────────────────▶│
   │                         │                          │        auto-sync  │
   │                         │                          │        to K8s     │
```

---

## Troubleshooting

### Ship It Not Working in Browser
**Cause:** Nginx `Host` header was passing `localhost` without the port. Review Board's JavaScript AJAX calls would target the wrong port.

**Fix:** In `nginx.conf`, set:
```nginx
proxy_set_header Host localhost:8084;
proxy_set_header X-Forwarded-Port 8084;
proxy_set_header X-Forwarded-Proto http;
```

### CSRF 403 Error on Login
**Cause:** Domain mismatch between browser URL and Review Board's configured site domain.

**Fix:** Add to `settings_local.py` inside the container:
```python
CSRF_TRUSTED_ORIGINS = ["http://localhost:8084", "http://localhost:8083"]
ALLOWED_HOSTS = ["*"]
```

### rbt post "Connection Refused"
**Cause:** `.reviewboardrc` pointed to Nginx port (8084), but API redirect URLs pointed to port 80.

**Fix:** Use direct backend port in `.reviewboardrc`:
```
REVIEWBOARD_URL = "http://localhost:8083"
```
Or after fixing Nginx `Host` header, port 8084 also works.

### 502 Bad Gateway
**Cause:** Review Board container stopped.

**Fix:** `podman start db memcached reviewboard rb-nginx`

---

## Review Board vs GitHub PRs

| Aspect | Review Board | GitHub PRs |
|--------|-------------|------------|
| **Best for** | Pre-commit review, large enterprises | GitHub-native workflows |
| **Setup** | Self-hosted (4 containers) | Zero setup |
| **SCM support** | Git, SVN, Mercurial, Perforce | Git only |
| **CI integration** | Via API (manual) | Native (GitHub Actions) |
| **Learning curve** | Moderate (new tool + CLI) | Low (already using GitHub) |
| **Team adoption** | Requires training | Already familiar |

**Recommendation:** For teams already on GitHub, GitHub PRs with branch protection rules provide the same code review workflow without the overhead of maintaining a separate tool. Review Board adds value when you need to support multiple SCMs (e.g., both Git and SVN) or need pre-commit review for workflows that don't use pull requests.

---

## Quick Reference

### Start/Stop Review Board
```bash
# Start all containers
podman start db memcached reviewboard rb-nginx

# Stop all containers
podman stop rb-nginx reviewboard memcached db
```

### Post a Review Request
```bash
export PATH="$PATH:$HOME/Library/Python/3.13/bin"
rbt post --server http://localhost:8084 \
  --username admin --password admin \
  --target-people reviewer1 \
  --publish HEAD
```

### Run CI Demo
```bash
REVIEWBOARD_URL="http://localhost:8084" bash scripts/reviewboard-ci-demo.sh
```

### Credentials
| User | Password | Role |
|------|----------|------|
| admin | admin | Owner (posts reviews) |
| reviewer1 | reviewer1 | Reviewer (Ship It) |

### URLs
| Service | URL |
|---------|-----|
| Review Board (browser) | http://localhost:8084 |
| Review Board (API/CLI) | http://localhost:8083 |
| Review Board Admin | http://localhost:8084/admin/ |

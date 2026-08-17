# SigChain-SLSA – Secure Software Supply Chain Verification Platform

**Phase 1: Basic Application and CI/CD Foundation**  
**Phase 2: Software Bill of Materials (SBOM) Generation with Syft**  
**Phase 3: Automated Vulnerability Scanning with Trivy**

SigChain-SLSA is a security platform project designed to demonstrate DevSecOps practices and SLSA (Supply-chain Levels for Software Artifacts) framework compliance. This repository contains the base Python Flask microservice secured across supply-chain pipeline phases, featuring automated container builds, SPDX-JSON SBOM generation, and automated vulnerability scanning.

---

## 📁 Repository Structure

```text
sigchain-slsa/
├── app/
│   ├── app.py                  # Core Flask application (homepage & /health endpoints)
│   └── requirements.txt        # Python dependencies (Flask, Gunicorn)
├── security-artifacts/         # Output directory for security artifacts, SBOMs & scan reports
│   └── .gitkeep                # Placeholder for git tracking (generated reports gitignored)
├── Dockerfile                  # Secure multi-stage container build file
├── .dockerignore               # Excludes unnecessary files from Docker build context
├── .gitignore                  # Ignores local environment & cache files from Git
├── README.md                   # Project documentation
└── .github/
    └── workflows/
        └── docker-build.yml    # CI/CD automation workflow (Build, SBOM & Vulnerability Scan)
```

---

## 🚀 Getting Started

### 1. Prerequisites
- Python 3.11+
- Docker (optional, for containerization testing)
- [Syft](https://github.com/anchore/syft) CLI (optional, for local SBOM generation)
- [Trivy](https://github.com/aquasecurity/trivy) CLI (optional, for local vulnerability scanning)

---

## 💻 Running the Application Locally

1. **Navigate to the workspace directory:**
   ```bash
   cd sigchain-slsa
   ```

2. **Create and activate a virtual environment (optional but recommended):**
   - **Linux/macOS:**
     ```bash
     python3 -m venv venv
     source venv/bin/activate
     ```
   - **Windows (PowerShell):**
     ```powershell
     python -m venv venv
     .\venv\Scripts\Activate.ps1
     ```

3. **Install dependencies:**
   ```bash
   pip install -r app/requirements.txt
   ```

4. **Run the Flask development server:**
   ```bash
   python app/app.py
   ```

5. **Test the endpoints:**
   - Homepage: [http://localhost:5000/](http://localhost:5000/)
   - Health check: [http://localhost:5000/health](http://localhost:5000/health)

   Using `curl`:
   ```bash
   curl http://localhost:5000/
   curl http://localhost:5000/health
   ```

---

## 🐳 Building and Running with Docker

### 1. Build the Docker Image
```bash
docker build -t sigchain-demo:latest .
```

### 2. Run the Docker Container
```bash
docker run -p 5000:5000 --name sigchain-app sigchain-demo:latest
```

### 3. Verify Container Status & Health
```bash
curl http://localhost:5000/health
```

### 4. Stop and Remove Container
```bash
docker stop sigchain-app
docker rm sigchain-app
```

---

## 📋 Phase 2: Software Bill of Materials (SBOM) Generation

### 1. What is an SBOM?
A **Software Bill of Materials (SBOM)** is a formal, machine-readable inventory of all components, libraries, modules, and dependencies included within a software product or container image.

### 2. Why is an SBOM Important for Software Supply-Chain Security?
- **Component Transparency:** Provides complete visibility into third-party dependencies and operating system packages inside containers.
- **Vulnerability Management & Incident Response:** Enables rapid identification of vulnerable components when new CVEs are disclosed.
- **Compliance & License Audit:** Helps ensure compliance with open-source licensing requirements and enterprise security policies.
- **Supply-Chain Assurance:** Forms a foundational building block for SLSA compliance and secure software provenance.

### 3. What is Syft?
[Syft](https://github.com/anchore/syft) is a powerful, open-source CLI tool developed by Anchore for generating Software Bill of Materials (SBOMs) from container images and filesystems.

### 4. What Information Does the Generated SBOM Contain?
The generated SBOM includes:
- **OS Package Inventory:** System packages installed via `apt` (e.g., `libc-bin`, `openssl`, `python3.11`).
- **Language-Specific Packages:** Python dependencies parsed from virtual environments or `requirements.txt` (e.g., `Flask`, `Gunicorn`, `Werkzeug`, `jinja2`).
- **Package Metadata:** Version numbers, package licenses, purls (Package URLs), supplier/author information, and checksums/digests.
- **Document Metadata:** SPDX format version, creation timestamp, tool versions (`syft`), and target image identifier (`sigchain-demo:latest`).

### 5. How to Generate the SBOM Locally
Ensure the Docker image `sigchain-demo:latest` is built first:
```bash
docker build -t sigchain-demo:latest .
```

Generate the SPDX-JSON SBOM using Syft CLI:
```bash
syft sigchain-demo:latest -o spdx-json=security-artifacts/sbom.spdx.json
```

*(Alternatively, if Syft CLI is not installed locally, run Syft via Docker):*
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ./security-artifacts:/out anchore/syft:v1.19.0 sigchain-demo:latest -o spdx-json=/out/sbom.spdx.json
```

### 6. Where is the Generated SBOM Stored?
The SBOM file is created at:
```text
security-artifacts/sbom.spdx.json
```

### 7. How to Download the SBOM from GitHub Actions
1. Navigate to the **Actions** tab in your GitHub repository.
2. Select the latest **Docker Build CI** workflow run.
3. Scroll down to the **Artifacts** section at the bottom of the run summary page.
4. Click on **`sbom-spdx-json`** to download the zip file containing `sbom.spdx.json`.

---

## 🔍 Phase 3: Automated Vulnerability Scanning with Trivy

### 1. What is Vulnerability Scanning?
**Vulnerability scanning** is an automated security testing process that analyzes software artifacts (such as container images, source code repositories, and dependency manifests) against public security databases to detect known security flaws and unpatched software bugs.

### 2. What is a CVE?
A **CVE (Common Vulnerabilities and Exposures)** is a standardized, unique dictionary identifier assigned to publicly disclosed cybersecurity vulnerabilities (e.g., `CVE-2023-30861`). CVE IDs allow security engineers and automated scanners to uniquely track and correlate vulnerabilities across security databases (NVD, GHSA, Debian Security Tracker).

### 3. Why is Vulnerability Scanning Important?
- **Early Vulnerability Detection:** Detects known security flaws in container OS layers and application dependencies before code is deployed.
- **Proactive Risk Mitigation:** Highlights available patch versions (`Fixed Version`) so developers can upgrade vulnerable libraries.
- **Supply-Chain Hardening:** Ensures that transitive or nested dependencies do not introduce silent attack vectors into production systems.

### 4. What is Trivy?
[Trivy](https://github.com/aquasecurity/trivy) is a comprehensive, open-source security scanner developed by Aqua Security. It quickly scans container images, filesystems, Git repositories, and VM images for vulnerabilities, misconfigurations, and exposed secrets.

### 5. What Parts of the Container are Scanned?
Trivy scans two primary component layers inside `sigchain-demo:latest`:
1. **OS Packages:** Linux distribution packages installed in `python:3.11-slim` via `dpkg`/`apt` (e.g., `openssl`, `glibc`, `zlib`, `bash`).
2. **Application Dependencies:** Python packages installed via `pip` (e.g., `Flask`, `Gunicorn`, `Werkzeug`, `jinja2`, `click`, `setuptools`).

### 6. What Do the Severity Levels Mean?
Trivy categorizes identified vulnerabilities into five standard severity levels:
- **`CRITICAL`:** High-impact vulnerabilities (e.g., remote code execution, unauthenticated access) that present immediate risk and should be remediated urgently.
- **`HIGH`:** Serious vulnerabilities (e.g., privilege escalation, data leakage) that require prioritized patching.
- **`MEDIUM`:** Moderate risk issues (e.g., denial of service under specific conditions, limited information disclosure).
- **`LOW`:** Low risk or minor issues with low exploitability impact.
- **`UNKNOWN`:** Vulnerabilities reported without assigned CVSS scores or severity ratings in vulnerability feeds.

### 7. How to Scan the Docker Image Locally
Build `sigchain-demo:latest` first:
```bash
docker build -t sigchain-demo:latest .
```

Scan the container image using Trivy CLI:
```bash
trivy image sigchain-demo:latest
```

Generate local report files (JSON and human-readable text table):
```bash
trivy image --format json --output security-artifacts/trivy-report.json sigchain-demo:latest
trivy image --format table --output security-artifacts/trivy-report.txt sigchain-demo:latest
```

*(Alternatively, if Trivy CLI is not installed locally, run Trivy via Docker):*
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ./security-artifacts:/out aquasec/trivy:0.58.0 image --format json --output /out/trivy-report.json sigchain-demo:latest
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ./security-artifacts:/out aquasec/trivy:0.58.0 image --format table --output /out/trivy-report.txt sigchain-demo:latest
```

### 8. Where are Vulnerability Reports Stored?
Vulnerability scan reports are generated in the `security-artifacts/` directory:
- **`security-artifacts/trivy-report.json`**: Machine-readable JSON report containing complete CVE details, target metadata, and package references.
- **`security-artifacts/trivy-report.txt`**: Human-readable table report listing CVE IDs, package names, installed versions, fixed versions, severity, and titles.

*Note: All generated vulnerability report files in `security-artifacts/*.json` and `security-artifacts/*.txt` are added to `.gitignore` to prevent build artifacts from being committed to Git.*

### 9. How to Download Vulnerability Reports from GitHub Actions
1. Navigate to the **Actions** tab in your GitHub repository.
2. Select the latest **Docker Build CI** workflow run.
3. Scroll down to the **Artifacts** section at the bottom of the run summary page.
4. Click on **`vulnerability-reports`** to download the zip bundle containing `trivy-report.json` and `trivy-report.txt`.

---

## 🔒 Security Best Practices Implemented in Dockerfile

1. **Minimal Base Image:** Uses `python:3.11-slim` to reduce the attack surface and image size.
2. **Non-Root Execution:** Creates and runs the process under an unprivileged user (`appuser`, UID 1000) instead of `root`.
3. **Layer Caching:** Copies `requirements.txt` before application source files to speed up builds and cache dependency layers.
4. **Production WSGI Server:** Uses Gunicorn instead of Flask's built-in development server.

---

## ⚙️ GitHub Actions CI/CD Workflow (`docker-build.yml`)

The GitHub Actions workflow automatically runs on `push` and `pull_request` events targeting `main` or `master` branches:

1. **Checkout:** Clones the repository code.
2. **Python Setup & Validation:** Installs Python 3.11, validates dependencies, and checks application syntax (`py_compile`).
3. **Docker Build:** Builds the container image `sigchain-demo:latest` with `load: true` so the image is loaded into the runner's Docker daemon.
4. **Directory Setup:** Prepares the `security-artifacts/` directory.
5. **Syft SBOM Analysis:** Analyzes `sigchain-demo:latest` using `anchore/sbom-action@v0.17.9` and generates `security-artifacts/sbom.spdx.json`.
6. **SBOM Artifact Upload:** Uploads `sbom.spdx.json` as artifact `sbom-spdx-json` via `actions/upload-artifact@v4`.
7. **Trivy Vulnerability Scan:** Scans `sigchain-demo:latest` using `aquasecurity/trivy-action@v0.36.0` (`exit-code: '0'`), generating machine-readable JSON (`trivy-report.json`) and human-readable text table (`trivy-report.txt`).
8. **Log Summary Display:** Prints the human-readable vulnerability table and severity summary directly in the workflow runner log.
9. **Vulnerability Artifact Upload:** Uploads both vulnerability reports (`trivy-report.json` and `trivy-report.txt`) as artifact bundle `vulnerability-reports`.

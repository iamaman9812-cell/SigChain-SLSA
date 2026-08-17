# SigChain-SLSA – Secure Software Supply Chain Verification Platform

**Phase 1: Basic Application and CI/CD Foundation**  
**Phase 2: Software Bill of Materials (SBOM) Generation with Syft**

SigChain-SLSA is a security platform project designed to demonstrate DevSecOps practices and SLSA (Supply-chain Levels for Software Artifacts) framework compliance. This repository contains the base Python Flask microservice secured across supply-chain pipeline phases, featuring automated container builds and SPDX-JSON SBOM generation.

---

## 📁 Repository Structure

```text
sigchain-slsa/
├── app/
│   ├── app.py                  # Core Flask application (homepage & /health endpoints)
│   └── requirements.txt        # Python dependencies (Flask, Gunicorn)
├── security-artifacts/         # Output directory for security artifacts & SBOMs
│   └── .gitkeep                # Placeholder for git tracking (JSON artifacts gitignored)
├── Dockerfile                  # Secure multi-stage container build file
├── .dockerignore               # Excludes unnecessary files from Docker build context
├── .gitignore                  # Ignores local environment & cache files from Git
├── README.md                   # Project documentation
└── .github/
    └── workflows/
        └── docker-build.yml    # CI/CD automation workflow (Build & SBOM generation)
```

---

## 🚀 Getting Started

### 1. Prerequisites
- Python 3.11+
- Docker (optional, for containerization testing)
- [Syft](https://github.com/anchore/syft) CLI (optional, for local SBOM generation)

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
- **Vulnerability Management & Incident Response:** Enables rapid identification of vulnerable components when new CVEs (e.g., Log4j) are disclosed.
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
*Note: Generated SBOM files in `security-artifacts/*.json` and `*.spdx.json` are added to `.gitignore` to prevent build artifacts from being committed to source control.*

### 7. How to Download the SBOM from GitHub Actions
1. Navigate to the **Actions** tab in your GitHub repository.
2. Select the latest **Docker Build CI** workflow run.
3. Scroll down to the **Artifacts** section at the bottom of the run summary page.
4. Click on **`sbom-spdx-json`** to download the zip file containing `sbom.spdx.json`.

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
5. **Syft SBOM Analysis:** Analyzes `sigchain-demo:latest` using `anchore/sbom-action@v0.17.9` and generates an `spdx-json` SBOM (`security-artifacts/sbom.spdx.json`).
6. **Artifact Upload:** Uploads `sbom.spdx.json` as a workflow artifact named `sbom-spdx-json` via `actions/upload-artifact@v4`.
7. **Build Gate:** Fails the workflow if image building or SBOM generation fails. Image is **not** pushed to external registries.

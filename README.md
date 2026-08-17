# SigChain-SLSA – Secure Software Supply Chain Verification Platform

**Phase 1: Basic Application and CI/CD Foundation**

SigChain-SLSA is a security platform project designed to demonstrate DevSecOps practices and SLSA (Supply-chain Levels for Software Artifacts) framework compliance. This repository currently contains the base Python Flask microservice that serves as the sample application to be secured across subsequent supply-chain pipeline phases.

---

## 📁 Repository Structure

```text
sigchain-slsa/
├── app/
│   ├── app.py              # Core Flask application (homepage & /health endpoints)
│   └── requirements.txt    # Python dependencies (Flask, Gunicorn)
├── Dockerfile              # Secure multi-stage container build file
├── .dockerignore           # Excludes unnecessary files from Docker build context
├── .gitignore              # Ignores local environment & cache files from Git
├── README.md               # Project documentation
└── .github/
    └── workflows/
        └── docker-build.yml # CI/CD automation workflow
```

---

## 🚀 Getting Started

### 1. Prerequisites
- Python 3.11+
- Docker (optional, for containerization testing)

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
docker build -t sigchain-slsa:latest .
```

### 2. Run the Docker Container
```bash
docker run -p 5000:5000 --name sigchain-app sigchain-slsa:latest
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

## 🔒 Security Best Practices Implemented in Dockerfile

1. **Minimal Base Image:** Uses `python:3.11-slim` to reduce the attack surface and image size.
2. **Non-Root Execution:** Creates and runs the process under an unprivileged user (`appuser`, UID 1000) instead of `root`.
3. **Layer Caching:** Copies `requirements.txt` before application source files to speed up builds and cache dependency layers.
4. **Production WSGI Server:** Uses Gunicorn instead of Flask's built-in development server.

---

## ⚙️ GitHub Actions CI/CD Workflow (`docker-build.yml`)

The GitHub Actions workflow automatically runs on `push` and `pull_request` events targeting `main` or `master` branches:

1. **Checkout:** Clones the code into the runner.
2. **Python Setup & Validation:** Installs Python 3.11, validates dependencies, and checks application syntax (`py_compile`).
3. **Docker Build:** Builds the container image using `docker/build-push-action` to verify there are no missing files or build breaks.
4. **Verification:** Does **not** push to any remote container registry yet; it serves purely as a validation build gate.

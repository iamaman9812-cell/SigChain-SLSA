#!/usr/bin/env bash
# ==============================================================================
# SigChain-SLSA Phase 4: Cosign Digital Signing & Verification Script (Bash)
# ==============================================================================
# This script demonstrates keypair generation, container image digest signing using
# Cosign Bundle format (--bundle), signature verification, and tamper detection.
# ==============================================================================

set -e

ARTIFACTS_DIR="security-artifacts"
KEY_PRIVATE="cosign.key"
KEY_PUBLIC="cosign.pub"
DIGEST_FILE="${ARTIFACTS_DIR}/image-digest.txt"
BUNDLE_FILE="${ARTIFACTS_DIR}/image.bundle"
IMAGE_TAG="sigchain-demo:latest"

echo "========================================================"
echo "      SIGCHAIN-SLSA: DIGITAL SIGNING & VERIFICATION     "
echo "========================================================"

# 1. Ensure artifacts directory exists
mkdir -p "${ARTIFACTS_DIR}"

# 2. Locate Cosign binary
COSIGN_BIN="cosign"
if ! command -v cosign &> /dev/null; then
    if command -v cosign-windows-amd64 &> /dev/null; then
        COSIGN_BIN="cosign-windows-amd64"
    elif [ -f "./cosign" ]; then
        COSIGN_BIN="./cosign"
    elif [ -f "./cosign-windows-amd64.exe" ]; then
        COSIGN_BIN="./cosign-windows-amd64.exe"
    else
        echo "[!] Error: 'cosign' CLI is not installed or not in PATH."
        echo "    Please install Cosign (https://docs.sigstore.dev/cosign/system_config/installation/)"
        exit 1
    fi
fi

# 3. Generate Key Pair if not already present
if [ ! -f "${KEY_PRIVATE}" ] || [ ! -f "${KEY_PUBLIC}" ]; then
    echo "[+] Generating new Cosign key pair..."
    export COSIGN_PASSWORD=""
    printf "\n\n" | $COSIGN_BIN generate-key-pair > /dev/null 2>&1
    echo "[✓] Cosign key pair generated: ${KEY_PRIVATE} (private) and ${KEY_PUBLIC} (public)"
else
    echo "[✓] Using existing Cosign key pair: ${KEY_PUBLIC}"
fi

# 4. Extract Docker Image Digest or fallback to simulated image SHA
if command -v docker &> /dev/null && docker image inspect "${IMAGE_TAG}" &> /dev/null; then
    echo "[+] Extracting image digest for '${IMAGE_TAG}'..."
    IMAGE_DIGEST=$(docker inspect --format='{{index .Id}}' "${IMAGE_TAG}")
else
    echo "[!] Docker image '${IMAGE_TAG}' not found locally in Docker daemon."
    echo "[+] Generating deterministic image digest artifact for local testing..."
    IMAGE_DIGEST="sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
fi

echo "Target Image Tag : ${IMAGE_TAG}"
echo "Target Manifest  : ${IMAGE_DIGEST}"
printf "%s" "${IMAGE_DIGEST}" > "${DIGEST_FILE}"

# 5. Sign the Image Digest using Cosign Private Key (Bundle format)
echo "--------------------------------------------------------"
echo "[+] Signing Docker image artifact with private key (${KEY_PRIVATE}) using Cosign Bundle format..."
export COSIGN_PASSWORD=""
printf "y\n" | $COSIGN_BIN sign-blob --key "${KEY_PRIVATE}" --bundle "${BUNDLE_FILE}" "${DIGEST_FILE}" --yes
echo "[✓] Cosign bundle generated successfully -> ${BUNDLE_FILE}"

# 6. Verify the Signature Bundle using Cosign Public Key
echo "--------------------------------------------------------"
echo "[+] Verifying Cosign bundle with public key (${KEY_PUBLIC})..."
if $COSIGN_BIN verify-blob --key "${KEY_PUBLIC}" --bundle "${BUNDLE_FILE}" "${DIGEST_FILE}"; then
    echo "[✓] SIGNATURE BUNDLE VERIFICATION SUCCESSFUL: Container artifact is authentic and untampered!"
else
    echo "[✗] SIGNATURE BUNDLE VERIFICATION FAILED!"
    exit 1
fi

# 7. Demonstrate Tamper Detection
echo "--------------------------------------------------------"
echo "[+] Demonstrating Tamper Detection (Simulating modified image content)..."
TAMPERED_DIGEST_FILE="${ARTIFACTS_DIR}/tampered-digest.txt"
printf "%s-TAMPERED-BAD-HASH" "${IMAGE_DIGEST}" > "${TAMPERED_DIGEST_FILE}"

if $COSIGN_BIN verify-blob --key "${KEY_PUBLIC}" --bundle "${BUNDLE_FILE}" "${TAMPERED_DIGEST_FILE}" 2>/dev/null; then
    echo "[✗] TAMPER TEST FAILED: Cosign accepted a tampered image artifact!"
    rm -f "${TAMPERED_DIGEST_FILE}"
    exit 1
else
    echo "[✓] TAMPER DETECTION CONFIRMED: Cosign correctly rejected the tampered image artifact!"
fi

rm -f "${TAMPERED_DIGEST_FILE}"

echo "========================================================"
echo "        PHASE 4 SIGNING & VERIFICATION COMPLETE         "
echo "========================================================"

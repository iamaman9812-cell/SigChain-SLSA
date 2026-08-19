#!/usr/bin/env bash
# ==============================================================================
# SigChain-SLSA Phase 5: Security Policy & Enforcement Script (Bash)
# ==============================================================================
# Evaluates security evidence across SBOM, Vulnerability Scanning, and Cosign
# Signature Verification to decide if an image is ALLOWED or BLOCKED.
# ==============================================================================

set -e

ARTIFACTS_DIR="security-artifacts"
SBOM_FILE="${ARTIFACTS_DIR}/sbom.spdx.json"
TRIVY_JSON="${ARTIFACTS_DIR}/trivy-report.json"
BUNDLE_FILE="${ARTIFACTS_DIR}/image.bundle"
DIGEST_FILE="${ARTIFACTS_DIR}/image-digest.txt"
KEY_PUBLIC="cosign.pub"

DEMO_MODE=""
if [ "$1" != "" ]; then
    DEMO_MODE="$1"
fi

echo "========================================================"
echo "        SIGCHAIN-SLSA: SECURITY POLICY ENFORCEMENT      "
echo "========================================================"

FAILED_REASONS=()

# ------------------------------------------------------------------------------
# Rule 1: Check SBOM Availability
# ------------------------------------------------------------------------------
if [ "$DEMO_MODE" = "--demo-fail-sbom" ] || [ "$DEMO_MODE" = "demo-fail-sbom" ]; then
    echo "[FAIL] Rule 1: Required SBOM is missing or invalid (Simulated)"
    FAILED_REASONS+=("Required SBOM is missing or invalid")
elif [ "$DEMO_MODE" = "--demo-pass" ] || [ "$DEMO_MODE" = "demo-pass" ] || [ "$DEMO_MODE" = "--demo-fail-vuln" ] || [ "$DEMO_MODE" = "demo-fail-vuln" ] || [ "$DEMO_MODE" = "--demo-fail-sig" ] || [ "$DEMO_MODE" = "demo-fail-sig" ]; then
    echo "[PASS] Rule 1: Required SBOM exists (Simulated: ${SBOM_FILE})"
elif [ -f "${SBOM_FILE}" ] && [ -s "${SBOM_FILE}" ]; then
    echo "[PASS] Rule 1: Required SBOM exists (${SBOM_FILE})"
else
    echo "[FAIL] Rule 1: Required SBOM is missing or empty (${SBOM_FILE})"
    FAILED_REASONS+=("Required SBOM is missing or empty")
fi

# ------------------------------------------------------------------------------
# Rule 2: Check Vulnerability Scan & CRITICAL Threshold
# ------------------------------------------------------------------------------
if [ "$DEMO_MODE" = "--demo-fail-vuln" ] || [ "$DEMO_MODE" = "demo-fail-vuln" ]; then
    echo "[FAIL] Rule 2: CRITICAL vulnerabilities detected (Simulated: 2 CRITICAL)"
    FAILED_REASONS+=("CRITICAL vulnerabilities found (2 CRITICAL)")
elif [ "$DEMO_MODE" = "--demo-pass" ] || [ "$DEMO_MODE" = "demo-pass" ] || [ "$DEMO_MODE" = "--demo-fail-sbom" ] || [ "$DEMO_MODE" = "demo-fail-sbom" ] || [ "$DEMO_MODE" = "--demo-fail-sig" ] || [ "$DEMO_MODE" = "demo-fail-sig" ]; then
    echo "[PASS] Rule 2: Vulnerability scan completed (Simulated: 0 CRITICAL vulnerabilities)"
elif [ -f "${TRIVY_JSON}" ]; then
    CRIT_COUNT=$(grep -o '"Severity": *"CRITICAL"' "${TRIVY_JSON}" 2>/dev/null | wc -l || echo "0")
    CRIT_COUNT=$(echo "${CRIT_COUNT}" | tr -d ' ')

    if [ "${CRIT_COUNT}" -eq 0 ]; then
        echo "[PASS] Rule 2: Vulnerability scan completed (Found: 0 CRITICAL vulnerabilities)"
    else
        echo "[FAIL] Rule 2: CRITICAL vulnerabilities detected (Found: ${CRIT_COUNT} CRITICAL)"
        FAILED_REASONS+=("CRITICAL vulnerabilities found (${CRIT_COUNT} CRITICAL)")
    fi
else
    echo "[FAIL] Rule 2: Trivy vulnerability report is missing (${TRIVY_JSON})"
    FAILED_REASONS+=("Trivy vulnerability report missing")
fi

# ------------------------------------------------------------------------------
# Rule 3: Check Cosign Digital Signature Verification
# ------------------------------------------------------------------------------
if [ "$DEMO_MODE" = "--demo-fail-sig" ] || [ "$DEMO_MODE" = "demo-fail-sig" ]; then
    echo "[FAIL] Rule 3: Cosign signature verification failed (Simulated invalid signature)"
    FAILED_REASONS+=("Cosign signature verification failed")
elif [ "$DEMO_MODE" = "--demo-pass" ] || [ "$DEMO_MODE" = "demo-pass" ] || [ "$DEMO_MODE" = "--demo-fail-sbom" ] || [ "$DEMO_MODE" = "demo-fail-sbom" ] || [ "$DEMO_MODE" = "--demo-fail-vuln" ] || [ "$DEMO_MODE" = "demo-fail-vuln" ]; then
    echo "[PASS] Rule 3: Cosign digital signature bundle verified against public key (Simulated: ${KEY_PUBLIC})"
else
    COSIGN_BIN="cosign"
    if ! command -v cosign &> /dev/null; then
        if command -v cosign-windows-amd64 &> /dev/null; then
            COSIGN_BIN="cosign-windows-amd64"
        elif [ -f "./cosign" ]; then
            COSIGN_BIN="./cosign"
        elif [ -f "./cosign-windows-amd64.exe" ]; then
            COSIGN_BIN="./cosign-windows-amd64.exe"
        fi
    fi

    if [ -f "${KEY_PUBLIC}" ] && [ -f "${BUNDLE_FILE}" ] && [ -f "${DIGEST_FILE}" ]; then
        if command -v $COSIGN_BIN &> /dev/null && $COSIGN_BIN verify-blob --key "${KEY_PUBLIC}" --bundle "${BUNDLE_FILE}" "${DIGEST_FILE}" > /dev/null 2>&1; then
            echo "[PASS] Rule 3: Cosign digital signature bundle verified against public key (${KEY_PUBLIC})"
        else
            echo "[FAIL] Rule 3: Cosign signature verification failed or signature is invalid"
            FAILED_REASONS+=("Cosign signature verification failed")
        fi
    else
        echo "[FAIL] Rule 3: Signature bundle (${BUNDLE_FILE}) or public key (${KEY_PUBLIC}) missing"
        FAILED_REASONS+=("Signature bundle or public key missing")
    fi
fi

# ------------------------------------------------------------------------------
# Final Decision & Enforcement Evaluation
# ------------------------------------------------------------------------------
echo "--------------------------------------------------------"

if [ ${#FAILED_REASONS[@]} -eq 0 ]; then
    echo "SECURITY CHECK: PASSED"
    echo "FINAL DECISION: ALLOW"
    echo "Reason        : All security policy rules satisfied (SBOM present, 0 CRITICAL CVEs, Valid Signature)."
    echo "========================================================"
    exit 0
else
    echo "SECURITY CHECK: FAILED"
    echo "FINAL DECISION: BLOCK"
    echo "Enforcement Reasons:"
    for reason in "${FAILED_REASONS[@]}"; do
        echo "  - ${reason}"
    done
    echo "========================================================"
    exit 1
fi

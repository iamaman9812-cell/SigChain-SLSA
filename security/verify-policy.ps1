# ==============================================================================
# SigChain-SLSA Phase 5: Security Policy & Enforcement Script (PowerShell)
# ==============================================================================
# Evaluates security evidence across SBOM, Vulnerability Scanning, and Cosign
# Signature Verification to decide if an image is ALLOWED or BLOCKED on Windows.
# ==============================================================================

param (
    [string]$DemoMode = ""
)

$ErrorActionPreference = "Continue"

$ArtifactsDir = "security-artifacts"
$SbomFile = Join-Path $ArtifactsDir "sbom.spdx.json"
$TrivyJson = Join-Path $ArtifactsDir "trivy-report.json"
$BundleFile = Join-Path $ArtifactsDir "image.bundle"
$DigestFile = Join-Path $ArtifactsDir "image-digest.txt"
$KeyPublic = "cosign.pub"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "        SIGCHAIN-SLSA: SECURITY POLICY ENFORCEMENT      " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$FailedReasons = @()

$IsDemoPass     = ($DemoMode -eq "demo-pass"     -or $DemoMode -eq "--demo-pass")
$IsDemoFailSbom = ($DemoMode -eq "demo-fail-sbom" -or $DemoMode -eq "--demo-fail-sbom")
$IsDemoFailVuln = ($DemoMode -eq "demo-fail-vuln" -or $DemoMode -eq "--demo-fail-vuln")
$IsDemoFailSig  = ($DemoMode -eq "demo-fail-sig"  -or $DemoMode -eq "--demo-fail-sig")
$IsAnyDemo      = ($IsDemoPass -or $IsDemoFailSbom -or $IsDemoFailVuln -or $IsDemoFailSig)

# ------------------------------------------------------------------------------
# Rule 1: Check SBOM Availability
# ------------------------------------------------------------------------------
if ($IsDemoFailSbom) {
    Write-Host "[FAIL] Rule 1: Required SBOM is missing or invalid (Simulated)" -ForegroundColor Red
    $FailedReasons += "Required SBOM is missing or invalid"
} elseif ($IsAnyDemo) {
    Write-Host "[PASS] Rule 1: Required SBOM exists (Simulated: $SbomFile)" -ForegroundColor Green
} elseif ((Test-Path $SbomFile) -and ((Get-Item $SbomFile).Length -gt 0)) {
    Write-Host "[PASS] Rule 1: Required SBOM exists ($SbomFile)" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Rule 1: Required SBOM is missing or empty ($SbomFile)" -ForegroundColor Red
    $FailedReasons += "Required SBOM is missing or empty"
}

# ------------------------------------------------------------------------------
# Rule 2: Check Vulnerability Scan & CRITICAL Threshold
# ------------------------------------------------------------------------------
if ($IsDemoFailVuln) {
    Write-Host "[FAIL] Rule 2: CRITICAL vulnerabilities detected (Simulated: 2 CRITICAL)" -ForegroundColor Red
    $FailedReasons += "CRITICAL vulnerabilities found (2 CRITICAL)"
} elseif ($IsAnyDemo) {
    Write-Host "[PASS] Rule 2: Vulnerability scan completed (Simulated: 0 CRITICAL vulnerabilities)" -ForegroundColor Green
} elseif (Test-Path $TrivyJson) {
    $TrivyContent = Get-Content -Path $TrivyJson -Raw -ErrorAction SilentlyContinue
    $CritMatches = [regex]::Matches($TrivyContent, '"Severity"\s*:\s*"CRITICAL"')
    $CritCount = $CritMatches.Count

    if ($CritCount -eq 0) {
        Write-Host "[PASS] Rule 2: Vulnerability scan completed (Found: 0 CRITICAL vulnerabilities)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Rule 2: CRITICAL vulnerabilities detected (Found: $CritCount CRITICAL)" -ForegroundColor Red
        $FailedReasons += "CRITICAL vulnerabilities found ($CritCount CRITICAL)"
    }
} else {
    Write-Host "[FAIL] Rule 2: Trivy vulnerability report is missing ($TrivyJson)" -ForegroundColor Red
    $FailedReasons += "Trivy vulnerability report missing"
}

# ------------------------------------------------------------------------------
# Rule 3: Check Cosign Digital Signature Verification
# ------------------------------------------------------------------------------
if ($IsDemoFailSig) {
    Write-Host "[FAIL] Rule 3: Cosign signature verification failed (Simulated invalid signature)" -ForegroundColor Red
    $FailedReasons += "Cosign signature verification failed"
} elseif ($IsAnyDemo) {
    Write-Host "[PASS] Rule 3: Cosign digital signature bundle verified against public key (Simulated: $KeyPublic)" -ForegroundColor Green
} else {
    $CosignCmd = ""
    if (Get-Command "cosign-windows-amd64" -ErrorAction SilentlyContinue) {
        $CosignCmd = "cosign-windows-amd64"
    } elseif (Test-Path ".\cosign-windows-amd64.exe") {
        $CosignCmd = ".\cosign-windows-amd64.exe"
    } elseif (Get-Command "cosign" -ErrorAction SilentlyContinue) {
        $CosignCmd = "cosign"
    } elseif (Test-Path ".\cosign.exe") {
        $CosignCmd = ".\cosign.exe"
    }

    if ((Test-Path $KeyPublic) -and (Test-Path $BundleFile) -and (Test-Path $DigestFile)) {
        if ($CosignCmd) {
            $VerifyProc = Start-Process -FilePath $CosignCmd -ArgumentList "verify-blob --key $KeyPublic --bundle $BundleFile $DigestFile" -NoNewWindow -Wait -PassThru
            if ($VerifyProc.ExitCode -eq 0) {
                Write-Host "[PASS] Rule 3: Cosign digital signature bundle verified against public key ($KeyPublic)" -ForegroundColor Green
            } else {
                Write-Host "[FAIL] Rule 3: Cosign signature verification failed or signature is invalid" -ForegroundColor Red
                $FailedReasons += "Cosign signature verification failed"
            }
        } else {
            Write-Host "[FAIL] Rule 3: Cosign executable not found to perform verification" -ForegroundColor Red
            $FailedReasons += "Cosign executable missing"
        }
    } else {
        Write-Host "[FAIL] Rule 3: Signature bundle ($BundleFile) or public key ($KeyPublic) missing" -ForegroundColor Red
        $FailedReasons += "Signature bundle or public key missing"
    }
}

# ------------------------------------------------------------------------------
# Final Decision & Enforcement Evaluation
# ------------------------------------------------------------------------------
Write-Host "--------------------------------------------------------" -ForegroundColor Gray

if ($FailedReasons.Count -eq 0) {
    Write-Host "SECURITY CHECK: PASSED" -ForegroundColor Green
    Write-Host "FINAL DECISION: ALLOW" -ForegroundColor Green
    Write-Host "Reason        : All security policy rules satisfied (SBOM present, 0 CRITICAL CVEs, Valid Signature)." -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "SECURITY CHECK: FAILED" -ForegroundColor Red
    Write-Host "FINAL DECISION: BLOCK" -ForegroundColor Red
    Write-Host "Enforcement Reasons:" -ForegroundColor Yellow
    foreach ($Reason in $FailedReasons) {
        Write-Host "  - $Reason" -ForegroundColor Red
    }
    Write-Host "========================================================" -ForegroundColor Cyan
    exit 1
}

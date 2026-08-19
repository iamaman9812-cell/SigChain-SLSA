# ==============================================================================
# SigChain-SLSA Phase 4: Cosign Digital Signing & Verification Script (PowerShell)
# ==============================================================================
# This script demonstrates keypair generation, container image digest signing using
# Cosign Bundle format (--bundle), signature verification, and tamper detection on Windows.
# ==============================================================================

$ErrorActionPreference = "Stop"

$ArtifactsDir = "security-artifacts"
$KeyPrivate = "cosign.key"
$KeyPublic = "cosign.pub"
$DigestFile = Join-Path $ArtifactsDir "image-digest.txt"
$BundleFile = Join-Path $ArtifactsDir "image.bundle"
$ImageTag = "sigchain-demo:latest"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "      SIGCHAIN-SLSA: DIGITAL SIGNING AND VERIFICATION   " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Ensure security-artifacts directory exists
if (-not (Test-Path -Path $ArtifactsDir)) {
    New-Item -ItemType Directory -Path $ArtifactsDir | Out-Null
}

# 2. Locate Cosign Binary
$CosignCmd = ""

if (Get-Command "cosign-windows-amd64" -ErrorAction SilentlyContinue) {
    $CosignCmd = "cosign-windows-amd64"
} elseif (Test-Path ".\cosign-windows-amd64.exe") {
    $CosignCmd = ".\cosign-windows-amd64.exe"
} elseif (Get-Command "cosign" -ErrorAction SilentlyContinue) {
    $CosignCmd = "cosign"
} elseif (Test-Path ".\cosign.exe") {
    $CosignCmd = ".\cosign.exe"
} else {
    Write-Host "[!] Error: 'cosign-windows-amd64' or 'cosign' CLI is not installed or not in PATH." -ForegroundColor Red
    Write-Host "    Please download Cosign from https://github.com/sigstore/cosign/releases" -ForegroundColor Yellow
    exit 1
}

# 3. Generate Key Pair if not present
if ((-not (Test-Path $KeyPrivate)) -or (-not (Test-Path $KeyPublic))) {
    Write-Host "[+] Generating new Cosign key pair..." -ForegroundColor Green
    $env:COSIGN_PASSWORD = ""
    cmd /c "echo.|echo.| `"$CosignCmd`" generate-key-pair" | Out-Null
    Write-Host "[OK] Cosign key pair generated: $KeyPrivate (private) and $KeyPublic (public)" -ForegroundColor Green
} else {
    Write-Host "[OK] Using existing Cosign key pair: $KeyPublic" -ForegroundColor Green
}

# 4. Extract Docker Image Digest or fallback to deterministic SHA
$ImageDigest = ""
if (Get-Command "docker" -ErrorAction SilentlyContinue) {
    try {
        $ImageDigest = (docker inspect --format='{{index .Id}}' $ImageTag 2>$null)
    } catch {}
}

if (-not $ImageDigest) {
    Write-Host "[!] Docker image '$ImageTag' not found in local daemon or Docker unreachable." -ForegroundColor Yellow
    Write-Host "[+] Using deterministic container image digest for local signature verification..." -ForegroundColor Green
    $ImageDigest = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}

Write-Host "Target Image Tag : $ImageTag" -ForegroundColor White
Write-Host "Target Manifest  : $ImageDigest" -ForegroundColor White
[System.IO.File]::WriteAllText((Resolve-Path . | Select-Object -ExpandProperty Path) + "\" + $DigestFile, $ImageDigest)

# 5. Sign Container Image Digest using Private Key (Cosign Bundle format)
Write-Host "--------------------------------------------------------" -ForegroundColor Gray
Write-Host "[+] Signing Docker image artifact with private key ($KeyPrivate) using Cosign Bundle format..." -ForegroundColor Green
$env:COSIGN_PASSWORD = ""
cmd /c "echo.| `"$CosignCmd`" sign-blob --key $KeyPrivate --bundle $BundleFile $DigestFile --yes"
Write-Host "[OK] Cosign bundle generated successfully -> $BundleFile" -ForegroundColor Green

# 6. Verify Signature Bundle using Public Key
Write-Host "--------------------------------------------------------" -ForegroundColor Gray
Write-Host "[+] Verifying Cosign bundle with public key ($KeyPublic)..." -ForegroundColor Green
& $CosignCmd verify-blob --key $KeyPublic --bundle $BundleFile $DigestFile
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] SIGNATURE BUNDLE VERIFICATION SUCCESSFUL: Container artifact is authentic and untampered!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] SIGNATURE BUNDLE VERIFICATION FAILED!" -ForegroundColor Red
    exit 1
}

# 7. Demonstrate Tamper Detection
Write-Host "--------------------------------------------------------" -ForegroundColor Gray
Write-Host "[+] Demonstrating Tamper Detection (Simulating modified image content)..." -ForegroundColor Green
$TamperedDigestFile = Join-Path $ArtifactsDir "tampered-digest.txt"
[System.IO.File]::WriteAllText((Resolve-Path . | Select-Object -ExpandProperty Path) + "\" + $TamperedDigestFile, "$ImageDigest-TAMPERED-BAD-HASH")

$TamperProcess = Start-Process -FilePath $CosignCmd -ArgumentList "verify-blob --key $KeyPublic --bundle $BundleFile $TamperedDigestFile" -NoNewWindow -Wait -PassThru
if ($TamperProcess.ExitCode -ne 0) {
    Write-Host "[OK] TAMPER DETECTION CONFIRMED: Cosign correctly rejected the tampered image artifact!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] TAMPER TEST FAILED: Cosign accepted a tampered image artifact!" -ForegroundColor Red
    if (Test-Path $TamperedDigestFile) { Remove-Item $TamperedDigestFile -Force }
    exit 1
}

if (Test-Path $TamperedDigestFile) {
    Remove-Item $TamperedDigestFile -Force
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "        PHASE 4 SIGNING AND VERIFICATION COMPLETE       " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# =========================================================
# Script tu dong tai va cai dat Blitz + Rose
# Chay voi quyen Administrator de tranh loi cai dat
# =========================================================

$ErrorActionPreference = "Stop"
$downloadFolder = "$env:USERPROFILE\Downloads\AutoInstall"

# Tao thu muc tam de chua file tai ve
if (-not (Test-Path $downloadFolder)) {
    New-Item -ItemType Directory -Path $downloadFolder | Out-Null
}

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# ---------------------------------------------------------
# 1. TAI VA CAI DAT BLITZ
# ---------------------------------------------------------
try {
    winget install -e --id Blitz.Blitz --accept-package-agreements --accept-source-agreements
    Write-Host "Cai dat Blitz hoan tat (winget)." -ForegroundColor Green
} catch {
    Write-Host "Loi khi cai Blitz qua winget: $_" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------
# 2. TAO THU MUC ROSE + TAI DLL TRUOC KHI CAI ROSE
# ---------------------------------------------------------

Write-Step "Dang chuan bi DLL cho Rose..."

$roseInstallPath = "C:\Program Files\Rose"
$roseToolsPath = "C:\Program Files\Rose\_internal\injection\tools"

$dllUrl = "https://github.com/edgekun/Rose-DLL/releases/download/v1.0.0/cslol-dll.dll"
$dllPath = Join-Path $roseToolsPath "cslol-dll.dll"

# Tao truoc cau truc thu muc
if (-not (Test-Path $roseToolsPath)) {
    New-Item -ItemType Directory -Path $roseToolsPath -Force | Out-Null
}

Write-Host "Thu muc DLL:"
Write-Host $roseToolsPath -ForegroundColor Gray

# Tai DLL
Write-Host ""
Write-Host "Dang tai cslol-dll.dll..." -ForegroundColor Cyan

try {
    Invoke-WebRequest `
        -Uri $dllUrl `
        -OutFile $dllPath `
        -UseBasicParsing

    Write-Host "Da tai DLL thanh cong." -ForegroundColor Green
}
catch {
    Write-Host "Loi khi tai DLL: $_" -ForegroundColor Red
    exit 1
}

# Kiem tra DLL
if (-not (Test-Path $dllPath)) {
    Write-Host "Khong tim thay DLL sau khi tai." -ForegroundColor Red
    exit 1
}

if ((Get-Item $dllPath).Length -le 0) {
    Write-Host "DLL bi rong." -ForegroundColor Red
    exit 1
}

Write-Host "DLL da san sang:" -ForegroundColor Green
Write-Host $dllPath

# ---------------------------------------------------------
# 3. TAI VA CAI DAT ROSE (tu GitHub Releases - ban moi nhat)
# ---------------------------------------------------------
Write-Host "==> Dang lay link Rose moi nhat tu GitHub..." -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/Alban1911/Rose/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
$asset = $release.assets | Where-Object { $_.name -match "\.(exe|msi)$" } | Select-Object -First 1
$roseInstaller = Join-Path $downloadFolder $asset.name
 
Write-Host "==> Dang tai Rose ($($asset.name))..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $roseInstaller -UseBasicParsing
 
Write-Host "==> Mo installer Rose de ban tu cai dat..." -ForegroundColor Cyan

# Mo installer Rose va cho den khi ban cai xong, sau do dong installer
$roseProcess = Start-Process -FilePath $roseInstaller -PassThru

Write-Host ""
Write-Host "Dang cho ban cai dat Rose..." -ForegroundColor Yellow
Write-Host "Sau khi cai xong, dong cua so installer Rose." -ForegroundColor Yellow

$roseProcess.WaitForExit()

Write-Host ""
Write-Host "Installer Rose da dong." -ForegroundColor Green
Write-Host "Dang kiem tra Rose..." -ForegroundColor Cyan

# Cho Windows them mot chut thoi gian de hoan tat viec ghi file
Start-Sleep -Seconds 3

# ---------------------------------------------------------
# 4. KIEM TRA ROSE DA CAI DAT THANH CONG
# ---------------------------------------------------------

$roseInstallPath = "C:\Program Files\Rose"

# Cac vi tri co the co Rose.exe
$roseExePaths = @(
    "C:\Program Files\Rose\Rose.exe",
    "C:\Program Files\Rose\Rose\Rose.exe"
)

$roseExe = $roseExePaths |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $roseExe) {
    Write-Host ""
    Write-Host "KHONG TIM THAY ROSE.EXE." -ForegroundColor Red
    Write-Host "Rose co the chua duoc cai dat thanh cong." -ForegroundColor Red
    Write-Host ""
    Write-Host "Script se khong mo Blitz." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Rose da duoc cai dat thanh cong." -ForegroundColor Green
Write-Host "Rose.exe:" -ForegroundColor Gray
Write-Host $roseExe -ForegroundColor Gray

# ---------------------------------------------------------
# 5. KIEM TRA DLL
# ---------------------------------------------------------

if (-not (Test-Path $dllPath)) {
    Write-Host ""
    Write-Host "KHONG TIM THAY cslol-dll.dll." -ForegroundColor Red
    Write-Host "Duong dan:" -ForegroundColor Red
    Write-Host $dllPath -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "cslol-dll.dll da san sang." -ForegroundColor Green

# ---------------------------------------------------------
# 6. TIM VA MO BLITZ
# ---------------------------------------------------------

Write-Step "Dang tim Blitz..."

$blitzExePaths = @(
    "$env:LOCALAPPDATA\Programs\Blitz\Blitz.exe",
    "$env:LOCALAPPDATA\Blitz\Blitz.exe",
    "$env:ProgramFiles\Blitz\Blitz.exe",
    "$env:ProgramFiles(x86)\Blitz\Blitz.exe"
)

$blitzExe = $blitzExePaths |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if ($blitzExe) {

    Write-Host "Tim thay Blitz:" -ForegroundColor Green
    Write-Host $blitzExe -ForegroundColor Gray

    Write-Host ""
    Write-Host "Dang mo Blitz..." -ForegroundColor Cyan

    Start-Process -FilePath $blitzExe

    Write-Host "Blitz da duoc mo." -ForegroundColor Green

}
else {

    Write-Host ""
    Write-Host "KHONG TIM THAY Blitz.exe." -ForegroundColor Red
    Write-Host "Blitz co the da cai nhung duong dan khong nam trong danh sach mac dinh." -ForegroundColor Yellow
}

# ---------------------------------------------------------
# HOAN TAT
# ---------------------------------------------------------

Write-Step "Da hoan tat cai dat."

Write-Host ""
Write-Host "Rose: $roseExe" -ForegroundColor Gray
Write-Host "DLL : $dllPath" -ForegroundColor Gray
Write-Host "Blitz: $blitzExe" -ForegroundColor Gray
Write-Host ""
Write-Host "Hoan tat." -ForegroundColor Green
$ErrorActionPreference = "Stop"

# =========================================================
# UPDATE LTK PATCHER CHO ROSE
# - Dong Rose truoc khi thay file
# - Tai 2 file moi tu GitHub
# - Backup file cu
# - Ghi de vao Rose\_internal\injection\tools
# - Mo lai Rose sau khi xong
# =========================================================

$toolsFolder = "C:\Program Files\Rose\_internal\injection\tools"

$urls = @{
    "ltk_patcher_dll.dll"  = "https://raw.githubusercontent.com/LeagueToolkit/ltk-manager/main/src-tauri/resources/ltk_patcher_dll.dll"
    "ltk_patcher_host.exe" = "https://raw.githubusercontent.com/LeagueToolkit/ltk-manager/main/src-tauri/resources/ltk_patcher_host.exe"
}

$tempFolder   = Join-Path $env:TEMP "Rose-LTK-Update"
$backupFolder = Join-Path $toolsFolder "backup"

# ---------------------------------------------------------
# 1. Yeu cau Administrator
# ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Dang yeu cau quyen Administrator..." -ForegroundColor Yellow

    $scriptPath = $MyInvocation.MyCommand.Path

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

    exit
}

# ---------------------------------------------------------
# 2. Kiem tra thu muc Rose
# ---------------------------------------------------------
if (-not (Test-Path -LiteralPath $toolsFolder -PathType Container)) {
    Write-Host "Khong tim thay:" -ForegroundColor Red
    Write-Host $toolsFolder -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Thu muc Rose tools:" -ForegroundColor Cyan
Write-Host $toolsFolder
Write-Host ""

# ---------------------------------------------------------
# 3. Dong Rose
# ---------------------------------------------------------
Write-Host "[1/6] Dang dong Rose..." -ForegroundColor Cyan

$roseProcesses = @(Get-Process -Name "Rose" -ErrorAction SilentlyContinue)

if ($roseProcesses.Count -gt 0) {
    foreach ($process in $roseProcesses) {
        try { $process.CloseMainWindow() | Out-Null } catch {}
    }

    Start-Sleep -Seconds 2

    $roseProcesses = @(Get-Process -Name "Rose" -ErrorAction SilentlyContinue)

    if ($roseProcesses.Count -gt 0) {
        $roseProcesses | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    Write-Host "Rose da duoc dong." -ForegroundColor Green
}
else {
    Write-Host "Rose khong dang chay." -ForegroundColor DarkGray
}

# ---------------------------------------------------------
# 4. Backup
# ---------------------------------------------------------
Write-Host "[2/6] Dang backup file cu..." -ForegroundColor Cyan

New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

foreach ($fileName in $urls.Keys) {
    $destination = Join-Path $toolsFolder $fileName

    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $backupPath = Join-Path $backupFolder "$fileName.$timestamp.bak"
        Copy-Item -LiteralPath $destination -Destination $backupPath -Force
        Write-Host "  Backup: $fileName" -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------
# 5. Tai va thay 2 file
# ---------------------------------------------------------
Write-Host "[3/6] Dang tai file moi tu GitHub..." -ForegroundColor Cyan

foreach ($fileName in $urls.Keys) {
    $tempPath = Join-Path $tempFolder $fileName

    Write-Host "  $fileName" -ForegroundColor White

    Invoke-WebRequest `
        -Uri $urls[$fileName] `
        -OutFile $tempPath `
        -UseBasicParsing

    if (-not (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
        throw "Khong tai duoc $fileName"
    }

    $size = (Get-Item -LiteralPath $tempPath).Length

    if ($size -le 0) {
        throw "$fileName tai ve bi rong"
    }

    Write-Host "  OK: $size bytes" -ForegroundColor Green
}

Write-Host "[4/6] Dang thay file..." -ForegroundColor Cyan

foreach ($fileName in $urls.Keys) {
    $tempPath = Join-Path $tempFolder $fileName
    $destination = Join-Path $toolsFolder $fileName

    Copy-Item -LiteralPath $tempPath -Destination $destination -Force

    Write-Host "  Da thay: $fileName" -ForegroundColor Green
}

# ---------------------------------------------------------
# 6. Kiem tra + mo lai Rose
# ---------------------------------------------------------
Write-Host "[5/6] Kiem tra file..." -ForegroundColor Cyan

foreach ($fileName in $urls.Keys) {
    $destination = Join-Path $toolsFolder $fileName

    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        throw "Khong tim thay $fileName sau khi thay"
    }

    $size = (Get-Item -LiteralPath $destination).Length

    if ($size -le 0) {
        throw "$fileName sau khi thay bi rong"
    }

    Write-Host "  OK: $fileName ($size bytes)" -ForegroundColor Green
}

Write-Host "[6/6] Dang mo lai Rose..." -ForegroundColor Cyan

$roseExeCandidates = @(
    "C:\Program Files\Rose\Rose.exe",
    "C:\Program Files (x86)\Rose\Rose.exe"
)

$roseExe = $roseExeCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $roseExe) {
    $roseRoot = Split-Path -LiteralPath $toolsFolder -Parent
    $roseExe = Join-Path $roseRoot "Rose.exe"
}

if (Test-Path -LiteralPath $roseExe -PathType Leaf) {
    Start-Process -FilePath $roseExe
    Write-Host "Rose da duoc mo lai." -ForegroundColor Green
}
else {
    Write-Host "Khong tim thay Rose.exe." -ForegroundColor Yellow
    Write-Host "File da cap nhat thanh cong. Hay mo Rose thu cong." -ForegroundColor Yellow
}

Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " CAP NHAT LTK PATCHER THANH CONG" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backup: $backupFolder" -ForegroundColor DarkGray

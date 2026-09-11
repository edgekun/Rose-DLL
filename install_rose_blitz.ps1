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
# 0. KIEM TRA VA CAI DAT CHOCOLATEY NEU CHUA CO
# ---------------------------------------------------------
Write-Host "==> Kiem tra Chocolatey..." -ForegroundColor Cyan
 
$chocoExists = Get-Command choco -ErrorAction SilentlyContinue
 
if (-not $chocoExists) {
    Write-Host "Chua tim thay Chocolatey. Dang cai dat..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Da cai dat Chocolatey thanh cong." -ForegroundColor Green
    } catch {
        Write-Host "Khong the tu dong cai Chocolatey: $_" -ForegroundColor Red
        exit 1
    }
 
    # Nap lai PATH trong phien hien tai de nhan lenh choco ngay
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
 
    $chocoExists = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoExists) {
        Write-Host "Da cai nhung chua nhan choco trong PATH. Hay dong va mo lai PowerShell roi chay lai script." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Da co Chocolatey." -ForegroundColor Green
}


# ---------------------------------------------------------
# 1. TAI VA CAI DAT BLITZ
# ---------------------------------------------------------
$downloadFolder = "$env:USERPROFILE\Downloads\AutoInstall"
if (-not (Test-Path $downloadFolder)) {
    New-Item -ItemType Directory -Path $downloadFolder | Out-Null
}
 
Write-Host "==> Dang cai dat Blitz qua Chocolatey..." -ForegroundColor Cyan
try {
    choco install blitz.gg -y
    Write-Host "Cai dat Blitz hoan tat (choco)." -ForegroundColor Green
} catch {
    Write-Host "Loi khi cai Blitz qua choco: $_" -ForegroundColor Red
    exit 1
}

Write-Host "==> Dang mo Blitz..." -ForegroundColor Cyan
$blitzExe = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Filter "Blitz.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $blitzExe) {
    $blitzExe = Get-ChildItem -Path "${env:ProgramFiles}", "${env:ProgramFiles(x86)}" -Filter "Blitz.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}
 
if ($blitzExe) {
    Start-Process -FilePath $blitzExe.FullName
    Write-Host "Da mo Blitz." -ForegroundColor Green
} else {
    Write-Host "Khong tim thay Blitz.exe de tu mo. Ban co the mo thu cong tu Start Menu." -ForegroundColor Yellow
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
# TAI VA CAI DAT ROSE (tu GitHub Releases - ban moi nhat)
# ---------------------------------------------------------
Write-Host "==> Dang lay link Rose moi nhat tu GitHub..." -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/Alban1911/Rose/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
$asset = $release.assets | Where-Object { $_.name -match "\.(exe|msi)$" } | Select-Object -First 1
$roseInstaller = Join-Path $downloadFolder $asset.name
 
Write-Host "==> Dang tai Rose ($($asset.name))..." -ForegroundColor Cyan
try {
    Start-BitsTransfer -Source $asset.browser_download_url -Destination $roseInstaller -ErrorAction Stop
} catch {
    Write-Host "BITS khong dung duoc, chuyen sang Invoke-WebRequest..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $roseInstaller -UseBasicParsing
}
 
# ---------------------------------------------------------
# CAI ROSE THU CONG VA CHO CAI DAT HOAN TAT
# ---------------------------------------------------------

Write-Host "==> Mo installer Rose de ban tu cai..." -ForegroundColor Cyan

$roseProcess = Start-Process -FilePath $roseInstaller -PassThru

Write-Host ""
Write-Host "Hay cai dat Rose binh thuong." -ForegroundColor Yellow
Write-Host "Script se tu dong chay buoc tiep theo sau khi Rose cai xong." -ForegroundColor Yellow
Write-Host ""

# Cho installer Rose ket thuc
$roseProcess.WaitForExit()

Write-Host "Installer Rose da dong." -ForegroundColor Green
Write-Host "Dang kiem tra Rose..." -ForegroundColor Cyan

# Cho Rose hoan tat viec tao file sau khi installer dong
$roseExe = "C:\Program Files\Rose\Rose.exe"
$timeout = 60
$elapsed = 0

while (-not (Test-Path $roseExe) -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2
}

if (Test-Path $roseExe) {
    Write-Host "Rose da cai dat thanh cong." -ForegroundColor Green
    Write-Host "Rose.exe: $roseExe" -ForegroundColor Gray
}
else {
    Write-Host "Khong tim thay Rose.exe sau $timeout giay." -ForegroundColor Red
    Write-Host "Script se dung de tranh chay cac buoc tiep theo khi Rose chua cai xong." -ForegroundColor Red
    exit 1
}

Write-Host "Tiep tuc buoc tiep theo..." -ForegroundColor Cyan

 
# =========================================================
# Script cap nhat game.cfg (Lien Minh Huyen Thoai)
# Sua gia tri neu da ton tai, them moi neu chua co
# Khong tao section trung lap
# =========================================================

$configPath = "G:\Online Games\LienMinhHuyenThoai\Config\game.cfg"

if (-not (Test-Path $configPath)) {
    Write-Host "Khong tim thay file: $configPath" -ForegroundColor Red
    exit 1
}

# Backup truoc khi sua, phong khi can khoi phuc
$backupPath = "$configPath.bak"
Copy-Item -Path $configPath -Destination $backupPath -Force
Write-Host "Da backup file goc tai: $backupPath" -ForegroundColor Gray

# Cac gia tri can dat, theo tung section
$settings = [ordered]@{
    "General" = [ordered]@{
        "WindowMode"          = "0"
        "Height"              = "1080"
        "Width"               = "1920"
        "WaitForVerticalSync" = "0"
    }
    "Performance" = [ordered]@{
        "ShadowQuality"       = "4"
        "FrameCapType"        = "9"
        "EnvironmentQuality"  = "4"
        "EffectsQuality"      = "4"
        "CharacterQuality"    = "4"
    }
}

$lines = Get-Content -Path $configPath

$currentSection = $null
$sectionsFound = @{}
$keysUpdated = @{}

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()

    # Nhan dien dong section, vd [General]
    if ($trimmed -match '^\[(.+)\]$') {
        $currentSection = $matches[1]
        $sectionsFound[$currentSection] = $true
        continue
    }

    if ($currentSection -and $settings.Contains($currentSection)) {
        foreach ($key in $settings[$currentSection].Keys) {
            if ($trimmed -match "^$([regex]::Escape($key))\s*=") {
                $newValue = $settings[$currentSection][$key]
                $lines[$i] = "$key=$newValue"
                $keysUpdated["$currentSection.$key"] = $true
            }
        }
    }
}

# Voi nhung key chua tim thay trong file, can them vao cuoi section tuong ung
# (hoac tao section moi neu section chua ton tai)
foreach ($section in $settings.Keys) {
    $missingKeys = @()
    foreach ($key in $settings[$section].Keys) {
        if (-not $keysUpdated.ContainsKey("$section.$key")) {
            $missingKeys += "$key=$($settings[$section][$key])"
        }
    }

    if ($missingKeys.Count -eq 0) { continue }

    if ($sectionsFound.ContainsKey($section)) {
        # Section da ton tai nhung thieu vai key -> chen vao ngay sau dong [Section]
        $newLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in $lines) {
            $newLines.Add($line)
            if ($line.Trim() -eq "[$section]") {
                foreach ($ml in $missingKeys) {
                    $newLines.Add($ml)
                }
            }
        }
        $lines = $newLines.ToArray()
    } else {
        # Section chua ton tai -> them moi vao cuoi file
        $lines += ""
        $lines += "[$section]"
        $lines += $missingKeys
    }
}

Set-Content -Path $configPath -Value $lines -Encoding UTF8

Write-Host "Da cap nhat xong game.cfg." -ForegroundColor Green
Write-Host "Neu game dang chay, hay dong game truoc khi thay doi co hieu luc." -ForegroundColor Yellow 
 
# ---------------------------------------------------------
# DARK MODE + TAT TRANSPARENCY
# ---------------------------------------------------------
Write-Host "==> Chuyen sang Dark Mode va tat hieu ung trong suot..." -ForegroundColor Cyan
$personalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $personalizeKey)) {
    New-Item -Path $personalizeKey -Force | Out-Null
}
Set-ItemProperty -Path $personalizeKey -Name "AppsUseLightTheme" -Value 0 -Type DWord
Set-ItemProperty -Path $personalizeKey -Name "SystemUsesLightTheme" -Value 0 -Type DWord
Set-ItemProperty -Path $personalizeKey -Name "EnableTransparency" -Value 0 -Type DWord
Write-Host "Da bat Dark Mode va tat transparency (co the can dang xuat/dang nhap lai de ap dung day du)." -ForegroundColor Green

# ---------------------------------------------------------
# DOI ANH NEN WINDOWS
# ---------------------------------------------------------

Write-Step "Dang tai va cai dat anh nen..."

$wallpaperUrl = "https://github.com/edgekun/Rose-DLL/releases/download/v1.2.0/newage.jpeg"
$wallpaperPath = "$env:USERPROFILE\Pictures\newage.jpeg"

try {
    Invoke-WebRequest `
        -Uri $wallpaperUrl `
        -OutFile $wallpaperPath `
        -UseBasicParsing

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni
    );
}
"@

    [Wallpaper]::SystemParametersInfo(
        20,
        0,
        $wallpaperPath,
        3
    )

    Write-Host "Da doi anh nen Windows thanh cong." -ForegroundColor Green
}
catch {
    Write-Host "Loi khi doi anh nen: $_" -ForegroundColor Red
}

# ---------------------------------------------------------
# TAT GIA TOC CHUOT (dung accelSwitch - https://github.com/jan-glx/accelSwitch)
# ---------------------------------------------------------
Write-Host "==> Dang tat gia toc chuot bang accelSwitch..." -ForegroundColor Cyan
 
$accelFolder = "$env:USERPROFILE\Downloads\accelSwitch"
if (-not (Test-Path $accelFolder)) {
    New-Item -ItemType Directory -Path $accelFolder | Out-Null
}
$accelExe = Join-Path $accelFolder "accelSwitch.exe"
 
if (-not (Test-Path $accelExe)) {
    try {
        $accelRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/jan-glx/accelSwitch/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
        $accelAsset = $accelRelease.assets | Where-Object { $_.name -eq "accelSwitch.exe" } | Select-Object -First 1
        if (-not $accelAsset) {
            $accelAsset = $accelRelease.assets | Where-Object { $_.name -match "^accelSwitch.*\.exe$" -and $_.name -notmatch "accelSwitcher" } | Select-Object -First 1
        }
        if ($accelAsset) {
            Invoke-WebRequest -Uri $accelAsset.browser_download_url -OutFile $accelExe -UseBasicParsing
        } else {
            Write-Host "Khong tim thay accelSwitch.exe trong release, bo qua buoc tat gia toc chuot." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Loi khi tai accelSwitch: $_" -ForegroundColor Yellow
    }
}
 
if (Test-Path $accelExe) {
    & $accelExe off
    Write-Host "Da tat gia toc chuot (ap dung ngay, khong can restart)." -ForegroundColor Green
}
 

# ---------------------------------------------------------
# CAI BRAVE BANG CHOCOLATEY
# ---------------------------------------------------------

Write-Step "Cai Brave"

Write-Host ""
$installBrave = Read-Host "Cai Brave? (Y/N) [Enter = Y]"

if ([string]::IsNullOrWhiteSpace($installBrave) -or $installBrave -match "^[Yy]$") {
    Write-Host "Dang cai Brave..." -ForegroundColor Cyan
    choco install brave -y
    Write-Host "Brave da cai xong." -ForegroundColor Green
}
elseif ($installBrave -match "^[Nn]$") {
    Write-Host "Bo qua Brave." -ForegroundColor Yellow
}
else {
    Write-Host "Lua chon khong hop le. Bo qua Brave." -ForegroundColor Yellow
}


# ---------------------------------------------------------
# CAI THORIUM BANG CHOCOLATEY
# ---------------------------------------------------------

Write-Step "Cai Thorium"

Write-Host ""
$installThorium = Read-Host "Cai Thorium? (Y/N) [Enter = Y]"

if ([string]::IsNullOrWhiteSpace($installThorium) -or $installThorium -match "^[Yy]$") {
    Write-Host "Dang cai Thorium..." -ForegroundColor Cyan
    choco install thorium -y
    Write-Host "Thorium da cai xong." -ForegroundColor Green
}
elseif ($installThorium -match "^[Nn]$") {
    Write-Host "Bo qua Thorium." -ForegroundColor Yellow
}
else {
    Write-Host "Lua chon khong hop le. Bo qua Thorium." -ForegroundColor Yellow
}
 
# ---------------------------------------------------------
# CAI VENCORD
# ---------------------------------------------------------

Write-Step "Cai Vencord"

$installVencord = Read-Host "Cai Vencord? (Y/N) [Enter = Y]"

if ([string]::IsNullOrWhiteSpace($installVencord) -or $installVencord -match "^[Yy]$") {

    Write-Host "Dang tai Vencord Installer..." -ForegroundColor Cyan

    $vencordUrl = "https://github.com/Vencord/Installer/releases/latest/download/VencordInstaller.exe"
    $vencordInstaller = Join-Path $downloadFolder "VencordInstaller.exe"

    Invoke-WebRequest `
        -Uri $vencordUrl `
        -OutFile $vencordInstaller `
        -UseBasicParsing

    Write-Host "Dang mo Vencord Installer..." -ForegroundColor Cyan

    Start-Process -FilePath $vencordInstaller -Wait

    Write-Host "Vencord Installer da dong." -ForegroundColor Green

}
elseif ($installVencord -match "^[Nn]$") {

    Write-Host "Bo qua Vencord." -ForegroundColor Yellow

}

 
# ---------------------------------------------------------
# ACTVE WINDOWS
# ---------------------------------------------------------

Write-Step "Active Win"

Write-Host ""
$caiWin = Read-Host "Active Win? (Y/N) [Enter = Y]"

if ([string]::IsNullOrWhiteSpace($caiWin) -or $caiWin -match "^[Yy]$") {
    Write-Host "Dang Active Win..." -ForegroundColor Cyan
    irm https://get.activated.win | iex
    Write-Host "Da Active Win xong" -ForegroundColor Green
}
elseif ($caiWin -match "^[Nn]$") {
    Write-Host "Bo qua Active Win." -ForegroundColor Yellow
}
else {
    Write-Host "Lua chon khong hop le. Bo qua Active Win." -ForegroundColor Yellow
}


# ---------------------------------------------------------
# HOAN TAT
# ---------------------------------------------------------

Write-Host ""
Write-Host "Tat ca da hoan tat. Cua so nay se tu dong dong sau 10 giay..." -ForegroundColor Green

exit
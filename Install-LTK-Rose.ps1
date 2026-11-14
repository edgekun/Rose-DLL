#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Set to $false to install only, without launching Rose afterwards.
$LaunchRoseAfterInstall = $true

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-LatestInstaller([string]$Repo, [string]$Pattern) {
    $api = "https://api.github.com/repos/$Repo/releases/latest"
    $release = Invoke-RestMethod -Uri $api -Headers @{
        'User-Agent' = 'LTK-Rose-Installer/1.0'
        'Accept'     = 'application/vnd.github+json'
    } -TimeoutSec 60

    $matches = @($release.assets | Where-Object {
        $_.name -match $Pattern -and $_.browser_download_url -match '^https://github\.com/'
    })
    if ($matches.Count -eq 0) {
        throw "No matching installer for $Repo. Check $api"
    }
    # More than one valid setup is fine. Pick one deterministically.
    $selected = $matches | Sort-Object -Property name | Select-Object -First 1
    if ($matches.Count -gt 1) {
        Write-Host "Found $($matches.Count) installers for $Repo. Selecting: $($selected.name)" -ForegroundColor Yellow
    }
    [pscustomobject]@{
        Repo    = $Repo
        Version = $release.tag_name
        Name    = $selected.name
        Url     = $selected.browser_download_url
        Size    = [long]$selected.size
    }
}

function Download-Installer($Asset, [string]$Directory) {
    $path = Join-Path $Directory $Asset.Name
    Write-Step "Downloading $($Asset.Repo) $($Asset.Version): $($Asset.Name)"
    Invoke-WebRequest -Uri $Asset.Url -OutFile $path -UseBasicParsing -TimeoutSec 1800
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Download missing: $path"
    }
    if ((Get-Item -LiteralPath $path).Length -ne $Asset.Size) {
        throw "Downloaded size does not match the GitHub release asset: $($Asset.Name)"
    }
    return $path
}

function Install-Setup([string]$File, [string]$Arguments) {
    Write-Step "Installing $(Split-Path -Path $File -Leaf)"
    $process = Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Installer exited with code $($process.ExitCode): $File"
    }
}

function Clear-LeagueRiotRunAsAdmin {
    Write-Step 'Removing League/Riot RUNASADMIN compatibility entries'
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    )) {
        $properties = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if (-not $properties) { continue }

        @($properties.PSObject.Properties) | Where-Object {
            $_.Name -notlike 'PS*' -and
            (Split-Path -Path $_.Name -Leaf) -match '^(League|Riot)' -and
            [string]$_.Value -match 'RUNASADMIN'
        } | ForEach-Object {
            Write-Host "Removing: $($_.Name)"
            Remove-ItemProperty -LiteralPath $key -Name $_.Name -ErrorAction Stop
        }
    }
}

try {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'Windows 64-bit is required.'
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if (-not $PSCommandPath) { throw 'Save this script as a .ps1 file first.' }
        Write-Step 'Requesting Administrator permission (UAC)'
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"')
        )
        return
    }

    # TLS 1.2 is required for GitHub on older PowerShell 5.1 installations.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $work = Join-Path ([IO.Path]::GetTempPath()) ("LTK-Rose-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    # Fetch only stable GitHub Releases, never source archives or portable packages.
    Write-Step 'Checking latest GitHub releases'
    $ltk  = Get-LatestInstaller 'LeagueToolkit/ltk-manager' '(?i)^LTK[ ._-]*Manager.*x64.*-setup\.exe$'
    $rose = Get-LatestInstaller 'Alban1911/Rose' '(?i)^Rose[_ -]Setup[_ -].*\.exe$'
    Write-Host "LTK:  $($ltk.Version) | $($ltk.Name)"
    Write-Host "Rose: $($rose.Version) | $($rose.Name)"

    # Download LTK first, install LTK first, do not run or inject LTK.
    $ltkFile = Download-Installer $ltk $work
    Install-Setup $ltkFile '/S'
    Write-Host 'LTK installation finished. LTK has not been launched by this script.' -ForegroundColor Green

    # Then install Rose. Inno Setup skips the post-install launch in silent mode.
    $roseFile = Download-Installer $rose $work
    Install-Setup $roseFile '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'

    # Follow the exact League/Riot registry cleanup requested.
    Clear-LeagueRiotRunAsAdmin
    Write-Host "`nInstallation and registry cleanup completed." -ForegroundColor Green

    if ($LaunchRoseAfterInstall) {
        $roseExe = Join-Path $env:ProgramFiles 'Rose\Rose.exe'
        if (Test-Path -LiteralPath $roseExe -PathType Leaf) {
            Write-Step 'Starting Rose for first-run skin data download'
            Start-Process -FilePath $roseExe
            Write-Host 'Rose started. Its internal download may continue in the application.'
        } else {
            Write-Warning "Rose.exe not found at $roseExe. Start Rose from the Start menu."
        }
    }
    Write-Host "Installers remain in: $work"
}
catch {
    Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host '`nPress Enter to close this PowerShell window.'
    [void][Console]::ReadLine()
}

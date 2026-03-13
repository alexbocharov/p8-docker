#!/usr/bin/env pwsh
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$Version,    # e.g. 8.5.6.1
    [Parameter(Mandatory=$false)][string]$BuildDate, # e.g. 20260212 (Optional)
    [Parameter(Mandatory=$false)][string]$Target = "all",
    [string]$DotNetVer = "8.0",
    [string]$OS = "bookworm-slim",
    [string]$Arch = "amd64"
)

# Detect container engine (Podman is preferred on Oracle Linux/RHEL)
$Engine = if (Get-Command podman -ErrorAction SilentlyContinue) { "podman" } else { "docker" }

# Determine the primary tag suffix
if ([string]::IsNullOrWhiteSpace($BuildDate)) {
    $TagSuffix = "latest"
} else {
    $TagSuffix = "$Version.$BuildDate"
}

$ExtraServices = @(
    "CryptoService", "EmbWebProxy", "MqActDocsService", "MqActDocsUploadService", 
    "MqAsOosService", "MqAtolService", "MqDocumentSigner", "MqFinancialDocsService", 
    "MqFrmr2Service", "MqGarService", "MqMailService", "MqMcdrService", 
    "MqMedStaffService", "MqMrkService", "MqReportService", "MqRskpService", 
    "MqSedoFssService", "MqSmev3Service", "MqTaxonomyService"
)

function Get-DockerPath ([string]$Product) {
    return "src/$Product/$DotNetVer/$OS/$Arch/Dockerfile"
}

function Build-Web {
    $DockerPath = Get-DockerPath "web"
    
    if (-not (Test-Path "archives/webcore.zip")) {
        Write-Error "CRITICAL: archives/webcore.zip not found!"
        return
    }
    if (-not (Test-Path $DockerPath)) {
        Write-Error "CRITICAL: Dockerfile not found at $DockerPath"
        return
    }

    $FullTag = "parus/web:${TagSuffix}"
    $LatestTag = "parus/web:latest"

    Write-Host "📦 Building WEB CLIENT via $Engine [$OS/$Arch] -> $FullTag" -ForegroundColor Green
    & $Engine build -f $DockerPath -t $FullTag .

    if ($LASTEXITCODE -eq 0 -and $TagSuffix -ne "latest") {
        Write-Host "🏷️ Tagging $LatestTag" -ForegroundColor Gray
        & $Engine tag $FullTag $LatestTag
    }
}

function Build-ExtraService ([string]$ServiceName) {
    $DockerPath = Get-DockerPath "services"

    if (-not (Test-Path "archives/extra.zip")) {
        Write-Error "CRITICAL: archives/extra.zip not found! Skipping $ServiceName."
        return
    }
    if (-not (Test-Path $DockerPath)) {
        Write-Error "CRITICAL: Dockerfile not found at $DockerPath"
        return
    }

    $ImageName = $ServiceName.ToLower()
    $FullTag = "parus/service/${ImageName}:${TagSuffix}"
    $LatestTag = "parus/service/${ImageName}:latest"
    
    Write-Host "⚙️ Building SERVICE [$ServiceName] via $Engine [$OS/$Arch] -> $FullTag" -ForegroundColor Cyan
    & $Engine build -f $DockerPath `
        --build-arg SRC_FOLDER="${ServiceName}Unix" `
        --build-arg FALLBACK_FOLDER="$ServiceName" `
        -t $FullTag .

    if ($LASTEXITCODE -eq 0 -and $TagSuffix -ne "latest") {
        Write-Host "🏷️ Tagging $LatestTag" -ForegroundColor Gray
        & $Engine tag $FullTag $LatestTag
    }
}

# Execution Block
try {
    Write-Host "--- Start Parus 8 Build Engine (dotnet-docker style) ---" -ForegroundColor White
    Write-Host "Engine: $Engine | Context: .NET $DotNetVer | OS $OS | Arch $Arch" -ForegroundColor Gray

    switch ($Target) {
        "all" { 
            Build-Web
            foreach ($s in $ExtraServices) { Build-ExtraService $s }
        }
        "web" { 
            Build-Web 
        }
        Default { 
            if ($ExtraServices -contains $Target) { Build-ExtraService $Target }
            else { Write-Error "Target '$Target' not recognized in ExtraServices list." }
        }
    }
}
finally {
    Write-Host "`n🧹 Cleaning up intermediate build layers..." -ForegroundColor Yellow
    & $Engine image prune -f
    Write-Host "🚀 Build process finished!" -ForegroundColor Green
}

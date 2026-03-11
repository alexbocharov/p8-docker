#!/usr/bin/env pwsh
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$Version,    # e.g. 8.5.6.1
    [Parameter(Mandatory=$true)][string]$BuildDate,  # e.g. 20260212
    [Parameter(Mandatory=$false)][string]$Target = "all",
    [string]$DotNetVer = "8.0",
    [string]$OS = "bookworm-slim",
    [string]$Arch = "amd64"
)

$TagSuffix = "$Version.$BuildDate"
$ExtraServices = @(
    "CryptoService", "EmbWebProxy", "MqActDocsService", "MqActDocsUploadService", 
    "MqAsOosService", "MqAtolService", "MqDocumentSigner", "MqFinancialDocsService", 
    "MqFrmr2Service", "MqGarService", "MqMailService", "MqMcdrService", 
    "MqMedStaffService", "MqMrkService", "MqReportService", "MqRskpService", 
    "MqSedoFssService", "MqSmev3Service", "MqTaxonomyService"
)

# Helper to resolve Dockerfile path in dotnet-docker style
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

    # Fixed: Variable delimiters added to prevent ParserError with colons
    $FullTag = "parus/web:${TagSuffix}"
    Write-Host "📦 Building WEB CLIENT [$OS/$Arch] -> $FullTag" -ForegroundColor Green
    docker build -f $DockerPath -t $FullTag .
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
    # Fixed: Variable delimiters added to prevent ParserError with colons
    $FullTag = "parus/service/${ImageName}:${TagSuffix}"
    
    Write-Host "⚙️ Building SERVICE [$ServiceName] [$OS/$Arch] -> $FullTag" -ForegroundColor Cyan
    docker build -f $DockerPath `
        --build-arg SRC_FOLDER="${ServiceName}Unix" `
        --build-arg FALLBACK_FOLDER="$ServiceName" `
        -t $FullTag .
}

# Execution Block
try {
    Write-Host "--- Start Parus 8 Build Engine (dotnet-docker style) ---" -ForegroundColor White
    Write-Host "Context: .NET $DotNetVer | OS $OS | Arch $Arch" -ForegroundColor Gray

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
    docker image prune -f
    Write-Host "🚀 Build process finished!" -ForegroundColor Green
}

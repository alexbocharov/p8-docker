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

# Detect container engine (prefers podman on RHEL/Oracle Linux)
$Engine = if (Get-Command podman -ErrorAction SilentlyContinue) { "podman" } else { "docker" }

# Determine the primary tag suffix
$TagSuffix = if ([string]::IsNullOrWhiteSpace($BuildDate)) { "latest" } else { "$Version.$BuildDate" }

# List of services that require CryptoPro installation
$CryptoRequired = @("web", "MqDocumentSigner", "CryptoService", "MqSedoFssService")

$ExtraServices = @(
    "CryptoService", "EmbWebProxy", "MqActDocsService", "MqActDocsUploadService", 
    "MqAsOosService", "MqAtolService", "MqDocumentSigner", "MqFinancialDocsService", 
    "MqFrmr2Service", "MqGarService", "MqMailService", "MqMcdrService", 
    "MqMedStaffService", "MqMrkService", "MqReportService", "MqRskpService", 
    "MqSedoFssService", "MqSmev3Service", "MqTaxonomyService"
)

# Resolves Dockerfile path based on product and service name
function Get-DockerPath ([string]$Product, [string]$ServiceName) {
    $SubFolder = $ServiceName.ToLower()
    
    # Path for Web: src/web/8.0/...
    # Path for Services: src/services/[name]/8.0/...
    $Path = if ($Product -eq "web") {
        "src/web/$DotNetVer/$OS/$Arch/Dockerfile"
    } else {
        "src/services/$SubFolder/$DotNetVer/$OS/$Arch/Dockerfile"
    }
    
    if (-not (Test-Path $Path)) {
        throw "CRITICAL: Dockerfile for '$ServiceName' not found at: $Path"
    }
    return $Path
}

function Build-Image ([string]$Product, [string]$ServiceName, [string]$ArchiveName) {
    try {
        $DockerPath = Get-DockerPath $Product $ServiceName
        
        if (-not (Test-Path "archives/$ArchiveName")) {
            Write-Error "CRITICAL: archives/$ArchiveName not found!"
            return
        }

        $ImageLower = $ServiceName.ToLower()
        $ImageBase = if ($Product -eq "web") { "parus/web" } else { "parus/service/$ImageLower" }
        $FullTag = "${ImageBase}:${TagSuffix}"
        $LatestTag = "${ImageBase}:latest"

        # Determine if CryptoPro should be installed via build-arg
        $InstallCrypto = if ($CryptoRequired -contains $ServiceName) { "true" } else { "false" }

        Write-Host "📦 Building [$ServiceName] via $Engine using $DockerPath" -ForegroundColor Cyan
        Write-Host "   Context: CryptoPro=$InstallCrypto | Arch=$Arch" -ForegroundColor Gray

        & $Engine build -f $DockerPath `
            --build-arg SRC_FOLDER="${ServiceName}Unix" `
            --build-arg FALLBACK_FOLDER="$ServiceName" `
            --build-arg INSTALL_CRYPTO="$InstallCrypto" `
            -t $FullTag .

        # Tag as latest if a specific version was built successfully
        if ($LASTEXITCODE -eq 0 -and $TagSuffix -ne "latest") {
            Write-Host "🏷️ Tagging $LatestTag" -ForegroundColor Gray
            & $Engine tag $FullTag $LatestTag
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

# Execution Block
try {
    Write-Host "--- Parus 8 Build Engine (Explicit Path Mode) ---" -ForegroundColor White
    Write-Host "Engine: $Engine | TagMode: $TagSuffix | Context: .NET $DotNetVer/$OS" -ForegroundColor Gray

    switch ($Target) {
        "all" { 
            Build-Image "web" "web" "webcore.zip"
            foreach ($s in $ExtraServices) { Build-Image "service" $s "extra.zip" }
        }
        "web" { 
            Build-Image "web" "web" "webcore.zip"
        }
        Default { 
            if ($ExtraServices -contains $Target) { 
                Build-Image "service" $Target "extra.zip" 
            } else { 
                Write-Error "Target '$Target' not recognized in the services list." 
            }
        }
    }
}
finally {
    Write-Host "`n🧹 Cleaning up intermediate build layers..." -ForegroundColor Yellow
    & $Engine image prune -f
    Write-Host "🚀 Build process finished!" -ForegroundColor Green
}

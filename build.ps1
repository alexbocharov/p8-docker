#!/usr/bin/env pwsh
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$Version,    # e.g., 8.561.0.0
    [Parameter(Mandatory=$false)][string]$BuildDate, # e.g., 20260212 (Optional)
    [Parameter(Mandatory=$false)][string]$Target = "all",
    [string]$DotNetVer = "8.0",
    [string]$OS = "bookworm-slim",                   # Default OS
    [string]$Arch = "amd64"
)

# Detect container engine (prefers podman on RHEL/Oracle Linux systems)
$Engine = if (Get-Command podman -ErrorAction SilentlyContinue) { "podman" } else { "docker" }

# List of services requiring CryptoPro CSP installation
$CryptoRequired = @("web", "MqDocumentSigner", "CryptoService", "MqSedoFssService")

# List of additional background services
$ExtraServices = @(
    "CryptoService", "EmbWebProxy", "MqActDocsService", "MqActDocsUploadService", 
    "MqAsOosService", "MqAtolService", "MqDocumentSigner", "MqFinancialDocsService", 
    "MqFrmr2Service", "MqGarService", "MqMailService", "MqMcdrService", 
    "MqMedStaffService", "MqMrkService", "MqReportService", "MqRskpService", 
    "MqSedoFssService", "MqSmev3Service", "MqTaxonomyService"
)

# Resolves Dockerfile path based on product type and service name
function Get-DockerPath ([string]$Product, [string]$ServiceName) {
    $SubFolder = $ServiceName.ToLower()
    
    # Pathing: src/[web|services]/[version]/[os]/[arch]/Dockerfile
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

# Handles the build process and multi-tagging logic
function Build-Image ([string]$Product, [string]$ServiceName, [string]$ArchiveName) {
    try {
        $DockerPath = Get-DockerPath $Product $ServiceName
        
        if (-not (Test-Path "archives/$ArchiveName")) {
            Write-Error "CRITICAL: archives/$ArchiveName missing!"
            return
        }

        $ImageLower = $ServiceName.ToLower()
        $ImageBase = if ($Product -eq "web") { "parus/web" } else { "parus/service/$ImageLower" }
        
        # Multi-Tag Logic Generation
        $TagList = New-Object System.Collections.Generic.List[string]
        
        # Version components (8.561.0.0 -> 8.561)
        $VerParts = $Version.Split('.')
        $ShortVer = if ($VerParts.Count -ge 2) { "$($VerParts[0]).$($VerParts[1])" } else { $Version }
        $FullVersion = if ([string]::IsNullOrWhiteSpace($BuildDate)) { $Version } else { "$Version.$BuildDate" }

        # 1. Primary OS-specific tags (e.g., 8.561.0.0-redos-ubi8)
        # We add these first so the build command uses a specific tag as its primary reference
        $TagList.Add("${FullVersion}-${OS}")
        $TagList.Add("${ShortVer}-${OS}")
        $TagList.Add($OS)

        # 2. "Clean" version tags (ONLY for the default OS to avoid overwriting)
        if ($OS -eq "bookworm-slim") {
            $TagList.Add($FullVersion) # e.g., parus/web:8.561.0.0
            $TagList.Add($ShortVer)    # e.g., parus/web:8.561
            $TagList.Add("latest")      # e.g., parus/web:latest
        }

        # Build Arguments
        $InstallCrypto = if ($CryptoRequired -contains $ServiceName) { "true" } else { "false" }
        $PrimaryTag = "${ImageBase}:$($TagList[0])"

        Write-Host "📦 Building [$ServiceName] via $Engine" -ForegroundColor Cyan
        Write-Host "   Tags: $($TagList -join ', ')" -ForegroundColor Gray
        Write-Host "   Context: CryptoPro=$InstallCrypto | Arch=$Arch" -ForegroundColor Gray

        # Execution
        & $Engine build -f $DockerPath `
            --build-arg SRC_FOLDER="${ServiceName}Unix" `
            --build-arg FALLBACK_FOLDER="$ServiceName" `
            --build-arg INSTALL_CRYPTO="$InstallCrypto" `
            -t $PrimaryTag .

        if ($LASTEXITCODE -eq 0) {
            # Apply all additional tags from the generated list
            for ($i = 1; $i -lt $TagList.Count; $i++) {
                $AdditionalTag = "${ImageBase}:$($TagList[$i])"
                Write-Host "🏷️ Tagging $AdditionalTag" -ForegroundColor Gray
                & $Engine tag $PrimaryTag $AdditionalTag
            }
        } else {
            throw "Build process exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "Failed to build ${ServiceName}: $($_.Exception.Message)"
    }
}

# Execution Block
try {
    Write-Host "`n--- Parus 8 Build Engine ---" -ForegroundColor White
    Write-Host "Engine: $Engine | OS: $OS | .NET: $DotNetVer" -ForegroundColor Gray

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
                Write-Error "Target '$Target' not recognized." 
            }
        }
    }
}
finally {
    Write-Host "`n🧹 Cleaning up intermediate build layers..." -ForegroundColor Yellow
    & $Engine image prune -f
    Write-Host "🚀 Build process finished!" -ForegroundColor Green
}

# Extraction
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS extractor
USER root
ARG SRC_FOLDER
ARG FALLBACK_FOLDER
WORKDIR /tmp

# Install unzip and clean cache
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*

# Copy extra.zip containing microservices
COPY archives/extra.zip .
RUN unzip extra.zip -d out

# Prioritize Unix-specific folder, fallback to standard if missing
RUN if [ -d "out/extra/${SRC_FOLDER}" ]; then \
        mv "out/extra/${SRC_FOLDER}" /final; \
    else \
        mv "out/extra/${FALLBACK_FOLDER}" /final; \
    fi

# Process JSON files to trim arrays
RUN pwsh -Command " \
    Get-ChildItem -Path /final -Filter *.json -Recurse | ForEach-Object { \
        try { \
            \$path = \$_.FullName; \
            \$json = Get-Content \$path -Raw | ConvertFrom-Json -ErrorAction Stop; \
            \
            function Trim-Arrays([object]\$data) { \
                if (\$data -is [System.Management.Automation.PSCustomObject]) { \
                    foreach (\$prop in \$data.psobject.Properties) { \
                        if (\$prop.Value -is [System.Collections.IList]) { \
                            if (\$prop.Value.Count -gt 1) { \
                                \$prop.Value = @(\$prop.Value[0]); \
                            } \
                            \$prop.Value | ForEach-Object { Trim-Arrays \$_ }; \
                        } \
                        elseif (\$prop.Value -is [System.Management.Automation.PSCustomObject]) { \
                            Trim-Arrays \$prop.Value; \
                        } \
                    } \
                } \
            } \
            \
            Trim-Arrays \$json; \
            \$json | ConvertTo-Json -Depth 20 -Compress | Set-Content \$path; \
            Write-Host 'Trimmed arrays in: ' \$path; \
        } catch { \
            Write-Host 'Skipping (not a valid JSON): ' \$path; \
        } \
    }"

# Clean up debug symbols and documentation inside /final
RUN find /final -type f \( -name "*.pdb" -o -name "*.md" -o -name "*.txt" \) -delete

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Install system dependencies required for MqReportService rendering and globalization
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdiplus \
    libc6-dev \
    libicu72 \
    libfreetype6 \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Copy final binaries from extractor stage
COPY --from=extractor /final ./

# Create symbolic link for freetype to ensure compatibility with System.Drawing in .NET 8
# This maps the Linux library to the Windows-style name expected by some .NET components
RUN ln -s /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /app/freetype.dll

# Static entrypoint for MqReportService
ENTRYPOINT ["dotnet", "MqReportService.dll", "--provider=self"]

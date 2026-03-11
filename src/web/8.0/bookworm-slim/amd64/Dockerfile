# Extraction
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS extractor
USER root
WORKDIR /tmp

# Install 7zip for robust archive handling
RUN apt-get update && apt-get install -y --no-install-recommends 7zip \
    && rm -rf /var/lib/apt/lists/*

# Copy the source archive from the local repository
COPY archives/webcore.zip .

# Extract main archive and find the nested linux-x64.zip for further extraction
RUN 7zz x webcore.zip -os1 && \
    INNER_ZIP=$(find s1 -name "linux-x64.zip") && \
    7zz x "$INNER_ZIP" -os2

# Process JSON files to trim arrays
RUN pwsh -Command " \
    Get-ChildItem -Path /tmp/s2 -Filter *.json -Recurse | ForEach-Object { \
        try { \
            \$path = \$_.FullName; \
            \$json = Get-Content \$path -Raw | ConvertFrom-Json -ErrorAction Stop; \
            \
            # Function to recursively trim arrays to their first element \
            function Trim-Arrays([object]\$data) { \
                if (\$data -is [System.Collections.IList]) { \
                    return Trim-Arrays \$data[0] \
                } \
                if (\$data -is [System.Management.Automation.PSCustomObject]) { \
                    foreach (\$prop in \$data.psobject.Properties) { \
                        if (\$prop.Value -is [System.Collections.IList] -and \$prop.Value.Count -gt 1) { \
                            \$prop.Value = @(\$prop.Value[0]); \
                        } \
                        Trim-Arrays \$prop.Value; \
                    } \
                } \
            } \
            \
            Trim-Arrays \$json; \
            \$json | ConvertTo-Json -Depth 20 -Compress | Set-Content \$path; \
            Write-Host 'Processed: ' \$path; \
        } catch { \
            Write-Host 'Skipping: ' \$_.Exception.Message \
        } \
    }"

# Clean up debug symbols and documentation to reduce image size
RUN find /tmp/s2/p8web/p8webcore/linux-x64 -name "*.pdb" -delete -o -name "*.md" -delete -o -name "*.txt" -delete

# Runtime (Optimized for Self-contained apps)
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0
WORKDIR /app

# Install ICU libraries (Required for globalization/dates/currencies in Parus 8)
RUN apt-get update && apt-get install -y --no-install-recommends libicu72 \
    && rm -rf /var/lib/apt/lists/*

# Install CryptoPro CSP dependencies (Required for cryptographic operations in Parus 8)
COPY tools /tmp/tools 
RUN cd /tmp/tools && \
    tar -xzf linux-amd64_deb.tgz && \
    linux-amd64_deb/install.sh && \
    cd /bin && \
    ln -s /opt/cprocsp/bin/amd64/certmgr && \
    ln -s /opt/cprocsp/bin/amd64/cpverify && \
    ln -s /opt/cprocsp/bin/amd64/cryptcp && \
    ln -s /opt/cprocsp/bin/amd64/csptest && \
    ln -s /opt/cprocsp/bin/amd64/csptestf && \
    ln -s /opt/cprocsp/bin/amd64/der2xer && \
    ln -s /opt/cprocsp/bin/amd64/inittst && \
    ln -s /opt/cprocsp/bin/amd64/wipefile && \
    ln -s /opt/cprocsp/sbin/amd64/cpconfig && \
    rm -rf /tmp/tools

# Copy the extracted binaries from the extractor stage
COPY --from=extractor /tmp/s2/p8web/p8webcore/linux-x64 ./

# Create symbolic links for CAPI libraries to ensure compatibility with .NET 8's expectations
RUN ln -s /opt/cprocsp/lib/amd64/libcapi20.so crypt32.dll && \
    ln -s /opt/cprocsp/lib/amd64/libcapi10.so advapi32.dll && \
    ln -s /opt/cprocsp/lib/amd64/libcapi10.so kernel32.dll

# Ensure the main binary has execute permissions
RUN chmod +x ./WebClientCore

# .NET 8 Environment Configuration
# Using port 8080 as the modern .NET 8 standard
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

# Run the binary directly (Self-contained mode)
ENTRYPOINT ["./WebClientCore"]
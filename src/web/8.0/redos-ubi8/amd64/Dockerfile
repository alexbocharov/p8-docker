# Extraction & Processing ---
FROM registry.red-soft.ru/ubi8/ubi AS extractor
USER root
WORKDIR /tmp

# Install 7zip, PowerShell (pwsh), and utilities for RED OS 8
RUN dnf update -y && \
    dnf install -y p7zip p7zip-plugins powershell findutils && \
    dnf clean all

# Path adjusted to project root context
COPY archives/webcore.zip .

# Extract archives (Note: RED OS uses '7z' command)
RUN 7z x webcore.zip -os1 && \
    INNER_ZIP=$(find s1 -name "linux-x64.zip") && \
    7z x "$INNER_ZIP" -os2

# Process JSON files via PowerShell to trim arrays
RUN pwsh -Command " \
    Get-ChildItem -Path /tmp/s2 -Filter *.json -Recurse | ForEach-Object { \
        try { \
            \$path = \$_.FullName; \
            \$json = Get-Content \$path -Raw | ConvertFrom-Json -ErrorAction Stop; \
            function Trim-Arrays([object]\$data) { \
                if (\$data -is [System.Collections.IList]) { \
                    if (\$data.Count -gt 0) { return @(Trim-Arrays \$data[0]) } else { return \$data } \
                } \
                if (\$data -is [System.Management.Automation.PSCustomObject]) { \
                    foreach (\$prop in \$data.psobject.Properties) { \
                        if (\$prop.Value -is [System.Collections.IList] -and \$prop.Value.Count -gt 1) { \
                            \$prop.Value = @(\$prop.Value[0]); \
                        } \
                        Trim-Arrays \$prop.Value; \
                    } \
                } \
                return \$data \
            } \
            \$trimmed = Trim-Arrays \$json; \
            \$trimmed | ConvertTo-Json -Depth 20 -Compress | Set-Content \$path; \
        } catch { Write-Host 'Skipping: ' \$_.Exception.Message } \
    }"

# Remove debug symbols and documentation
RUN find /tmp/s2/p8web/p8webcore/linux-x64 -name "*.pdb" -delete -o -name "*.md" -delete -o -name "*.txt" -delete


# Runtime (RED OS 8) ---
FROM registry.red-soft.ru/ubi8/ubi
WORKDIR /app

ARG INSTALL_CRYPTO=false

# Install .NET 8 dependencies via dnf
RUN dnf update -y && \
    dnf install -y libicu openssl-libs krb5-libs zlib && \
    dnf clean all

# Path adjusted: ensure tools/ exists at the root of p8-docker
COPY tools/ /tmp/tools/
RUN if [ "$INSTALL_CRYPTO" = "true" ] && [ -f /tmp/tools/linux-amd64_rpm.tgz ]; then \
        cd /tmp/tools && tar -xzf linux-amd64_rpm.tgz && \
        ./linux-amd64_rpm/install.sh && \
        for util in certmgr cpverify cryptcp csptest csptestf der2xer inittst wipefile; do \
            ln -s /opt/cprocsp/bin/amd64/$util /usr/bin/$util; done && \
        ln -s /opt/cprocsp/sbin/amd64/cpconfig /usr/sbin/cpconfig; \
    fi && rm -rf /tmp/tools

# Copy binaries from the extractor stage
COPY --from=extractor /tmp/s2/p8web/p8webcore/linux-x64 ./

# Create CAPI symbolic links for CryptoPro compatibility
RUN if [ "$INSTALL_CRYPTO" = "true" ]; then \
        ln -s /opt/cprocsp/lib/amd64/libcapi20.so crypt32.dll && \
        ln -s /opt/cprocsp/lib/amd64/libcapi10.so advapi32.dll && \
        ln -s /opt/cprocsp/lib/amd64/libcapi10.so kernel32.dll; \
    fi

# Path adjusted for scripts/
COPY scripts/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh ./WebClientCore

ENV ASPNETCORE_HTTP_PORTS=8080
ENV CPROCSP_LICENSE=""
EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]
CMD ["./WebClientCore"]

#!/bin/sh
# Exit immediately if a command exits with a non-zero status
set -e

# Path to the CryptoPro license configuration utility
CPCONFIG="/opt/cprocsp/sbin/amd64/cpconfig"

echo "--- Container Startup Sequence ---"

# 1. Optional CryptoPro CSP License Activation
if [ -x "$CPCONFIG" ]; then
    if [ -n "$CPROCSP_LICENSE" ]; then
        echo "[CryptoPro] Activating license..."
        if "$CPCONFIG" -license -set "$CPROCSP_LICENSE" >/dev/null 2>&1; then
            echo "[CryptoPro] License successfully applied."
            "$CPCONFIG" -license -view
        else
            echo "[CryptoPro] WARNING: Failed to apply license. Check key format or permissions."
        fi
    else
        echo "[CryptoPro] No license key provided (CPROCSP_LICENSE is empty). Skipping activation."
    fi
else
    # Only show this if you expect CryptoPro to be there but it's missing
    echo "[System] CryptoPro CSP not detected at $CPCONFIG. Proceeding without GOST cryptography."
fi

# 2. Check for Application Binary
if [ -z "$1" ]; then
    echo "[Error] No command or binary specified for execution. Check CMD in Dockerfile."
    exit 1
fi

# 3. Hand over execution to the main application process
echo "--- Starting Application: $@ ---"
exec "$@"
# 🚢 Parus 8 Docker 🐳

Automated Docker image construction engine for **Parus 8 Web Client** and **Microservices** based on **.NET 8+**.

## ⚖️ Legal Disclaimer

> [!IMPORTANT]  
> This repository **does not contain** any Parus 8 software binaries or distribution packages.
> This repository **does not distribute** CryptoPro CSP 5.0 or any of its components.

- The source archives (`webcore.zip` and `extra.zip`) are the **exclusive property of the copyright holder**.
- The source archive `linux-amd64_deb.tgz` are the **exclusive property of the copyright holder**.
- Users must obtain these archives directly from the official software provider or copyright owner.
- This repository is provided solely as an **automation tool** to facilitate the containerization of legally acquired software.

## 📂 Repository Structure

The repository follows a hierarchical structure for better scalability and multi-architecture support.

```text
/p8-docker
├── archives/                                   # [Drop Zone] Place webcore.zip and extra.zip here
├── tools/                                      # [Drop Zone] Place linux-amd64_deb.tgz here
├── src/
│   ├── web/                                    # Web Client product logic
│   │   └── 8.0/bookworm-slim/amd64/Dockerfile  # Default Debian image (clean tags point here)
│   │   └── 8.0/redos-ubi8/amd64/Dockerfile     # RED OS 8 image (tagged with -redos-ubi8 suffix)
│   └── service/                                # Microservices product logic
│       └── 8.0/bookworm-slim/amd64/Dockerfile  # Default Debian image for services
├── build.ps1                                   # Unified Build Engine (PowerShell Core)
├── .gitignore                                  # Prevents binaries from being committed to Git
└── .dockerignore                               # Optimizes Docker build context by excluding junk
```

## 🚀 Getting Started

### 1. Prepare Archives

Place the following distribution files in the archives/ folder:

* `webcore.zip`: Contains the core Web Client assets.
* `extra.zip`: Contains microservices (MqDocumentSigner, MqReportService, EmbWebProxy, etc.).

### 2. Build Execution

The `build.ps1` script handles versioning, lowercase naming, and folder logic (prioritizing *Unix folders for Linux compatibility).

**Build with specific version and date (tags as both `version.date` and `latest`):**
```pwsh
./build.ps1 -Version "8.561.0.0" -BuildDate "20260212" -Target "all"
```

**Build with latest tag only (omitting BuildDate):**
```pwsh
./build.ps1 -Version "8.561.0.0" -Target "all"
```

**Build a specific service (e.g., MqDocumentSigner):**
```pwsh
./build.ps1 -Version "8.561.0.0" -Target "MqDocumentSigner"
```

## 🏗 Image Naming & Tagging

The build engine uses a multi-tier tagging strategy. **"Clean" tags** (without an OS suffix) are mapped to the default **Debian (bookworm-slim)** image for optimal size.

### Supported Tags & OS Mapping


| OS Flavor | Version + Date Tag (Example) | Short Version Tag | OS Alias / Latest | Default |
| :--- | :--- | :--- | :--- | :---: |
| **Debian 12** | `8.561.0.0.20260212` | `8.561` | `bookworm-slim`, `latest` | ✅ |
| **RED OS 8** | `8.561.0.0.20260212-redos-ubi8` | `8.561-redos-ubi8` | `redos-ubi8` | ❌ |

### Tagging Logic
- **Full Versioning:** If `-BuildDate` is provided, images are tagged as `[Version].[BuildDate]`.
- **OS Specifics:** Use the `-OS` parameter to build for different environments. Non-default OS images always append the OS name to the tag (e.g., `-redos-ubi8`).
- **Short Tags:** The engine automatically creates a major.minor tag (e.g., `8.561`) for easier updates.

### Examples

**Pull the latest stable (Debian):**
```bash
docker pull parus/web:latest
```

**Pull a specific certified build (RED OS):**
```bash
docker pull parus/web:8.561.0.0.20260212-redos-ubi8
```

> [!TIP]
> If you omit -BuildDate, the engine will skip the date-stamped tags and update the latest and [OS] aliases only.

## 🛠 Technical Implementation

* **Base OS:** Built on **Debian 12 (Bookworm)** via [https://mcr.microsoft.com](https://mcr.microsoft.com/). This ensures maximum compatibility with Parus 8 binaries requiring standard glibc.
* **Smart Extraction:** The engine automatically prioritizes `[Name]Unix` folders within `extra.zip`, falling back to `[Name]` if a Unix-specific version is unavailable (e.g., `EmbWebProxy`).
* **Multi-stage Builds:** An intermediate extractor stage (running as root) handles unzip operations, ensuring the final runtime stage remains clean and secure.
* **Dynamic Entrypoint:** Service containers use a shell launcher to automatically identify and execute the primary `.dll` file (matching Mq*, Proxy, or Service patterns).
* **Auto-Cleanup:** The build script automatically triggers docker image prune after completion to remove intermediate layers and reclaim disk space.

## ⚙️ Requirements

* **Container Engine:** Docker Engine 24.0+, Podman 4.0+, or Docker Desktop
* **PowerShell Core:** 7.0+ (Install via `brew install --cask powershell` on macOS)
* **Storage:** At least 10GB of free space is recommended for intermediate extraction layers during full builds.
* **Operating Systems:**
  * **Linux:** Ubuntu, Debian, Oracle Linux, RHEL, etc.
  * **macOS:** Intel or Apple Silicon (via Docker Desktop, OrbStack, or Podman)
  * **Windows:** via WSL2 (Ubuntu/Debian) or PowerShell Core directly

## 🤝 **Community Standards**
We value respectful and constructive interactions. Please refer to our [Code of Conduct](CODE_OF_CONDUCT.md) for detailed guidelines on community behavior.

## 📄 **License**
This repository is licensed under a MIT License. Please see the [LICENSE](LICENSE) file for more details.
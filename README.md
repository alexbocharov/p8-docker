# P8 Docker

Automated Docker image construction engine for **Parus 8 Web Client** and **Microservices** based on **.NET 8+**.

## ⚖️ Legal Disclaimer

> [!IMPORTANT]  
> This repository **does not contain** any Parus 8 software binaries or distribution packages. 

- The source archives (`webcore.zip` and `extra.zip`) are the **exclusive property of the copyright holder**.
- The source archive `linux-amd64_deb.tgz` are the **exclusive property of the copyright holder**.
- Users must obtain these archives directly from the official software provider or copyright owner.
- This repository is provided solely as an **automation tool** to facilitate the containerization of legally acquired software.

## 📂 Repository Structure

The repository follows a hierarchical structure for better scalability and multi-architecture support.

```text
/p8-docker
├── archives/               # [Drop Zone] Place webcore.zip and extra.zip here
├── tools/                  # [Drop Zone] Place linux-amd64_deb.tgz here
├── src/
│   ├── web/                # Web Client product logic
│   │   └── 8.0/bookworm/amd64/Dockerfile
│   └── service/            # Microservices product logic
│       └── 8.0/bookworm/amd64/Dockerfile
├── build.ps1               # Unified Build Engine (PowerShell Core)
├── .gitignore              # Prevents binaries from being committed to Git
└── .dockerignore           # Optimizes Docker build context by excluding junk
```

## 🚀 Getting Started

### 1. Prepare Archives

Place the following distribution files in the archives/ folder:

* `webcore.zip`: Contains the core Web Client assets.
* `extra.zip`: Contains microservices (MqDocumentSigner, MqReportService, EmbWebProxy, etc.).

### 2. Build Execution

The `build.ps1` script handles versioning, lowercase naming, and folder logic (prioritizing *Unix folders for Linux compatibility).

**Build everything (Web + All Services):**

```pwsh
./build.ps1 -Version "8.5.6.1" -BuildDate "20260212" -Target "all"
```

**Build only the Web Client:**

```pwsh
./build.ps1 -Version "8.5.6.1" -BuildDate "20260212" -Target "web"
```

**Build a specific service (e.g., MqDocumentSigner):**

```pwsh
./build.ps1 -Version "8.5.6.1" -BuildDate "20260212" -Target "MqDocumentSigner"
```

## 🏗 Image Naming & Tagging

Images are tagged using the format: `parus/[type]/[name]:[version].[date]`

| Component | Source Archive | Target Docker Image Tag (Example) |
|---|---|---|
| Web Client | `webcore.zip` | `parus/web:8.5.6.1.20260212` |
| Microservices | `extra.zip` | `parus/service/[name]:8.5.6.1.20260212` |

## 🛠 Technical Implementation

* **Base OS:** Built on **Debian 12 (Bookworm)** via [https://mcr.microsoft.com](https://mcr.microsoft.com/). This ensures maximum compatibility with Parus 8 binaries requiring standard glibc.
* **Smart Extraction:** The engine automatically prioritizes `[Name]Unix` folders within `extra.zip`, falling back to `[Name]` if a Unix-specific version is unavailable (e.g., `EmbWebProxy`).
* **Multi-stage Builds:** An intermediate extractor stage (running as root) handles unzip operations, ensuring the final runtime stage remains clean and secure.
* **Dynamic Entrypoint:** Service containers use a shell launcher to automatically identify and execute the primary `.dll` file (matching Mq*, Proxy, or Service patterns).
* **Auto-Cleanup:** The build script automatically triggers docker image prune after completion to remove intermediate layers and reclaim disk space.

## ⚙️ Requirements

* Docker Engine 24.0+
* PowerShell Core 7.0+
* Storage: At least 10GB of free space is recommended for intermediate extraction layers during full builds.

## 🤝 **Community Standards**
We value respectful and constructive interactions. Please refer to our [Code of Conduct](CODE_OF_CONDUCT.md) for detailed guidelines on community behavior.

## 📄 **License**
This repository is licensed under a MIT License. Please see the [LICENSE](LICENSE) file for more details.
# 01 - Environment Setup & Prerequisites

This section guides an engineer from a fresh Ubuntu Linux or Windows WSL2 installation to a fully operational, containerized open-source ASIC design environment capable of compiling, synthesizing, and timing the AFTxAI SoC.

---

## 1. Hardware & Operating System Requirements

- **Host Operating System:** Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, Debian 12, or Windows 11 with WSL2 (Ubuntu).
- **CPU:** 4 physical cores minimum (8 cores recommended).
- **RAM:** 16 GB minimum (32 GB recommended for full-chip gate-level optimization and place-and-route).
- **Disk Storage:** At least 40 GB free space on SSD (container images require ~15 GB, synthesis netlists and STA databases require ~5-10 GB).

---

## 2. Docker Engine Installation (Fresh Machine)

Ensure the official Docker Engine is installed and configured for non-root execution.

### Ubuntu / Debian:
```bash
# Update repository index and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and CLI
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the 'docker' group to run commands without sudo
sudo usermod -aG docker "$USER"
newgrp docker
```

---

## 3. Pulling and Building the EDA Container

AFTxAI uses OpenROAD Flow Scripts (ORFS) as the foundation. ORFS provides:
- **Yosys** with the native C++ **read_slang** SystemVerilog-2017 frontend plugin.
- **OpenROAD** with integrated OpenSTA timing engine and database.
- Complete **SkyWater SKY130 (sky130hd)** PDK liberty, LEF, GDS, and rule files.

Because standalone ORFS images do not include Verilator, AFTxAI extends the image using `synth/docker/Dockerfile`.

Run the automated setup script:
```bash
bash synth/scripts/setup_eda.sh
```

Or execute manually:
```bash
# Step 1: Pull base OpenROAD Flow Scripts image
docker pull openroad/orfs:latest

# Step 2: Build the extended image containing Verilator
docker build -t aftxai_eda:latest -f synth/docker/Dockerfile synth/docker
```

### Exact Verified Digests:
- **Base image:** `openroad/orfs:latest` (`sha256:166f512b73119e3f2af6e21b8a51f9fdddaf1a25f7809834c52174dc41ebda95`)
- **Yosys Version:** `0.68+post` with `read_slang` plugin
- **OpenROAD Version:** OpenROAD 2.0 release
- **Verilator Version:** `5.032 2025-01-01 rev (Debian 5.032-1)`

---

## 4. Verifying the Installation

Execute the environment sanity check script:
```bash
bash synth/scripts/check_environment.sh
```

**Expected Successful Output:**
```text
============================================================
 AFTxAI: EDA Environment & Prerequisites Sanity Check
============================================================
Host Operating System: Linux ... x86_64
Host User:             ... (UID: 1000, GID: 1000)
Repository Path:       .../AFTxAI
[OK] Docker CLI detected: Docker version 29.1.3...
[OK] Docker daemon is running and accessible without sudo.
[OK] Docker image 'aftxai_eda:latest' found.
==> Testing EDA tools inside Docker container...
  - Yosys:     Yosys 0.68+post
  - Slang:     slang revision active
  - OpenROAD:  OpenROAD active
  - Verilator: Verilator 5.032 2025-01-01
============================================================
[SUCCESS] Environment sanity check passed completely!
============================================================
```

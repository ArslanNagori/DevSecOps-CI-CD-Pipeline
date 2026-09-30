#!/bin/bash
# Prepares an Ubuntu EC2 instance (Jenkins already installed) for the DevSecOps pipeline.
# Installs Docker, Trivy and Node.js; sets kernel settings and swap for SonarQube;
# creates the Dependency-Check data folder; starts SonarQube in Docker.
# Run as a normal user with sudo:  bash scripts/install-tools.sh
set -euo pipefail

echo "==> Base packages"
sudo apt-get update
sudo apt-get install -y docker.io nodejs unzip wget gnupg lsb-release apt-transport-https curl

echo "==> Docker access for the current user and jenkins"
sudo usermod -aG docker "$USER"
if id jenkins >/dev/null 2>&1; then
    sudo usermod -aG docker jenkins
    sudo systemctl restart jenkins
fi

echo "==> Trivy"
if ! command -v trivy >/dev/null 2>&1; then
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y trivy
fi

echo "==> Kernel settings required by SonarQube (Elasticsearch)"
for kv in "vm.max_map_count=262144" "fs.file-max=65536"; do
    key="${kv%%=*}"
    sudo sysctl -w "$kv"
    grep -q "^${key}=" /etc/sysctl.conf || echo "$kv" | sudo tee -a /etc/sysctl.conf >/dev/null
done

echo "==> 2 GB swap file (protects against memory spikes during scans)"
if ! sudo swapon --show | grep -q '/swapfile'; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

echo "==> Dependency-Check data folder (keeps the NVD database between builds)"
sudo mkdir -p /var/lib/jenkins/odc-data
if id jenkins >/dev/null 2>&1; then
    sudo chown jenkins:jenkins /var/lib/jenkins/odc-data
fi

echo "==> SonarQube (Community) in Docker"
if ! sudo docker ps -a --format '{{.Names}}' | grep -qx sonarqube; then
    sudo docker run -d --name sonarqube --restart unless-stopped -p 9000:9000 sonarqube:lts-community
fi

echo
echo "Done. Log out and back in so the docker group applies to your shell."
echo "Check versions:  node -v   trivy --version   docker --version"

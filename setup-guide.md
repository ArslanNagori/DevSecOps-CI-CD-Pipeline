# Setup guide

Everything needed to rebuild this pipeline from scratch.

## 1. EC2 instance

| Setting | Value |
|---|---|
| OS | Ubuntu 22.04 or 24.04 LTS |
| Size | `t3.large` (2 vCPU, 8 GB RAM) recommended. SonarQube alone needs about 2-3 GB, and Dependency-Check spikes to 1-2 GB. |
| Disk | 30 GB gp3 minimum, 40-50 GB if you build several images |
| Elastic IP | Yes, so the address survives stop/start |

Security group (inbound, **your IP only**): `22` (SSH), `8080` (Jenkins), `9000` (SonarQube).

## 2. Install Jenkins

Follow the official guide for Ubuntu: <https://www.jenkins.io/doc/book/installing/linux/>. Open `http://<elastic-ip>:8080`, unlock with `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`, install the suggested plugins and create the admin user.

## 3. Install the tools

```bash
bash scripts/install-tools.sh
```

This installs Docker, Trivy and Node.js, adds the `jenkins` user to the `docker` group and restarts Jenkins, sets the kernel settings SonarQube needs, creates a swap file and the Dependency-Check data folder, and starts SonarQube in Docker. Log out and back in afterwards.

Check:

```bash
docker ps
trivy --version
node -v            # 18 or newer, needed for SonarQube's JavaScript analysis
sudo -u jenkins docker ps
```

## 4. Jenkins plugins

SonarQube Scanner, OWASP Dependency-Check, Docker Pipeline, Pipeline Stage View, Workspace Cleanup, Email Extension (`emailext`), Git and GitHub credentials support.

## 5. SonarQube

1. Open `http://<elastic-ip>:9000`, log in with `admin` / `admin` and set a new password.
2. Create a token: avatar (top right) -> My Account -> Security -> Generate Token.
3. Create a webhook: Administration -> Configuration -> Webhooks.
   - URL: `http://<instance-private-ip>:8080/sonarqube-webhook/`
   - Use the **private** IP. SonarQube runs in a container, and the public IP is blocked by the security group.

## 6. NVD API key

Request a free key at <https://nvd.nist.gov/developers/request-an-api-key>. Without it, the first Dependency-Check database download is very slow and often rate-limited.

## 7. Jenkins credentials

Manage Jenkins -> Credentials -> Global.

| ID | Kind | Used for |
|---|---|---|
| `sonar-token` | Secret text | SonarQube server connection |
| `nvd-api-key` | Secret text | OWASP Dependency-Check |
| `docker` | Username with password | Docker Hub login (username plus access token) |
| `GitHub-Credential` | Username with password | CD job pushing manifest changes (username plus personal access token) |

## 8. Jenkins tools and servers

| Where | Name | Notes |
|---|---|---|
| Tools -> SonarQube Scanner | `Sonar` | Install automatically |
| Tools -> Dependency-Check | `OWASP` | Install from github.com |
| System -> SonarQube servers | `Sonar` | URL `http://localhost:9000`, token `sonar-token`, tick "Environment variables" |
| System -> Global Trusted Pipeline Libraries | `Shared` | Default version `main`, Git, repo `https://github.com/ArslanNagori/Shared-Library-Jenkins` |

The names must match the Jenkinsfile and library exactly (they are case-sensitive).

## 9. Jobs

**Wanderlust-CI** - Pipeline, Definition "Pipeline script from SCM", Git, repository `https://github.com/ArslanNagori/Wanderlust.git`, branch `*/main`, Script Path `Jenkinsfile`. Tick "Discard old builds" and keep the last 5.

**Wanderlust-CD** - Pipeline from SCM with the same repository and the path of the CD Jenkinsfile (`GitOps/Jenkinsfile`).

## 10. First run

1. Run **Build Now** once. It fails at "Validate Parameters", which is expected.
2. Use **Build with Parameters** and enter tags such as `v1` for both.
3. Expect the OWASP stage to take a long time on the first real run (NVD download). Later runs are fast.
4. On success, the CI job starts the CD job, which pushes a commit updating the manifests.

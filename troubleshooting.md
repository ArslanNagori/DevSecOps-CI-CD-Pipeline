# Troubleshooting log

Problems I ran into while building the pipeline, with the cause and the fix.

<!-- Keep only the entries you actually hit. Delete any that did not happen to you. -->

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `permission denied ... /var/run/docker.sock` | The `docker` group change does not apply to a shell that is already open | Log out and back in (or `newgrp docker`), add `jenkins` to the group too and restart Jenkins |
| 2 | Dependency-Check very slow or failing on the NVD download | No API key, so requests are heavily rate-limited | Request a free NVD API key, store it as the Jenkins credential `nvd-api-key`, pass it with `--nvdApiKey`, and keep the data in a persistent folder with `--data` |
| 3 | `No installation OWASP found` | The Dependency-Check tool was not defined in Jenkins | Add a Dependency-Check installation named exactly `OWASP` under Manage Jenkins -> Tools |
| 4 | SonarQube stage: `HTTP connect timed out` | The SonarQube server URL used the public IP, and the security group only allows my IP | Use `http://localhost:9000` because Jenkins and SonarQube share the host |
| 5 | Quality gate stuck at `PENDING`, then timeout | The webhook from the SonarQube container to Jenkins used the public IP and was blocked | Point the webhook at the private IP (`http://<private-ip>:8080/sonarqube-webhook/`). If SonarQube refuses private addresses, start the container with `SONAR_VALIDATEWEBHOOKS=false` |
| 6 | SonarQube: `Error when running: 'node -v'` and no JS rules executed | Node.js was not installed on the Jenkins host | `sudo apt install -y nodejs` (version 18 or newer) |
| 7 | Env-setup scripts silently wrote `http://:5173` | The original scripts looked up a hard-coded EC2 instance ID with the AWS CLI, which had no credentials, and did not stop on the error | Replaced them with `scripts/update-*-env.sh`: detect the public IP with `curl`, validate it, and fail loudly |
| 8 | CD job wrote another Docker Hub namespace into the manifests | The `sed` command replaced only the tag, so the old `namespace/` prefix stayed | Replace the whole `image:` line with my own namespace |
| 9 | Jenkinsfile failed to compile: `unexpected char: '#'` | `#` is not a comment in Groovy | Comment out every line with `//` |
| 10 | CD stage failed with "nothing to commit" when re-run with the same tags | `git commit` fails when there are no changes | Only commit when `git diff --cached --quiet` reports a change |

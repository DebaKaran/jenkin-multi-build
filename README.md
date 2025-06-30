# jenkin-multi-build

jenkin-multi-build

1️: Goal

A: Run Jenkins master in one container

B: Run 2 agents as separate containers

C: All running in same docker-compose.yml

D: No need to open Windows firewall ports manually

E: No host-to-host networking problems

F: Agents auto-connect to master

G: Easy restart with docker-compose down && up

2️: Architecture:

docker-compose:

- jenkins-master (port 8888:8080)
- jenkins-agent-01
- jenkins-agent-02

Internal Docker network → `jenkins-net`

3️: Files

A: docker-compose.yml

version: '3.8'

services:

jenkins-master:
image: jenkins/jenkins:lts-jdk17
container_name: jenkins-master
ports: - "8888:8080" - "50000:50000"
volumes: - jenkins_home:/var/jenkins_home
networks: - jenkins-net

jenkins-agent-01:
image: jenkins/inbound-agent
container_name: jenkins-agent-01
depends_on: - jenkins-master
environment: - JENKINS_URL=${JENKINS_URL}
      - JENKINS_SECRET=${JENKINS_SECRET_AGENT01} - JENKINS_AGENT_NAME=${JENKINS_AGENT_NAME01}
entrypoint: >
sh -c "while ! nc -z jenkins-master 8080; do echo Waiting for Jenkins master...; sleep 5; done;
java -jar /usr/share/jenkins/agent.jar -url ${JENKINS_URL} -secret ${JENKINS_SECRET} -name ${JENKINS_AGENT_NAME} -workDir /home/jenkins/agent"
networks: - jenkins-net

jenkins-agent-02:
image: jenkins/inbound-agent
container_name: jenkins-agent-02
depends_on: - jenkins-master
environment: - JENKINS_URL=${JENKINS_URL}
      - JENKINS_SECRET=${JENKINS_SECRET_AGENT02} - JENKINS_AGENT_NAME=${JENKINS_AGENT_NAME02}
entrypoint: >
sh -c "while ! nc -z jenkins-master 8080; do echo Waiting for Jenkins master...; sleep 5; done;
java -jar /usr/share/jenkins/agent.jar -url ${JENKINS_URL} -secret ${JENKINS_SECRET} -name ${JENKINS_AGENT_NAME} -workDir /home/jenkins/agent"
networks: - jenkins-net

volumes:
jenkins_home:

networks:
jenkins-net:

B: .env

# Master URL (internal docker hostname, not localhost)

JENKINS_URL=http://jenkins-master:8080/

# Agent 01

JENKINS_SECRET_AGENT01=xxxxxx-secret-agent01-xxxxxx
JENKINS_AGENT_NAME01=agent-01

# Agent 02

JENKINS_SECRET_AGENT02=yyyyyy-secret-agent02-yyyyyy
JENKINS_AGENT_NAME02=agent-02

4️: How to Run:

# Start all containers

docker-compose up -d

# See logs

docker-compose logs -f

# Stop containers

docker-compose down

5️: How to Add New Agents (Steps)

A: Go to Jenkins Web UI → http://localhost:8888

B: Go to → Manage Jenkins → Nodes → New Node

C: Enter name → example: agent-01

D: Type → Permanent Agent

E: Fill:

Remote root directory → /home/jenkins/agent

Launch method → Launch agent by connecting it to the controller

F: Save → Jenkins shows:

Agent Secret → <SECRET KEY>
Agent URL → http://jenkins-master:8080/

6️: How to Update .env:

Copy secret from Jenkins UI → update .env:

JENKINS_SECRET_AGENT01=copy-from-jenkins-ui
JENKINS_AGENT_NAME01=agent-01

7️: Restart After Agent Creation

8️: Issues We Faced & Solution

Problem 1: Agent failing with "503 Service Unavailable"

A: Caused by agents starting before master was ready
B: Fixed by adding:

entrypoint: >
sh -c "while ! nc -z jenkins-master 8080; do echo Waiting for Jenkins master...; sleep 5; done;
java -jar ..."

Problem 2: Secret reset after master restart?

No. If you use volume:
volumes:

- jenkins_home:/var/jenkins_home

Then secrets and Jenkins config are persisted.

🔸 Problem 3: Should secret be stored in .env?

Yes — in .env is fine because:

A: .env is not committed to Git

B: Easy to update

C: Safe practice for dev systems

D: For production → use Jenkins Credentials Plugin (advanced)

#### Agent container log: sh: 1: nc: not found

Problem:

Agent container logs showed: sh: 1: nc: not found

Root Cause:

The default jenkins/inbound-agent image does not come with netcat (nc), which is used in the entrypoint wait-loop to check when the Jenkins master is ready.

Without nc, the wait-loop fails and the agent keeps failing to connect.

We created a small Dockerfile.agent to install nc:

Dockerfile.agent

# Dockerfile.agent

FROM jenkins/inbound-agent:latest-jdk17

USER root

# Install netcat-openbsd (because "netcat" fails now in Debian images)

RUN apt-get update \
 && apt-get install -y --no-install-recommends netcat-openbsd \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/\*

USER jenkins

####Jenkins Multi-Agent Setup with Docker Compose

This project shows how to run a Jenkins controller with one or more agents using `docker-compose`.

✅ Supports:

- Jenkins controller (`jenkins/jenkins:lts-jdk17`)
- Jenkins agents (`jenkins/inbound-agent:latest-jdk17`)
- Auto-connect agents via JNLP with secret tokens
- Easily add more agents via `.env` file and `docker-compose.yaml`

---

## .env File (Example)

```env
# Jenkins Controller URL
JENKINS_URL=http://jenkins-master:8080/

# Agent 01 secret & name
JENKINS_SECRET_AGENT01=<your-agent-01-secret>
JENKINS_AGENT_NAME01=agent-01

# Agent 02 secret & name (optional)
JENKINS_SECRET_AGENT02=<your-agent-02-secret>
JENKINS_AGENT_NAME02=agent-02

```

You can find the agent secret in:

Manage Jenkins → Nodes → agent-01 → Configure → Agent Secret

How to Run
1️: Build & Start: docker compose --env-file .env up --build -d
2: Stop: docker compose down

How to Add More Agents
1️: In docker-compose.yaml, copy/paste and update service:

jenkins-agent-2:
container_name: jenkins-agent-02
image: jenkins/inbound-agent:latest-jdk17
networks: - jenkins-net
depends_on:
jenkins-master:
condition: service_started
entrypoint: - java - -jar - /usr/share/jenkins/agent.jar - -url - "$JENKINS_URL"
      - -secret
      - "$JENKINS_SECRET_AGENT02" - -name - "$JENKINS_AGENT_NAME02" - -workDir - "/home/jenkins/agent"

2️: In .env, add secret + name for the agent:

JENKINS_SECRET_AGENT02=xxx
JENKINS_AGENT_NAME02=agent-02

3️⃣ Redeploy: docker compose --env-file .env up --build -d

Assign Labels to Agents:

Go to:

Manage Jenkins → Nodes → agent-01 → Configure → Labels

Example: docker linux

#######
⚠️ Issue: docker-compose Not Found in Jenkins Agent
When running a Jenkins pipeline that uses Docker Compose, you might encounter the following error in Jenkins:

docker-compose: not found

Root Cause:

Even though /var/run/docker.sock is mounted into the Jenkins agent container (giving it access to the Docker daemon), the agent container does not include the docker-compose CLI tool by default.

The Docker socket allows the agent to communicate with Docker, but it still needs the docker-compose binary to run Compose commands like docker-compose up.

Solution: Add docker-compose to Jenkins Agent

To resolve this:

1: Create a custom Dockerfile for Jenkins agents that installs docker-compose.

2: Update your docker-compose.yml to build the agents using this Dockerfile.

Step 1: Create Dockerfile.agent-with-compose

# Dockerfile.agent-with-compose

FROM jenkins/inbound-agent:latest-jdk17

USER root

RUN apt-get update && \
 apt-get install -y curl && \
 curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose && \
 chmod +x /usr/local/bin/docker-compose

USER jenkins

## Update the Docker Compose version if needed: https://github.com/docker/compose/releases

2: Step 2: Modify your Jenkins agent service in docker-compose.yml
jenkins-agent-1:
build:
context: .
dockerfile: Dockerfile.agent-with-compose

Similarly for other agents.

### The Problem

When running docker commands from Jenkins agents (inside containers), you might encounter this error:

permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock

⚠️ Why It Happens:

A: The host's /var/run/docker.sock is mounted into the container.

B: The socket is owned by a group (usually docker) with a dynamic GID like 1001, 998, or even 0.

C: Inside the agent container, if the jenkins user is not part of the same GID group, it cannot access the socket → results in permission denied.

🚫 Common (But Inflexible) Fixes

A: Hardcoding DOCKER_GID=1001 in .env and Dockerfile

B: Using usermod -aG docker jenkins with a fixed group

C: Manually checking and editing GID each time

These break if GID changes on a new system or reboot.

✅ Final Working Approach:

We solved the problem dynamically and robustly using these steps:

1. Removed DOCKER_GID from .env and Dockerfile

No more relying on fixed group IDs.

2. Added entrypoint.sh to dynamically match host GID
   Dockerfile.agent-with-compose:

FROM jenkins/inbound-agent:latest-jdk17

USER root

RUN apt-get update && \
 apt-get install -y curl docker.io && \
 curl -L "https://github.com/docker/compose/releases/download/v2.37.3/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose && \
 chmod +x /usr/local/bin/docker-compose

# Copy custom entrypoint script

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER jenkins
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

3. entrypoint.sh – automatic GID matching

#!/bin/bash

set -e

DOCKER_SOCK="/var/run/docker.sock"
DOCKER_GID=$(stat -c '%g' $DOCKER_SOCK)

if ! getent group docker >/dev/null; then
echo "[INFO] Creating 'docker' group with GID $DOCKER_GID"
  sudo groupadd -g "$DOCKER_GID" docker || true
fi

echo "[INFO] Adding 'jenkins' user to 'docker' group"
sudo usermod -aG docker jenkins || true

echo "[INFO] Starting Jenkins agent..."
exec java -jar /usr/share/jenkins/agent.jar "$@"

✅ This script runs inside the container before Jenkins agent starts. It reads the real GID of /var/run/docker.sock, creates a matching group if needed, and adds jenkins to it.

4. 🔁 Used in docker-compose.yaml

jenkins-agent-1:
build:
context: .
dockerfile: Dockerfile.agent-with-compose
...
volumes: - /var/run/docker.sock:/var/run/docker.sock

✅ Verification
Run from inside agent container:

$ whoami
jenkins

$ groups
jenkins docker

$ docker ps
CONTAINER ID IMAGE ... STATUS ...

🎉 No more permission errors! Agent can now run Docker builds, tests, or deploy steps.

Security Notes:

1: Do not expose Docker socket to untrusted containers.

2: This setup is safe within a trusted CI/CD pipeline.

3: For production: consider using a remote Docker daemon or docker-in-docker alternatives like kaniko.

### Problem: Duplicate Image Builds

When both `jenkins-agent-1` and `jenkins-agent-2` services have a `build:` section (even if using the same Dockerfile), running: docker compose --env-file .env build --no-cache

results in two separate image builds, even though the builds are identical.

Why this is bad:

A: Wastes disk space

B: Slows down build process

C: Causes unnecessary duplication of Docker images

Solution: Use a Shared Image Tag (Option 1)

Strategy:

A: Build the agent image once (with jenkins-agent-1)

B: Assign a custom image name: jenkins-agent:custom

C: Make other agents (like jenkins-agent-2) reuse the same image via the image: directive

Build Image Once: docker compose --env-file .env build jenkins-agent-1

Or alternatively (if not using Compose for build):

docker build -t jenkins-agent:custom -f Dockerfile.agent-with-compose .

Start the Jenkins stack: docker compose --env-file .env up -d

docker-compose.yml Snippet (Simplified)

jenkins-agent-1:
build:
context: .
dockerfile: Dockerfile.agent-with-compose
args:
DOCKER_GID: ${DOCKER_GID}
image: jenkins-agent:custom
...

jenkins-agent-2:
image: jenkins-agent:custom
...

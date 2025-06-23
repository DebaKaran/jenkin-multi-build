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

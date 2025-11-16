# maven-project

Simple Maven Project with CI/CD pipeline, Docker containerization, ECR registry, and EKS deployment.

## Project Structure

```
maven-project/
├── Jenkinsfile              # CI/CD pipeline (Maven build, Docker, ECR push, EKS deploy)
├── Dockerfile               # Docker image for Tomcat 9 web application
├── pom.xml                  # Root Maven pom
├── server/                  # Maven server module (Java source, tests)
├── webapp/                  # Maven webapp module (JSP, web.xml)
├── eks/
│   └── manifestfiles/       # Kubernetes manifests for EKS deployment
│       ├── webapp-deployment.yaml
│       └── webapp-service.yaml
└── README.md
```

## Prerequisites

### Local Development
- Maven 3.6+
- Java 8+
- Git

### CI/CD & Deployment
- Jenkins with Pipeline support
- kubectl installed on Jenkins agents
- aws-cli installed on Jenkins agents
- AWS IAM credentials with permissions:
  - S3 (GetObject, PutObject on `poc-maven-project` bucket)
  - ECR (DescribeRepositories, GetDownloadUrlForLayer, PutImage, InitiateLayerUpload)
  - EKS (DescribeCluster, ListClusters)
- EKS cluster named `devops-poc` in `ap-south-1` region
- ECR repository named `webapp-tomcat9` in account `086266612868`

## Step-by-step Setup (Jenkins + AWS + EKS)

Follow these steps on the Jenkins EC2 instance (or a host with AWS CLI access) to reproduce the CI/CD environment used by this repository.

1. Attach an IAM role to the Jenkins EC2 instance

```bash
# Create a role in the AWS Console or via CLI and attach policies listed in the "IAM permissions" section.
# Example: assume the role name is EC2_Role and it is attached to the instance running Jenkins.
```

2. Install Jenkins and required plugins

```bash
# On Ubuntu (example)
sudo apt update && sudo apt install -y openjdk-11-jre
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update && sudo apt install -y jenkins

# Then in Jenkins UI: Manage Jenkins -> Manage Plugins -> Install:
# - Pipeline
# - Pipeline: AWS Steps (pipeline-aws)
# - Git
# - SonarQube Scanner (optional)
```

3. Configure Jenkins to allow agents to use instance credentials

```
# In Jenkins UI -> Manage Jenkins -> Configure System
# Under "Pipeline: AWS Steps" enable "Retrieve credentials from node" if you run agents/steps on nodes
# that should obtain credentials from the instance metadata (EC2 instance role).
```

4. Create a Pipeline job using this repository

```
# Create a new Pipeline job and point it to this Git repository. The job uses the `Jenkinsfile` at repo root.
# Optionally add GitHub webhook to trigger builds on push to main.
```

5. Map the Jenkins EC2 role into EKS RBAC (so kubectl calls from Jenkins are authorized)

Use `eksctl` (recommended) or edit the `aws-auth` configmap manually. Replace account/role names below.

```bash
ACCOUNT=086266612868
ROLE_NAME=EC2_Role
CLUSTER=devops-poc

eksctl create iamidentitymapping \
  --cluster "${CLUSTER}" \
  --arn "arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}" \
  --group system:masters \
  --username jenkins-ec2
```

6. Verify Jenkins can call EKS

Run this on the Jenkins EC2 instance (or in the pipeline Docker agent if metadata is available):

```bash
aws sts get-caller-identity
aws eks describe-cluster --name devops-poc --region ap-south-1 --query 'cluster.endpoint'
aws eks get-token --cluster-name devops-poc --region ap-south-1 --query status.token --output text
# Build a temporary kubeconfig as used by the pipeline and run kubectl get nodes
```

7. Trigger a build in Jenkins

```
# Push code to main or click Build Now in Jenkins UI. Monitor Console Output.
```

## Build & Test Locally

```bash
# Build all modules
mvn clean install

# Run only unit tests
mvn test

# Run integration tests
mvn verify
```

## Docker Build (Local)

```bash
# Build Docker image
docker build -t webapp-tomcat9:latest .

# Run container locally
docker run -d -p 8080:8080 --name webapp-tomcat9 webapp-tomcat9:latest

# Verify
curl http://localhost:8080

# Stop & remove
docker stop webapp-tomcat9
docker rm webapp-tomcat9
```

## CI/CD Pipeline (Jenkins)

The `Jenkinsfile` defines a declarative pipeline with the following stages:

### 1. Checkout
- Clones the repository using GitHub token credentials.
- Branch: `main`

### 2. Build & Unit Test
- Runs `mvn clean install -DskipTests=false` on the master agent.
- Compiles Java code and runs unit tests.

### 3. SonarQube Analysis
- Runs `mvn clean verify sonar:sonar` using SonarQube 25 environment.
- Analyzes code quality and publishes results.

### 4. Publish Test Results
- Archives surefire test reports from `**/target/surefire-reports/*.xml`.

### 5. Archive Artifacts
- Fingerprints and archives `.jar` and `.war` files.

### 6. Upload WAR to S3
- Uploads the compiled WAR file to S3 bucket `poc-maven-project`.
- Key format: `webapp-${BUILD_NUMBER}.war`

### 7. Remote Docker Build, Run & Push
- Runs on the `docker` agent label.
- **Steps:**
  1. Pulls WAR from S3.
  2. Fetches Dockerfile from GitHub.
  3. Creates isolated Docker build context (avoids stray files).
  4. Builds Docker image locally as `webapp-tomcat9:latest`.
  5. Stops/removes any container on port 8080.
  6. Runs new container (bound to local port 8080).
  7. Tags image for ECR: `086266612868.dkr.ecr.ap-south-1.amazonaws.com/webapp-tomcat9:latest`
  8. Logs in to ECR using IAM role credentials.
  9. Pushes image to ECR.
  10. Cleans up temporary files.

### 8. Deploy to EKS
- Runs on the `docker` agent label.
- **Steps:**
  1. Installs kubectl if missing (idempotent).
  2. Fetches EKS cluster endpoint, CA cert, and generates a bearer token using `aws eks get-token`.
  3. Builds a temporary kubeconfig with explicit token (avoids exec plugin issues).
  4. Applies Kubernetes manifests from `eks/manifestfiles/` (Deployment + Service).
  5. Retries with `--validate=false` if OpenAPI validation fails.
  6. Waits for `webapp-tomcat` deployment rollout (5-minute timeout, non-fatal).
  7. Displays the LoadBalancer external IP.
  8. Cleans up temporary kubeconfig.

## Kubernetes Deployment

Manifests are stored in `eks/manifestfiles/`:

- **webapp-deployment.yaml**: Deploys `webapp-tomcat9:latest` image to EKS.
- **webapp-service.yaml**: Exposes the deployment via LoadBalancer service on port 80.

### Manual Deployment (if needed)

```bash
# Update kubeconfig
aws eks update-kubeconfig --name devops-poc --region ap-south-1

# Apply manifests
kubectl apply -f eks/manifestfiles/

# Check deployment status
kubectl get pods
kubectl get svc
kubectl logs -f deployment/webapp-tomcat

# Wait for rollout
kubectl rollout status deployment/webapp-tomcat
```

## Pipeline Execution

### Trigger a Build

1. **Via GitHub webhook** (recommended):
   - Push to `main` branch; Jenkins automatically triggers the pipeline.

2. **Manual trigger**:
   - Click "Build Now" in Jenkins UI.

### Monitor the Build

- Open Jenkins job → "Build #N" → "Console Output" to see real-time logs.
- Pipeline stages appear in the UI with pass/fail status.

### Post-Build Verification

After a successful run:

```bash
# Check EKS deployment
kubectl get pods -n default
kubectl get svc -n default

# Verify image in ECR
aws ecr describe-images --repository-name webapp-tomcat9 --region ap-south-1

# Access the web app (use LoadBalancer hostname from kubectl get svc)
EXTERNAL_IP=$(kubectl get svc webapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$EXTERNAL_IP
```

## Environment Variables (Jenkins)

| Variable | Value | Description |
|----------|-------|-------------|
| `PROJECT_NAME` | `maven-project` | Project identifier |
| `AWS_REGION` | `ap-south-1` | AWS region |
| `ECR_REPO` | `webapp-tomcat9` | ECR repository name |
| `ECR_REGISTRY` | `086266612868.dkr.ecr.ap-south-1.amazonaws.com` | ECR registry URL |
| `IMAGE_TAG` | `${ECR_REGISTRY}/${ECR_REPO}:latest` | Full image tag |
| `S3_BUCKET` | `poc-maven-project` | S3 bucket for WAR artifacts |
| `WAR_PATH` | `webapp/target/webapp.war` | Relative path to WAR in workspace |
| `WAR_S3_KEY` | `webapp-${BUILD_NUMBER}.war` | S3 object key (includes build number) |
| `EKS_CLUSTER` | `devops-poc` | EKS cluster name |
| `K8S_MANIFEST_DIR` | `eks/manifestfiles` | Path to Kubernetes manifests |

## Troubleshooting

### Jenkins Parse Error
**Problem**: `WorkflowScript: XX: illegal string body character after dollar sign`
**Solution**: Jenkinsfile uses triple-single-quoted `sh ''' ... '''` for shell blocks to avoid Groovy GString interpolation.

### EKS Authentication Error
**Problem**: `the server has asked for the client to provide credentials`
**Solution**: The Deploy stage constructs a kubeconfig with an explicit bearer token fetched from `aws eks get-token`; ensure IAM role has EKS permissions.

### Docker Build Context Error
**Problem**: `error checking context: can't stat '/tmp/elasticsearch-...'`
**Solution**: Pipeline creates an isolated temporary build directory (only WAR + Dockerfile) to avoid stray files interfering.

### WAR Not Found in S3
**Problem**: `NoSuchKey` error during S3 download
**Solution**: Ensure the WAR was uploaded in the "Upload WAR to S3" stage; check bucket permissions and object key format.

## References

- [Jenkinsfile Declarative Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Maven Documentation](https://maven.apache.org/guides/index.html)
- [Docker Documentation](https://docs.docker.com/)


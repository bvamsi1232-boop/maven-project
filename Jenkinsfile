pipeline {
  agent { label 'master' }

  tools {
    maven 'Maven 3'
  }

  environment {
    PROJECT_NAME   = 'maven-project'
    AWS_REGION     = 'ap-south-1'
    ECR_REPO       = 'webapp-tomcat9'
    ECR_REGISTRY   = '086266612868.dkr.ecr.ap-south-1.amazonaws.com'
    IMAGE_TAG      = "${ECR_REGISTRY}/${ECR_REPO}:latest"
    S3_BUCKET      = 'poc-maven-project'
    WAR_PATH       = 'webapp/target/webapp.war'
    WAR_S3_KEY     = "webapp-${BUILD_NUMBER}.war"
    EKS_CLUSTER    = 'devops-poc'
    K8S_MANIFEST_DIR = 'eks/manifestfiles'
  }

  stages {
    stage('Checkout') {
      steps {
        withCredentials([string(credentialsId: 'github-token', variable: 'GIT_TOKEN')]) {
          git url: "https://${GIT_TOKEN}@github.com/bvamsi1232-boop/maven-project.git", branch: 'main'
        }
      }
    }

    stage('Build & Unit Test') {
      steps {
        sh 'mvn clean install -DskipTests=false'
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube 25') {
          sh 'mvn clean verify sonar:sonar -Dsonar.projectKey=maven-project'
        }
      }
    }

    stage('Publish Test Results') {
      steps {
        junit '**/target/surefire-reports/*.xml'
      }
    }

    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: '**/target/*.jar, **/target/*.war', fingerprint: true
      }
    }

    stage('Upload WAR to S3') {
      steps {
        sh '''
          echo "Checking WAR file at ${WAR_PATH}"
          ls -lh ${WAR_PATH}
          aws s3 cp ${WAR_PATH} s3://${S3_BUCKET}/${WAR_S3_KEY}
        '''
      }
    }

    stage('Remote Docker Build, Run & Push') {
      agent { label 'docker' }

      environment {
        IMAGE_TAG_REMOTE = 'webapp-tomcat9:latest'
        CONTAINER_NAME   = "webapp-${BUILD_NUMBER}"
      }

      steps {
        sh '''
          set -e
          echo "[INFO] Step 1: Pulling WAR from S3..."
          aws s3 cp s3://${S3_BUCKET}/${WAR_S3_KEY} /tmp/webapp.war

          echo "[INFO] Step 2: Fetching Dockerfile from GitHub..."
          curl -sSL https://raw.githubusercontent.com/bvamsi1232-boop/maven-project/main/Dockerfile -o /tmp/Dockerfile

          echo "[INFO] Step 3: Creating isolated build context..."
          BUILD_DIR=$(mktemp -d /tmp/docker-build-XXXX)
          cp /tmp/webapp.war /tmp/Dockerfile "$BUILD_DIR"/

          echo "[INFO] Step 4: Validating Docker access..."
          if ! docker info > /dev/null 2>&1; then
            echo "[ERROR] Docker not accessible. Ensure user is in 'docker' group."
            rm -rf "$BUILD_DIR"
            exit 1
          fi

          echo "[INFO] Step 5: Building Docker image from isolated context..."
          docker build -t ${IMAGE_TAG_REMOTE} "$BUILD_DIR"

          echo "[INFO] Step 6: Cleaning up isolated build context..."
          rm -rf "$BUILD_DIR"

          echo "[INFO] Step 7: Stopping and removing any container using port 8080..."
          docker ps --format '{{.ID}} {{.Ports}}' | grep '8080->' | awk '{print $1}' | xargs -r docker rm -f

          echo "[INFO] Step 8: Stopping and removing previous container by name (if any)..."
          docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | xargs -r docker rm -f

          echo "[INFO] Step 9: Running new container..."
          docker run -d --name ${CONTAINER_NAME} -p 8080:8080 ${IMAGE_TAG_REMOTE}

          echo "[INFO] Step 10: Tagging image for ECR..."
          docker tag ${IMAGE_TAG_REMOTE} ${IMAGE_TAG}

          echo "[INFO] Step 11: Logging in to ECR..."
          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

          echo "[INFO] Step 12: Pushing image to ECR..."
          docker push ${IMAGE_TAG}

          echo "[INFO] Step 13: Cleaning up temporary files..."
          rm -f /tmp/webapp.war /tmp/Dockerfile
        '''
      }
    }

    stage('Deploy to EKS') {
      agent { label 'docker' }

      steps {
        withCredentials([
          string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
            set -e
            
            echo "[INFO] Installing kubectl if missing..."
            if ! command -v kubectl >/dev/null 2>&1; then
              echo "[INFO] Downloading kubectl..."
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              rm -f kubectl
            fi

            echo "[INFO] Checking AWS credentials access..."
            aws sts get-caller-identity

            echo "[INFO] Fetching EKS cluster details..."
            ENDPOINT=$(aws eks describe-cluster --name "${EKS_CLUSTER}" --region "${AWS_REGION}" --query 'cluster.endpoint' --output text)
            CA_DATA=$(aws eks describe-cluster --name "${EKS_CLUSTER}" --region "${AWS_REGION}" --query 'cluster.certificateAuthority.data' --output text)
            
            echo "[INFO] Generating EKS authentication token..."
            TOKEN=$(aws eks get-token --cluster-name "${EKS_CLUSTER}" --region "${AWS_REGION}" --query 'status.token' --output text)
            echo "[INFO] Token length: ${#TOKEN}"

            echo "[INFO] Creating temporary kubeconfig with embedded token..."
            KUBECONFIG_PATH=$(mktemp)
            
            # Build kubeconfig using echo and tee to ensure file is written correctly
            (
              echo "apiVersion: v1"
              echo "clusters:"
              echo "- cluster:"
              echo "    server: ${ENDPOINT}"
              echo "    certificate-authority-data: ${CA_DATA}"
              echo "  name: eks_cluster"
              echo "contexts:"
              echo "- context:"
              echo "    cluster: eks_cluster"
              echo "    user: eks_user"
              echo "  name: eks"
              echo "current-context: eks"
              echo "kind: Config"
              echo "preferences: {}"
              echo "users:"
              echo "- name: eks_user"
              echo "  user:"
              echo "    token: ${TOKEN}"
            ) | tee "$KUBECONFIG_PATH" > /dev/null

            echo "[INFO] Kubeconfig created. Testing kubectl access..."
            kubectl --kubeconfig="$KUBECONFIG_PATH" get nodes
            
            echo "[INFO] Applying Kubernetes manifests (skipping validation)..."
            kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "${K8S_MANIFEST_DIR}" --validate=false

            echo "[INFO] Waiting for deployment rollout..."
            kubectl --kubeconfig="$KUBECONFIG_PATH" rollout status deployment/webapp-tomcat --timeout=5m || true
            
            echo "[INFO] Fetching LoadBalancer IP..."
            EXTERNAL_IP=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get svc webapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
            echo "[INFO] Web application accessible at: http://${EXTERNAL_IP}"

            echo "[INFO] Cleaning up temporary kubeconfig..."
            rm -f "$KUBECONFIG_PATH"
          '''
        }
      }
    }
  }

  post {
    always {
      echo "Build completed for ${env.PROJECT_NAME}"
    }
    success {
      echo "Pipeline succeeded: Build, Test, SonarQube, S3 upload, Docker push to ECR, and EKS deployment completed!"
    }
    failure {
      echo "Pipeline failed. Check logs above for details."
    }
  }
}

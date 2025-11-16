pipeline {
  agent { label 'master' }

  tools {
    maven 'Maven 3'
  }

  environment {
    PROJECT_NAME   = 'maven-project'
    AWS_REGION     = 'ap-south-1'
    ECR_REPO       = 'webapp-tomcat9'
    ECR_REGISTRY   = '086266612868.dkr.ecr.ap-south-1.amazonaws.com/webapp-tomcat9'
    IMAGE_TAG      = "${ECR_REGISTRY}/${ECR_REPO}:${BUILD_NUMBER}"
    S3_BUCKET      = 'poc-maven-project'
    WAR_PATH       = 'webapp/target/webapp.war'
    WAR_S3_KEY     = "webapp-${BUILD_NUMBER}.war"
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
        sh """
          echo "Checking WAR file at ${WAR_PATH}"
          ls -lh ${WAR_PATH}
          aws s3 cp ${WAR_PATH} s3://${S3_BUCKET}/${WAR_S3_KEY}
        """
      }
    }

  //   stage('Remote Docker Build, Run & Push') {
  //     agent { label 'docker' }
    
  //     environment {
  //       IMAGE_TAG_REMOTE = "webapp-tomcat9:${BUILD_NUMBER}"
  //       CONTAINER_NAME   = "webapp-${BUILD_NUMBER}"
  //     }
    
  //     steps {
  //       sh """
  //         echo "[INFO] Step 1: Pulling WAR from S3..."
  //         aws s3 cp s3://\$S3_BUCKET/\$WAR_S3_KEY /tmp/webapp.war
    
  //         echo "[INFO] Step 2: Fetching Dockerfile from GitHub..."
  //         curl -sSL https://raw.githubusercontent.com/bvamsi1232-boop/maven-project/main/Dockerfile -o /tmp/Dockerfile
    
  //         echo "[INFO] Step 3: Validating Docker access..."
  //         if ! docker info > /dev/null 2>&1; then
  //           echo "[ERROR] Docker not accessible. Ensure user is in 'docker' group."
  //           exit 1
  //         fi
    
  //         echo "[INFO] Step 4: Building Docker image..."
  //         cd /tmp
  //         docker build -t \$IMAGE_TAG_REMOTE .
    
  //         echo "[INFO] Step 5: Stopping and removing any container using port 8080..."
  //         docker ps --format '{{.ID}} {{.Ports}}' | grep '8080->' | awk '{print \$1}' | xargs -r docker rm -f
    
  //         echo "[INFO] Step 6: Stopping and removing previous container by name (if any)..."
  //         docker ps -a --filter "name=\$CONTAINER_NAME" --format "{{.ID}}" | xargs -r docker rm -f
    
  //         echo "[INFO] Step 7: Running new container..."
  //         docker run -d --name \$CONTAINER_NAME -p 8080:8080 \$IMAGE_TAG_REMOTE
    
  //         echo "[INFO] Step 8: Tagging image for ECR..."
  //         docker tag \$IMAGE_TAG_REMOTE \$IMAGE_TAG
    
  //         echo "[INFO] Step 9: Logging in to ECR..."
  //         aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin \$ECR_REGISTRY
    
  //         echo "[INFO] Step 10: Pushing image to ECR..."
  //         docker push \$IMAGE_TAG
    
  //         echo "[INFO] Step 11: Cleaning up temporary files..."
  //         rm -f /tmp/webapp.war /tmp/Dockerfile
  //       """
  //     }
    }
  }
  post {
    always {
      echo "Build completed for ${env.PROJECT_NAME}"
    }
    success {
      echo "✅ Build, Test, SonarQube analysis, S3 upload, and remote container launch, ECR push succeeded!"
    }
    failure {
      echo "❌ Pipeline failed. Check logs for details."
    }
  }
}
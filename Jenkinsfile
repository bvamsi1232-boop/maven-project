pipeline {
  agent { label 'master' }

  tools {
    maven 'Maven 3'
  }

  environment {
    PROJECT_NAME   = 'maven-project'
    AWS_REGION     = 'ap-south-1'
    ECR_REPO       = 'webapp-tomcat9'
    ECR_REGISTRY   = '443370681480.dkr.ecr.ap-south-1.amazonaws.com'
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

    stage('Remote Docker Build & Run') {
      agent { label 'docker' }

      environment {
        IMAGE_TAG_REMOTE = "webapp-tomcat9:${BUILD_NUMBER}"
      }

      steps {
        sh """
          echo "Step 1: Pulling WAR from S3..."
          aws s3 cp s3://${S3_BUCKET}/${WAR_S3_KEY} /tmp/webapp.war

          echo "Step 2: Fetching Dockerfile from GitHub..."
          curl -sSL https://raw.githubusercontent.com/Vamsi-Reddy/Sample-Docker/main/Dockerfile -o /tmp/Dockerfile

          echo "Step 3: Building Docker image..."
          cd /tmp
          docker build -t ${IMAGE_TAG_REMOTE} .

          echo "Step 4: Stopping any existing container..."
          docker ps -q --filter ancestor=${IMAGE_TAG_REMOTE} | xargs -r docker stop

          echo "Step 5: Running container..."
          docker run -d -p 8080:8080 ${IMAGE_TAG_REMOTE}
        """
      }
    }
  }

  post {
    always {
      echo "Build completed for ${env.PROJECT_NAME}"
    }
    success {
      echo "✅ Build, S3 upload, and remote container launch succeeded!"
    }
    failure {
      echo "❌ Pipeline failed. Check logs for details."
    }
  }
}
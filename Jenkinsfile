pipeline {
  agent { label 'maven' }

  tools {
    maven 'Maven 3'
  }

  environment {
    PROJECT_NAME = 'maven-project'
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
  }

  post {
    always {
      echo "Build completed for ${env.PROJECT_NAME}"
    }
    success {
      echo "✅ Build and tests passed!"
    }
    failure {
      echo "❌ Build failed. Check logs for details."
    }
  }
}
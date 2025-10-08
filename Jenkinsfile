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
        git branch: 'main',
            credentialsId: 'github-token',
            url: 'https://github.com/bvamsi1232-boop/maven-project.git'
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
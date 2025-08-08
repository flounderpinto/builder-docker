pipeline {
  agent any

  stages {
    stage('Init') {
      steps {
        sh 'make init'
      }
    }
    stage('Test') {
      steps {
        sh 'make unit_test'
      }
    }
    stage('Analyze') {
      steps{
        sh 'make analyze'
      }
    }
  }
}

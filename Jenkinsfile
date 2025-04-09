pipeline{
    agent any

    // Set environment variables for the image
    environment {
        IMAGE_NAME = 'ensf400-project'
        TAG = 'latest'
    }

    stages{
        // Step to run SonarQube
        stage('Start SonarQube') {
            steps {
                script {
                    // Pull and run SonarQube
                    sh 'docker pull sonarqube:9.2-community'
                    sh 'docker run -d -p 9000:9000 sonarqube:9.2-community'
                    
                    // Wait for SonarQube to be ready
                    echo "Waiting for SonarQube to be ready..."
                    sleep 30  // Give SonarQube time to start up
                }
            }
        }

        // Building the image itself
        stage('Build'){
            steps{
                sh 'docker build -t $IMAGE_NAME:$TAG .'
            }
        }

        //Running the tests:
        stage('Unit Tests') {
            agent {
                docker {
                    image 'gradle:7.6.1-jdk11'
                }
            }
            steps {
                sh './gradlew test'
            }
            post {
                always {
                    junit 'build/test-results/test/*.xml'
                }
            }
        }

        // Runs an analysis of the code, looking for any
        // patterns that suggest potential bugs.
        stage('Static Analysis') {
            agent {
                docker {
                    image 'gradle:7.6.1-jdk11'
                }
            }
            steps {
                sh './gradlew sonarqube'
                // wait for sonarqube to finish its analysis
                sleep 5
                sh './gradlew checkQualityGate'
            }
        }

    }
}
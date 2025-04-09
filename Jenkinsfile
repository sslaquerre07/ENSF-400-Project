pipeline{
    agent any

    // Set environment variables for the image
    environment {
        IMAGE_NAME = 'ensf400-project'
        TAG = 'latest'
    }

    stages{
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

        //Use a docker in docker container to run sonarcube (can't figure out)
        stage('Static Analysis') {
            agent {
                docker {
                    image 'docker:20.10.7-dind'
                    args '--privileged'
                }
            }
            environment {
                SONAR_HOST_URL = 'http://localhost:9000'
                SONAR_TOKEN = credentials('your-sonar-token-id')  // Jenkins credentials
            }
            steps {
                script {
                    sh '''
                        docker run -d --name sonarqube -p 9000:9000 sonarqube:9.2-community
                        echo "Waiting for SonarQube to be ready..."
                        while ! curl -s http://localhost:9000/api/system/health | grep '"status":"UP"'; do sleep 5; done
                    '''
                    sh './gradlew sonarqube -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_TOKEN'
                    sh 'docker stop sonarqube'
                    sh 'docker rm sonarqube'
                }
            }
        }
    }
}
//Add comment to test


/* groovylint-disable BlockEndsWithBlankLine, LineLength, NestedBlockDepth */
pipeline {
    agent any

    // Set environment variables for the Jenkins container
    environment {
        IMAGE_NAME = 'ensf400-project'
        TAG = 'latest'
        DOCKER_USER = 'bhavna2309'
        DOCKER_PASS = 'Calgary2309'
        IP_ADDRESS = sh(script: '''
        # First check if host.docker.internal can be resolved
        if getent hosts host.docker.internal &> /dev/null; then
            # If it resolves, then ping to verify connectivity
            if ping -c 1 -W 1 host.docker.internal &> /dev/null; then
                echo "host.docker.internal"
            else
                # Hostname resolves but ping fails - still use fallback
                echo "172.18.0.1"
            fi
        else
            # Hostname doesn't resolve at all - use fallback immediately
            echo "172.18.0.1"
        fi
        ''', returnStdout: true).trim()
    }

    stages {
        stage('Setup') {
            steps {
                // // Use checkout SCM instead of git clone to avoid directory conflicts
                // checkout([$class: 'GitSCM',
                //     branches: [[name: '*/jenkinsSetup']],
                //     userRemoteConfigs: [[url: 'https://github.com/sslaquerre07/ENSF-400-Project/']]
                // ])

                // Start SonarQube Server
                sh '(docker stop sonarqube && docker rm sonarqube) || true'
                sh 'docker run -d --name sonarqube -p 9000:9000 sonarqube:9.2-community'

                // Login to Docker
                sh """echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin"""

                // Shutdown current deployment (if up)
                sh """(docker stop ${IMAGE_NAME} && docker rm ${IMAGE_NAME}) || true"""

            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    sh 'hostname'
                    sh 'ls'
                    sh 'echo $IP_ADDRESS'
                }
            }
        }

        // Stage for building the image
        stage('Build') {
            steps {
                script {
                    // Build the Docker image
                    sh 'docker build -t $IMAGE_NAME:$TAG .'
                }
            }
        }

        // Stage for pushing the image to DockerHub
        stage('Push to DockerHub') {
            steps {
                script {
                    sh '''
                        docker build -t $DOCKER_USER/$IMAGE_NAME:$TAG .
                        docker push $DOCKER_USER/$IMAGE_NAME:$TAG
                    '''
                }
            }
        }

        //Running the tests:
        stage('Tests') {
            agent {
                docker {
                    image 'gradle:7.6.1-jdk11'
                    reuseNode true  // This ensures the same workspace is used
                }
            }
            steps {
                script {
                    sh './gradlew check'
                }
            }
            post {
                always {
                    junit 'build/test-results/test/*.xml'
                }
            }
        }

        // Security Analysis with OWASP's "DependencyCheck"
        stage('Dependency Check') {
            agent {
                docker {
                    image 'gradle:7.6.1-jdk11'
                    reuseNode true  // This ensures the same workspace is used
                }
            }
            steps {
                script {
                    // Run OWASP Dependency-Check for security analysis
                    sh './gradlew dependencyCheckAnalyze'
                }
            }
        }

        //Generate and save JavaDocs as an artifact
        stage('Generate JavaDocs') {
            agent {
                docker {
                    image 'gradle:7.6.1-jdk11'
                    reuseNode true  // This ensures the same workspace is used
                }
            }
            steps {
                // Generate JavaDocs
                sh './gradlew javadoc'
            }
            post {
                success {
                    // Archive the generated JavaDocs as build artifacts
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'build/docs/javadoc/**'
                }
            }
        }

        // Use a docker in docker container to run sonarcube (can't figure out)
        stage('Static Analysis') {
            stages {
                stage('SonarQube Auth') {
                    steps {
                        script {
                            sh 'echo "Waiting for SonarQube to start..." && sleep 80'

                            // Remotely change login username and password
                            sh """
                        curl -X POST "http://${IP_ADDRESS}:9000/api/users/change_password" \
                        -H "Content-Type: application/x-www-form-urlencoded" \
                        -d "login=admin&previousPassword=admin&password=password" \
                        -u admin:admin
                    """
                        }
                    }
                }

                stage('SonarQube Analysis') {
                    agent {
                        docker {
                            image 'gradle:7.6.1-jdk11'
                            reuseNode true  // This ensures the same workspace is used
                        }
                    }
                    steps {
                        script {
                            sh "./gradlew sonarqube -Dsonar.host.url=http://${IP_ADDRESS}:9000"
                        }
                    }
                    post {
                        success {
                            sh 'echo SonarQube results available at 9000/?id=Demo'
                        }
                    }
                }
            }
        }

        // Stage for pulling the image and running the application
        stage('Deploy Application') {
            steps {
                script {
                    sh '''
                        docker pull $DOCKER_USER/$IMAGE_NAME:$TAG
                        docker run --name $IMAGE_NAME -di -p 8081:8080 $DOCKER_USER/$IMAGE_NAME:$TAG
                    '''
                }
            }
            post {
                success {
                    sh 'echo Deployment is available at 8081/demo'
                }
            }
        }

    }

    post {
        cleanup {
            // Clean up Docker resources
            sh 'docker system prune -f || true'
        }
    }
}
//Comment for pull request

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

                            // Wait for SonarQube to process results
                            sh 'sleep 10'

                            // Generate HTML report from SonarQube API
                            sh """
                # Create HTML report
                echo '<html><head><title>SonarQube Analysis Report</title>' > sonar-report.html
                echo '<style>body{font-family:Arial;} .metric{margin:15px;padding:15px;border:1px solid #ccc;border-radius:5px;} .good{background:#e7f6e7;} .bad{background:#f6e7e7;}</style>' >> sonar-report.html
                echo '</head><body><h1>SonarQube Analysis Report</h1>' >> sonar-report.html

                # Fetch project key
                PROJECT_KEY=\$(curl -s -u admin:password "http://${IP_ADDRESS}:9000/api/projects/search" | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)
                echo "<h2>Project: \$PROJECT_KEY</h2>" >> sonar-report.html

                # Get metrics and add to HTML
                curl -s -u admin:password "http://${IP_ADDRESS}:9000/api/measures/component?component=\$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,security_hotspots" > metrics.json

                # Parse metrics with grep and generate HTML
                echo '<div class="metrics">' >> sonar-report.html
                grep -o '"metric":"[^"]*","value":"[^"]*"' metrics.json | while read -r line; do
                    metric=\$(echo \$line | cut -d'"' -f4)
                    value=\$(echo \$line | cut -d'"' -f8)

                    # Determine class based on metric
                    class="good"
                    if [[ "\$metric" == "bugs" && "\$value" != "0" ]] || [[ "\$metric" == "vulnerabilities" && "\$value" != "0" ]] || [[ "\$metric" == "code_smells" && "\$value" -gt 5 ]]; then
                        class="bad"
                    fi

                    # Format metric name
                    formatted_metric=\$(echo \$metric | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) \$i=toupper(substr(\$i,1,1)) substr(\$i,2)} 1')

                    echo "<div class='metric \$class'><h3>\$formatted_metric</h3><p>\$value</p></div>" >> sonar-report.html
                done
                echo '</div>' >> sonar-report.html

                # Add screenshot/link
                echo "<h2>SonarQube Dashboard</h2>" >> sonar-report.html
                echo "<p>View full report at: <a href='http://${IP_ADDRESS}:9000/dashboard?id=\$PROJECT_KEY' target='_blank'>SonarQube Dashboard</a></p>" >> sonar-report.html
                echo '</body></html>' >> sonar-report.html
            """
                        }
                    }
                    post {
                        success {
                            // Archive the HTML report
                            archiveArtifacts artifacts: 'sonar-report.html', fingerprint: true

                        // If you have the HTML Publisher plugin installed, you can also use:
                        // publishHTML([
                        //     allowMissing: false,
                        //     alwaysLinkToLastBuild: true,
                        //     keepAll: true,
                        //     reportDir: '.',
                        //     reportFiles: 'sonar-report.html',
                        //     reportName: 'SonarQube Analysis Report'
                        // ])
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
                    sh 'echo Deployment is up on 8081/demo'
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

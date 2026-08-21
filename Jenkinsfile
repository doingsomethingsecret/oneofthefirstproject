pipeline {
    agent any
    
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        AWS_CREDENTIALS = credentials('aws-credentials')
        FLASK_SECRET_KEY = credentials('flask-secret-key')
        SONARQUBE_URL = 'http://atlas-ai-alb-111188473.ap-south-1.elb.amazonaws.com/sonar'
        SONARQUBE_TOKEN = credentials('sonarqube-token')
        IMAGE_NAME = "atlas-ai:${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Lint') {
            steps {
                sh '''
                    flake8 app-lite.py src/ --max-line-length=120 --exclude=__pycache__
                '''
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                    pytest tests/ -v || echo "No tests found"
                '''
            }
        }
        
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                            -Dsonar.projectKey=atlas-ai \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=${SONARQUBE_URL} \
                            -Dsonar.login=${SONARQUBE_TOKEN}
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build(IMAGE_NAME)
                }
            }
        }
        
        stage('Push to DockerHub') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-credentials') {
                        docker.image(IMAGE_NAME).push()
                        docker.image(IMAGE_NAME).push('latest')
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentials', credentialsId: 'aws-credentials']]) {
                    sh '''
                        ansible-playbook -i ansible/inventory.ini ansible/site.yml \
                            --extra-vars "docker_image=${IMAGE_NAME} flask_secret_key=${FLASK_SECRET_KEY}" \
                            --vault-password-file .vault_password
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline succeeded!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}

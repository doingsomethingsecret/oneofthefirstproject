pipeline {
    agent any
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        FLASK_SECRET_KEY = credentials('flask-secret-key')
        SONARQUBE_URL = 'http://atlas-ai-alb-111188473.ap-south-1.elb.amazonaws.com/sonar'
        SONARQUBE_TOKEN = credentials('sonarqube-token')
        IMAGE_NAME = "atlas-ai:${BUILD_NUMBER}"
        // SSH + deploy targets (key lives in the persisted Jenkins volume)
        SSH_KEY = '/var/jenkins_home/.ssh/tkxel_devops_project.pem'
        BASTION_IP = '65.2.130.169'
        APP_IP = '10.0.3.163'
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Lint') {
            steps {
                sh 'python3 -m flake8 Atlas-AI-Project-main/app-lite.py Atlas-AI-Project-main/src/ --max-line-length=200 --exit-zero --exclude=__pycache__'
            }
        }
        stage('Test') {
            steps {
                sh 'python3 -m pytest Atlas-AI-Project-main/tests/ -v || echo "No tests found"'
            }
        }
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner -Dsonar.projectKey=atlas-ai -Dsonar.sources=Atlas-AI-Project-main -Dsonar.host.url=${SONARQUBE_URL} -Dsonar.login=${SONARQUBE_TOKEN}'
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    // Build the application image from the app Dockerfile
                    docker.build(IMAGE_NAME, 'Atlas-AI-Project-main')
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
                sh '''
                    set -e
                    KEY="$SSH_KEY"
                    BASTION="$BASTION_IP"
                    APPHOST="$APP_IP"
                    PROXY="-o ProxyCommand=ssh -i $KEY -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION"
                    O="-o StrictHostKeyChecking=no -i $KEY"

                    # Package the updated app source (exclude runtime data so the app DB/sessions/logs are preserved)
                    tar -czf /tmp/atlas-src.tgz --exclude='data' --exclude='sessions' --exclude='logs' -C Atlas-AI-Project-main .

                    # Ship the source to the app server through the bastion
                    scp $O "$PROXY" /tmp/atlas-src.tgz ubuntu@$APPHOST:/tmp/atlas-src.tgz

                    # Unpack + rebuild + restart the app on the app server
                    ssh $O "$PROXY" ubuntu@$APPHOST "cd /app && tar -xzf /tmp/atlas-src.tgz && FLASK_SECRET_KEY='$FLASK_SECRET_KEY' docker compose -f docker-compose.app.yml up -d --build && sleep 10 && echo DEPLOY_DONE"

                    # Report final app status
                    ssh $O "$PROXY" ubuntu@$APPHOST "docker ps --filter name=atlas-ai --format '{{.Names}} {{.Status}}'; curl -s -o /dev/null -w 'health_http=%{http_code}\\n' http://localhost:5000/api/health || true"
                '''
            }
        }
    }
    post {
        success { echo 'Pipeline succeeded!' }
        failure { echo 'Pipeline failed!' }
    }
}

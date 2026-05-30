# Setup Guide — DevSecOps on AWS EKS

## Prerequisites
- AWS CLI >= 2.x configured
- Terraform >= 1.5.0
- kubectl >= 1.29
- Helm >= 3.x
- Docker >= 24.x
- Git

---

## Step 1 — Bootstrap Remote State

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
# Note the S3 bucket name from output
```

Update `terraform/backend.tf` — replace `REPLACE_WITH_ACCOUNT_ID` with your AWS account ID.

---

## Step 2 — Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

Expected outputs:
```
eks_cluster_name     = "devsecops-eks-cluster"
ecr_repository_url   = "ACCOUNT.dkr.ecr.us-west-2.amazonaws.com/devsecops-app"
kubeconfig_command   = "aws eks update-kubeconfig ..."
```

---

## Step 3 — Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name devsecops-eks-cluster
kubectl get nodes
kubectl get namespaces
```

Expected namespaces: `jenkins`, `sonarqube`, `dev`, `monitoring`

---

## Step 4 — Install Jenkins

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/helm-values.yaml \
  --wait

# Get Jenkins URL
kubectl get svc jenkins -n jenkins

# Get admin password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password
```

### Configure Jenkins Credentials
In Jenkins UI → Manage Jenkins → Credentials → Add:
- `ECR_REPO_URL` — ECR repository URL
- `SONAR_URL` — SonarQube URL
- `SONAR_TOKEN` — SonarQube token
- `AWS_CREDENTIALS` — AWS IAM role or keys

---

## Step 5 — Install SonarQube

```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --values sonarqube/helm-values.yaml \
  --wait

kubectl get svc sonarqube-sonarqube -n sonarqube
```

### Configure SonarQube
1. Login at SonarQube URL (admin/admin — change immediately)
2. Create project: `devsecops-app`
3. Generate token: My Account → Security → Generate Token
4. Add token to Jenkins credentials as `SONAR_TOKEN`
5. Configure Quality Gate: Projects → Quality Gates → set conditions

---

## Step 6 — Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml \
  --wait

kubectl get svc -n monitoring
```

Access Grafana:
```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Open http://localhost:3000 — admin/admin123
```

---

## Step 7 — Enable CloudWatch Container Insights

```bash
ClusterName=devsecops-eks-cluster
RegionName=us-west-2
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'

curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | \
  sed "s/{{cluster_name}}/${ClusterName}/;s/{{region_name}}/${RegionName}/;s/{{http_port}}/${FluentBitHttpPort}/;s/{{read_from_head}}/${FluentBitReadFromHead}/" | \
  kubectl apply -f -
```

---

## Step 8 — Build and Push Docker Image (manual test)

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/devsecops-app"

aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin ${ECR_URL}

cd app
docker build -t ${ECR_URL}:latest .
docker push ${ECR_URL}:latest
```

---

## Step 9 — Deploy Application

```bash
# Update image in deployment.yaml with your account ID and tag
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secret.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/hpa.yaml

kubectl rollout status deployment/devsecops-app -n dev
kubectl get pods -n dev
```

---

## Step 10 — Create Jenkins Pipeline

1. Jenkins UI → New Item → Pipeline
2. Pipeline script from SCM → Git → your repo URL
3. Script Path: `jenkins/Jenkinsfile`
4. Save and Build

---

## Validation Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# App health
kubectl get pods -n dev
kubectl logs -n dev -l app=devsecops-app

# HPA status
kubectl get hpa -n dev

# Jenkins
kubectl get pods -n jenkins
kubectl get svc -n jenkins

# SonarQube
kubectl get pods -n sonarqube

# Monitoring
kubectl get pods -n monitoring
```

---

## Cleanup

```bash
# Remove app
kubectl delete -f kubernetes/

# Remove Helm releases
helm uninstall jenkins -n jenkins
helm uninstall sonarqube -n sonarqube
helm uninstall monitoring -n monitoring

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Nodes NotReady | Check node group in AWS Console → EC2 |
| Jenkins pod Pending | Check PVC — `kubectl get pvc -n jenkins` |
| ECR push denied | Run `aws ecr get-login-password` again |
| SonarQube OOMKilled | Increase memory in helm-values.yaml |
| Pipeline fails Quality Gate | Fix code issues flagged by SonarQube |
| Trivy HIGH found | Fix vulnerabilities or update base image |

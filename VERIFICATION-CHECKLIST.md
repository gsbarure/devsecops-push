# Post-Deployment Verification Checklist

Run these checks after `./run.sh deploy` completes.

---

## 1. AWS Infrastructure (Terraform)

### VPC
```bash
aws ec2 describe-vpcs --region us-west-2 --filters "Name=tag:Name,Values=devsecops-vpc" --output table
```
**Expected:** 1 VPC with CIDR 10.0.0.0/16, State = available

```bash
aws ec2 describe-subnets --region us-west-2 --filters "Name=vpc-id,Values=<VPC_ID>" --output table
```
**Expected:** 4 subnets — 2 public (10.0.1.x, 10.0.2.x), 2 private (10.0.10.x, 10.0.11.x)

```bash
aws ec2 describe-nat-gateways --region us-west-2 --output table
```
**Expected:** 2 NAT Gateways, State = available

### EKS Cluster
```bash
aws eks describe-cluster --name devsecops-eks-cluster --region us-west-2 --output table
```
**Expected:** Status = ACTIVE, Version = 1.29

```bash
aws eks list-nodegroups --cluster-name devsecops-eks-cluster --region us-west-2
```
**Expected:** nodegroup = devsecops-node-group

### ECR Repository
```bash
aws ecr describe-repositories --region us-west-2 --output table
```
**Expected:** Repository = devsecops-app, imageScanningConfiguration.scanOnPush = true

```bash
aws ecr list-images --repository-name devsecops-app --region us-west-2 --output table
```
**Expected:** At least 2 image tags — latest and 1.0.0-ansible

### IAM Roles
```bash
aws iam list-roles --query "Roles[?contains(RoleName,'devsecops')].[RoleName]" --output table
```
**Expected:** 3 roles — devsecops-eks-cluster-role, devsecops-eks-node-role, devsecops-jenkins-irsa

---

## 2. Kubernetes Cluster

### Nodes
```bash
kubectl get nodes -o wide
```
**Expected:** 3 nodes, Status = Ready, Roles = none (managed node group)

```bash
kubectl top nodes
```
**Expected:** CPU and memory usage shown per node

### Namespaces
```bash
kubectl get namespaces
```
**Expected output:**
```
NAME              STATUS
default           Active
jenkins           Active
sonarqube         Active
dev               Active
monitoring        Active
amazon-cloudwatch Active
kube-system       Active
```

### RBAC
```bash
kubectl get clusterrolebinding jenkins-cluster-role-binding
kubectl get serviceaccount jenkins -n jenkins
```
**Expected:** Both exist, SA has IRSA annotation with IAM role ARN

---

## 3. Jenkins

### Pod Status
```bash
kubectl get pods -n jenkins
```
**Expected:** jenkins-0 pod, Status = Running, Ready = 2/2

```bash
kubectl get svc -n jenkins
```
**Expected:** jenkins service, Type = LoadBalancer, EXTERNAL-IP = AWS hostname

### PVC (Persistent Volume)
```bash
kubectl get pvc -n jenkins
```
**Expected:** jenkins PVC, Status = Bound, Storage = 20Gi

### Access Jenkins UI
```bash
# Get URL
kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
Open in browser: `http://<URL>:8080`

**What to verify in Jenkins UI:**
- [ ] Login works (admin / admin123)
- [ ] Dashboard loads
- [ ] Manage Jenkins → Plugins → Installed: Git, Pipeline, Docker, Kubernetes, SonarQube Scanner, Amazon ECR
- [ ] Manage Jenkins → Nodes → Built-In Node shows online
- [ ] Manage Jenkins → Clouds → Kubernetes cloud configured

---

## 4. SonarQube

### Pod Status
```bash
kubectl get pods -n sonarqube
```
**Expected:** sonarqube-sonarqube-0, Status = Running, Ready = 1/1

```bash
kubectl get svc -n sonarqube
```
**Expected:** LoadBalancer with external hostname

### API Health Check
```bash
SONAR_URL=$(kubectl get svc sonarqube-sonarqube -n sonarqube -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://${SONAR_URL}:9000/api/system/status
```
**Expected:** `{"status":"UP"}`

### Access SonarQube UI
Open: `http://<SONAR_URL>:9000`

**What to verify in SonarQube UI:**
- [ ] Login works (admin / admin)
- [ ] Administration → System → System Info shows UP
- [ ] Projects tab (empty until first pipeline run)
- [ ] Quality Gates → Sonar way gate exists
- [ ] Administration → Security → Force authentication = ON

---

## 5. Prometheus + Grafana

### Pod Status
```bash
kubectl get pods -n monitoring
```
**Expected pods:**
```
monitoring-grafana-xxx                    Running
monitoring-kube-prometheus-operator-xxx  Running
monitoring-prometheus-xxx                Running
alertmanager-monitoring-xxx              Running
```

### Prometheus Targets
```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &
```
Open: `http://localhost:9090/targets`

**What to verify:**
- [ ] kubernetes-nodes targets = UP
- [ ] kubernetes-pods targets = UP
- [ ] kube-state-metrics = UP

### Grafana
```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
```
Open: `http://localhost:3000` (admin / admin123)

**What to verify in Grafana:**
- [ ] Login works
- [ ] Dashboards → DevSecOps folder exists
- [ ] Dashboard: Kubernetes Cluster (ID 7249) — shows node CPU/memory
- [ ] Dashboard: Node Exporter (ID 1860) — shows disk, network
- [ ] Dashboard: Jenkins (ID 9964) — shows build metrics
- [ ] Data Sources → Prometheus = Connected (green)

---

## 6. Application

### Pod Status
```bash
kubectl get pods -n dev -l app=devsecops-app -o wide
```
**Expected:** 2 pods, Status = Running, Ready = 1/1

### HPA
```bash
kubectl get hpa -n dev
```
**Expected:** devsecops-app-hpa, MINPODS=2, MAXPODS=10, TARGETS showing CPU%

### Health Endpoints
```bash
kubectl port-forward svc/devsecops-app-svc 8080:80 -n dev &
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/
```
**Expected responses:**
```json
{"status":"healthy","timestamp":"2026-..."}
{"status":"ready","timestamp":"2026-..."}
{"message":"DevSecOps App","version":"1.0.0","status":"running"}
```

### Liveness and Readiness Probes
```bash
kubectl describe pod -n dev -l app=devsecops-app | grep -A5 "Liveness\|Readiness"
```
**Expected:** Both probes configured, Last State shows no failures

---

## 7. Trivy Security Scans

### Run manually to verify
```bash
# Image scan
ECR_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)
trivy image ${ECR_URL}:latest

# Filesystem scan
trivy fs app/

# Terraform IaC scan
trivy config terraform/

# Kubernetes manifest scan
trivy config kubernetes/
```

**What to look for:**
- CRITICAL vulnerabilities → must be 0 for pipeline to pass
- HIGH vulnerabilities → pipeline fails if found in image scan
- Terraform misconfigs → informational (exit-code 0)
- K8s manifest issues → informational (exit-code 0)

---

## 8. CloudWatch Container Insights

```bash
kubectl get pods -n amazon-cloudwatch
```
**Expected:** cloudwatch-agent and fluent-bit DaemonSet pods on every node

**In AWS Console:**
- CloudWatch → Container Insights → Performance Monitoring
- Select cluster: devsecops-eks-cluster
- View: EKS Nodes, EKS Pods, EKS Services

---

## 9. Full Pipeline Run (Jenkins)

1. Open Jenkins UI
2. New Item → Pipeline → name: `devsecops-pipeline`
3. Pipeline from SCM → Git → `https://github.com/gsbarure/devsecops-push`
4. Script Path: `jenkins/Jenkinsfile`
5. Save → Build Now

**Expected pipeline stages (all green):**
```
✅ Git Checkout
✅ Terraform Validate
✅ Trivy Terraform Scan
✅ SonarQube Scan
✅ Quality Gate
✅ Docker Build
✅ Trivy Filesystem Scan
✅ Trivy Image Scan
✅ Push to ECR
✅ Update K8s Manifest
✅ Trivy K8s Manifest Scan
✅ Deploy to EKS
✅ Post Deployment Verification
```

**After pipeline runs — verify in SonarQube:**
- Project `devsecops-app` appears
- Quality Gate = PASSED
- 0 Bugs, 0 Vulnerabilities

**After pipeline runs — verify in ECR:**
```bash
aws ecr list-images --repository-name devsecops-app --region us-west-2 --output table
```
**Expected:** New image tag with build number and git commit hash

---

## 10. Quick Summary Command

Run this single command to get a health snapshot of everything:

```bash
echo "=== NODES ===" && kubectl get nodes && \
echo "=== NAMESPACES ===" && kubectl get ns && \
echo "=== JENKINS ===" && kubectl get pods,svc -n jenkins && \
echo "=== SONARQUBE ===" && kubectl get pods,svc -n sonarqube && \
echo "=== MONITORING ===" && kubectl get pods -n monitoring && \
echo "=== APP ===" && kubectl get pods,svc,hpa -n dev && \
echo "=== ECR IMAGES ===" && aws ecr list-images --repository-name devsecops-app --region us-west-2 --output table
```

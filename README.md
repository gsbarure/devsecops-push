# DevSecOps on AWS — EKS + Jenkins + SonarQube + Trivy

End-to-end DevSecOps pipeline on AWS using Terraform, EKS, Jenkins, SonarQube, Trivy, Docker, ECR.

## Architecture

```
Developer → GitHub → Jenkins (EKS)
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         SonarQube    Trivy      Docker Build
         (Code Scan)  (Security)  │
              │          │        ▼
         Quality Gate  Fail on   ECR Push
              │        HIGH/CRIT  │
              └──────────┴────────┘
                         │
                    EKS Deploy (dev ns)
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
         Prometheus             CloudWatch
         + Grafana            Container Insights
```

## Stack
| Tool | Purpose |
|------|---------|
| Terraform | All AWS infrastructure (VPC, EKS, ECR, IAM) |
| AWS EKS | Kubernetes — private worker nodes |
| AWS ECR | Container image registry |
| Jenkins | CI/CD — deployed on EKS via Helm |
| SonarQube | Static code analysis + Quality Gates |
| Trivy | Security scanning (code, image, K8s, Terraform) |
| Prometheus + Grafana | Monitoring and dashboards |
| CloudWatch | Container Insights logging |

## Folder Structure
```
devsecops-eks-aws/
├── terraform/
│   ├── bootstrap/          # S3 + DynamoDB for remote state (run once)
│   ├── modules/
│   │   ├── vpc/            # VPC, subnets, IGW, NAT, routes
│   │   ├── security-groups/# EKS cluster + node SGs
│   │   ├── iam/            # Cluster + node IAM roles
│   │   ├── ecr/            # ECR repository
│   │   ├── eks/            # EKS cluster + managed node group
│   │   └── k8s-setup/      # Namespaces + RBAC
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   └── hpa.yaml
├── jenkins/
│   ├── Jenkinsfile
│   └── helm-values.yaml
├── sonarqube/
│   ├── helm-values.yaml
│   └── sonar-project.properties
├── monitoring/
│   └── prometheus-values.yaml
├── app/
│   ├── app.js
│   ├── app.test.js
│   ├── package.json
│   └── Dockerfile
└── SETUP-GUIDE.md
```

## Quick Start
See [SETUP-GUIDE.md](./SETUP-GUIDE.md)

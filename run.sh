#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# DevSecOps EKS — Single Execution Script
# Terraform handles infra, Ansible handles installations
#
# Usage:
#   ./run.sh deploy    → Deploy everything
#   ./run.sh destroy   → Tear down everything
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log()     { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"; exit 1; }
section() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}\n"; }

AWS_REGION="us-west-2"
ACTION="${1:-deploy}"
ANSIBLE_DIR="ansible"
INVENTORY="${ANSIBLE_DIR}/inventory/hosts.yml"

# ── Check prerequisites ────────────────────────
check_prerequisites() {
  section "Checking Prerequisites"
  for tool in aws terraform ansible kubectl helm docker; do
    command -v $tool &>/dev/null && log "$tool: OK" || error "$tool not installed"
  done
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  CALLER=$(aws sts get-caller-identity --query Arn --output text)
  log "AWS Account : ${ACCOUNT_ID}"
  log "IAM Principal: ${CALLER}"
}

# ── DEPLOY ─────────────────────────────────────
deploy() {
  section "DEPLOY — Terraform + Ansible"

  # Step 1: Bootstrap S3 + DynamoDB
  section "Step 1/8 — Bootstrap Remote State (Terraform)"
  cd terraform/bootstrap
  terraform init -input=false
  terraform apply -auto-approve -input=false
  S3_BUCKET=$(terraform output -raw s3_bucket)
  log "S3 bucket: ${S3_BUCKET}"
  cd ../..
  sed -i "s/REPLACE_WITH_ACCOUNT_ID/${ACCOUNT_ID}/g" terraform/backend.tf
  log "backend.tf updated"

  # Step 2: Deploy infrastructure
  section "Step 2/8 — Deploy AWS Infrastructure (Terraform)"
  cd terraform
  terraform init -input=false -reconfigure
  terraform validate && log "Validate passed"
  terraform plan -out=tfplan -input=false
  terraform apply -auto-approve tfplan
  log "Infrastructure deployed"
  cd ..

  # Step 3–7: Ansible handles all installations
  section "Step 3/8 — Configure kubectl (Ansible)"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/01-configure-kubectl.yml

  section "Step 4/8 — Install Jenkins (Ansible + Helm)"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/02-install-jenkins.yml

  section "Step 5/8 — Install SonarQube (Ansible + Helm)"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/03-install-sonarqube.yml

  section "Step 6/8 — Install Prometheus + Grafana (Ansible + Helm)"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/04-install-monitoring.yml

  section "Step 7/8 — Enable CloudWatch Container Insights (Ansible)"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/05-install-cloudwatch.yml

  section "Step 8/8 — Build, Push Docker Image, Deploy App (Ansible)"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/06-build-push-deploy.yml

  # Print full summary with all URLs
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/07-print-summary.yml
}

# ── DESTROY ────────────────────────────────────
destroy() {
  section "DESTROY — Ansible + Terraform"
  ansible-playbook -i ${INVENTORY} ${ANSIBLE_DIR}/playbooks/08-destroy.yml
}

# ── MAIN ───────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   DevSecOps EKS — Terraform + Ansible Automation            ║"
echo "║   Action : ${ACTION^^}                                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

check_prerequisites

case "${ACTION}" in
  deploy)  deploy  ;;
  destroy) destroy ;;
  *) error "Unknown action: ${ACTION}. Use 'deploy' or 'destroy'" ;;
esac

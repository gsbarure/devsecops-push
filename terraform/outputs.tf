output "vpc_id"               { value = module.vpc.vpc_id }
output "eks_cluster_name"     { value = module.eks.cluster_name }
output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "ecr_repository_url"   { value = module.ecr.repository_url }
output "jenkins_irsa_arn"     { value = module.iam.jenkins_irsa_arn }
output "kubeconfig_command"   { value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}" }

output "cluster_name"     { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_ca"       { value = aws_eks_cluster.main.certificate_authority[0].data }
output "cluster_arn"      { value = aws_eks_cluster.main.arn }
output "oidc_issuer_url"  { value = aws_eks_cluster.main.identity[0].oidc[0].issuer }

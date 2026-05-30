output "eks_cluster_sg_id" { value = aws_security_group.eks_cluster.id }
output "eks_node_sg_id"    { value = aws_security_group.eks_nodes.id }

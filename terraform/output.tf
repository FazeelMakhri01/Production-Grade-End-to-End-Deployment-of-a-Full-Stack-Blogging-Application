output "eks_cluster_id" {
    value = aws_eks_cluster.eks_cluster.id
  
}

output "eks_node_group_id" {
    value = aws_eks_node_group.node_group.id  
}

output "vpc_id" {
    value = aws_vpc.main_vpc.id
}

output "subnet_id" {
    value = aws_subnet.subnet[*].id
  
}
resource "aws_vpc" "main_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "main_vpc"
    }
}

resource "aws_subnet" "subnet" {
    count = 2
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index)
    availability_zone = element([ "eu-west-2a", "eu-west-2b" ], count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "subnet-${count.index}"
    }
  
}

resource "aws_internet_gateway" "Internet_Gateway" {
    vpc_id = aws_vpc.main_vpc.id
    tags = {
        Name = "Internet_Gateway"
    }
}

resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.main_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.Internet_Gateway.id
    }
        tags = {
            Name = "route_table"
        }
}

resource "aws_route_table_association" "route_table_association" {
    count = 2
    subnet_id = aws_subnet.subnet[count.index].id
    route_table_id = aws_route_table.route_table.id

}

resource "aws_security_group" "cluster_sg" {
    name = "cluster_sg"
    description = "Security group for the cluster"
    vpc_id = aws_vpc.main_vpc.id

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
}
    tags = {
        Name = "cluster_sg"
    }
}

resource "aws_security_group" "nodes_sg" {
    name = "nodes_sg"
    description = "Security group for the nodes"
    vpc_id = aws_vpc.main_vpc.id

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "nodes_sg"
    }
}

resource "aws_eks_cluster" "eks_cluster" {
    name = "eks_cluster"
    role_arn = aws_iam_role.eks_cluster_role.arn

    vpc_config {
        subnet_ids = aws_subnet.subnet[*].id
        security_group_ids = [aws_security_group.cluster_sg.id]
    }  
}

resource "aws_eks_node_group" "node_group" {
    cluster_name = aws_eks_cluster.eks_cluster.name
    node_group_name = "eks_node_group"
    node_role_arn = aws_iam_role.eks_node_group_role.arn
    subnet_ids = aws_subnet.subnet[*].id

    scaling_config {
        desired_size = 3
        max_size = 3
        min_size = 3
    }

    instance_types = ["t2.large"]
    remote_access {
      ec2_ssh_key = var.ssh_key_name
      source_security_group_ids = [aws_security_group.nodes_sg.id]
    }
}

resource "aws_iam_role" "eks_cluster_role" {
    name = "eks_cluster_role"
    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "eks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
    role = aws_iam_role.eks_cluster_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  
}

resource "aws_iam_role" "eks_node_group_role" {
    name = "eks_node_group_role"
    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attachment" {
    role = aws_iam_role.eks_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_cni_policy_attachment" {
    role = aws_iam_role.eks_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_registry_policy_attachment" {
    role = aws_iam_role.eks_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" 
}
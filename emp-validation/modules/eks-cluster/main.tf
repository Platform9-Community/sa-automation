provider "aws" {
    region = "us-east-1"
    access_key = var.iam_access_key
    secret_key = var.iam_secret_key
}

module "vpc-and-more" {
    source = "../vpc-and-more"
    iam_access_key = module.iam.iam_access_key_id
    iam_secret_key = module.iam.iam_secret_access_key
}

resource "aws_eks_cluster" "eks_cluster" {
    name = "emp-test-cluster-${random_string.name-extension.result}"
    version = "1.27"
    role_arn = aws_iam_role.eks_iam_role.arn



    vpc_config {
        vpc_id = module.vpc-and-more.vpc-subnets-nat-igw-rt["vpc"]
        subnet_ids = [ 
            module.vpc-and-more.vpc-subnets-nat-igw-rt["private_subnet_1a"],
            module.vpc-and-more.vpc-subnets-nat-igw-rt["private_subnet_1b"],
            module.vpc-and-more.vpc-subnets-nat-igw-rt["public_subnet_1a"],
            module.vpc-and-more.vpc-subnets-nat-igw-rt["public_subnet_1b"]
        ]

        security_group_ids = [ aws_security_group.eks_cluster_sg.id ]
    }

}

resource "aws_eks_node_group" "eks_cluster_nodegroup" {
    cluster_name = aws_eks_cluster.eks_cluster.name
    node_group_name = "emp-test-cluster-ng-${random_string.name-extension.result}"
    node_role_arn = aws_iam_role.eks_iam_nodegroup_role.arn
    instance_types = [ "t3.small" ]
    subnet_ids = [ 
        module.vpc-and-more.vpc-subnets-nat-igw-rt["private_subnet_1a"],
        module.vpc-and-more.vpc-subnets-nat-igw-rt["private_subnet_1b"],
        module.vpc-and-more.vpc-subnets-nat-igw-rt["public_subnet_1a"],
        module.vpc-and-more.vpc-subnets-nat-igw-rt["public_subnet_1b"]
       ]
    scaling_config {
      min_size = 1
      max_size = 4
      desired_size = 1
      
    }

    remote_access {
      ec2_ssh_key = "emp-validation-key"
    }

 
}

resource "aws_security_group" "eks_cluster_sg" {
  vpc_id = module.vpc-and-more.vpc-subnets-nat-igw-rt["vpc"]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create an iam role, Trust relationship, and attach the role to an AWS managed policy for eks cluster.
resource "aws_iam_role" "eks_iam_role" {
    name = "eks-iam-role"
    assume_role_policy = data.aws_iam_policy_document.eks_policy_doc.json
}

data "aws_iam_policy_document" "eks_iam_policy_doc" {
    statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eks_iam_policy_attachment" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = aws_iam_role.eks_iam_role.name
}


# Create an iam role, Trust relationship, and attach the role to AWS managed policies for eks cluster's nodegroup.
resource "aws_iam_role" "eks_iam_nodegroup_role" {
    name = "eks_iam_nodegroup_role"
    assume_role_policy = data.aws_iam_policy_document.eks_iam_nodegroup_policy_doc.json
}

data "aws_iam_policy_document" "eks_iam_nodegroup_policy_doc" {
    statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }   
}

resource "aws_iam_role_policy_attachment" "eks_iam_nodegroup_policy_attachment-1" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role = aws_iam_role.eks_iam_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks_iam_nodegroup_policy_attachment-2" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role = aws_iam_role.eks_iam_nodegroup_role.name
}



resource "random_string" "name-extension" {
    length = 5
    special = false
    upper = false
}
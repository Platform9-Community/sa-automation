provider "aws" {
  region = "us-east-1"
}


module "iam" {
    source = "./modules/iam" 
}

module "vpc" {
  source = "./modules/vpc-and-more"
  iam_access_key = module.iam.iam_access_key_id
  iam_secret_key = module.iam.iam_secret_access_key
  
  depends_on = [ module.iam ]
}

module "eks_cluster" {
  source = "./modules/eks-cluster"
  iam_access_key = module.iam.iam_access_key_id
  iam_secret_key = module.iam.iam_secret_access_key

  depends_on = [ module.vpc ]
}

module "ec2" {
  source = "./modules/ec2"
  iam_access_key = module.iam.iam_access_key_id
  iam_secret_key = module.iam.iam_secret_access_key

  depends_on = [ module.vpc ]
}


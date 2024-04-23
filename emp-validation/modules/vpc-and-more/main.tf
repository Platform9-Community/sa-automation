provider "aws" {
  region = "us-east-1"
  access_key = var.iam_access_key
  secret_key = var.iam_secret_key
}

# Create a custom VPC
resource "aws_vpc" "emptesting_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = { Name = "emptesting_vpc" }
}

# Create an internet gateway
resource "aws_internet_gateway" "emptesting_igw" {
  vpc_id = aws_vpc.emptesting_vpc.id

  tags = { Name = "emptesting_igw" }
}

# Create NAT Gateway
resource "aws_nat_gateway" "emptesting_nat_gateway" {
  allocation_id = aws_eip.emptesting_eip.id
  subnet_id = aws_subnet.emptesting_public_subnet_1a.id
  
  depends_on = [
    aws_internet_gateway.emptesting_igw
  ]

tags = { Name = "emptesting_nat_gateway" }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "emptesting_eip" {
    domain = "vpc"

    depends_on = [
    aws_internet_gateway.emptesting_igw
  ]

tags = { Name = "emptesting_eip" }

}

# Create 2 private subnets within the VPC
resource "aws_subnet" "emptesting_private_subnet_1a" {
  vpc_id            = aws_vpc.emptesting_vpc.id
  cidr_block        = var.private_subnet_1a
  availability_zone = "us-east-1a"

  # Dependency for attaching route table
  depends_on = [
    aws_nat_gateway.emptesting_nat_gateway
  ]

  tags = {Name = "emptesting_private_subnet_1a"}

}

resource "aws_subnet" "emptesting_private_subnet_1b" {
  vpc_id            = aws_vpc.emptesting_vpc.id
  cidr_block        = var.private_subnet_1b
  availability_zone = "us-east-1b"

  # Dependency for attaching route table
  depends_on = [
    aws_nat_gateway.emptesting_nat_gateway
  ]

  tags = {Name = "emptesting_private_subnet_1b"}

}

# Create 2 public subnets within the VPC
resource "aws_subnet" "emptesting_public_subnet_1a" {
  vpc_id            =  aws_vpc.emptesting_vpc.id
  cidr_block        = var.public_subnet_1a
  availability_zone = "us-east-1a"

  tags = {Name = "emptesting_public_subnet_1a"}
}

resource "aws_subnet" "emptesting_public_subnet_1b" {
  vpc_id            = aws_vpc.emptesting_vpc.id
  cidr_block        = var.public_subnet_1b
  availability_zone = "us-east-1b"

  tags = {Name = "emptesting_public_subnet_1b"}
}

# Create route table for private subnets
resource "aws_route_table" "emptesting_private_route_table1_us-east-1a" {
  vpc_id = aws_vpc.emptesting_vpc.id

  route {
    cidr_block = var.rt_cidr_all
    nat_gateway_id = aws_nat_gateway.emptesting_nat_gateway.id
  }

  tags = {Name = "emptesting_private_route_table1_us-east-1a"}
}

resource "aws_route_table" "emptesting_private_route_table2_us-east-1b" {
  vpc_id = aws_vpc.emptesting_vpc.id

  route {
    cidr_block = var.rt_cidr_all
    nat_gateway_id = aws_nat_gateway.emptesting_nat_gateway.id
  }

  tags = {Name = "emptesting_private_route_table2_us-east-1b"}
}

# Create route table for the public subnets
resource "aws_route_table" "emptesting_public_route_table" {
  vpc_id = aws_vpc.emptesting_vpc.id

  route {
    cidr_block = var.rt_cidr_all
    gateway_id = aws_internet_gateway.emptesting_igw.id
  }

  tags = {Name = "emptesting_public_route_table"}
}

# Create VPC S3 Endpoint
resource "aws_vpc_endpoint" "emptesting_s3_endpoint" {
  vpc_id       = aws_vpc.emptesting_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"

  tags = {Name = "emptesting_s3_endpoint"}
}

# Associate private route table with the private subnets
resource "aws_route_table_association" "emptesting_private_subnet_1a_association" {
  subnet_id      = aws_subnet.emptesting_private_subnet_1a.id
  route_table_id = aws_route_table.emptesting_private_route_table1_us-east-1a.id
}

resource "aws_route_table_association" "emptesting_private_subnet_1b_association" {
  subnet_id      = aws_subnet.emptesting_private_subnet_1b.id
  route_table_id = aws_route_table.emptesting_private_route_table2_us-east-1b.id
}


# Associate public route table with the public subnets
resource "aws_route_table_association" "emptesting_public_subnet_1a_association" {
  subnet_id      = aws_subnet.emptesting_public_subnet_1a.id
  route_table_id = aws_route_table.emptesting_public_route_table.id
}

resource "aws_route_table_association" "emptesting_public_subnet_1b_association" {
  subnet_id      = aws_subnet.emptesting_public_subnet_1b.id
  route_table_id = aws_route_table.emptesting_public_route_table.id
}

# Associate S3 endpoint with the private route tables
resource "aws_vpc_endpoint_route_table_association" "emptesting_s3_endpoint_association_1a" {
  vpc_endpoint_id = aws_vpc_endpoint.emptesting_s3_endpoint.id
  route_table_id  = aws_route_table.emptesting_private_route_table1_us-east-1a.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_association_b" {
  vpc_endpoint_id = aws_vpc_endpoint.emptesting_s3_endpoint.id
  route_table_id  = aws_route_table.emptesting_private_route_table2_us-east-1b.id
}


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

# Create ec2 instance.
resource "aws_instance" "emp-terraform-example_ec2" {
  ami           = "ami-080e1f13689e07408"
  instance_type = "t2.micro"
  key_name      = "emp-validation-key"
  associate_public_ip_address = true
  subnet_id = module.vpc-and-more.vpc-subnets-nat-igw-rt["public_subnet_1a"]
  security_groups = [ aws_security_group.example_security_group.name ]

  tags = {
    Name = "emp-terraform-example_ec2"
  }

# create ssh key pair within the ec2 instance
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      host = "${aws_instance.emp-terraform-example_ec2.public_ip}"
      private_key = "${file("../../emp-validation-key.pem")}"
      agent = false
      timeout = "3m"
    }
    inline = [ 
      "ssh-keygen -N '' -f ~/.ssh/id_rsa",
#      "cat ~/.ssh/id_rsa.pub"
     ]  
}
}

# scp the aws private key .pem file to the above ec2 instance.
resource "null_resource" "scp_file" {
  depends_on = [aws_instance.niket-emp-terraform-example_ec2]

  provisioner "local-exec" {
    command = "sleep 30 ; scp -i ../../emp-validation-key.pem -o StrictHostKeyChecking=no ../../emp-validation-key.pem ubuntu@${aws_instance.emp-terraform-example_ec2.public_ip}:/home/ubuntu/"
  }

  provisioner "local-exec" {
    command = "ssh -i ./emp-validation-key.pem -o StrictHostKeyChecking=no ubuntu@${aws_instance.niket-emp-terraform-example_ec2.public_ip} cat ~/.ssh/id_rsa.pub > ec2_instance_id_rsa.pub" 
  }
}

data "external" "cmd_output" {
  program = [ "cat", "ec2_instance_id_rsa.pub" ] 

  depends_on = [ aws_instance.niket-emp-terraform-example_ec2 ]
}

# Inbound security group rule of ec2 instance for ssh to work.
resource "aws_security_group" "example_security_group" {
  name        = "example-security-group"
  description = "Allow SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

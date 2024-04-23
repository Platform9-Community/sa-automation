output "ec2-public_ip" {
    value = aws_instance.emp-terraform-example_ec2.public_ip
}

output "ec2-public_key" {
  value = "${data.external.cmd_output.result}"
}

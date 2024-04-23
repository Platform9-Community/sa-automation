
# Output all the created resources
output "vpc-subnets-nat-igw-rt" {
  value = {
    vpc = aws_vpc.emptesting_vpc.id
    private_subnet_1a = aws_subnet.emptesting_private_subnet_1a.id
    private_subnet_1b = aws_subnet.emptesting_private_subnet_1b.id
    public_subnet_1a = aws_subnet.emptesting_public_subnet_1a.id
    public_subnet_1b = aws_subnet.emptesting_public_subnet_1b.id
    internet_gateway = aws_internet_gateway.emptesting_igw.id
    nat_gateway = aws_nat_gateway.emptesting_nat_gateway.id
    private_route_table1-us-east-1a = aws_route_table.emptesting_private_route_table1_us-east-1a.id
    private_route_table2-us-east-1b = aws_route_table.emptesting_private_route_table2_us-east-1b.id
    public_route_table = aws_route_table.emptesting_public_route_table.id

  }
}
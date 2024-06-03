# create vpc
resource "aws_vpc" "MyVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}

# create public subnet in us-east-2a
resource "aws_subnet" "Public-2A" {
  vpc_id            = aws_vpc.MyVPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"
  tags = {
    Name        = "Public-2A"
    Description = "Public Subnet in us-east-2a"
  }
}

# create public subnet in us-east-2b
resource "aws_subnet" "Public-2B" {
  vpc_id            = aws_vpc.MyVPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2b"
  tags = {
    Name        = "Public-2B"
    Description = "Public Subnet in us-east-2b"
  }
}


# create private subnet in us-east-2a
resource "aws_subnet" "Private-2A" {
  vpc_id            = aws_vpc.MyVPC.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-2a"
  tags = {
    Name        = "Private-2A"
    Description = "Private Subnet in us-east-2a"
  }
}

# create private subnet in us-east-2b
resource "aws_subnet" "Private-2B" {
  vpc_id            = aws_vpc.MyVPC.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-2b"
  tags = {
    Name        = "Private-2B"
    Description = "Private Subnet in us-east-2b"
  }
}

# create private route table
resource "aws_route_table" "Private-RT" {
  vpc_id = aws_vpc.MyVPC.id
  tags = {
    Name        = "Private-RT"
    Description = "Private Route Table from Advanced Networking Hands on Lab"
  }
}

# associate private subnet 2A with private route table
resource "aws_route_table_association" "Private-RT-Association-2A" {
  subnet_id      = aws_subnet.Private-2A.id
  route_table_id = aws_route_table.Private-RT.id
}

# associate private subnet 1B with private route table
resource "aws_route_table_association" "Private-RT-Association-2B" {
  subnet_id      = aws_subnet.Private-2B.id
  route_table_id = aws_route_table.Private-RT.id
}

# create IGW and attach to MyVPC
resource "aws_internet_gateway" "MyIGW" {
  vpc_id = aws_vpc.MyVPC.id
  tags = {
    Name        = "MyIGW"
    Description = "IGW from Advanced Networking Hands on Lab"
  }
}

# add IGW route to main route table
resource "aws_route" "IGW-Route" {
  route_table_id         = aws_vpc.MyVPC.main_route_table_id
  gateway_id             = aws_internet_gateway.MyIGW.id
  depends_on             = [aws_internet_gateway.MyIGW]
  destination_cidr_block = "0.0.0.0/0"
}

# create EIP for NAT gateway in Public 2a & 2b
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  tags = {
    Name        = "MyEIP"
    Description = "EIP from Advanced Networking Hands on Lab"
  }
}


# create NAT gateway in Public subnet 2a & 2b
resource "aws_nat_gateway" "MyNAT" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.Public-2A.id
  tags = {
    Name        = "MyNAT"
    Description = "NAT Gateway from Advanced Networking Hands on Lab"
  }
  depends_on = [aws_eip.nat_gateway_eip]
}

# add route to NAT gateway
resource "aws_route" "NAT-Route" {
  route_table_id         = aws_route_table.Private-RT.id
  nat_gateway_id         = aws_nat_gateway.MyNAT.id
  destination_cidr_block = "0.0.0.0/0"
  depends_on             = [aws_nat_gateway.MyNAT]
}
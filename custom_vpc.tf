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
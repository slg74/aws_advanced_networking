provider "aws" {
  region = "us-east-2"
}

# Create a VPC
resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "example-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id

  tags = {
    Name = "example-igw"
  }
}

# Create a NAT gateway
resource "aws_nat_gateway" "example_nat_gw" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "example-nat-gw"
  }
}

# Create an Elastic IP for the NAT gateway
resource "aws_eip" "nat_gw_eip" {
  tags = {
    Name = "nat-gw-eip"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a route table for the private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example_nat_gw.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Associate the private subnet with the private route table
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Create a security group for the EC2 instances
resource "aws_security_group" "example_sg" {
  name        = "example-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.example_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-sg"
  }
}

# Create 4 EC2 instances with Elastic IPs in the private subnet, to later be managed with Ansible
resource "aws_instance" "example" {
  count                  = 4
  ami                    = "ami-0c9921088121ad00b"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.example_sg.id]

  associate_public_ip_address = true

  tags = {
    Name = "example-instance-${count.index}"
  }
}

# Create Elastic IPs for the EC2 instances
resource "aws_eip" "example_eip_instances" {
  count = 4

  instance                  = aws_instance.example[count.index].id
  associate_with_private_ip = aws_instance.example[count.index].private_ip

  tags = {
    Name = "example-eip-instance-${count.index}"
  }
}

output "instance_elastic_ips" {
  description = "Elastic IP addresses of the EC2 instances"
  value       = aws_eip.example_eip_instances[*].public_ip
}

# create AWS key pair
resource "aws_key_pair" "example" {
  key_name   = "ansible_tf_keypair"
}
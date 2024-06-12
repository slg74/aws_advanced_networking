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

# Create an internet gateway
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id

  tags = {
    Name = "example-igw"
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

# Create a security group for the EC2 instances
resource "aws_security_group" "example_sg" {
  name        = "example-sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.example_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# Create EC2 instances in the public subnet
resource "aws_instance" "public_instance" {
  count                       = 2
  ami                         = "ami-0c9921088121ad00b"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.example_sg.id]
  key_name                    = "ansible_tf_keypair"
  associate_public_ip_address = true
  user_data                   = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INTERFACE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$INTERFACE/subnet-id)
echo "<center><h1>Public Instance in Subnet $SUBNET_ID</h1></center>" > /var/www/html/index.html
EOF
  tags = {
    Name = "public-instance-${count.index}"
  }
}

# create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.example_vpc.id
  cidr_block = "10.0.2.0/24"
}

# create elastic IP for NAT gateway in private subnet
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  tags = {
    Name = "NAT Gateway Elastic IP"
  }
}

output "eip_address" {
  description = "Nat Gateway Elastic IP public address"
  value       = aws_eip.nat_gateway_eip.public_ip
}

# create NAT gateway in private subnet
resource "aws_nat_gateway" "example_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.private_subnet.id
  depends_on    = [aws_eip.nat_gateway_eip]
  tags = {
    Name = "Private NAT Gateway"
  }
}

# create a private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.example_vpc.id
  tags = {
    Name = "private route table"
  }
}

# associate private subnet with private route table
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# add NAT gateway route to private route table
resource "aws_route" "NATGW-Route" {
  route_table_id         = aws_route_table.private_rt.id
  nat_gateway_id         = aws_nat_gateway.example_nat_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

# create IGW and attach to VPC
resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.example_vpc.id
  tags = {
    Name = "VPC Internet Gateway"
  }
}

# add IGW route to main VPC route table
resource "aws_route" "igw-route" {
  route_table_id         = aws_vpc.example_vpc.default_route_table_id
  gateway_id             = aws_internet_gateway.vpc_igw.id
  destination_cidr_block = "0.0.0.0/0"
}


# create security group for private subnet
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.example_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create 2 EC2 instances in private subnet
resource "aws_instance" "private_instance" {
  count                  = 2
  ami                    = "ami-0c9921088121ad00b"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = "ansible_tf_keypair"
  user_data              = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INTERFACE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$INTERFACE/subnet-id)
echo "<center><h1>Private Instance in Subnet $SUBNET_ID</h1></center>" > /var/www/html/index.html
EOF
  tags = {
    Name = "private-instance-${count.index}"
  }
}

# create an S3 bucket
resource "aws_s3_bucket" "s3_bucket_tf_ansible1" {
  bucket = "s3-bucket-tf-ansible-0000000000000001"
}

# create an S3 bucket
resource "aws_s3_bucket" "s3_bucket_tf_ansible2" {
  bucket = "s3-bucket-tf-ansible-0000000000000002"
}
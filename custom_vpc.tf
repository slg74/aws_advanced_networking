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

# associate private subnet 2B with private route table
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

# add IGW route to main route table for MyVPC
resource "aws_route" "IGW-Route" {
  route_table_id         = aws_vpc.MyVPC.main_route_table_id # IGW in main RT
  gateway_id             = aws_internet_gateway.MyIGW.id
  depends_on             = [aws_internet_gateway.MyIGW]
  destination_cidr_block = "0.0.0.0/0"
}

# create SG for public subnet
resource "aws_security_group" "Public-SG" {
  name   = "Public-SG"
  vpc_id = aws_vpc.MyVPC.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}


# create EIP for NAT gateway
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  tags = {
    Name        = "MyEIP"
    Description = "EIP for NAT Gateway"
  }
}

output "eip_address" {
  description = "EIP public address"
  value       = aws_eip.nat_gateway_eip.public_ip
}

# create NAT gateway in Private subnet 2a
resource "aws_nat_gateway" "MyNATGW" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.Private-2A.id
  tags = {
    Name        = "MyNATGW"
    Description = "NAT Gateway in Private subnet"
  }
  depends_on = [aws_eip.nat_gateway_eip]
}

# create a security group for the NAT gateway
resource "aws_security_group" "NAT-SG" {
  name   = "NAT-SG"
  vpc_id = aws_vpc.MyVPC.id
}

resource "aws_security_group_rule" "NAT-SG-Inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.NAT-SG.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# allow outbound traffic via NAT SG
resource "aws_security_group_rule" "NAT-SG-Outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.NAT-SG.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# add NAT gateway route to private route table
resource "aws_route" "NATGW-Route" {
  route_table_id         = aws_route_table.Private-RT.id
  nat_gateway_id         = aws_nat_gateway.MyNATGW.id
  destination_cidr_block = "0.0.0.0/0"
}

# create ec2 instance in routable public subnet 2a
resource "aws_instance" "MyInstance1" {
  ami                         = "ami-0c9921088121ad00b"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.Public-2A.id
  security_groups             = [aws_security_group.Public-SG.id]

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INTERFACE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$INTERFACE/subnet-id)
echo "<center><h1>Instance 2 in Subnet $SUBNET_ID</h1></center>" > /var/www/html/index.html
EOF

  tags = {
    Name = "ec2_1"
  }
}

# create ec2 instance in public subnet 2b
resource "aws_instance" "MyInstance2" {
  ami                         = "ami-0c9921088121ad00b"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.Public-2B.id
  security_groups             = [aws_security_group.Public-SG.id]

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INTERFACE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$INTERFACE/subnet-id)
echo "<center><h1>Instance 2 in Subnet $SUBNET_ID</h1></center>" > /var/www/html/index.html
EOF

  tags = {
    Name = "ec2_2"
  }
}

# security group for private subnet
resource "aws_security_group" "Private-SG" {
  name   = "Private-SG"
  vpc_id = aws_vpc.MyVPC.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

# create ec2 instance in private subnet 2a
resource "aws_instance" "MyInstance_Private_2A" {
  ami                         = "ami-0c9921088121ad00b"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.Private-2A.id
  security_groups             = [aws_security_group.Private-SG.id]

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INTERFACE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$INTERFACE/subnet-id)
echo "<center><h1>Instance 2 in Subnet $SUBNET_ID</h1></center>" > /var/www/html/index.html
EOF

  tags = {
    Name = "ec2_Private_2A"
  }
}

# create ec2 instance in private subnet 2b
resource "aws_instance" "MyInstance_Private_2B" {
  ami                         = "ami-0c9921088121ad00b"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.Private-2B.id
  security_groups             = [aws_security_group.Private-SG.id]

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
INTERFACE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$INTERFACE/subnet-id)
echo "<center><h1>Instance 2 in Subnet $SUBNET_ID</h1></center>" > /var/www/html/index.html
EOF

  tags = {
    Name = "ec2_Private_2B"
  }
}

# create an S3 bucket
resource "aws_s3_bucket" "MyS3Bucket" {
  bucket = "s3-bucket-pulumi-0000000000000000"
}

# create an S3 bucket
resource "aws_s3_bucket" "MyS3Bucket" {
  bucket = "s3-bucket-pulumi-0000000000000001"
}

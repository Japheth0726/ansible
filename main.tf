locals {
  name = "set-21"
}
# Creating vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.name}-vpc"
  }
}

# creating public subnet
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  tags = {
    Name = "${local.name}-subnet1"
  }
}

# creating private subnet2
resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3a"
  tags = {
    Name = "${local.name}-subnet2"
  }
}

# creating igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${local.name}-igw"
  }
}

# creating eip
resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "${local.name}-eip"
  }
}

# creating Natgateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "${local.name}-gw-NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# creating public route table
resource "aws_route_table" "pub-rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-pub-rt"
  }
}

# creating route table association for public subnet
resource "aws_route_table_association" "pub-rt" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.pub-rt.id
}

# creating private route table
resource "aws_route_table" "pri-rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "${local.name}-pri-rt"
  }
}

# creating route table association for private subnet
resource "aws_route_table_association" "pri-rt" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.pri-rt.id
}

# Creating a security group for ansible
resource "aws_security_group" "ansible-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "This is my ansible security group"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-ansible-sg"
  }
}

# Creating a security group for managed nodes
resource "aws_security_group" "managed-node-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "This is my managed-node security group"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-managed-nodes"
  }
}

#creating key pair on aws
resource "aws_key_pair" "key-pair" {
  key_name   = "ansible-keypair"
  public_key = file("./ansible-key.pub")
}

# creating ansible instance
resource "aws_instance" "ansible" {
  ami                         = "ami-09d83d8d719da9808" //ubuntu-ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  key_name                    = aws_key_pair.key-pair.id
  vpc_security_group_ids      = [aws_security_group.ansible-sg.id]
  associate_public_ip_address = true
  user_data                   = file("./user-data.sh")

  tags = {
    Name = "${local.name}-ansible-node"
  }
}

# creating managed noded 1
resource "aws_instance" "redhat" {
  ami                         = "ami-0574a94188d1b84a1" //red hat
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  key_name                    = aws_key_pair.key-pair.id
  vpc_security_group_ids      = [aws_security_group.managed-node-sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "${local.name}-redhat-node"
  }
}

# creating managed node 2
resource "aws_instance" "ubuntu" {
  ami                         = "ami-09d83d8d719da9808" //ubuntu-ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  key_name                    = aws_key_pair.key-pair.id
  vpc_security_group_ids      = [aws_security_group.managed-node-sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "${local.name}-ubuntu-node"
  }
}
terraform {
  required_providers {
    aws = {
      source  = "aws"
      version = ">5.0.0 "
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = "AKIAXBSKSOKUROSRGWQI"
  secret_key = "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"
}




data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "key-for-test"
  public_key = file("keys/key.pub")
}


resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
}

resource "aws_security_group" "allow-ssh" {
  vpc_id = resource.aws_vpc.main.id
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

resource "aws_security_group" "allow-for-private" {
  vpc_id = resource.aws_vpc.main.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "main-private" {
  vpc_id     = resource.aws_vpc.main.id
  cidr_block = "10.10.11.0/24"

  tags = {
    Name = "main_subnet"
  }
}

resource "aws_subnet" "supplemental-public" {
  vpc_id                  = resource.aws_vpc.main.id
  cidr_block              = "10.10.10.0/24"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "additional_subnet"
  }
}

resource "aws_internet_gateway" "subnet-gateway" {
  vpc_id = resource.aws_vpc.main.id
}



resource "aws_route_table" "public-route-table" {
  vpc_id = resource.aws_vpc.main.id
  tags = {
    Name = "public_route_table"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = resource.aws_internet_gateway.subnet-gateway.id
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = resource.aws_vpc.main.id

  tags = {
    Name = "private_route_table"
  }
}

resource "aws_route_table_association" "public-route-table-records" {
  subnet_id      = resource.aws_subnet.supplemental-public.id
  route_table_id = resource.aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "private-route-table-records" {
  subnet_id      = resource.aws_subnet.main-private.id
  route_table_id = resource.aws_route_table.private-route-table.id
}




resource "aws_instance" "public" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = resource.aws_key_pair.ssh-key.key_name
  subnet_id              = resource.aws_subnet.supplemental-public.id
  vpc_security_group_ids = [resource.aws_security_group.allow-ssh.id]
}

resource "aws_instance" "private" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = resource.aws_key_pair.ssh-key.key_name
  subnet_id              = resource.aws_subnet.main-private.id
  vpc_security_group_ids = [resource.aws_security_group.allow-for-private.id]
}

output "public_ip" {
  value = aws_instance.public.public_ip
}

output "private_ip" {
  value = aws_instance.private.private_ip
}
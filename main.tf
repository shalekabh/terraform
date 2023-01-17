# Use terraform init to download everything trform needs for aws
  # Use terraform plan to show the changes being made
  # Use terraform apply to apply changes
  # Use terraform destroy to remove instance from aws
  # Use terraform destroy -target aws_instance.ShyServ (or anything else) to destroy sections
  # Comment out sections, then plan and apply to essentialy remove this part

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.49.0"
    }
  }
}

# Create key pair

provider "aws" {
  # Configuration options
  region = "eu-west-2"
}

# Variables

variable "subnet_prefix" {
  description = "The cidr block for the subnet"
  default = "10.0.1.0/24"
  
  
}

# Create VPC

resource "aws_vpc" "ShyVPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ShallyVPC"
  }
}

# Create subnet

resource "aws_subnet" "ShySub1" {
  vpc_id     = aws_vpc.ShyVPC.id
  cidr_block = var.subnet_prefix[0]
  availability_zone = "eu-west-2a"

  tags = {
    Name = "ShallySub1"
  }
}

resource "aws_subnet" "ShySub2" {
  vpc_id     = aws_vpc.ShyVPC.id
  cidr_block = var.subnet_prefix[1]
  availability_zone = "eu-west-2a"

  tags = {
    Name = "ShallySub2"
  }
}

# To get VPC ID we can dynamically pass the name of the resource VPC(NOT TAG)/
# (Continued) into our subnet section for the vpc_id - as above

# Create internet gateway

resource "aws_internet_gateway" "Shygw" {
  vpc_id = aws_vpc.ShyVPC.id

  tags = {
    Name = "ShallyIGW"
  }
}

# Create route table

resource "aws_route_table" "ShyRouteTable" {
  vpc_id = aws_vpc.ShyVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Shygw.id 
    # For the gateway ID we put in "gw" we DO NOT put the route table name
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.Shygw.id
  }

  tags = {
    Name = "ShallyRouteTable"
  }
}

# Associate route table with subnet

resource "aws_route_table_association" "S1" {
  subnet_id      = aws_subnet.ShySub1.id
  route_table_id = aws_route_table.ShyRouteTable.id
}

# Create security group for por 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.ShyVPC.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    # "-1" means any protocol
  }

  tags = {
    Name = "allow_web"
  }
}

# Create network interface with IP in the subnet

resource "aws_network_interface" "ShyWebServNic" {
  subnet_id       = aws_subnet.ShySub1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
} 

# Assign an elsatic IP for the network interface

resource "aws_eip" "EIPone" {
  vpc                       = true
  network_interface         = aws_network_interface.ShyWebServNic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.Shygw
  ]
  
}

resource "aws_instance" "ShyServ" {
  ami           = "ami-084e8c05825742534"
  instance_type = "t2.micro"
  availability_zone = "eu-west-2a"
  key_name = "ShallyKey"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.ShyWebServNic.id
  }

  tags = {
    Name = "ShallyInstance"
    # This will be the name of your instance
  }


# Create a Linux server and install and enable apache2(apt)(ubuntu) or httpd(yum)(linux)

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd -y
              sudo systemctl start httpd
              sudo bash -c 'echo BADMAN 4 LIFE > /var/www/html/index.html' 
              EOF
}


/*
 provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

variable "instance_type" {
 default = "t2.micro"
}

resource "aws_instance" "ec2_instance" {
 ami = "ami-0d1cd67c26f5fca19"
 instance_type = "var.instance_type"
}

output "ip" {
 value = "aws_instance.ec2_instance.public_ip"
} 
*/

#launches an instance without a key

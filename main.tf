provider "aws" {
  region = "us-east-1"
  access_key = "AKIA4VXLPW3HDQ6PCCE3"
  secret_key = "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"
}

# 1. Create VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

# 2. Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id
}

# 3. Custome Route Table

resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod_vpc.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

# 4. Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod subnet"
  }
}

# 5. Route table association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create security group 

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#  8. Create Elastic ip
resource "aws_eip" "one" {
  domain = "vpc"
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw]
}

# 9. Create Ubantu server and insall/enable apache2
# !!!! = Subnet must be in the same region

resource "aws_instance" "web-server-instance" {
  ami = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main_key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id

  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemct1 start apache2
              sudo bash -c 'Web Server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "web-server"
  }
}

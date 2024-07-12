terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3.0"
    }
  }
}



resource "aws_vpc" "my_vpc_terraform" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My-VPC-terraform"
  }
}

resource "aws_subnet" "PublicSubnetTerraform" {
  vpc_id     = aws_vpc.my_vpc_terraform.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "publicSubnet"
  }
}

resource "aws_subnet" "PrivateSubnetTerraform" {
  vpc_id     = aws_vpc.my_vpc_terraform.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "privateSubnet"
  }
}

resource "aws_internet_gateway" "internet_gateway_terrafom" {
  vpc_id = aws_vpc.my_vpc_terraform.id
  tags = {
    Name = "gw"
  }
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc_terraform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway_terrafom.id
  }

  tags = {
    Name = "routeTable"
  }
}

resource "aws_route_table_association" "Subnet_Association" {
  subnet_id      = aws_subnet.PublicSubnetTerraform.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_security_group" "terraform_security_group" {
  name        = "allow_ssh_http_and_https"
  description = "Allow SSH, HTTP, and HTTPS inbound traffic"
  vpc_id      = aws_vpc.my_vpc_terraform.id

  ingress {
    description = "SSH from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this for better security
  }
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from anywhere"
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
    Name = "allow_ssh_http_and_https"
  }
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

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "my_ec2_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.PublicSubnetTerraform.id
  vpc_security_group_ids      = [aws_security_group.terraform_security_group.id]
  key_name                    = "my-second-key"
  associate_public_ip_address = true

  tags = {
    Name = "MyEC2Instance"
  }
}

resource "local_file" "ssh_key_file" {
  filename = "my-second-key.pem"
  content  = var.ssh_private_key
  file_permission = "0600"
}


resource "local_file" "inventory_file" {
  filename = "../ansible/inventory.ini"
  content  = <<-EOF
    [servers]
    ${aws_instance.my_ec2_instance.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=my-second-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOF
}


resource "null_resource" "ansible" {
  depends_on = [local_file.inventory_file]
  triggers = {
    instance_id       = aws_instance.my_ec2_instance.id
    inventory_created = local_file.inventory_file.filename
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ../ansible/inventory.ini ../ansible/playbook.yaml"
  }
}



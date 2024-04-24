resource "aws_vpc" "tf-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-vpc.id

  tags = {
    Name = "p-igw"
  }
}

resource "aws_subnet" "tf-pub-sub1" {
  vpc_id     = aws_vpc.tf-vpc.id
  cidr_block = "10.0.1.0/24"
availability_zone= "eu-west-2a"
map_public_ip_on_launch= "true"

  tags = {
    Name = "p-pub1"
  }
}

resource "aws_subnet" "tf-pub-sub2" {
  vpc_id     = aws_vpc.tf-vpc.id
  cidr_block = "10.0.3.0/24"
availability_zone= "eu-west-2b"
map_public_ip_on_launch= "true"

  tags = {
    Name = "p-pub2"
  }
}

resource "aws_subnet" "tf-pvt-sub1" {
  vpc_id     = aws_vpc.tf-vpc.id
  cidr_block = "10.0.2.0/24"
availability_zone= "eu-west-2a"
map_public_ip_on_launch= "false"

  tags = {
    Name = "p-pvt1"
  }
}

resource "aws_route_table" "tf-pub-rt" {
  vpc_id = aws_vpc.tf-vpc.id

 route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }
tags = {
    Name = "p-pub-rt"
  }
}

resource "aws_route_table" "tf-pvt-rt" {
  vpc_id = aws_vpc.tf-vpc.id
tags = {
    Name = "p-pvt-rt"
  }
}

resource "aws_route_table_association" "association-1" {
  subnet_id      = aws_subnet.tf-pub-sub1.id
  route_table_id = aws_route_table.tf-pub-rt.id
}
resource "aws_route_table_association" "association-2" {
  subnet_id      = aws_subnet.tf-pub-sub2.id
  route_table_id = aws_route_table.tf-pub-rt.id
}

resource "aws_route_table_association" "association-3" {
  subnet_id      = aws_subnet.tf-pvt-sub1.id
  route_table_id = aws_route_table.tf-pvt-rt.id
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey"       # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./myKey.pem"
  }
}

resource "aws_security_group" "tf-sg" {
 description = "Allow HTTPS to web server"
 vpc_id      = aws_vpc.tf-vpc.id

ingress {
   description = "HTTPS ingress"
   from_port   = 443
   to_port     = 443
   protocol    = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }
ingress {
 from_port = 22
 to_port = 22
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]

}
ingress {
 from_port = 80
 to_port = 80
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]
}

egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]

}
tags = {
 Name = "tf-sg"
}
}

resource "aws_instance" "tf-instance1" {
 ami = "ami-019a292cfb114a776"
 instance_type = "t2.micro"
 key_name = "myKey"
 vpc_security_group_ids = ["${aws_security_group.tf-sg.id}"]
 subnet_id = "${aws_subnet.tf-pub-sub1.id}"
 associate_public_ip_address = true
user_data = "${file("userdata1.sh")}"
tags = {
 Name = "tf-instance1"
}
}

resource "aws_instance" "tf-instance2" {
 ami = "ami-019a292cfb114a776"
 instance_type = "t2.micro"
 key_name = "myKey"
 vpc_security_group_ids = ["${aws_security_group.tf-sg.id}"]
 subnet_id = "${aws_subnet.tf-pub-sub1.id}"
 associate_public_ip_address = true
user_data = "${file("userdata2.sh")}"
tags = {
 Name = "tf-instance2"
}
}

resource "aws_lb" "tf-alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tf-sg.id]
  subnets            = [aws_subnet.tf-pub-sub1.id, aws_subnet.tf-pub-sub2.id]
}

resource "aws_lb_target_group" "tf-tg" {
  name     = "tf-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.tf-vpc.id
}

resource "aws_lb_target_group_attachment" "elb1" {
  target_group_arn = aws_lb_target_group.tf-tg.arn
  target_id        = aws_instance.tf-instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "elb2" {
  target_group_arn = aws_lb_target_group.tf-tg.arn
  target_id        = aws_instance.tf-instance2.id
  port             = 80
}
resource "aws_lb_listener" "alb" {
  load_balancer_arn = aws_lb.tf-alb.arn
  port              = "443"
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tf-tg.arn
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default     = 8080
}

data "aws_availability_zones" "all" {}

// output "public_ip" {
//   value = "${aws_instance.terra-test.public_ip}"
// }
output "elb_dns_name" {
  value = "${aws_elb.terra-test.dns_name}"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_launch_configuration" "terra-test" {
  image_id        = "ami-40d28157"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
                        #! /bin/sh
                        echo "Hello World" > index.html
                        nohup busybox httpd -f -p 8080 &
                        EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terra-test" {
  launch_configuration = "${aws_launch_configuration.terra-test.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  load_balancers    = ["${aws_elb.terra-test.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-terra-test"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance" {
  name = "terra-test-instance"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "terra-test" {
  name               = "terraform-asg-terra-test"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}

resource "aws_security_group" "elb" {
  name = "terraform-terra-test-elb"

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

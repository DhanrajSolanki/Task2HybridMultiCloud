provider "aws"{
 region = "ap-south-1"
 profile = "default"
}

variable "cidr_vpc"{
  description = "Newtork Range of VPC"
  default = "192.168.0.0/16"
}

variable "cidr_subnet1"{
  description = "Network Range From VPC"
  default = "192.168.1.0/24"
}

resource "aws_vpc" "myvpc"{
cidr_block = "${var.cidr_vpc}"
enable_dns_hostnames = true
 tags = {
   Name = "MyVPC"
   }
}

resource "aws_subnet" "Public_Sub"{
  vpc_id = "${aws_vpc.myvpc.id}"
  cidr_block = "${var.cidr_subnet1}"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
  Name = "Public_Subnet"
  }
}

resource "aws_internet_gateway" "IG"{
  vpc_id = "${aws_vpc.myvpc.id}"
  tags = {
   Name = "MyIG"
 }
}

resource "aws_route_table" "RouteTable"{
  vpc_id = "${aws_vpc.myvpc.id}"
  
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.IG.id}"
  }
 tags ={
 Name = "RouteTable"
}
}

resource "aws_route_table_association" "SUBNET_ASSO" {
  subnet_id      = "${aws_subnet.Public_Sub.id}"
  route_table_id = "${aws_route_table.RouteTable.id}"
}

//Assign Default Ip

resource "aws_default_subnet" "default_ip" {
  availability_zone = "ap-south-1a"

  tags = {
    Name = "AssignAutoIp"
  }
}



  // Create a Security Group 

resource "aws_security_group" "Security"{
 name = "MYSECURITY"
 description = "Allow HTTP Only i.e Port 80"
 vpc_id      = "${aws_vpc.myvpc.id}"
 ingress{
  description = "allow Port 80 Only"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
 ingress{
  description = "allow SSH"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
 ingress{
  description = "allow NFS"
  from_port = 2049
  to_port = 2049
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
egress{
 from_port = 0
 to_port = 0
 protocol ="-1"
 cidr_blocks = ["0.0.0.0/0"]
}
 tags = {
 Name= "My_SEC"
 }
}

// Create a Key

resource "tls_private_key" "tera_key" {
  algorithm   = "RSA"
} 


//Create a Key_pair

 resource "aws_key_pair" "dha_key"{
 key_name = "tera_key"
 public_key = "${tls_private_key.tera_key.public_key_openssh}"
	depends_on = [
  		tls_private_key.tera_key
 	] 
}

// Create a Local File to store Key

resource "local_file" "key_file"{
 content = "${tls_private_key.tera_key.private_key_pem}"
 filename = "tera_key.pem"
	depends_on = [
  		aws_key_pair.dha_key
 	] 
}


//Variables

 variable "ami_id"{
 type = string
 default = "ami-0732b62d310b80e97"
}

variable "ami_type"{
 type = string
 default = "t2.micro"
}

//Create a Instance 

resource "aws_instance" "Task2Instance"{
 ami = "${var.ami_id}"
 instance_type = "${var.ami_type}"
 key_name = "tera_key"
 subnet_id = "${aws_subnet.Public_Sub.id}"
 vpc_security_group_ids = ["${aws_security_group.Security.id}"]

tags = {
 Name = "TestingOS"
}
}

resource "null_resource" "null1"{
  depends_on = [
   aws_instance.Task2Instance,
   aws_efs_mount_target.efs_mount
 ]
 connection {
     agent = "false"
     type = "ssh"
     user = "ec2-user"
     private_key = "${tls_private_key.tera_key.private_key_pem}"
     host = aws_instance.Task2Instance.public_ip
   }
provisioner "remote-exec"{  
   inline = [
        "sudo yum update -y",
	"sudo yum install httpd php git amazon-efs-utils nfs-utils -y",
        "sudo systemctl restart httpd",
        "sudo systemctl enable httpd",
      ]
 }
}


//Create EFS(Elastic File System)

resource "aws_efs_file_system" "EFS"{
 creation_token = "efs"
 tags = {
  Name = "EFS"
  }
}

// Mounting EFS

resource "aws_efs_mount_target" "efs_mount" {
 depends_on = [
    aws_efs_file_system.EFS
  ]
  file_system_id = "${aws_efs_file_system.EFS.id}"
  subnet_id      = "${aws_subnet.Public_Sub.id}"
  security_groups = ["${aws_security_group.Security.id}"]
}
   
resource "null_resource" "null_remote"{
 depends_on = [
   null_resource.null1,
   aws_efs_mount_target.efs_mount,
 ]
connection{
  type = "ssh"
  user = "ec2-user"
  private_key  = "${tls_private_key.tera_key.private_key_pem}"
  host = "${aws_instance.Task2Instance.public_ip}"
}

provisioner "remote-exec"{
  inline = [
     "sudo mount -t efs ${aws_efs_file_system.EFS.id}:/ /var/www/html",
     "sudo rm -rf /var/www/html/",
     "sudo git clone https://github.com/DhanrajSolanki/Task2HybridMultiCloud /var/www/html/",
    ]
 }
}
resource "aws_s3_bucket" "dhanraj1234"{
 bucket ="web-tera-bucket"
 acl = "public-read"

  tags = {
    Name = "bucket1"
}
 versioning{
   enabled = true
}
}



//Create a S3 Bucket Object

resource "aws_s3_bucket_object" "object1"{

	depends_on = [
		aws_s3_bucket.dhanraj1234,
	]
  bucket = "${aws_s3_bucket.dhanraj1234.bucket}"
  key = "Dog.jpg"
  source = "C:/Users/Shiv/TeraTask2/Dog.jpg"
  acl = "public-read"
  content_type= "images or jpg"
}	

//Create a CloudFront Distribution

resource "aws_cloudfront_distribution" "cfd"{
  origin {
    domain_name = "${aws_s3_bucket.dhanraj1234.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.dhanraj1234.id}"
  }
 	
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "s3 Distribution"
  default_root_object ="Dog.jpg"

	logging_config{
	include_cookies =false
	bucket = "${aws_s3_bucket.dhanraj1234.bucket_regional_domain_name}"
	}



default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.dhanraj1234.id}"


forwarded_values {
      query_string = false




      cookies {
        forward = "none"
      }
    }



viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

# Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${aws_s3_bucket.dhanraj1234.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.dhanraj1234.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"


restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
tags = {
    Name        = "CloudFront-Distribution-Tera"
    Environment = "Production"
  }


viewer_certificate {
    cloudfront_default_certificate = true
  }
}


#provider info
provider "aws" {
  region   = "ap-south-1"
  profile  = "myanshika"
}


#creating key 
resource "aws_key_pair" "mykey11101" {
  key_name   = "mykey111access01"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 anshu.anshikasharma114@gmail.com"
}


#creating security group 
resource "aws_security_group" "mysecurity" {
  name        = "mysecurity01"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-82dcc3ea"

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
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

  tags = {
    Name = "MySecurityGroup"
  }
}

#creating s3
resource "aws_s3_bucket" "bucketanshika23" {
  bucket = "bucketanshi23"
  acl   = "public-read"
  force_destroy = true
  cors_rule {
     allowed_headers = ["*"]
     allowed_methods = ["PUT","POST"]
     allowed_origins = ["https://bucketanshika23"]
     expose_headers = ["ETag"]
     max_age_seconds = 4000
  }
}

#to cloning data to local

resource "null_resource" "cloning-data" {
      depends_on = ["aws_s3_bucket.bucketanshika23"]
      provisioner "local-exec" {
         command = "git clone https://github.com/Anshika-Sharma-as/cloud_Task01.git mybadges"
      }
      
}

#upload

resource "aws_s3_bucket_object" "obj" {
depends_on = [aws_s3_bucket.bucketanshika23,null_resource.cloning-data]
    bucket = "bucketanshika23"
    key = "mastry_badge.jpg"
    source = "mybadges/mastry_badge.jpg"
    acl = "public-read"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name =  "${aws_s3_bucket.bucketanshika23.bucket_regional_domain_name}"
    origin_id   =  "S3-${aws_s3_bucket.bucketanshi23.bucket}"
    custom_origin_config {
       http_port = 80
       https_port = 443
       origin_protocol_policy = "match-viewer"
       origin_ssl_protocols = ["TLSv1","TLSv1.1","TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "anshikasharma"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.bucketanshika23.bucket}"

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

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.bucketanshika23.bucket}"


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
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "cloud_production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}



#creating instance
resource "aws_instance" "web01" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "mykey111access01"
  security_groups = ["mysecurity01"]
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/ANSHIKA SHARMA/Documents/mykey111access01.pem")
    host    = aws_instance.web01.public_ip
  } 

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "MYFirstTerraOS"
  }
}

#creating volume
resource "aws_ebs_volume" "myVolume" {
	availability_zone = aws_instance.web01.availability_zone
	size = 1
	encrypted = "true" 
	tags = {
		Name = "MyEBSVolume"
	}
}

output "myout_vol_id" {
	value = aws_ebs_volume.myVolume.id
}


#attaching volume
resource "aws_volume_attachment" "ebs_attached" {
  device_name = "/dev/sde"
  volume_id   = aws_ebs_volume.myVolume.id
  instance_id = aws_instance.web01.id
  force_detach = true
}

#creating a text file that store the public ip 
resource "null_resource" "nullrsclo01"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web01.public_ip} > publicip.txt"
  	}
}

#creating a null resource to provision the partitions
resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_attached,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ANSHIKA SHARMA/Documents/mykey111access01.pem")
    host     = aws_instance.web01.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvde",
      "sudo mount  /dev/xvde  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Anshika-Sharma-as/webserberProvisioning.git /var/www/html/"
    ]
  }
}


#creating snapshot
resource "aws_ebs_snapshot" "Sample_Snapshot" {
  volume_id = aws_ebs_volume.myVolume.id
  tags = {
    Name = "myEBS_Volsnap01"
  }
}

output "myout_snap_id" {
	value = aws_ebs_snapshot.Sample_Snapshot.id
}






resource "null_resource" "nulllocal1"  {

depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web01.public_ip}"
  	}
}
 

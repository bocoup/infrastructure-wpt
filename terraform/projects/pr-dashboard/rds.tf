resource "aws_db_subnet_group" "rds" {       
  name = "default-db"                        
  description = "default subnets"            
  subnet_ids = ["${aws_subnet_wpt_id}"]
}

resource "aws_subnet_wpt" "wpt-subnet" {
  vpc_id            = "vpc-eb65f992"
  cidr_block        = "10.100.0.0/16"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "rds" {
  identifier = "web-platform-tests-db"
  storage_type = "gp2"
  allocated_storage = 10
  engine = "postgres"
  engine_version = "9.5.4"
  instance_class = "db.t2.small"
  name = "wptdash"
  username = "wptdash"
  password = "${trimspace(file("${path.module}/secrets/wpt-db-password.txt"))}"
  multi_az = true
  backup_retention_period = 30
  backup_window = "05:00-18:30"
  maintenance_window = "sun:03:00-sun:04:00"
  allow_major_version_upgrade = true
  db_subnet_group_name = "${aws_db_subnet_group.rds.id}"
  vpc_security_group_ids = [
    "${aws_security_group.web-platform-tests-db1.id}",
  ]
}


resource "aws_security_group" "web-platform-tests-db1" {  
  name = "web-platform-tests-db1"

  description = "RDS postgres servers (terraform-managed)"
  vpc_id = "vpc-eb65f992"

  # Only postgres in
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = [
      "${var.vpc_cidr}",
    ]

  }

  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "web-platform-tests-db-backup" {
  name = "web-platform-tests-db-backup"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${var.nas_backup_bucket}/db",
        "arn:aws:s3:::${var.nas_backup_bucket}/db*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_user" "web-platform-tests-db-backup" {
  name = "web-platform-tests-db-backup"
}

resource "aws_iam_policy_attachment" "web-platform-tests-db-backup" {
  name = "web-platform-tests-db-backup"
  policy_arn = "${aws_iam_policy.web-platform-tests-db-backup.arn}"
  users = ["${aws_iam_user.web-platform-tests-db-backup.id}"]
}

# this key was created manually to prevent the secret
# from being stored in the tfstate file.
# it is available under /mnt/secrets/db-backup-keys
#resource "aws_iam_access_key" "db-backup" {
#  user = "${aws_iam_user.db-backup.id}"
#}

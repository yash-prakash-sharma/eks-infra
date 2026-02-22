resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.name_prefix}-rds-"
  description = "Security group for RDS MySQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from allowed security groups"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version

  db_name  = var.db_name
  username = var.username
  password = var.password

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  storage_encrypted = true
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql"
  })
}

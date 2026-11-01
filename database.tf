resource "aws_db_subnet_group" "main" {
  name       = "fleet-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_security_group" "app" {
  name   = "fleet-app"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "db" {
  name   = "fleet-db"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier          = "fleet-aurora"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  database_name               = "fleet"
  master_username             = "fleetadmin"
  manage_master_user_password = true
  storage_encrypted           = true
  backup_retention_period     = 7
  skip_final_snapshot         = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.db.id]

  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 1
    seconds_until_auto_pause = 300
  }
}

resource "aws_rds_cluster_instance" "main" {
  count              = 2
  identifier         = "fleet-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}

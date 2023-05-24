# rds=mysql >>  comes with only ONE_END_POINT
# Steps to be followed in any data_base service of aws
#1. Cluster
#2. Subnet_groups
#3. Cluster_instance

resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${var.env}-rds-cluster"
  engine                  = var.engine
  engine_version          = var.engine_version
  database_name           = "${var.env}-myrds"
  master_username         = data.aws_ssm_parameter.rds_master_username.value
  master_password         = data.aws_ssm_parameter.rds_master_password.value
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window

  # E
  kms_key_id           = data.aws_kms_key.by_alias.arn
  storage_encrypted    = "true"
  # as we are using kms_key, data in the database shall be encrypted, by default it is false, we are setting it to be true

  # E
  # referencing back the subnet_group to cluster
  db_subnet_group_name = aws_db_subnet_group.main.name

  vpc_security_group_ids = [aws_security_group.main.id]
}


resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-rds-subnet-group-main"
  subnet_ids = var.db_subnet_ids

  tags = {
    merge (var.tags, Name = "${var.env}-rds-subnet-group-main")

}


resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = var.count
  identifier         = "${var.env}-rds-cluster-${count.index}"   # when count_loop is used, to access index_number >> count.index is used
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = var.engine
  engine_version     = var.engine_version
}

#------------------------------------------------------------------------------
shipping_route >>
1. endpoint (create_parameters)
2. security_group
3. attach security_group back to rds
4. iam policy (allowing app_subnet_shipping to access rds )
5. schema update with (parameters, username:password)

# elasticache_endpoint
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "${var.env}.rds.endpoint"
  type  = "String"
  value = aws_rds_cluster.main.endpoint
}

# Security_Group for rds
resource "aws_security_group" "main" {
  name        = "rds-${var.env}-sg"
  description = "rds-${var.env}-sg"
  vpc_id      = var.vpc_id


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "RDS"
    from_port        = 3306           # inside RDS we are opening port 3306 (Aurora/MySQL/MariaDB)
    to_port          = 3306           # inside RDS we are opening port 3306 (Aurora/MySQL/MariaDB)
    protocol         = "tcp"
    cidr_blocks      = var.cidr_block     # here we have to specify which (app)subnet should access the docdb (not in terms of subnet_id, but in terms of cidr_block)
  }

  tags = {
    merge (var.tags, Name = "rds-${var.env}-security-group")
}

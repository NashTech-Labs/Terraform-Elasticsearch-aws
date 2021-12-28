
data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "es_cloudwatch_index_log_group" {
  name = join("-", list(var.environment,"es","index-log-group"))
}

resource "aws_cloudwatch_log_group" "es_cloudwatch_search_log_group" {
  name = join("-", list(var.environment,"es","search-log-group"))
}

resource "aws_cloudwatch_log_group" "es_cloudwatch_application_log_group" {
  name = join("-", list(var.environment,"es","application-log-group"))
}

resource "aws_cloudwatch_log_resource_policy" "es_cloudwatch_log_policy" {
  policy_name = join("-", list(var.environment,"es","log-policy"))

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}

resource "aws_elasticsearch_domain" "es" {
  domain_name           = var.domain_name
  elasticsearch_version = var.cluster_version

  cluster_config {
    dedicated_master_enabled = var.dedicated_master
    instance_count           = var.instance_count
    instance_type            = var.instance_type
  }

  advanced_security_options {
    enabled = var.advanced_security_options
    internal_user_database_enabled = var.internal_user_db
    master_user_options {
      master_user_name = var.master_user_name
      master_user_password = var.master_user_pass
    }
  }

  domain_endpoint_options {
    enforce_https = var.enforce_domain_https
    tls_security_policy = var.tls_policy
  }

  node_to_node_encryption {
    enabled = var.node_to_node_encryption
  }

  encrypt_at_rest {
    enabled = var.encrypt_at_rest
  }

  ebs_options {
    ebs_enabled = var.ebs_enabled
    volume_size = var.ebs_size
  }

  log_publishing_options {
    enabled = var.publishing_es_logs
    log_type = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_cloudwatch_index_log_group.arn
  }

  log_publishing_options {
    enabled = var.publishing_es_logs
    log_type = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_cloudwatch_search_log_group.arn
  }

  log_publishing_options {
    enabled = var.publishing_es_logs
    log_type = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_cloudwatch_application_log_group.arn
  }

  tags = var.tags
}

resource "aws_elasticsearch_domain_policy" "es-policy" {
  domain_name = aws_elasticsearch_domain.es.domain_name

  access_policies = <<POLICIES
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "${aws_elasticsearch_domain.es.arn}/*"
    }
  ]
}
POLICIES

  provisioner "local-exec" {
    command = "curl -X PUT -H 'Content-Type: application/json' -d '{\"index_patterns\":[\"*\"], \"order\":0, \"settings\":{\"number_of_shards\":${var.index_default_number_of_shards}, \"number_of_replicas\":${var.index_default_number_of_replicas}, \"mapping.total_fields.limit\":${var.index_maximum_number_of_fields}}}' https://${aws_elasticsearch_domain.es.endpoint}/_template/template_1"
  }
}

resource "aws_cloudwatch_metric_alarm" "clusterStatusRed" {
  alarm_name                = "${var.domain_name}-ESClusterStatusIsRed"
  alarm_description         = "${var.domain_name} elasticsearch cluster status is Red! a primary shard is offline!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "ClusterStatus.red"
  statistic                 = "Maximum"
  period                    = "60"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "1"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "clusterStatusYellow" {
  alarm_name                = "${var.domain_name}-ESClusterStatusIsYellow"
  alarm_description         = "${var.domain_name} elasticsearch cluster status is Yellow! a replica shard is offline!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "ClusterStatus.yellow"
  statistic                 = "Maximum"
  period                    = "60"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "1"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "lowDiskSpace" {
  alarm_name                = "${var.domain_name}-LowDiskSpace"
  alarm_description         = "${var.domain_name} disk utilization on one node in this elasticsearch cluster is over 75%!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "FreeStorageSpace"
  statistic                 = "Minimum"
  period                    = "60"
  evaluation_periods        = "1"
  comparison_operator       = "LessThanThreshold"
  threshold                 = var.ebs_size * 1024 * 0.25
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "blockingWriteRequests" {
  alarm_name                = "${var.domain_name}-BlockingWriteRequests"
  alarm_description         = "${var.domain_name} elasticsearch cluster has been blocking write requests!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "ClusterIndexWritesBlocked"
  statistic                 = "Sum"
  period                    = "300"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "1"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "deadNode" {
  alarm_name                = "${var.domain_name}-DeadNode"
  alarm_description         = "${var.domain_name} elasticsearch cluster has been missing one or more nodes for several hours!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "Nodes"
  statistic                 = "Minimum"
  period                    = "3600"
  evaluation_periods        = "3"
  comparison_operator       = "LessThanThreshold"
  threshold                 = var.instance_count
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "snapshotFailure" {
  alarm_name                = "${var.domain_name}-SnapshotFailure"
  alarm_description         = "${var.domain_name} a nightly elasticsearch backup snapshot has failed! (is the cluster dead?)"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "AutomatedSnapshotFailure"
  statistic                 = "Maximum"
  period                    = "60"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "1"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "dataNodeCpuUtilization" {
  alarm_name                = "${var.domain_name}-DataNodeCpuUtilization"
  alarm_description         = "${var.domain_name} elasticsearch cluster data node CPU has been running too high, for too long!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "CPUUtilization"
  statistic                 = "Average"
  period                    = "900"
  evaluation_periods        = "3"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "80"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "dataNodeMemoryPressure" {
  alarm_name                = "${var.domain_name}-DataNodeMemoryPressure"
  alarm_description         = "${var.domain_name} elasticsearch cluster data nodes are experiencing high JVMMemoryPressure!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "JVMMemoryPressure"
  statistic                 = "Maximum"
  period                    = "900"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "80"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "masterNodeCpuUtilization" {
  alarm_name                = "${var.domain_name}-MasterNodeCpuUtilization"
  alarm_description         = "${var.domain_name} elasticsearch cluster master node CPU has been running too high, for too long!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "MasterCPUUtilization"
  statistic                 = "Average"
  period                    = "900"
  evaluation_periods        = "3"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "50"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "masterNodeMemoryPressure" {
  alarm_name                = "${var.domain_name}-MasterNodeMemoryPressure"
  alarm_description         = "${var.domain_name} elasticsearch cluster master nodes are experiencing high JVMMemoryPressure!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "MasterJVMMemoryPressure"
  statistic                 = "Maximum"
  period                    = "900"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "80"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "encryptionKeyError" {
  alarm_name                = "${var.domain_name}-EncryptionKeyError"
  alarm_description         = "${var.domain_name} elasticsearch cluster KMS encryption key is disabled!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "KMSKeyError"
  statistic                 = "Maximum"
  period                    = "60"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "1"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

resource "aws_cloudwatch_metric_alarm" "encryptionKeyInaccessible" {
  alarm_name                = "${var.domain_name}-EncryptionKeyInaccessible"
  alarm_description         = "${var.domain_name} elasticsearch cluster KMS encryption key is inaccessible!"
  namespace                 = "AWS/ES"
  dimensions                = {
    ClientId = data.aws_caller_identity.current.account_id
    DomainName = var.domain_name
  }
  metric_name               = "KMSKeyInaccessible"
  statistic                 = "Maximum"
  period                    = "60"
  evaluation_periods        = "1"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "1"
  alarm_actions             = var.cloudwatch_alarm_default_actions
}

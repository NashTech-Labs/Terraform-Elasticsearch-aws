module "elasticsearch" {
  source                              = "./modules/elasticsearch"
  environment                         = var.environment
  domain_name                         = var.domain_name
  cluster_version                     = var.cluster_version
  dedicated_master                    = false
  instance_type                       = var.instance_type
  instance_count                      = var.instance_count
  publishing_es_logs                  = true
  advanced_security_options           = true
  internal_user_db                    = true
  master_user_name                    = var.master_user_name
  master_user_pass                    = var.master_user_pass
  enforce_domain_https                = true
  tls_policy                          = "Policy-Min-TLS-1-2-2019-07"
  node_to_node_encryption             = true
  encrypt_at_rest                     = true
  ebs_enabled                         = true
  ebs_size                            = var.ebs_size
  cloudwatch_alarm_default_actions    = var.cloudwatch_alarm_default_actions
  index_default_number_of_shards      = 5
  index_default_number_of_replicas    = 0
  tags    = {
    Domain = var.domain_name
    Environment = var.environment
  }
}
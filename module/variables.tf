
variable "environment" {}
variable "publishing_es_logs" {
  description = "should we publish the ES logs to Cloudwatch?"
  type = "string"
  default = "false"
}
variable "cloudwatch_alarm_default_actions" {
  description = "ARNs to execute in the event of a Cloudwatch alarm being triggered"
  type = "list"
  default = []
}
variable "index_default_number_of_shards" {
  description = "Default number of shards for each index"
  type = "string"
  default = "5"
}
variable "index_default_number_of_replicas" {
  description = "Default number of replicas for each index"
  type = "string"
  default = "0"
}
variable "index_maximum_number_of_fields" {
  description = "Maximum number of fields in each index"
  type = "string"
  default = "1000"
}
variable "domain_name" {
  description = "Domain name for AWS Elasticsearch"
  type = "string"
}
variable "cluster_version" {
  description = "Elasticsearch version"
  type = "string"
  default = "6.8"
}
variable "dedicated_master" {}
variable "instance_count" {
  default = 1
}
variable "instance_type" {
  description = "the instance type for the data instances"
  type = "string"
}
variable "advanced_security_options" {}
variable "master_user_arn" {
  default = ""
}
variable "internal_user_db" {
  default = false
}
variable "master_user_name" {
  default = ""
}
variable "master_user_pass" {
  default = ""
}
variable "enforce_domain_https" {
  default = false
}
variable "tls_policy" {}
variable "node_to_node_encryption" {
  default = false
}
variable "encrypt_at_rest" {
  default = false
}
variable "ebs_enabled" {
  default = true
}
variable "ebs_size" {
  default = 10
}
variable "tags" {
  type = map(string)
}

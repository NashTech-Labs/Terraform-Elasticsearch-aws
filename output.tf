output "elasticsearch-endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}

output "kibana-endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}
# Define output variables that can be used by Terraform callers to access
# attributes of resources created by the config or input values that were
# passed into the config at build time

locals {
  batch_job_definition_arn = (
    var.batch_compute_environment_backend == "fargate" ?
    aws_batch_job_definition.fargate[0].arn :
    aws_batch_job_definition.ec2[0].arn
  )
  batch_job_queue_arn = (
    var.batch_compute_environment_backend == "fargate" ?
    aws_batch_job_queue.fargate[0].arn :
    aws_batch_job_queue.ec2[0].arn
  )
}

output "batch_job_definition_arn" {
  description = "ARN of the Batch job definition"
  value       = local.batch_job_definition_arn
}

output "batch_job_queue_arn" {
  description = "ARN of the Batch job queue"
  value       = local.batch_job_queue_arn
}

output "batch_job_name" {
  description = "Name of the Batch job"
  value       = local.batch_job_name
}

output "batch_container_image_name" {
  description = "Name of the container image to use for the Batch job"
  value       = var.batch_container_image_name
}

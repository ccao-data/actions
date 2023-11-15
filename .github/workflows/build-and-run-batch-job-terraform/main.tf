# Terraform configuration for AWS Batch job resources that can run the model.
#
# Note that some stable resources that are shared between all Batch environments
# are either builtin to all AWS accounts or are defined in our core AWS
# infrastructure repository, which is separate from this module. These resources
# are thus referenced using Terraform `data` entities rather than `resource`
# entities, which means Terraform will not attempt to create or update them.
# These resources include, but are not limited to:
#
#  * The VPC, subnets, and security group used for container networking
#  * IAM roles for task execution and Batch provisioning

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.23"
    }
  }

  required_version = ">= 1.5.7"

  # Backend configs change based on the calling repo, so we leave it empty here
  # and then leave it up to the caller of `terraform init` to pass the required
  # S3 backend config attributes in via `-backend-config` flags.
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

# This variable defines the name of all of the Batch resources managed by
# this configuration. The name should have appropriate prefixes depending on
# whether it's intended for a staging or prod environment, so we leave the
# naming logic up to the Terraform caller, which we expect to be a CI
# environment with knowledge of the current git branch name
variable "batch_job_name" {
  type = string
}

# Set the name of the container image that the Batch job should pull to use as
# its execution environment, e.g. "ghcr.io/ccao-data/model-res-avm:master".
# This is defined as a variable so that CI environments can point Batch
# job definitions to freshly built images
variable "batch_container_image_name" {
  type = string
}

# How many vCPUs should be provisioned for Batch jobs
variable "batch_job_definition_vcpu" {
  type = string
}

# How many GPUs should be provisioned for Batch jobs (note that this requires
# EC2 as a backend, and will be ignored if Fargate is configured instead)
variable "batch_job_definition_gpu" {
  type    = string
  default = null
}

# How much memory should be provisioned for Batch jobs
variable "batch_job_definition_memory" {
  type = string
}

# Set the backend for the Batch compute environment (one of "fargate" or "ec2")
variable "batch_compute_environment_backend" {
  type = string

  # Raise an error if the backend is not recognized. Note that our outputs
  # assume there are only two options here, so if we add support for more
  # backends we'll need to adjust our output vars
  validation {
    condition     = contains(["fargate", "ec2"], var.batch_compute_environment_backend)
    error_message = "Allowed values for batch_compute_environment_backend are \"fargate\" or \"ec2\""
  }
}

# Raise an error if GPU support is configured without an EC2 backend. This is
# the recommended approach to variable validation per this thread:
# https://github.com/hashicorp/terraform/issues/25609#issuecomment-1472119672
output "validate_batch_job_definition_gpu" {
  value = null

  precondition {
    condition = (
      var.batch_job_definition_gpu == null ||
      var.batch_compute_environment_backend == "ec2"
    )
    error_message = "batch_compute_environment_backend must be 'ec2' to enable GPU, got '${var.batch_compute_environment_backend}'"
  }
}

# Retrieve the default VPC for this region, which is builtin to AWS.
# Containers in the Batch compute environment will be deployed into this VPC
data "aws_vpc" "default" {
  default = true
}

# Retrieve the default subnets in the default VPC, which are builtin to AWS.
# Containers in the Batch compute environment are connected to the Internet
# using these subnets. Note that these subnets are public by default, but the
# use of an additional security group ensures that we block all ingress to the
# compute environment
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = [true]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Retrieve the security group that blocks all ingress and allows egress over
# HTTPS only
data "aws_security_group" "outbound_https" {
  name   = "outbound-https"
  vpc_id = data.aws_vpc.default.id
}

# Retrieve the IAM role that the Batch compute environment uses to manage
# EC2/ECS resources
data "aws_iam_role" "batch_service_role" {
  name = "AWSServiceRoleForBatch"
}

# Retrieve the IAM role that EC2 uses to run ECS tasks (used by the EC2 backend)
data "aws_iam_role" "ec2_service_role_for_ecs" {
  name = "AWSEC2ServiceRoleForECS"
}

# Retrieve the IAM role that the Batch job definition uses to execute ECS
# operations like pulling Docker images and pushing logs to CloudWatch
# (used by the Fargate backend)
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Retrieve the IAM role that the Batch job passes on to the containers, allowing
# those containers to access AWS resources like data stored in S3
data "aws_iam_role" "ecs_job_role" {
  name = "ccao-ecs-model-runner"
}


# Create a Batch compute environment to run containers. Compute environments
# define the underlying ECS or EC2 resources that will be provisioned to
# use for running jobs in containers. Docs here:
# https://docs.aws.amazon.com/batch/latest/userguide/compute_environments.html
resource "aws_batch_compute_environment" "fargate" {
  # Only create this resource if the Fargate backend is enabled
  count                    = var.batch_compute_environment_backend == "fargate" ? 1 : 0
  compute_environment_name = var.batch_job_name
  service_role             = data.aws_iam_role.batch_service_role.arn
  state                    = "ENABLED"
  type                     = "MANAGED"

  compute_resources {
    type               = "FARGATE"
    min_vcpus          = 0
    max_vcpus          = 64 # Max across all jobs, not within one job
    security_group_ids = [data.aws_security_group.outbound_https.id]
    subnets            = data.aws_subnets.default.ids
  }
}

resource "aws_batch_compute_environment" "ec2" {
  # Only create this resource if the EC2 backend is enabled
  count                    = var.batch_compute_environment_backend == "ec2" ? 1 : 0
  compute_environment_name = var.batch_job_name
  service_role             = data.aws_iam_role.batch_service_role.arn
  state                    = "ENABLED"
  type                     = "MANAGED"

  compute_resources {
    type                = "EC2"
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    bid_percentage      = 0
    min_vcpus           = 0
    desired_vcpus       = 0
    max_vcpus           = 64
    instance_role       = data.aws_iam_role.ec2_service_role_for_ecs.arn
    instance_type       = ["optimal"]
    security_group_ids  = [data.aws_security_group.outbound_https.id]
    subnets             = data.aws_subnets.default.ids
  }
}

# Create a Batch job queue to run jobs. Job queues keep track of which jobs
# are waiting to run and in what order they should be prioritized in cases
# where its associated compute environment has reached max capacity. Docs here:
# https://docs.aws.amazon.com/batch/latest/userguide/job_queues.html
resource "aws_batch_job_queue" "fargate" {
  count                = var.batch_compute_environment_backend == "fargate" ? 1 : 0
  name                 = var.batch_job_name
  compute_environments = [aws_batch_compute_environment.fargate[0].arn]
  priority             = 0
  state                = "ENABLED"
}

resource "aws_batch_job_queue" "ec2" {
  count                = var.batch_compute_environment_backend == "ec2" ? 1 : 0
  name                 = var.batch_job_name
  compute_environments = [aws_batch_compute_environment.ec2[0].arn]
  priority             = 0
  state                = "ENABLED"
}

# Create a Batch job definition to define jobs. Job definitions provide the
# information about how containers should be configured in a compute
# environment and what those containers should do. When combined with a
# job queue, they provide enough information to submit a job. Docs here:
# https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html
#
# Note that jobs using this job definition cannot be provisioned by Terraform,
# and are instead submitted via calls to `aws batch submit-job` in the same CI
# workflow that provisions these resources
resource "aws_batch_job_definition" "fargate" {
  count                 = var.batch_compute_environment_backend == "fargate" ? 1 : 0
  name                  = var.batch_job_name
  platform_capabilities = ["FARGATE"]
  type                  = "container"

  container_properties = jsonencode({
    executionRoleArn = data.aws_iam_role.ecs_task_execution_role.arn
    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }
    image      = var.batch_container_image_name
    jobRoleArn = data.aws_iam_role.ecs_job_role.arn
    logConfiguration = {
      logDriver = "awslogs"
    }
    networkConfiguration = {
      assignPublicIp = "ENABLED"
    }
    resourceRequirements = [
      {
        type  = "VCPU"
        value = var.batch_job_definition_vcpu
      },
      {
        type  = "MEMORY"
        value = var.batch_job_definition_memory
      }
    ]
    runtimePlatform = {
      cpuArchitecture       = "X86_64"
      operatingSystemFamily = "LINUX"
    }
  })
}

resource "aws_batch_job_definition" "ec2" {
  count                 = var.batch_compute_environment_backend == "ec2" ? 1 : 0
  name                  = var.batch_job_name
  platform_capabilities = ["EC2"]
  type                  = "container"

  container_properties = jsonencode({
    executionRoleArn = data.aws_iam_role.ecs_task_execution_role.arn
    image            = var.batch_container_image_name
    jobRoleArn       = data.aws_iam_role.ecs_job_role.arn
    logConfiguration = {
      logDriver = "awslogs"
    }
    # Use flatten() so that we only add GPU if it's not null. Source for this
    # approach: https://stackoverflow.com/a/70088628
    resourceRequirements = flatten([
      {
        type  = "VCPU"
        value = var.batch_job_definition_vcpu
      },
      {
        type  = "MEMORY"
        value = var.batch_job_definition_memory
      },
      var.batch_job_definition_gpu != null ?
      [{ type = "GPU", value = var.batch_job_definition_gpu }] :
      []
    ])
  })
}

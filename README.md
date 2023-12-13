# Actions

GitHub Actions for CCAO Data projects.

This repo also includes reusable workflows (stored in the `.github/workflows/`
directory) and bash scripts to support them (stored in the
`.github/workflow/scripts/` directory.)

# Quick links

* [Actions](#actions)
  * [`setup-terraform`](#setup-terraform)
  * [`cleanup-terraform`](#cleanup-terraform)
* [Workflows](#workflows)
  * [`build-and-run-batch-job`](#build-and-run-batch-job)

# Actions

The following composite actions are available for use:

## setup-terraform

Install and configure Terraform and AWS for the correct workspace (staging or
prod).

### Requirements

* At least one Terraform (`*.tf`) config file must exist in the repo. The path
  to these files can be specified with the `working-directory` input variable
  (defaults to `"."`).
* The calling workflow must grant the following permissions to the job that
  calls this action:
    * `contents: read`
    * `id-token: write`
* Various required inputs and secrets must be passed in by the calling workflow.
  See the [action file](./setup-terraform/action.yaml) for details.

### Sample usage

See the `Setup Terraform` step in the `run` job in the
[build-and-run-batch-job](./.github/workflows/build-and-run-batch-job.yaml)
workflow.

## cleanup-terraform

Delete all AWS resources managed by a Terraform configuration.

### Requirements

See the requirements for [`setup-terraform`](#setup-terraform).

### Sample usage

See the sample usage for [`setup-terraform`](#setup-terraform).

# Workflows

The following reusable workflows are available for use:

## build-and-run-batch-job

Build a Docker image, push it to the GitHub Container Registry, and then
optionally use that container image to run a job on AWS Batch.

The Batch job will only run when the workflow is manually dispatched from the
GitHub UI. Jobs are gated behind an environment called `deploy`, which can
be configured to require approval before running. This is handy for intensive
jobs that don't need to be run on every commit during development.

An optional cleanup step will run on the `pull_request.closed` event if the
calling workflow is configured to run on that event as well. This step will
delete all AWS resources provisioned by Terraform. No other steps will run
on `pull_request.closed`.

The workflow is composed of three jobs:

* `build`: Always runs, except on the `pull_request.closed` event. Builds a
  Docker image and pushes it to GHCR.
* `run`: Runs after `build` only when manually dispatched and when the
  `deploy` environment is approved. Provisions a Batch compute
  environment, job queue, and job definition using the image built in the
  `build` step using Terraform, and then kicks off a job using that job
  definition. Waits for the job to complete before exiting.
* `cleanup`: Deletes all AWS resources created by the workflow. Only runs on
  the `pull_request.closed` event, in which case neither `build` nor `run`
  will run.

### Requirements

* A Dockerfile must be defined in the root of the repo whose workflow is
  calling `build-and-run-batch-job`.
* An environment called `deploy` must be configured in the calling repo. This
  environment can be used to gate the `run` job behind approval.
* If you would like the `cleanup` step to run, the calling workflow must be
  configured to run on the `pull_request.closed` event.
* Various AWS VPC and IAM resources that are used across jobs are assumed to
  already exist. These resources are defined as `data` entities in the Terraform
  config for the workflow. In the future we could factor this out to make
  these resource IDs configurable, but for now they are hardcoded to point to
  the corresponding resources in the CCAO Data AWS organization. See the
  [Terraform
  config](./github/workflows/build-and-run-batch-job-terraform/main.tf)
  for details.
* The calling workflow must grant the following permissions to the job
  that calls this workflow:
    * `contents: read`
    * `id-token: write`
    * `packages: write`
* Various required inputs and secrets must be passed in by the calling workflow.
  See the [workflow file](./workflows/build-and-run-batch-job/deploy.yaml) for details.

### Sample usage

See the `build-and-run-model` workflow in
[model-res-avm](https://github.com/ccao-data/model-res-avm/blob/master/.github/workflows/build-and-run-model.yaml).

# actions

GitHub Actions for CCAO Data projects.

This repo also includes reusable workflows (stored in the `workflows` directory)
and bash scripts to support them (stored in the `scripts` directory.)

## Quick links

* [Actions](#actions)
  * [`setup-terraform`](#setup-terraform)
  * [`cleanup-terraform`](#cleanup-terraform)
* [Workflows](#workflows)
  * [`build-and-run-batch-job/deploy`](#build-and-run-batch-jobdeploy)
  * [`build-and-run-batch-job/cleanup`](#build-and-run-batch-jobcleanup)

## Actions

The following composite actions are available for use:

### setup-terraform

Install and configure Terraform and AWS for the correct workspace (staging or
prod).

#### Requirements

* At least one Terraform (`*.tf`) config file must exist in the repo. The path
  to these files can be specified with the `working-directory` input variable
  (defaults to `"."`).
* The calling workflow must grant the following permissions to the job that
  calls this action:
    * `contents: read`
    * `id-token: write`
* Various required inputs and secrets must be passed in by the calling workflow.
  See the [action file](./setup-terraform/action.yaml) for details.

#### Sample usage

See the `Setup Terraform` step in the `run` job in the
[build-and-run-batch-job/deploy](./workflows/build-and-run-batch-job/deploy.yaml)
workflow.

### cleanup-terraform

Delete all AWS resources managed by a Terraform configuration.

#### Requirements

See the requirements for [`setup-terraform`](#setup-terraform).

#### Sample usage

See the sample usage for [`setup-terraform`](#setup-terraform).

## Workflows

The following reusable workflows are available for use:

### build-and-run-batch-job/deploy

Build a Docker image, push it to the GitHub Container Registry, and then
optionally use that container image to run a job on AWS Batch.

The Batch job will be gated behind an environment called `deploy`, which can
be configured to require approval before running. This is handy for intensive
jobs that don't need to be run on every commit during development.

#### Requirements

* A Dockerfile must be defined in the root of the repo whose workflow is
  calling `build-and-run-batch-job`.
* A `deploy` environment must be configured in the calling repo. This
  environment can be used to gate the `run` job behind approval.
* The calling workflow must grant the following permissions to the job
  that calls this workflow:
    * `contents: read`
    * `id-token: write`
    * `packages: write`
* Various required inputs and secrets must be passed in by the calling workflow.
  See the [workflow file](./workflows/build-and-run-batch-job/deploy.yaml) for details.

#### Sample usage

See the `build-and-run-model` workflow in
[model-res-avm](https://github.com/ccao-data/model-res-avm/blob/master/.github/workflows/build-and-run-model.yaml).

### build-and-run-batch-job/cleanup

Delete all AWS resources managed by the Terraform configuration for the
`build-and-run-batch-job/deploy` workflow.

This can be useful to call from the context of a workflow that runs on
the `pull_request.closed` event in order to clean up any staging resources
that were used for testing.

#### Requirements

* At least one Terraform (`*.tf`) config file must exist in the repo.
* The calling workflow must grant the following permissions to the job that
  calls this workflow:
    * `contents: read`
    * `id-token: write`
* Various required inputs and secrets must be passed in by the calling workflow.
  See the [workflow file](./workflows/build-and-run-batch-job/cleanup.yaml) for details.

#### Sample usage

See the `cleanup-model` workflow in
[model-res-avm](https://github.com/ccao-data/model-res-avm/blob/master/.github/workflows/cleanup-model.yaml)

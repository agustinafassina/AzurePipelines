# Azure Pipelines and Elastic Container Registry
This repository contains a pipeline that builds a Docker image and pushes it to Amazon ECR for vulnerability scanning. If vulnerabilities are detected, the pipeline fails and halts the deployment process. If no vulnerabilities are found, it proceeds with the deployment automatically, ensuring secure container images.

### Structure
- azure-pipelines.yml
- README.md

### Comments and recomendations
- Pipelines for Azure Devops
- Environment variables in the pipelines
- It is required to have an aws account.

#### Repository version
v 0.1.0

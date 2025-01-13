# Terraform Module: EKS Cluster

## Overview

This Terraform module sets up an Amazon EKS (Elastic Kubernetes Service) cluster along with its worker nodes and necessary networking components. The module is designed to be reusable and configurable to fit various use cases.

## Prerequisites

- Terraform installed on your local machine
- AWS CLI configured with appropriate permissions
- An existing VPC or the ability to create a new one

## Usage

To use this module, include it in your Terraform configuration as follows:

```hcl
module "eks_cluster" {
  source = "<module-source>"

  # Add your module input variables here
  cluster_name              = "my-eks-cluster"
  region                    = "us-west-2"
  vpc_id                    = "vpc-12345678"
  subnet_ids                = ["subnet-12345678", "subnet-87654321"]
  control_plan_subnet_ids   = ["subnet-87654323", "subnet-87654324"]
  cluster_version           = 1.29
  # Add other variables as needed
}
```


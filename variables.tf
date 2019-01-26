variable "region" {
  default = "us-west-2"
}

variable "cluster_name" {
  default = "k8s"
}

variable "cluster_domain" {}

variable "kops_state" {}

variable "kubernetes_version" {
  default = "v1.10.11"
}

variable "vpc_id" {}

variable "container_networking" {
  default = "calico"
}

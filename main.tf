provider "aws" {
  region = "${var.region}"
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id = "${var.vpc_id}"
}

data "aws_availability_zones" "available" {}

data "aws_subnet_ids" "this" {
  vpc_id = "${var.vpc_id}"
}

data "aws_subnet" "this" {
  count = "${length(data.aws_subnet_ids.this.ids)}"
  id    = "${data.aws_subnet_ids.this.ids[count.index]}"
}

locals {
  full_cluster_name = "${var.cluster_name}.${var.cluster_domain}"
  azs               = "${data.aws_availability_zones.available.names}"
}

data "template_file" "cluster_spec" {
  template = "${file("${path.module}/tmpl/cluster.yaml.tmpl")}"

  vars {
    cluster            = "${local.full_cluster_name}"
    cluster_name       = "${var.cluster_name}"
    cluster_domain     = "${var.cluster_domain}"
    kops_state         = "${var.kops_state}"
    kubernetes_version = "${var.kubernetes_version}"

    # network setup
    vpc_id               = "${var.vpc_id}"
    vpc_cidr             = "${data.aws_vpc.this.cidr_block}"
    container_networking = "${var.container_networking}"

    # etcd
    etcd_clusters = "${join("\n", data.template_file.etcd_cluster.*.rendered)}"
  }
}

data "template_file" "etcd_cluster" {
  template = <<EOF
  - etcdMembers:
${join("", data.template_file.etcd_member.*.rendered)}
    name: main
  - etcdMembers:
${join("", data.template_file.etcd_member.*.rendered)}
    name: events
EOF
}

data "template_file" "etcd_member" {
  count = "${length(local.azs)}"

  template = <<EOF
    - encryptedVolume: true
      instanceGroup: master-$${az}
      name: $${az}
EOF

  vars {
    az = "${element(local.azs, count.index)}"
  }
}

resource "local_file" "cluster_spec" {
  content  = "${data.template_file.cluster_spec.rendered}"
  filename = "${path.cwd}/cluster-spec.yaml"
}

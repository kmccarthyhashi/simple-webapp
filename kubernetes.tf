terraform {

# test run

  cloud {
    organization = "KELLY-training"
    workspaces {
      name = "simple-webapp"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.48.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.1"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "remote"

  config = {
    organization = "KELLY-training"
    workspaces = {
      name = "eks-cluster"
    }
  }
}

# Retrieve EKS cluster information
provider "aws" {
  region = "us-east-2"
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_deployment" "app1" {
  metadata {
    name = "frontend"
    labels = {
      App = "frontend"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "webapp"
      }
    }
    template {
      metadata {
        labels = {
          App = "webapp"
        }
      }
      spec {
        container {
          image = "simple-webapp"
          name  = "kodekloud/webapp-color:v1"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          
        }
      }
    }
  }
}
resource "kubernetes_service" "webapp_service" {
  metadata {
    name = "webapp-service"
  }
  spec {
    selector = {
      App = kubernetes_deployment.app1.spec.0.template.0.metadata[0].labels.App
    }

    type = "NodePort"

    port {
      port        = 80
      target_port = 80
      node_port = 8081
    }

    # type = "LoadBalancer"
  }
}

output "lb_ip" {
  value = kubernetes_service.webapp_service.status.0.load_balancer.0.ingress.0.hostname
}




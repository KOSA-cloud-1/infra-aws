# =========================================================
# AWS 기본 설정
# =========================================================

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_access_key" {
  description = "AWS Access Key ID. profile을 쓰지 않을 때 terraform.tfvars에 설정합니다."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key. profile을 쓰지 않을 때 terraform.tfvars에 설정합니다."
  type        = string
  default     = null
  sensitive   = true
}

variable "project_name" {
  description = "리소스 이름과 태그에 사용할 프로젝트명"
  type        = string
  default     = "cloud-team1"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name은 소문자, 숫자, 하이픈만 사용할 수 있습니다."
  }
}

variable "environment" {
  description = "환경 이름"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment는 소문자, 숫자, 하이픈만 사용할 수 있습니다."
  }
}

variable "tags" {
  description = "모든 리소스에 추가할 공통 태그"
  type        = map(string)
  default     = {}
}

# =========================================================
# VPC / Subnet 구성
# =========================================================

variable "vpc_name" {
  description = "기존 AWS VPC Name 태그"
  type        = string
  default     = "cloud-team1-vpc"
}

variable "public_subnets" {
  description = "HAProxy와 NLB를 배치할 기존 Public Subnet 목록"

  type = map(object({
    name = string
  }))

  default = {
    public-a = {
      name = "cloud-team1-subnet-public1-ap-northeast-2a"
    }
    public-b = {
      name = "cloud-team1-subnet-public2-ap-northeast-2b"
    }
  }
}

variable "private_subnets" {
  description = "기존 Private Subnet 목록"

  type = map(object({
    name = string
  }))

  default = {
    private-a = {
      name = "cloud-team1-subnet-private1-ap-northeast-2a"
    }
    private-b = {
      name = "cloud-team1-subnet-private2-ap-northeast-2b"
    }
  }
}

# =========================================================
# HAProxy EC2 구성
# =========================================================

variable "ami_id" {
  description = "HAProxy EC2에 사용할 AMI ID. null이면 Ubuntu 24.04 LTS 최신 AMI를 조회합니다."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  description = "EC2 접속용 SSH 공개 키. null이면 key pair를 생성하지 않습니다."
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "HAProxy EC2에 SSH 접속을 허용할 CIDR 목록"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "HAProxy EC2에 Public IP를 연결할지 여부"
  type        = bool
  default     = true
}

variable "haproxy_instances" {
  description = "생성할 HAProxy EC2 목록"

  type = map(object({
    subnet_key       = string
    instance_type    = optional(string, "t3.micro")
    private_ip       = optional(string)
    root_volume_size = optional(number, 20)
  }))

  default = {
    haproxy-a = {
      subnet_key = "public-a"
    }
    haproxy-b = {
      subnet_key = "public-b"
    }
  }
}

variable "haproxy_backends" {
  description = "AWS HAProxy가 전달할 On-Prem 또는 EKS backend 목록"

  type = map(object({
    address    = string
    http_port  = optional(number, 80)
    https_port = optional(number, 443)
    check      = optional(bool, true)
  }))
}

variable "haproxy_balance_algorithm" {
  description = "HAProxy backend balance 알고리즘"
  type        = string
  default     = "roundrobin"
}

variable "haproxy_maxconn" {
  description = "HAProxy global maxconn 값"
  type        = number
  default     = 4096
}

# =========================================================
# NLB / 보안 정책
# =========================================================

variable "client_allowed_cidrs" {
  description = "AWS NLB 80/443 접근을 허용할 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "project_name" {
  description = "리소스 이름과 태그에 사용할 프로젝트명"
  type        = string
}

variable "environment" {
  description = "환경 이름"
  type        = string
}

variable "tags" {
  description = "모든 리소스에 추가할 공통 태그"
  type        = map(string)
  default     = {}
}

variable "vpc_name" {
  description = "기존 AWS VPC Name 태그"
  type        = string
}

variable "public_subnets" {
  description = "HAProxy와 NLB를 배치할 기존 Public Subnet 목록"

  type = map(object({
    name = string
  }))
}

variable "ami_id" {
  description = "HAProxy EC2에 사용할 AMI ID. null이면 Ubuntu 24.04 LTS 최신 AMI를 조회합니다."
  type        = string
  default     = null
}

variable "ssh_key_name" {
  description = "EC2에 연결할 기존 AWS Key Pair 이름"
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

variable "haproxy_security_group_name" {
  description = "HAProxy EC2 Security Group 이름. null이면 project_name 기반 기본 이름을 사용합니다."
  type        = string
  default     = null
}

variable "nlb_security_group_name" {
  description = "NLB Security Group 이름. null이면 project_name/environment 기반 기본 이름을 사용합니다."
  type        = string
  default     = null
}

variable "haproxy_instances" {
  description = "생성할 HAProxy EC2 목록"

  type = map(object({
    subnet_key       = string
    instance_type    = optional(string, "t3.micro")
    private_ip       = optional(string)
    root_volume_size = optional(number, 20)
  }))
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

variable "client_allowed_cidrs" {
  description = "AWS NLB 80/443 접근을 허용할 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

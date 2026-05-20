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

# =========================================================
# VPN Server 구성
# =========================================================

variable "enable_vpn_server" {
  description = "ER605 연동용 StrongSwan VPN EC2 생성 여부"
  type        = bool
  default     = false
}

variable "vpn_instance_type" {
  description = "VPN Server EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "vpn_subnet_key" {
  description = "VPN Server EC2를 배치할 public_subnets key"
  type        = string
  default     = "public-a"
}

variable "vpn_root_volume_size" {
  description = "VPN Server root volume size"
  type        = number
  default     = 20
}

variable "vpn_security_group_name" {
  description = "VPN Server Security Group 이름. null이면 project_name 기반 기본 이름을 사용합니다."
  type        = string
  default     = null
}

variable "vpn_instances" {
  description = "생성할 StrongSwan VPN EC2 목록. 비우면 기존 단일 vpn_* 변수로 1대를 생성합니다."

  type = map(object({
    subnet_key       = string
    instance_type    = optional(string)
    private_ip       = optional(string)
    root_volume_size = optional(number)
    priority         = optional(number, 100)
  }))

  default = {}
}

variable "vpn_active_instance_key" {
  description = "초기 서비스 EIP와 On-Prem route를 연결할 Active VPN instance key. null이면 정렬상 첫 key를 사용합니다."
  type        = string
  default     = null
}

variable "enable_vpn_failover" {
  description = "여러 VPN EC2 중 장애가 아닌 인스턴스로 EIP와 route를 넘기는 Lambda failover 사용 여부"
  type        = bool
  default     = true
}

variable "vpn_failover_schedule_expression" {
  description = "VPN failover Lambda 실행 주기"
  type        = string
  default     = "rate(1 minute)"
}

variable "vpn_preshared_key" {
  description = "ER605 IPsec Pre-shared Key"
  type        = string
  default     = null
  sensitive   = true
}

variable "vpn_peer_allowed_cidrs" {
  description = "ER605 쪽 IKE/NAT-T 접속을 허용할 CIDR. ER605가 NAT 뒤에 있으면 0.0.0.0/0로 둡니다."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpn_icmp_allowed_cidrs" {
  description = "VPN Server에 ICMP(ping)를 허용할 CIDR 목록. 비우면 ICMP 규칙을 추가하지 않습니다."
  type        = list(string)
  default     = []
}

variable "vpn_aws_cidrs" {
  description = "IPsec leftsubnet으로 사용할 AWS CIDR 목록. 비우면 VPC CIDR을 사용합니다."
  type        = list(string)
  default     = []
}

variable "vpn_onprem_cidrs" {
  description = "IPsec rightsubnet 및 AWS route destination으로 사용할 On-Prem CIDR 목록"
  type        = list(string)
  default     = ["172.17.32.0/24"]
}

variable "vpn_right_id" {
  description = "ER605 IPsec peer ID"
  type        = string
  default     = "@er605"
}

variable "vpn_auto" {
  description = "StrongSwan conn auto 값. ER605가 NAT 뒤에서 먼저 접속하는 구조라면 add, AWS에서 먼저 연결해야 하면 start"
  type        = string
  default     = "add"
}

variable "vpn_ike_proposal" {
  description = "StrongSwan IKE proposal"
  type        = string
  default     = "aes256-sha1-modp1024!"
}

variable "vpn_esp_proposal" {
  description = "StrongSwan ESP proposal"
  type        = string
  default     = "aes128-sha1!"
}

variable "vpn_route_table_names" {
  description = "On-Prem CIDR route를 추가할 기존 Route Table Name 목록"

  type = map(string)

  default = {
    public    = "cloud-team1-rtb-public"
    private-a = "cloud-team1-rtb-private1-ap-northeast-2a"
    private-b = "cloud-team1-rtb-private2-ap-northeast-2b"
  }
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

variable "nlb_tls_certificate_arn" {
  description = "NLB 443 TLS listener에 연결할 ACM 인증서 ARN. TLS는 AWS NLB에서 종료하고 HAProxy에는 복호화된 HTTP로 전달합니다."
  type        = string
}

variable "nlb_tls_ssl_policy" {
  description = "NLB 443 TLS listener SSL policy"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
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
  description = "AWS HAProxy가 HTTP 80으로 전달할 On-Prem 또는 EKS backend 목록"

  type = map(object({
    address   = string
    http_port = optional(number, 80)
    check     = optional(bool, true)
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

# =========================================================
# Route53
# =========================================================

variable "route53_zone_name" {
  description = "기존 Route53 호스팅 영역 이름 (예: example.com). null이면 Route53 레코드를 생성하지 않습니다."
  type        = string
  default     = null
}

variable "nlb_record_names" {
  description = "NLB alias 레코드를 생성할 서브도메인 목록 (예: [\"app\", \"www\"]). 비우면 zone apex에만 생성합니다."
  type        = list(string)
  default     = []
}

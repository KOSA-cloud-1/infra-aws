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
  description = "VPN Server EC2를 배치할 기존 Public Subnet 목록"

  type = map(object({
    name = string
  }))
}

variable "ami_id" {
  description = "VPN Server EC2에 사용할 AMI ID. null이면 Ubuntu 24.04 LTS 최신 AMI를 조회합니다."
  type        = string
  default     = null
}

variable "ssh_key_name" {
  description = "EC2에 연결할 기존 AWS Key Pair 이름"
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "VPN Server EC2에 SSH 접속을 허용할 CIDR 목록"
  type        = list(string)
  default     = []
}

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
  type        = map(string)
  default     = {}
}

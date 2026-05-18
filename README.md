### 레포지토리 구조

```
infra-aws/
└─ terraform/
   ├─ provider.tf
   ├─ variables.tf
   ├─ main.tf
   ├─ outputs.tf
   ├─ terraform.tfvars.example
   ├─ haproxy/
   │  ├─ main.tf
   │  ├─ variables.tf
   │  ├─ outputs.tf
   │  └─ templates/
   └─ vpn/
      ├─ main.tf
      ├─ variables.tf
      ├─ outputs.tf
      └─ templates/
```

### Terraform 구성

기존 AWS 네트워크 위에 외부 진입 구간을 구성한다. 기존 `terraform/` root module은 state 호환을 위해 유지하고, 실제 HAProxy/NLB와 VPN 리소스는 각각 `terraform/haproxy`, `terraform/vpn` 하위 모듈로 분리했다.

- Terraform: `>= 1.15.3, < 1.16.0`
- VPC: `cloud-team1-vpc`
- Public Subnet: `cloud-team1-subnet-public1-ap-northeast-2a`, `cloud-team1-subnet-public2-ap-northeast-2b`
- Private Subnet: `cloud-team1-subnet-private1-ap-northeast-2a`, `cloud-team1-subnet-private2-ap-northeast-2b`
- NLB: 80/443 TCP Listener
- EC2 HAProxy: Public Subnet에 2대 구성
- HAProxy backend: `haproxy_backends` 변수로 VLAN20 On-Prem HAProxy VIP 지정
- VPN Server: ER605 IPsec initiator 연결을 받는 StrongSwan EC2 2대와 서비스 Elastic IP 구성
- VPN Failover: EventBridge가 Lambda를 1분마다 실행해 정상 EC2 중 우선순위가 높은 인스턴스로 서비스 EIP와 On-Prem route를 이동
- VPN on-prem CIDR: 기본값은 VLAN20 DMZ `172.17.32.0/24`로 두어 AWS/VPN에서 VLAN40으로 직접 라우팅하지 않는다.
- 기본 backend 예시는 `infra-proxmox/terraform/haproxy`의 `haproxy_vip` 값인 `172.17.32.20`에 맞춰 둔다.

### 실행 방법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

또는 Proxmox Terraform과 같은 단계별 배포 스크립트를 사용할 수 있다.

```bash
cd terraform
./terraform-execute.sh
```

`terraform.tfvars`에서 `haproxy_backends`의 `address`를 실제 VLAN20 On-Prem HAProxy VIP로 변경해야 한다.
ER605 VPN을 적용하려면 `vpn_preshared_key`를 실제 Pre-shared Key로 변경해야 한다.
ER605 Remote Gateway에는 Terraform output `vpn_server_public_ip`로 나오는 VPN 서비스 EIP를 설정한다.

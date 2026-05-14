### 레포지토리 구조

```
infra-aws/
└─ terraform/
   ├─ provider.tf
   ├─ variables.tf
   ├─ main.tf
   ├─ outputs.tf
   ├─ terraform.tfvars.example
   └─ templates/
      ├─ cloud-init.yml.tftpl
      └─ haproxy.cfg.tftpl
```

### Terraform 구성

기존 AWS 네트워크 위에 외부 진입 구간을 구성한다.

- VPC: `cloud-team1-vpc` (`10.1.0.0/16`)
- Public Subnet: `cloud-team1-subnet-public1-ap-northeast-2a`, `cloud-team1-subnet-public2-ap-northeast-2b`
- Private Subnet: `cloud-team1-subnet-private1-ap-northeast-2a`, `cloud-team1-subnet-private2-ap-northeast-2b`
- NLB: 80/443 TCP Listener
- EC2 HAProxy: Public Subnet에 2대 구성
- HAProxy backend: `haproxy_backends` 변수로 On-Prem HAProxy 또는 Ingress endpoint 지정
- VPN Server: ER605 IPsec initiator 연결을 받는 StrongSwan EC2와 Elastic IP 구성

### 실행 방법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

`terraform.tfvars`에서 `haproxy_backends`의 `address`를 실제 On-Prem HAProxy IP로 변경해야 한다.
ER605 VPN을 적용하려면 `vpn_preshared_key`를 실제 Pre-shared Key로 변경해야 한다.

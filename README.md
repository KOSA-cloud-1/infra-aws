# infra-aws

AWS 외부 진입(Edge) 구간 Terraform 코드. 기존 AWS 네트워크(VPC/Subnet) 위에
**공개 진입점(Route53 + NLB + HAProxy)** 과 **온프렘 연결용 IPsec VPN(StrongSwan)** 을 구성한다.

## 레포지토리 구조

```text
infra-aws/
└─ terraform/
   ├─ provider.tf
   ├─ variables.tf
   ├─ main.tf                 # haproxy / vpn 모듈을 조합하는 root module
   ├─ outputs.tf
   ├─ moved.tf
   ├─ terraform.tfvars(.example)
   ├─ deploy.sh / terraform-execute.sh   # 단계별 배포 스크립트
   ├─ haproxy/                # NLB + HAProxy EC2 (+ Route53 alias)
   │  ├─ main.tf / variables.tf / outputs.tf / versions.tf
   │  └─ templates/           # cloud-init, haproxy.cfg
   └─ vpn/                    # StrongSwan EC2 + 서비스 EIP + 페일오버 Lambda
      ├─ main.tf / variables.tf / outputs.tf / versions.tf
      └─ templates/           # cloud-init, ipsec.conf, vpn-failover.py
```

## 아키텍처 / 트래픽 흐름

```text
client
  └─ Route53 (fhwang.cloud, www.fhwang.cloud) ── alias ──▶ AWS NLB (cross-zone)
        ├─ :443 TLS listener (ACM 인증서로 TLS 종료) ─┐
        └─ :80  TCP listener ─────────────────────────┤
                                                       ▼
        AWS HAProxy EC2 × 2 (haproxy-a / haproxy-b, Public Subnet)
          ├─ :80   → HTTP→HTTPS 301 redirect
          └─ :8080 → NLB가 복호화한 HTTP 수신 → backend 전달
                                                       ▼
        [ IPsec VPN tunnel: AWS StrongSwan ↔ On-Prem ER605 ]
                                                       ▼
        On-Prem HAProxy VIP 172.17.32.20:80 (DMZ VLAN20, keepalived)
                                                       ▼
        K8s Ingress VIP 172.17.128.240:80 (MetalLB) → Service → Pod
```

- **TLS는 NLB(443)에서 종료**하고, 이후 구간은 평문 HTTP `80`만 사용한다.
- AWS HAProxy → 온프렘 HAProxy(`172.17.32.20`)는 사설망이라 **VPN 터널을 통해** 도달한다.

## 이중화(HA) 방식

| 구성 | 방식 | 메커니즘 |
|---|---|---|
| **AWS HAProxy** | **active/active** | NLB cross-zone LB가 `haproxy-a`/`haproxy-b` 두 EC2에 동시 분산. health check로 비정상 인스턴스 자동 제외 |
| **AWS VPN (StrongSwan)** | **active/backup** | 서비스 EIP를 active 인스턴스에만 연결 + 온프렘 route를 active ENI로 지정. EventBridge가 Lambda를 1분 주기로 실행해 우선순위(`vpn-a` 100 > `vpn-b` 90) 높은 정상 인스턴스로 EIP·route 이전 |
| (온프렘 HAProxy) | active/backup | keepalived VRRP 단일 VIP — `infra-proxmox` 참고 |

> IPsec 터널은 peer IP 고정의 stateful 연결이라 **단일 EIP + Lambda 페일오버(active/backup)** 로 두고,
> L4 분산이 가능한 HAProxy 앞단은 **NLB로 active/active** 로 구성했다.

## Terraform 구성

기존 AWS 네트워크 위에 외부 진입 구간을 구성한다. 기존 `terraform/` root module은 state 호환을 위해 유지하고,
실제 HAProxy/NLB와 VPN 리소스는 각각 `terraform/haproxy`, `terraform/vpn` 하위 모듈로 분리했다.

- Terraform: `>= 1.15.3, < 1.16.0`
- VPC: `cloud-team1-vpc`
- Public Subnet: `...-public1-ap-northeast-2a`, `...-public2-ap-northeast-2b`
- Private Subnet: `...-private1-ap-northeast-2a`, `...-private2-ap-northeast-2b`
- NLB: 80 TCP Listener, 443 TLS Listener (cross-zone LB)
- EC2 HAProxy: Public Subnet에 2대(`haproxy-a`/`haproxy-b`)
- HTTP redirect: NLB 80 → AWS HAProxy 80에서 HTTPS 301 redirect
- TLS 종료: ACM 인증서를 NLB 443 TLS Listener에 연결, 복호화된 HTTP를 AWS HAProxy 8080으로 전달
- Backend 전달: AWS HAProxy → On-Prem HAProxy → Kubernetes Ingress는 HTTP 80만 사용
- HAProxy backend: `haproxy_backends` 변수로 VLAN20 On-Prem HAProxy VIP의 HTTP 80 지정
- VPN Server: ER605 IPsec initiator 연결을 받는 StrongSwan EC2 2대(`vpn-a`/`vpn-b`)와 서비스 EIP
- VPN Failover: EventBridge가 Lambda를 1분마다 실행해 정상 EC2 중 우선순위가 높은 인스턴스로 서비스 EIP와 On-Prem route를 이동
- VPN on-prem CIDR: 기본값 VLAN20 DMZ `172.17.32.0/24`(+ `192.168.36.0/24`)
- 기본 backend 예시는 `infra-proxmox/terraform/haproxy`의 `haproxy_vip` 값 `172.17.32.20`에 맞춰 둔다.

## 실행 방법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

또는 단계별 배포 스크립트를 사용할 수 있다.

```bash
cd terraform
./terraform-execute.sh
```

적용 전 `terraform.tfvars`에서 다음을 실제 값으로 변경한다.

- `haproxy_backends`의 `address` → 실제 VLAN20 On-Prem HAProxy VIP
- `nlb_tls_certificate_arn` → `ap-northeast-2` ACM 인증서 ARN
- `vpn_preshared_key` → 실제 ER605 Pre-shared Key
- ER605 Remote Gateway에는 Terraform output `vpn_server_public_ip`(VPN 서비스 EIP)를 설정

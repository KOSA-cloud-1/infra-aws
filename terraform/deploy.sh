#!/bin/bash
set -euo pipefail

echo "======================================"
echo "1단계: VPN Server 및 On-Prem route 적용"
echo "======================================"
terraform apply -target='module.vpn' -auto-approve

echo ""
echo "======================================"
echo "2단계: AWS HAProxy 및 NLB 생성"
echo "======================================"
terraform apply -target='module.haproxy' -auto-approve

echo ""
echo "======================================"
echo "3단계: 전체 Terraform 상태 동기화"
echo "======================================"
terraform apply -auto-approve

echo ""
echo "======================================"
echo "모든 AWS 진입 구간 리소스 생성 완료"
echo "======================================"

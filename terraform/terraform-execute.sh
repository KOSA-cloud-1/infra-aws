#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "[1/3] terraform init 시작"
echo "=================================================="
terraform init
echo "terraform init 완료"

sleep 5

echo "=================================================="
echo "[2/3] terraform plan 시작"
echo "=================================================="
terraform plan
echo "terraform plan 완료"

sleep 5

echo "=================================================="
echo "[3/3] deploy.sh 실행"
echo "=================================================="
chmod +x deploy.sh
./deploy.sh
echo "deploy.sh 실행 완료"

echo "=================================================="
echo "전체 작업 완료"
echo "=================================================="

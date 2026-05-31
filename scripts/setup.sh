#!/bin/bash
set -e

echo "=== 온디바이스 AI 보고서 시스템 설정 ==="

# 1. Ollama 실행 확인
echo ""
echo "[1/4] Ollama + Gemma E4B 확인..."
if ! command -v ollama &>/dev/null; then
  echo "  ❌ Ollama가 설치되어 있지 않습니다."
  echo "  → https://ollama.com 에서 설치 후 다시 실행하세요."
  exit 1
fi

if ! ollama list | grep -q "gemma3:4b"; then
  echo "  Gemma3 4B 모델 다운로드 중 (약 3GB)..."
  ollama pull gemma3:4b
fi
echo "  ✅ Ollama 준비 완료"

# 2. Docker 서비스 시작
echo ""
echo "[2/4] Docker 서비스 시작..."
docker compose up -d --build
echo "  ✅ Docker 서비스 시작됨"

# 3. PostgreSQL 준비 대기
echo ""
echo "[3/4] PostgreSQL 준비 대기..."
until docker compose exec postgres pg_isready -U agent -d agent_db &>/dev/null; do
  sleep 1
  printf "."
done
echo ""
echo "  ✅ PostgreSQL 준비 완료"

# 4. BGE-M3 헬스 체크
echo ""
echo "[4/4] BGE-M3 임베딩 서버 준비 대기 (최초 실행 시 모델 다운로드로 시간이 걸립니다)..."
for i in {1..30}; do
  if curl -sf http://localhost:8001/health &>/dev/null; then
    echo "  ✅ BGE-M3 서버 준비 완료"
    break
  fi
  sleep 5
  printf "."
done

echo ""
echo "=== 서비스 주소 ==="
echo "  n8n 워크플로우: http://localhost:5678  (admin / localpass)"
echo "  Keycloak 인증:  http://localhost:8080  (admin / localpass)"
echo "  BGE-M3 임베딩: http://localhost:8001"
echo "  앱 다운로드:    http://localhost:9000/download"
echo ""
echo "다음 단계: Keycloak에서 Realm 'agent-realm'을 설정하세요."
echo "  → http://localhost:8080 접속 후 새 Realm 생성"

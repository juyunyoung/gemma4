# 온디바이스 AI 업무 보고서 자동화 시스템

클라우드 없이 로컬(PC + 모바일)에서 완전히 동작하는 AI 기반 업무 보고서 자동화 시스템입니다.
음성으로 보고 내용을 말하면 AI가 자동으로 분류·정제하고, 결재 흐름까지 처리합니다.

---

## 주요 기능

- **음성 보고** — 온디바이스 STT(한국어)로 음성을 텍스트로 변환
- **AI 자동 분류** — Gemma E4B(로컬 LLM)가 발화 내용을 템플릿 항목별로 분류·정제
- **오프라인 동작** — 네트워크 없이 SQLite에 임시 저장, 연결 복구 후 자동 동기화
- **3단계 결재** — 작성자 → 팀장 → 부서장 승인 플로우
- **의미 검색** — BGE-M3 임베딩 + pgvector 기반 AI 시맨틱 검색
- **멀티플랫폼** — Android / iOS / macOS / Windows 단일 코드베이스(Flutter)

---

## 기술 스택

| 컴포넌트 | 역할 | 포트 |
|---|---|---|
| PostgreSQL + pgvector | 보고서 DB + 벡터 검색 | 5432 |
| n8n | 워크플로우 오케스트레이션 | 5678 |
| BGE-M3 (FastAPI) | 한국어 임베딩 (1024차원) | 8001 |
| Ollama + Gemma E4B | 로컬 LLM 추론 | 11434 |
| Keycloak | 인증/인가 (OIDC) | 8080 |
| Nginx | 앱 배포 서버 | 9000 |
| Flutter | 모바일/데스크톱 앱 | — |

> Ollama는 Docker 외부 호스트에서 직접 실행합니다 (M3 MacBook Air GPU 접근 제약).

---

## 시스템 아키텍처

```
[모바일 앱]
    │
    ├─ 온디바이스 STT (한국어)
    │       ↓
    ├─ Gemma E4B 템플릿 분류
    │   음성 원문 → { 인부출역현황, 재고현황, 작업진행현황, ... }
    │       ↓
    ├─ 사용자 검토 & 수정
    │       ↓
    └─ 제출 → n8n Webhook
                │
                ├─ BGE-M3 임베딩 생성 → pgvector 저장
                ├─ 일일 보고서 자동 생성 (Gemma, 매일 00:05)
                └─ 이상 항목 알림 (매일 18:00)

[PC 앱]
    └─ 결재 플로우 (팀장 → 부서장)
```

---

## 프로젝트 구조

```
gemma4/
├── docker-compose.yml          # 전체 서비스 구성
├── .env.example                # 환경변수 템플릿
├── infra/
│   ├── init.sql                # DB 스키마 + 초기 데이터
│   └── nginx.conf              # 앱 배포 서버 설정
├── services/
│   └── embedding/              # BGE-M3 FastAPI 서버
│       ├── main.py
│       ├── requirements.txt
│       └── Dockerfile
├── flutter-app/
│   ├── pubspec.yaml
│   └── lib/
│       ├── core/               # DB, 네트워크, STT, 동기화
│       ├── features/           # 화면별 기능
│       │   ├── auth/           # Keycloak OIDC 로그인
│       │   ├── report_create/  # 음성 보고서 작성
│       │   ├── report_view/    # 보고서 조회
│       │   ├── report_manage/  # 결재 처리 (PC)
│       │   ├── search/         # AI 의미 검색
│       │   └── admin/          # 관리자 패널
│       └── shared/             # 공통 위젯 (모바일/데스크톱 레이아웃)
└── scripts/
    ├── setup.sh                # 환경 구성 스크립트
    ├── deploy_app.sh           # 플랫폼별 빌드
    └── eval/
        ├── eval_dataset.json             # 분류 테스트 케이스
        └── eval_gemma_classification.py  # 정확도 평가 (목표 80%+)
```

---

## 시작하기

### 사전 요구사항

- macOS (Apple Silicon 권장)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Ollama](https://ollama.com)
- [Flutter SDK](https://flutter.dev) 3.x 이상

### 1. 환경변수 설정

```bash
cp .env.example .env
# .env 파일을 열어 비밀번호 설정
```

### 2. 인프라 실행

```bash
./scripts/setup.sh
```

스크립트가 자동으로:
- Gemma3 4B 모델 다운로드 (`ollama pull gemma3:4b`)
- Docker 서비스 6개 시작
- PostgreSQL 스키마 초기화
- BGE-M3 서버 준비 대기

### 3. Keycloak 설정

`http://localhost:8080` 접속 후:
1. 새 Realm 생성: `agent-realm`
2. Client 등록: `flutter-app` (Authorization Code + PKCE)
3. Client 등록: `n8n-service` (Client Credentials)
4. Roles 생성: `reporter`, `team_leader`, `department_head`, `admin`

### 4. Flutter 앱 실행

```bash
cd flutter-app
flutter pub get
flutter pub run build_runner build
flutter run \
  --dart-define=KEYCLOAK_ISSUER=http://localhost:8080/realms/agent-realm \
  --dart-define=N8N_BASE_URL=http://localhost:5678
```

---

## 서비스 접속 정보

| 서비스 | URL | 기본 계정 |
|---|---|---|
| n8n | http://localhost:5678 | `.env` 참조 |
| Keycloak | http://localhost:8080 | `.env` 참조 |
| BGE-M3 | http://localhost:8001/health | — |
| 앱 다운로드 | http://localhost:9000/download | — |

---

## 앱 빌드 & 배포

```bash
# Android APK
./scripts/deploy_app.sh android

# macOS
./scripts/deploy_app.sh macos

# iOS (Xcode Enterprise 서명 필요)
./scripts/deploy_app.sh ios

# Windows
./scripts/deploy_app.sh windows
```

---

## AI 분류 정확도 평가

```bash
# Ollama 실행 확인 후
python scripts/eval/eval_gemma_classification.py
```

목표: 80% 이상. 미달 시 `services/embedding/` 프롬프트 튜닝 후 재평가.

---

## 개발 로드맵

| Phase | 기간 | 내용 | 상태 |
|---|---|---|---|
| 1 — 인프라 | 4주 | Docker, DB, n8n, BGE-M3 | ✅ 완료 |
| 2 — 모바일 앱 | 4주 | Flutter, STT, 오프라인 동기화 | ✅ 완료 |
| 3 — AI 배치 | 3주 | 보고서 자동 생성, 의미 검색 | 🔲 진행 예정 |
| 4 — PC 앱 | 3주 | 결재 워크플로우, 하이브리드 검색 | 🔲 진행 예정 |
| 5 — 통합 테스트 | 2주 | E2E, 오프라인 내구성 | 🔲 진행 예정 |

---

## 보안 주의사항

- `.env` 파일은 절대 커밋하지 마세요 (`.gitignore` 처리됨)
- 프로덕션 환경에서는 Keycloak `start-dev` → `start` + TLS 설정 필요
- iOS 배포는 Apple Enterprise Developer Program ($299/년) 필요

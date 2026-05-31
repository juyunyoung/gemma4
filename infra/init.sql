-- pgvector 확장 활성화
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- 사용자 및 조직
-- ============================================================

CREATE TABLE users (
    id           SERIAL PRIMARY KEY,
    username     VARCHAR(100) UNIQUE NOT NULL,
    keycloak_id  UUID UNIQUE,
    role         VARCHAR(30) DEFAULT 'reporter',
    device_token TEXT,
    created_at   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE teams (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE team_members (
    id      SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    team_id INTEGER REFERENCES teams(id),
    role    VARCHAR(30) NOT NULL,
    UNIQUE(user_id, team_id)
);

-- ============================================================
-- 보고서 템플릿
-- ============================================================

CREATE TABLE report_templates (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    description   TEXT,
    fields        JSONB,
    display_order INTEGER,
    active        BOOLEAN DEFAULT true
);

CREATE TABLE team_template_configs (
    id           SERIAL PRIMARY KEY,
    team_id      INTEGER REFERENCES teams(id),
    user_id      INTEGER REFERENCES users(id),
    template_ids INTEGER[],
    updated_at   TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 보고서
-- ============================================================

CREATE TABLE reports (
    id             SERIAL PRIMARY KEY,
    report_date    DATE NOT NULL,
    author_id      INTEGER REFERENCES users(id),
    team_id        INTEGER REFERENCES teams(id),
    status         VARCHAR(20) DEFAULT 'draft',
    voice_raw_text TEXT,
    processed_text TEXT,
    items          JSONB,
    submitted_at   TIMESTAMP,
    created_at     TIMESTAMP DEFAULT NOW(),
    updated_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE report_embeddings (
    id         SERIAL PRIMARY KEY,
    report_id  INTEGER REFERENCES reports(id),
    chunk_text TEXT,
    embedding  VECTOR(1024),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON report_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================================
-- 자동 생성 보고서
-- ============================================================

CREATE TABLE generated_reports (
    id                SERIAL PRIMARY KEY,
    target_date       DATE NOT NULL,
    team_id           INTEGER REFERENCES teams(id),
    source_report_ids INTEGER[],
    summary           TEXT,
    comparison_data   JSONB,
    chart_data        JSONB,
    progress_table    JSONB,
    approved_by       INTEGER REFERENCES users(id),
    approved_at       TIMESTAMP,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 결재
-- ============================================================

CREATE TABLE approval_history (
    id          SERIAL PRIMARY KEY,
    report_id   INTEGER REFERENCES generated_reports(id),
    approver_id INTEGER REFERENCES users(id),
    action      VARCHAR(20),
    comment     TEXT,
    step        INTEGER,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 알림 & 감사 로그
-- ============================================================

CREATE TABLE notifications (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER REFERENCES users(id),
    type       VARCHAR(50),
    message    TEXT,
    is_read    BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE report_change_history (
    id         SERIAL PRIMARY KEY,
    report_id  INTEGER REFERENCES reports(id),
    changed_by INTEGER REFERENCES users(id),
    field_name VARCHAR(100),
    old_value  TEXT,
    new_value  TEXT,
    changed_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id          SERIAL PRIMARY KEY,
    actor_id    INTEGER REFERENCES users(id),
    action      VARCHAR(100),
    target_type VARCHAR(50),
    target_id   INTEGER,
    detail      JSONB,
    ip_address  VARCHAR(45),
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 초기 데이터
-- ============================================================

INSERT INTO teams (name) VALUES ('영업팀'), ('시공팀'), ('재무팀');

INSERT INTO report_templates (name, description, display_order) VALUES
  ('인부출역현황', '당일 인부 출역 인원 현황', 1),
  ('재고현황', '자재/장비 재고 현황', 2),
  ('작업진행현황', '공구별 작업 진행률', 3),
  ('장비가동율현황', '중장비 가동 상태', 4),
  ('전표처리현황', '당일 전표 처리 내역', 5);

-- 시공팀 기본 템플릿 설정
INSERT INTO team_template_configs (team_id, user_id, template_ids)
VALUES (2, NULL, ARRAY[1,2,3,4]);

-- 영업팀 기본 템플릿 설정
INSERT INTO team_template_configs (team_id, user_id, template_ids)
VALUES (1, NULL, ARRAY[5]);

-- 재무팀 기본 템플릿 설정
INSERT INTO team_template_configs (team_id, user_id, template_ids)
VALUES (3, NULL, ARRAY[5]);

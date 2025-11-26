# 데이터 모델 - Backend

## 개요
DuckDB 기반의 MyDogCare 데이터베이스 스키마

## 데이터베이스 테이블

### 1. dogs
강아지 프로필 정보를 저장합니다.

```sql
CREATE TABLE dogs (
    id UUID PRIMARY KEY,                    -- 강아지 고유 ID
    name VARCHAR NOT NULL,                   -- 강아지 이름
    breed VARCHAR,                           -- 품종
    photo_id VARCHAR,                        -- 사진 ID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 생성 시간
);
```

**컬럼 설명:**
- `id`: 강아지의 고유 식별자 (UUID)
- `name`: 강아지 이름 (필수)
- `breed`: 품종 정보 (선택)
- `photo_id`: 프로필 사진 참조 ID (선택)
- `created_at`: 레코드 생성 시간

### 2. dog_states
강아지의 실시간 상태 데이터를 시계열로 저장합니다.

```sql
CREATE TABLE dog_states (
    t TIMESTAMP NOT NULL,                    -- 타임스탬프
    device_id VARCHAR NOT NULL,               -- 디바이스 ID
    session_id VARCHAR NOT NULL,              -- 세션 ID
    dog_id UUID NOT NULL,                    -- 강아지 ID (dogs 테이블 FK)
    
    -- 바운딩 박스 (정규화된 좌표)
    bbox_cx FLOAT,                           -- 중심 X 좌표 (0-1)
    bbox_cy FLOAT,                           -- 중심 Y 좌표 (0-1)
    bbox_w FLOAT,                            -- 너비 (0-1)
    bbox_h FLOAT,                            -- 높이 (0-1)
    
    -- 운동 정보
    speed_px FLOAT,                          -- 픽셀 속도
    direction_rad FLOAT,                     -- 방향 (라디안)
    
    -- 행동 분석
    behavior_probs JSON,                      -- 행동 확률 분포
    stress_proxy FLOAT,                       -- 스트레스 지수 (0-1)
    
    -- 환경 데이터
    environment_lux FLOAT,                   -- 조도
    environment_db FLOAT,                     -- 소음 수준 (데시벨)
    
    -- VLM 분석 결과
    vlm_action VARCHAR,                       -- 행동 (예: "sleeping", "running")
    vlm_emotion VARCHAR,                     -- 감정 (예: "happy", "relaxed")
    vlm_posture VARCHAR,                    -- 자세 (예: "lying_side", "sitting")
    vlm_health VARCHAR,                      -- 건강 상태 (예: "limping", "none")
    vlm_notes VARCHAR                         -- 상세 관찰 노트
);
```

**behavior_probs JSON 구조:**
```json
{
  "play": 0.8,        -- 놀이 확률
  "rest": 0.1,        -- 휴식 확률
  "chase": 0.05,      -- 추격 확률
  "avoid": 0.02,      -- 회피 확률
  "freeze": 0.01,     -- 멈춤 확률
  "face_off": 0.02    -- 대면 확률
}
```

### 3. pair_relations
강아지 간의 관계 데이터를 저장합니다.

```sql
CREATE TABLE pair_relations (
    t TIMESTAMP NOT NULL,                    -- 타임스탬프
    device_id VARCHAR NOT NULL,               -- 디바이스 ID
    session_id VARCHAR NOT NULL,              -- 세션 ID
    dog_i_id UUID NOT NULL,                  -- 첫 번째 강아지 ID
    dog_j_id UUID NOT NULL,                  -- 두 번째 강아지 ID
    
    -- 관계 지표
    distance_norm FLOAT,                     -- 정규화된 거리
    affinity_score FLOAT,                    -- 친밀도 점수
    tension_score FLOAT,                     -- 긴장도 점수
    interaction_tags VARCHAR[]                -- 상호작용 태그 배열
);
```

**interaction_tags 배열 예시:**
```sql
['playing', 'fighting', 'grooming', 'ignoring']
```

## 데이터 흐름

### 1. 데이터 수집 파이프라인
```
iOS 앱 → /events/batch → dog_states 테이블
                    → pair_relations 테이블
```

### 2. AI 챗봇 쿼리 파이프라인
```
사용자 질의 → /chat → SQL 변환 → DuckDB 쿼리 → 분석 결과
```

## 쿼리 예시

### 1. 특정 강아지의 최근 활동
```sql
SELECT 
    t,
    json_extract(behavior_probs, '$.play') as play_prob,
    stress_proxy,
    vlm_action
FROM dog_states 
WHERE dog_id = 'uuid-dog-1' 
  AND t > now() - INTERVAL '1 hour'
ORDER BY t DESC;
```

### 2. 강아지 간 상호작용 빈도
```sql
SELECT 
    dog_i_id,
    dog_j_id,
    COUNT(*) as interaction_count,
    AVG(affinity_score) as avg_affinity,
    AVG(tension_score) as avg_tension
FROM pair_relations 
WHERE t > now() - INTERVAL '24 hours'
GROUP BY dog_i_id, dog_j_id;
```

### 3. 스트레스 레벨 분석
```sql
SELECT 
    DATE_TRUNC('hour', t) as hour,
    AVG(stress_proxy) as avg_stress,
    MAX(stress_proxy) as max_stress
FROM dog_states 
WHERE dog_id = 'uuid-dog-1'
  AND t > now() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;
```

## 인덱스 전략

### 권장 인덱스
```sql
-- 시계열 쿼리 최적화
CREATE INDEX idx_dog_states_time_dog ON dog_states(t, dog_id);

-- 디바이스/세션 기반 쿼리
CREATE INDEX idx_dog_states_device_session ON dog_states(device_id, session_id, t);

-- 관계 쿼리 최적화
CREATE INDEX idx_pair_relations_time_dogs ON pair_relations(t, dog_i_id, dog_j_id);

-- 강아지 기본 조회
CREATE INDEX idx_dogs_name ON dogs(name);
```

## 데이터 보존 정책

### 권장 보존 기간
- **실시간 상태 데이터**: 30일 (이후 집계 데이터로 보관)
- **관계 데이터**: 90일 (장기 패턴 분석용)
- **강아지 프로필**: 영구 보존

### 집계 테이블 (향후 구현)
```sql
-- 일별 활동 집계
CREATE TABLE daily_activity_summary (
    date DATE,
    dog_id UUID,
    total_play_minutes FLOAT,
    avg_stress_level FLOAT,
    interaction_count INTEGER
);
```

## 데이터 무결성

### 제약 조건
- `dog_states.dog_id`는 `dogs.id`를 참조해야 함 (FK)
- 모든 타임스탬프는 유효한 ISO 8601 형식
- `behavior_probs`는 유효한 JSON 객체
- 정규화된 좌표는 0-1 범위

### 데이터 검증
- 속도 값은 0 이상
- 스트레스 지수는 0-1 범위
- 방향은 0-2π 범위 (라디안)
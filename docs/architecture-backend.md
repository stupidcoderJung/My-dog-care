# 아키텍처 문서 - Backend

## 개요
FastAPI 기반 MyDogCare 백엔드 서비스의 마이크로서비스 아키텍처

## 시스템 아키텍처

### 컴포넌트 다이어그램
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App      │    │   Web Client   │    │   Other Apps   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │ HTTP/JSON            │ HTTP/JSON            │ HTTP/JSON
          ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│                FastAPI Application                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │ Events API  │  │ Dogs API    │  │ Chat API    │   │
│  │ /events     │  │ /dogs       │  │ /chat       │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────────┘
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│                  DuckDB Database                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   dogs      │  │ dog_states  │  │pair_relations│   │
│  │             │  │             │  │             │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                External Services                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │ NVIDIA API  │  │ OpenAI API  │  │ Google API  │   │
│  │ (Qwen LLM)  │  │ (GPT)       │  │ (Gemini)    │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 핵심 컴포넌트

### 1. FastAPI 애플리케이션
- **진입점**: `main.py`
- **수명 주기**: `lifespan` 컨텍스트 매니저
- **라우터**: 모듈화된 API 라우터 구조

### 2. API 라우터
| 라우터 | 경로 | 기능 | 상태 |
|--------|------|------|------|
| Events | `/events` | 상태 패킷 수신 | ✅ 구현됨 |
| Dogs | `/dogs` | 강아지 관리 | ✅ 구현됨 |
| Chat | `/chat` | AI 채팅 | ✅ 구현됨 |

### 3. 데이터베이스 계층
- **엔진**: DuckDB (임베디드 OLAP)
- **연결**: 단일 연결 객체
- **스키마**: 시계열 데이터 최적화

### 4. AI 통합 계층
- **LLM**: Qwen3-Next-80B (NVIDIA API)
- **도구**: SQL 실행 도구 등록
- **에이전트**: 자연어 → SQL 변환

## 데이터 모델 아키텍처

### 1. Pydantic 모델
```python
# 요청/응답 모델
class DeviceStatePacket(BaseModel):
    timestamp: str
    deviceId: str
    sessionId: str
    dogs: List[DogState]
    relations: Optional[List[PairRelation]]
    environment: Optional[EnvironmentData]

class ChatRequest(BaseModel):
    query: str

class ChatResponse(BaseModel):
    answer: str
    sql: Optional[str]
    data: Optional[List[Dict]]
```

### 2. 데이터베이스 스키마
```sql
-- 강아지 프로필
CREATE TABLE dogs (
    id UUID PRIMARY KEY,
    name VARCHAR NOT NULL,
    breed VARCHAR,
    photo_id VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 시계열 상태 데이터
CREATE TABLE dog_states (
    t TIMESTAMP NOT NULL,
    device_id VARCHAR NOT NULL,
    session_id VARCHAR NOT NULL,
    dog_id UUID NOT NULL,
    bbox_cx FLOAT, bbox_cy FLOAT, bbox_w FLOAT, bbox_h FLOAT,
    speed_px FLOAT, direction_rad FLOAT,
    behavior_probs JSON,
    stress_proxy FLOAT,
    environment_lux FLOAT, environment_db FLOAT,
    vlm_action VARCHAR, vlm_emotion VARCHAR,
    vlm_posture VARCHAR, vlm_health VARCHAR, vlm_notes VARCHAR
);

-- 강아지 관계 데이터
CREATE TABLE pair_relations (
    t TIMESTAMP NOT NULL,
    device_id VARCHAR NOT NULL,
    session_id VARCHAR NOT NULL,
    dog_i_id UUID NOT NULL,
    dog_j_id UUID NOT NULL,
    distance_norm FLOAT,
    affinity_score FLOAT,
    tension_score FLOAT,
    interaction_tags VARCHAR[]
);
```

## 비즈니스 로직 아키텍처

### 1. 이벤트 수신 파이프라인
```
HTTP POST → Pydantic 검증 → 배치 처리 → DuckDB 삽입
```

### 2. AI 채팅 파이프라인
```
사용자 질의 → LLM → SQL 생성 → DuckDB 쿼리 → 결과 분석 → 응답
```

### 3. 데이터 처리 흐름
```
실시간 데이터 → 배치 수신 → 대량 삽입 → 시계열 저장
```

## 기술 스택 상세

### 핵심 프레임워크
| 기술 | 버전 | 용도 |
|------|------|------|
| Python | 3.13+ | 개발 언어 |
| FastAPI | 0.122.0+ | 웹 프레임워크 |
| Pydantic | 2.12.4+ | 데이터 검증 |
| Uvicorn | 0.38.0+ | ASGI 서버 |

### 데이터베이스
| 기술 | 버전 | 용도 |
|------|------|------|
| DuckDB | 1.4.2+ | 임베디드 OLAP |
| SQL | 표준 | 쿼리 언어 |

### AI/ML 통합
| 기술 | 버전 | 용도 |
|------|------|------|
| Qwen Agent | 0.0.31+ | LLM 에이전트 |
| NVIDIA API | - | LLM 추론 |
| OpenAI | 2.8.1+ | GPT 통합 |
| Google AI | 0.8.5+ | Gemini 통합 |

## 성능 아키텍처

### 1. 데이터베이스 최적화
- **인덱싱**: 시계열 데이터 쿼리 최적화
- **배치 처리**: 대량 데이터 대량 삽입
- **압축**: 오래된 데이터 압축 저장

### 2. API 성능
- **비동기 처리**: FastAPI 비동기 엔드포인트
- **요청 검증**: Pydantic 기반 데이터 검증
- **에러 처리**: 구조화된 에러 응답

### 3. 메모리 관리
- **연결 풀**: 데이터베이스 연결 재사용
- **배치 크기**: 메모리 사용량 최적화
- **가비지 컬렉션**: 주기적 데이터 정리

## 보안 아키텍처

### 1. 현재 상태
- **인증**: 없음
- **권한 부여**: 없음
- **데이터 암호화**: 없음

### 2. 필요한 보안 조치
- **API 인증**: JWT 또는 API 키
- **HTTPS**: TLS/SSL 암호화
- **입력 검증**: SQL 인젝션 방지
- **속도 제한**: API 호출 제한

## 배포 아키텍처

### 1. 현재 개발 환경
```
로컬 개발 머신
├── Python 3.13+ 가상환경
├── DuckDB 파일 기반 데이터베이스
└── Uvicorn 개발 서버
```

### 2. 프로덕션 환경 계획
```
클라우드 인프라
├── 컨테이너화된 애플리케이션
├── 외부 데이터베이스 (TimescaleDB)
├── 로드 밸런서
└── 모니터링 시스템
```

## 확장성 아키텍처

### 1. 수평적 확장
- **로드 밸런싱**: 다중 인스턴스
- **데이터베이스 분할**: 시계열 데이터 분할
- **캐싱**: Redis 캐시 계층

### 2. 수직적 확장
- **리소스 확장**: CPU/메모리 증설
- **데이터베이스 튜닝**: 쿼리 성능 최적화
- **인덱스 전략**: 검색 성능 향상

## 모니터링 아키텍처

### 1. 로깅
- **구조화된 로깅**: JSON 형식
- **로그 레벨**: INFO, WARNING, ERROR
- **로그 회전**: 파일 크기 기반

### 2. 메트릭
- **API 성능**: 응답 시간, 처리량
- **데이터베이스**: 쿼리 성능, 연결 수
- **시스템**: CPU, 메모리, 디스크

## 문제 해결 아키텍처

### 1. 장애 처리
- **재시도 로직**: 네트워크 장애 대응
- **서킷 브레이커**: 연속적인 장애 방지
- **폴백**: 대체 서비스 전환

### 2. 데이터 일관성
- **트랜잭션**: 데이터 무결성 보장
- **검증**: 데이터 정확성 확인
- **복구**: 손상된 데이터 복구

## 향후 개선 방향

### 1. 단기 개선
- **API 인증**: JWT 기반 인증 구현
- **속도 제한**: API 호출 제한
- **문서화**: OpenAPI 자동화

### 2. 중기 개선
- **마이크로서비스**: 서비스 분리
- **이벤트 버스**: 비동기 통신
- **데이터 파이프라인**: ETL 프로세스

### 3. 장기 개선
- **분산 시스템**: 다중 지역 배포
- **실시간 분석**: 스트림 처리
- **ML Ops**: 모델 배포 자동화
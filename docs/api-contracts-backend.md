# API 계약 - Backend

## 개요
FastAPI 기반의 MyDogCare 백엔드 API 계약 문서

## 기본 정보
- **기본 URL**: `http://localhost:8001`
- **API 버전**: v1
- **인증**: 현재 없음 (향후 추가 예정)

## 엔드포인트

### 1. Events API (`/events`)

#### POST /events/batch
디바이스 상태 패킷을 대량으로 수신합니다.

**요청:**
```json
{
  "packets": [
    {
      "timestamp": "2025-11-26T23:14:08+09:00",
      "deviceId": "device-001",
      "sessionId": "session-abc123",
      "dogs": [
        {
          "dogId": "uuid-dog-1",
          "bboxNorm": {"cx": 0.5, "cy": 0.5, "w": 0.2, "h": 0.3},
          "speedPx": 10.5,
          "directionRad": 1.57,
          "behaviorProbs": {"play": 0.8, "rest": 0.1, "chase": 0.05},
          "stressProxy": 0.2,
          "vlmAction": "sleeping",
          "vlmEmotion": "relaxed",
          "vlmPosture": "lying_side",
          "vlmHealth": "none",
          "vlmNotes": "Sleeping peacefully"
        }
      ],
      "relations": [
        {
          "dogIId": "uuid-dog-1",
          "dogJId": "uuid-dog-2", 
          "distanceNorm": 0.8,
          "affinityScore": 0.7,
          "tensionScore": 0.1,
          "interactionTags": ["playing"]
        }
      ],
      "environment": {
        "lux": 500.0,
        "decibel": 45.0
      }
    }
  ]
}
```

**응답:**
```json
{
  "status": "ok",
  "inserted_packets": 1
}
```

### 2. Dogs API (`/dogs`)

#### POST /dogs
새로운 강아지 프로필을 생성합니다.

**요청:**
```json
{
  "name": "Buddy",
  "breed": "Golden Retriever",
  "photo_id": "photo-uuid-123"
}
```

**응답:**
```json
{
  "id": "uuid-dog-1",
  "name": "Buddy", 
  "breed": "Golden Retriever",
  "photo_id": "photo-uuid-123",
  "created_at": "2025-11-26T23:14:08+09:00"
}
```

#### GET /dogs
등록된 모든 강아지 목록을 조회합니다.

**응답:**
```json
[
  {
    "id": "uuid-dog-1",
    "name": "Buddy",
    "breed": "Golden Retriever", 
    "photo_id": "photo-uuid-123",
    "created_at": "2025-11-26T23:14:08+09:00"
  }
]
```

### 3. Chat API (`/chat`)

#### POST /chat
자연어 질의에 대한 AI 분석 결과를 반환합니다.

**요청:**
```json
{
  "query": "오늘 버디가 얼마나 놀았어?"
}
```

**응답:**
```json
{
  "answer": "버디는 오늘 약 2시간 동안 활발하게 놀았습니다. 주로 오후에 활동량이 많았으며...",
  "sql": "SELECT COUNT(*) FROM dog_states WHERE dog_id = 'uuid-dog-1' AND json_extract(behavior_probs, '$.play') > 0.7 AND t > now() - INTERVAL '1 day'",
  "data": [
    {"count": 120}
  ]
}
```

## 데이터 모델

### DeviceStatePacket
```typescript
interface DeviceStatePacket {
  timestamp: string;        // ISO 8601
  deviceId: string;         // 고유 디바이스 ID
  sessionId: string;        // 세션 식별자
  dogs: DogState[];          // 강아지 상태 배열
  relations?: PairRelation[]; // 강아지 간 관계
  environment?: {            // 환경 데이터
    lux: number;             // 조도
    decibel: number;         // 소음 수준
  };
}
```

### DogState
```typescript
interface DogState {
  dogId: string;                    // 강아지 UUID
  bboxNorm: {                       // 정규화된 바운딩 박스
    cx: number;                     // 중심 X (0-1)
    cy: number;                     // 중심 Y (0-1) 
    w: number;                      // 너비 (0-1)
    h: number;                      // 높이 (0-1)
  };
  speedPx: number;                   // 픽셀 속도
  directionRad: number;              // 방향 (라디안)
  behaviorProbs?: {                  // 행동 확률
    [key: string]: number;           // play: 0.8, rest: 0.1...
  };
  stressProxy?: number;               // 스트레스 지수 (0-1)
  vlmAction?: string;                // VLM 분석 액션
  vlmEmotion?: string;              // VLM 분석 감정
  vlmPosture?: string;             // VLM 분석 자세
  vlmHealth?: string;              // VLM 분석 건강 상태
  vlmNotes?: string;                // VLM 상세 관찰
}
```

### PairRelation
```typescript
interface PairRelation {
  dogIId: string;           // 첫 번째 강아지 ID
  dogJId: string;           // 두 번째 강아지 ID
  distanceNorm: number;      // 정규화된 거리
  affinityScore: number;     // 친밀도 점수
  tensionScore: number;      // 긴장도 점수
  interactionTags: string[]; // 상호작용 태그
}
```

## 에러 처리

### 표준 에러 응답
```json
{
  "detail": "에러 메시지"
}
```

### 상태 코드
- `200`: 성공
- `422`: 요청 데이터 검증 실패
- `500`: 서버 내부 에러

## 속도 제한
현재 구현되지 않음 (향후 추가 예정)

## 인증
현재 인증 없음 (향후 JWT/Clerk 인증 추가 예정)
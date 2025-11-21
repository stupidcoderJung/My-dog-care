# AI 통합 및 데이터 파이프라인 비전

## 🎯 프로젝트 비전
이 프로젝트의 목표는 **포괄적인 AI 반려견 케어 어시스턴트**를 구축하는 것입니다.
1.  **데이터 소스 ("On Air")**: 앱은 "On Air" 기능을 통해 실시간 데이터(비디오 스트림, 행동 분석, 활동 로그)를 캡처합니다.
2.  **데이터 수집 (Ingestion)**: 이 데이터는 서버로 스트리밍되어 반려견의 삶에 대한 역사적 기록으로 저장됩니다.
3.  **AI 인터페이스 ("Chat")**: 사용자는 AI Chat을 통해 이 데이터와 상호 작용합니다. AI는 **데이터 분석가이자 수의사** 역할을 하며, *"오늘 벨라가 얼마나 잤어?"* 또는 *"이번 주 활동 그래프를 보여줘"*와 같은 질문에 답할 수 있습니다.

## 🏗️ 아키텍처 계획

이를 달성하기 위해 원시 데이터를 LLM과 연결하는 백엔드 인프라가 필요합니다.

### 1. 데이터 파이프라인 ("눈")
*   **클라이언트 (iOS)**: `OnAirView`는 비디오 프레임(Vision 프레임워크 또는 로컬 VLM 사용)을 분석하고 구조화된 이벤트를 추출합니다.
    *   *데이터 예시*: `{ "timestamp": "2023-10-27T10:00:00Z", "event": "sleeping", "confidence": 0.95 }`
*   **수집 API**: 이러한 로그를 실시간으로 수신하기 위한 경량 서버 엔드포인트(예: `POST /api/events`).
*   **데이터베이스**:
    *   타임스탬프가 있는 활동 로그를 저장하는 데는 **시계열 DB**(예: InfluxDB, TimescaleDB) 또는 **NoSQL**(Firestore, MongoDB)이 가장 적합합니다.

### 2. AI 서비스 ("두뇌")
이것은 구축해야 할 핵심 서비스입니다. Chat UI와 데이터베이스 사이에 위치합니다.

#### 추천 스택: **Python Backend (FastAPI)**
Python은 AI/데이터 엔지니어링의 표준입니다.
*   **프레임워크**: FastAPI (고성능, API 구축 용이).
*   **LLM 오케스트레이션**: LangChain 또는 LlamaIndex.
*   **모델**: GPT-4o 또는 Gemini 1.5 Pro (강력한 추론 능력과 큰 컨텍스트 윈도우를 가진 모델).

### 3. "실행 가능한 코드" 워크플로우
그래프를 보여주기 위해 AI는 숫자를 환각(hallucinate)해서는 안 됩니다. **실제 데이터를 쿼리**해야 합니다.

1.  **사용자 쿼리**: "지난 7일간의 활동 그래프를 보여줘."
2.  **함수 호출 (Function Calling - 마법의 핵심)**:
    *   LLM은 데이터가 필요함을 인식하고 정의된 도구를 호출합니다: `get_activity_stats(days=7)`.
    *   백엔드는 이 SQL/데이터베이스 쿼리를 실행합니다.
    *   **결과**: JSON 데이터 반환 `[{day: "Mon", active_hours: 4}, ...]`.
3.  **코드 생성 / 시각화**:
    *   LLM은 JSON을 받습니다.
    *   이 실제 데이터로 채워진 **HTML/Chart.js 코드**(우리가 `ChatView`에 구현한 것)를 생성합니다.
    *   **응답**: iOS 앱은 HTML 문자열을 수신하고 `GraphWebView`에서 렌더링합니다.

## 🧠 전문가 VLM 전략 및 데이터 스키마

반려견을 진정으로 이해하려면 단순한 "먹기/자기" 라벨을 넘어서야 합니다. 우리는 VLM 프롬프트 엔지니어링에 **다중 전문가 접근 방식(Multi-Expert Approach)**을 활용할 것입니다.

### A. 비전 모델 전문가 ("관찰자")
건강과 기분을 나타내는 세밀한 시각적 세부 정보를 추출해야 합니다.
*   **프롬프트 추가 사항**:
    *   **자세 (Posture)**: `standing`(서기), `sitting`(앉기), `lying_side`(옆으로 눕기), `lying_belly`(배 깔고 눕기), `curled`(웅크리기), `sploot`(다리 뻗고 엎드리기).
    *   **감정 지표 (Emotional Indicators)**: `tail_wagging`(꼬리 흔들기), `tail_tucked`(꼬리 말기), `ears_erect`(귀 세우기), `ears_flat`(귀 젖히기), `panting`(헉헉거림), `yawning`(하품), `whale_eye`(흰자위 보임).
    *   **건강 신호 (Health Signals)**: `limping`(절뚝거림), `scratching_excessive`(과도한 긁기), `shaking`(떨림), `vomiting`(구토), `head_tilt`(고개 갸웃).
    *   **컨텍스트 (Context)**: `near_food_bowl`(밥그릇 근처), `near_door`(문 근처), `on_bed`(침대 위), `on_floor`(바닥 위).

### B. 시계열 데이터베이스 전문가 ("역사가")
시간적 맥락 없는 데이터는 쓸모가 없습니다.
*   **저장 전략**:
    *   **InfluxDB / TimescaleDB**: 고빈도 이벤트 저장 (초당 1 이벤트).
    *   **집계 (Aggregation)**: 장기 추세 분석을 위해 데이터를 "5분 버킷" 등으로 다운샘플링 (예: "시간당 평균 활동 수준").
    *   **이상 탐지 (Anomaly Detection)**: 통계적 방법(Z-score)을 사용하여 편차 감지. *예: "벨라는 보통 14시간을 자는데, 오늘은 18시간을 잤습니다."*

### C. 벡터 데이터베이스 전문가 ("기억")
정성적 데이터("메모" 및 "설명")를 위한 것입니다.
*   **기술**: **FAISS** 또는 **Pinecone**.
*   **사용법**: `notes` 필드(예: "벨라가 슬퍼 보이고 문을 쳐다보고 있음")를 임베딩합니다.
*   **쿼리**: 사용자가 "요즘 벨라가 외로워 보였어?"라고 물으면, 시스템은 벡터 공간에서 의미적으로 유사한 과거 이벤트를 검색합니다.

### D. 비즈니스 모델 전문가 ("전략가")
데이터를 가치로 전환합니다.
*   **건강 알림**: "오늘 과도한 긁기 5회 감지됨" -> **푸시 알림**: "벼룩/알레르기 확인 필요."
*   **소모품**: "물그릇 비움" 반복 감지 -> **추천**: "자동 급수기 구매 추천."
*   **수의사 리포트**: "30일 활동 및 증상 로그 내보내기" -> 수의사 방문을 위한 **프리미엄 기능**.

## 📝 향상된 JSON 스키마 (목표)
VLM은 다음과 같은 더 풍부한 구조를 출력해야 합니다:

```json
{
  "timestamp": "ISO8601",
  "subject": {
    "name": "Bella",
    "confidence": 0.98
  },
  "behavior": {
    "primary_action": "rest",
    "posture": "lying_side",
    "intensity": "low"
  },
  "health": {
    "symptom": "none", // 또는 "limping"(절뚝거림), "scratching"(긁기)
    "severity": 0
  },
  "emotion": {
    "mood": "relaxed", // 꼬리/귀에서 추론
    "indicators": ["eyes_closed", "breathing_slow"]
  },
  "context": {
    "location": "living_room_bed",
    "objects_nearby": ["toy_bone"]
  },
  "notes": "Bella is sleeping deeply on her side, occasional twitching (dreaming)."
}
```

## 🚀 구현 로드맵

### 1단계: 서버 설정 (MVP)
- [ ] 간단한 Python FastAPI 서버 설정.
- [ ] "On Air" 이벤트를 저장할 데이터베이스(예: Supabase/PostgreSQL) 생성.
- [ ] iOS 앱이 데이터를 업로드할 API 엔드포인트 `POST /events` 생성.

### 2단계: AI 에이전트 설정
- [ ] Python 서버에 OpenAI 또는 Gemini API 통합.
- [ ] LLM을 위한 **도구(Tools)** 정의 (예: `query_database`).
- [ ] 사용자 텍스트를 받아 AI 응답(텍스트 또는 그래프 HTML)을 반환하는 `/chat` 엔드포인트 구현.

### 3단계: 연결
- [ ] iOS 앱의 `ChatService.swift`를 Mock 서비스 대신 실제 Python 백엔드에 연결.

## 💡 구축(Build) vs 구매(Buy)?
*   **구축 (권장)**: **FastAPI + LangChain + OpenAI/Gemini**를 사용하면 데이터와 "그래프 생성" 로직에 대한 완전한 제어권을 가질 수 있습니다. "실행 가능한 코드" 요구 사항에 가장 유연합니다.
*   **구매 (관리형)**: **Firebase Genkit** 또는 **Supabase Edge Functions** 같은 플랫폼은 인프라를 단순화할 수 있지만, 전용 Python 백엔드에 비해 복잡한 "코드 인터프리터" 스타일의 기능을 구현하기 더 어려울 수 있습니다.

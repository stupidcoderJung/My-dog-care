# 📘 Master Implementation Guide: MyDogCare

이 문서는 프로젝트의 **A to Z**를 다루는 마스터 가이드입니다. 각 단계는 논리적으로 연결되어 있으며, 앞 단계가 완료되어야 다음 단계로 넘어갈 수 있습니다.

---

## 🚨 Priority 0: On Air Continuous Loop (Real-time Foundation) ✅
**목표**: "On Air" 기능이 단발성 실행이 아닌, 활성화 시 계속해서 루프를 돌며 분석하도록 만듭니다.

### 0-1. Continuous Analysis Loop ✅
- [x] **[TASK] 루프 로직 구현 (`Views/OnAirView.swift`)**
    - [x] **Toggle UI**: "Start Analysis" / "Stop Analysis" 버튼 구현.
    - [x] **State Management**: `isAnalyzing` 상태 변수 추가.
    - [x] **Loop Logic**:
        - `isAnalyzing`이 `true`일 때 `VisionClient.analyzeStream` 호출.
        - 분석 완료 후 결과 처리 (로그 저장 등).
        - 1초 딜레이 후 재귀적으로(또는 Timer로) 다시 호출.
        - `isAnalyzing`이 `false`가 되면 루프 중단.
    - [x] **Visual Indicator**: "LIVE" 배지 표시 추가.
    - [x] **Error Handling**: API 오류 시에도 루프 중단되지 않도록 구현.
    - [x] **Memory Management**: `onDisappear`에서 루프 자동 정지.

---

## 🏁 Phase 1: Local Foundation (앱 내실 다지기)
**목표**: 서버 없이도 "똑똑한 비전"과 "쓸모 있는 캘린더"가 동작해야 합니다.

### 1-1. Vision Intelligence (The Eyes)
Vision 모델이 "멍청한 설명" 대신 "구조화된 데이터"를 뱉게 만듭니다.
- [ ] **[TASK] 프롬프트 고도화 (`Services/ModelRegistry.swift`)**
    - [ ] `analyzeStream` 함수 내 `systemPrompt` 교체.
    - [ ] **Role**: "You are a veterinary behaviorist AI."
    - [ ] **Instruction**: "Analyze the image stream and output a SINGLE JSON object."
    - [ ] **Output Schema (Strict)**:
      ```json
      {
        "timestamp": "YYYY-MM-DDTHH:mm:ssZ",
        "dogs": [
          {
            "name": "Bella",
            "confidence": 0.98,
            "bbox": [0.1, 0.2, 0.5, 0.6], // (x, y, w, h)
            "posture": "lying_side", // standing, sitting, lying_belly, curled, sploot
            "action": "sleeping", // eating, drinking, playing, walking, grooming
            "emotion": "relaxed", // tail_wagging, ears_flat, panting, whale_eye
            "health_signals": ["none"] // limping, scratching, vomiting, shaking
          }
        ],
        "environment": {
          "location": "living_room",
          "objects": ["water_bowl_empty", "toy_bone"]
        }
      }
      ```
- [ ] **[TASK] 데이터 파싱 로직 구현**
    - [ ] `struct VisionResponse: Codable` 정의.
    - [ ] JSON 파싱 실패 시 재시도 로직(Retry) 추가 (최대 1회).

### 1-2. Care Calendar (The Body)
사용자가 수동으로 기록하는 데이터는 AI 판단의 근거가 됩니다.
- [ ] **[TASK] 로컬 DB 설계 (`Models/CareEvent.swift`)**
    - [ ] **Library**: `SwiftData` (@Model)
    - [ ] **Schema**:
        - `id: UUID`
        - `dogId: UUID` (나중에 서버 동기화 시 필요)
        - `date: Date`
        - `category: Enum` (vet, vaccine, weight, grooming, medication, symptom)
        - `title: String`
        - `value: Double?` (체중 kg, 체온 등)
        - `notes: String?`
        - `isSynced: Bool` (서버 동기화 여부)
- [ ] **[TASK] 캘린더 UI 구현 (`Views/CareCalendarView.swift`)**
    - [ ] **Library**: `FSCalendar` (UIKit Wrapper) 또는 `LazyVGrid` (Native).
    - [ ] **Feature**:
        - 월별 달력 보기.
        - 날짜 선택 시 하단에 `List`로 이벤트 표시.
        - 우측 하단 `FloatingButton` -> `AddCareEventSheet` 호출.

---

## 🌉 Phase 2: Backend Infrastructure (서버 & 동기화)
**목표**: "내 폰"과 "공기계"가 데이터를 공유하고, "On Air" 데이터가 중앙으로 모입니다.

### 2-1. Server Setup (The Spine)
- [ ] **[TASK] 프로젝트 초기화**
    - [ ] `mkdir backend && cd backend`
    - [ ] `poetry init` or `pip install fastapi uvicorn sqlalchemy psycopg2-binary`
    - [ ] **Structure**:
        ```text
        backend/
        ├── main.py          # App Entry
        ├── database.py      # DB Connection
        ├── models.py        # SQLAlchemy Models
        ├── schemas.py       # Pydantic Models
        ├── routers/
        │   ├── auth.py      # Clerk Auth
        │   ├── dogs.py      # Dog Sync
        │   ├── events.py    # On Air Logs
        │   └── care.py      # Calendar Logs
        └── agent/           # AI Logic
        ```

### 2-2. Identity & Dog Sync (The Soul)
- [ ] **[TASK] DB 모델링 (`backend/models.py`)**
    - [ ] **User**: `id` (Clerk ID, PK), `email`, `created_at`
    - [ ] **Dog**: `id` (PK), `owner_id` (FK -> User), `name`, `breed`, `birthdate`, `image_url`
- [ ] **[TASK] API 구현 (`backend/routers/dogs.py`)**
    - [ ] `POST /dogs`: 강아지 등록 (이미지 업로드 포함).
    - [ ] `GET /dogs`: 내 강아지 목록 조회 (Header의 Token으로 owner_id 식별).
- [ ] **[TASK] iOS 연동 (`Services/DogSyncService.swift`)**
    - [ ] 앱 시작 시 `GET /dogs` 호출 -> 로컬 SwiftData와 비교 -> 없는 강아지 추가 (Down-sync).
    - [ ] 강아지 추가 시 `POST /dogs` 호출 (Up-sync).

### 2-3. Event Ingestion (The Nerves)
- [ ] **[TASK] DB 모델링 (`backend/models.py`)**
    - [ ] **EventLog**: `id`, `dog_id` (FK), `timestamp`, `raw_json` (JSONB Type recommended).
- [ ] **[TASK] API 구현 (`backend/routers/events.py`)**
    - [ ] `POST /events`: Vision JSON 수신 -> DB 저장.
    - [ ] **Optimization**: 1초에 1번씩 쏘면 DB 터짐 -> iOS에서 10초 단위로 묶어서(Batch) 전송.
- [ ] **[TASK] iOS 연동 (`Views/OnAirView.swift`)**
    - [ ] Vision 분석 성공 시 -> `Buffer`에 저장.
    - [ ] `Timer` (10초) -> `Buffer`에 있는 데이터 묶어서 `POST /events/batch` 전송.

---

## 🧠 Phase 3: Intelligence (지능 연결)
**목표**: 쌓인 데이터를 AI가 조회하고 판단합니다.

### 3-1. AI Agent Setup (The Brain)
- [ ] **[TASK] Tool 정의 (`backend/agent/tools.py`)**
    - [ ] `get_dog_profile(dog_id)`: 기본 정보 조회.
    - [ ] `get_care_history(dog_id, category)`: "마지막 접종일" 조회 (SQL Query).
    - [ ] `get_activity_stats(dog_id, days)`: "최근 활동량" 조회 (EventLog 집계).
    - [ ] `get_weight_trend(dog_id)`: 체중 변화 조회.
- [ ] **[TASK] Agent 구성 (`backend/agent/core.py`)**
    - [ ] **Framework**: LangChain `OpenAIFunctionsAgent`.
    - [ ] **System Prompt**: "You are a vet assistant. Use tools to answer based on REAL data."

### 3-2. Chat Integration
- [ ] **[TASK] API 구현 (`backend/routers/chat.py`)**
    - [ ] `POST /chat`: `{ "message": "...", "dog_id": 1 }`
    - [ ] **Process**: User Msg -> Agent -> Tools -> DB -> Agent -> Final Answer.
- [ ] **[TASK] iOS 연동 (`Services/ChatService.swift`)**
    - [ ] Mock 제거 -> `POST /chat` 연결.
    - [ ] **Streaming**: 답변이 길어질 수 있으므로 `Server-Sent Events (SSE)` 고려.

---

## 💎 Phase 4: Value & Polish (가치 창출)
**목표**: 사용자가 "와, 이걸 알아서 챙겨주네?"라고 느끼게 합니다.

### 4-1. Proactive Notifications (알림)
- [ ] **[TASK] 백엔드 스케줄러 (`backend/scheduler.py`)**
    - [ ] **Library**: `APScheduler`.
    - [ ] **Job**: 매일 밤 12시 실행.
    - [ ] **Logic**:
        - "오늘 긁는 행동(`scratching`) > 10회?" -> 푸시 알림 테이블에 추가.
        - "마지막 심장사상충(`medication`) > 30일?" -> 푸시 알림 테이블에 추가.
- [ ] **[TASK] iOS 푸시 수신**
    - [ ] `UNUserNotificationCenter` 연동.

### 4-2. Monthly Report (리포트)
- [ ] **[TASK] 리포트 생성기 (`backend/reports.py`)**
    - [ ] **Library**: `ReportLab` (PDF 생성).
    - [ ] **Content**: 활동량 그래프, 체중 변화, 특이 행동(구토 등) 횟수 요약.
    - [ ] **Delivery**: 이메일 발송 또는 앱 내 다운로드 링크 제공.

---
**💡 실행 가이드**:
이 문서는 살아있는 문서입니다. **Phase 1-1**부터 하나씩 정복해 나가세요. 체크박스(`[ ]`)를 하나씩 채울 때마다 앱은 똑똑해집니다.

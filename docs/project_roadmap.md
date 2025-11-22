📘 Master Implementation Guide: MyDogCare (Hybrid Edge-Cloud + Blackbox)

이 문서는 YOLO 기반 온디바이스 분석, 시계열 + 클립 기반 블랙박스 메모리,
**클라우드 LLM + VLM(Gemini 2.5 Pro)**를 결합한 하이브리드 아키텍처를 구현하기 위한
최종 마스터 체크리스트입니다.
    •    Camera Device (Sender): 집에 두는 iPhone – YOLO + ReID + State Packet + Clip Trigger
    •    Viewer Device (Receiver): 사용자가 들고 다니는 iPhone – Chat, Chart, Calendar, Report
    •    Backend: TimescaleDB + VectorDB + S3(MinIO) + LLM Agent
    •    VLM(Gemini 2.5 Pro): 오토라벨링/학습 데이터 생성용 (실시간 질의에 직접 쓰지 않음)

⸻⎻

🅰️ Phase 0: Bootstrap (VLM Data Collection) - 초기 1달

목표
Behavior/Stress 모델 학습을 위한 학습 데이터를 수집하기 위해,
초기 1달간은 **VLM(Vision-Language Model)을 실시간 사용**하여 행동 분석을 수행합니다.
VLM이 분석한 결과는 백엔드에 저장되며, 이후 Behavior Classifier 학습에 사용됩니다.

⎻

0-0-1. VLM 기반 실시간 분석 (ios-app) - 초기 운영
    •    [✓] VisionClient.swift 활용 (Services/VisionClient.swift 또는 ModelRegistry.swift)
    •    기존 코드 유지: VLM API 호출로 posture, action, emotion, health_signals 분석.
    •    **파이프라인 개선** (중요):
    •    기존: 카메라 → 프레임 5장 → VLM
    •    **변경**: 카메라 → **YOLO 감지** → **ReID 식별** → 등록 강아지 태깅된 이미지 스트리밍 → 프레임 5장 → VLM
    •    **이유**: VLM에게 이미 식별된 강아지 정보(name, bbox)를 컨텍스트로 제공하여 더 정확한 행동 분석 유도.
    •    **구현**:
    •    OnAirView: 카메라 프레임을 YOLOClient로 전달.
    •    YOLO 결과 (bbox, confidence)를 ReIDTracker로 전달.
    •    ReID가 식별한 dog_id를 이미지에 오버레이 (텍스트 또는 메타데이터).
    •    태깅된 프레임 5장을 VisionClient.analyzeStream()에 전달.
    •    출력: `VisionResponse` (dogs: [DogAnalysis]).
    •    [ ] 데이터 수집 로직 추가 (Services/DataCollector.swift)
    •    VLM 분석 결과를 로그 형태로 저장: `logs/vlm_analysis_{date}.jsonl`.
    •    각 레코드: timestamp, dog_id, bbox, action, emotion, image_hash.
    •    주기적 서버 업로드: `POST /training_data/vlm_logs`.
    •    [ ] 백엔드 저장소 구축 (backend/training_data/)
    •    S3/MinIO에 `vlm_logs/` 버킷 생성.
    •    DB 테이블: `vlm_training_samples`
    •    주요 컨럼: id, timestamp, dog_id, action_label, emotion_label, image_url, bbox_json.

0-0-2. 학습 데이터 큐레이션 (ai-models/data_curation/)
    •    [ ] VLM 로그 정제 스크립트 (curate_vlm_logs.py)
    •    Low-confidence 샘플 필터링 (confidence < 0.6 제거).
    •    중복 제거: 동일 시간대/동일 행동 중복 제거.
    •    충분히 모인 후 (1달, ~10k 샘플) 학습 데이터셋 준비.

0-0-3. 전환 전략 (1달 후)
    •    1달 간 VLM 데이터 수집 완료 후:
    •    [ ] Behavior Classifier 학습 (ai-models/train_behavior.py)
    •    [ ] Stress Proxy Head 학습 (ai-models/train_stress.py)
    •    [ ] CoreML 변환 및 온디바이스 배포 (0-4 섹션 참조)
    •    [ ] VLM 비활성화: VisionClient 사용 중단, BehaviorHead.swift로 전환.

⎻

🚨 Priority 0: On-Device Intelligence (The “Eyes”)

목표
VLM에 의존하지 않고, YOLO + ReID + 경량 Behavior/Stress 헤드를 사용하여
엣지(iPhone)에서 실시간으로 강아지를 추적하고,
매초 정규화된 DeviceStatePacket을 생성해 서버로 보낸다.

⸻

0-0. 공통 모델/데이터 구조 정의 (ios-app)

DetectedObject / DogState / PairState / Environment / DeviceStatePacket
    •    [ ] DetectedObject 정의 (Models/DetectedObject.swift)
    •    bbox: CGRect — 원본 영상 좌표
    •    confidence: Float
    •    classId: Int — dog class index
    •    trackId: Int? — 트래커에서 부여하는 temp ID
    •    embedding: [Float]? — ReID/appearance 128d 벡터 (JDE 헤드 출력)
    •    [ ] DogState / BBoxNorm 정의 (Models/DogState.swift)
    •    tempTrackId: Int
    •    dogId: UUID? — 레퍼런스 매칭 성공 시만 set
    •    bboxNorm: BBoxNorm — cx, cy, w, h: Float (0~1)
    •    speedPx: Float? — px/s
    •    directionRad: Float? — 라디안
    •    behaviorProbs: [String: Float] — { "play":0.8, "rest":0.1, ... }
    •    stressProxy: Float? — 0~1 추정 긴장도
    •    [ ] PairState 정의 (Models/PairState.swift)
    •    dogIId: UUID
    •    dogJId: UUID
    •    distanceNorm: Float — 0~1
    •    relativeAngle: Float?
    •    affinityScore: Float? — 0~1
    •    tensionScore: Float? — 0~1
    •    interactionTags: [String] — ["play","chase","face_off"] 등
    •    [ ] EnvironmentState 정의 (Models/EnvironmentState.swift)
    •    lux: Float?
    •    decibel: Float?
    •    crowding: Int? — 화면 내 감지 개수(강아지+사람 등)
    •    [ ] DeviceStatePacket 정의 (Models/DeviceStatePacket.swift)
    •    timestamp: Date — UTC 기준
    •    deviceId: String
    •    sessionId: String — OnAir 세션 UUID
    •    fps: Float?
    •    dogs: [DogState]
    •    relations: [PairState]? — 초기엔 nil 가능
    •    environment: EnvironmentState?

PairState 관련 Note
    •    한 프레임에 N마리(a,b,c,…)가 있어도, 관계는 (a,b), (a,c), (b,c)… 처럼 쌍 단위로 표현하므로 지금 구조로 충분합니다.
    •    구현 시 항상 dog_i_id < dog_j_id로 정규화해서 (a,b)와 (b,a)가 중복 저장되지 않도록 해야 합니다.
    •    N이 커질 경우, distanceNorm가 너무 큰 쌍은 생략하거나 가까운 k마리만 PairState 생성하는 최적화 옵션을 둘 수 있습니다.

⸻

0-1. YOLO CoreML Integration (ios-app)
    •    [ ] YOLO 모델 준비 (ai-models/)
    •    Selection: YOLOv11-nano 또는 YOLOv12-nano (속도 최우선).
    •    Conversion: ultralytics로 .pt → .mlmodel 변환.
    •    Integration: ios-app/MyDogCare/Resources/Models/에 모델 파일 추가.
    •    [ ] Vision Pipeline 구축 (Services/Vision/YOLOClient.swift)
    •    VNCoreMLRequest 설정.
    •    Post-Processing: Confidence > 0.5, IOU > 0.45.
    •    Output: [DetectedObject] 리스트 반환.

⸻

0-2. ReID (One-Shot Tracking) (ios-app)
    •    [ ] Dog 엔티티 확장 (Models/Dog.swift or Core Data)
    •    id: UUID
    •    name: String
    •    breed: String?
    •    birthdate: Date?
    •    sex: String? — "male" | "female" | "unknown"
    •    profilePhotoURL: URL?
    •    referenceEmbeddings: [[Float]] — 3~5장, 각 128d
    •    [ ] Reference Data Management (Views/DogProfile/)
    •    AddDogView에 “AI 인식용 사진 등록(3~5장)” 섹션 추가.
    •    각 사진에서 강아지 영역 Crop (YOLO or 사용자 드래그).
    •    Crop -> ReID 모델 -> 128d 벡터 추출.
    •    Dog.referenceEmbeddings 배열로 저장.
    •    [ ] Real-time Matching (Services/Vision/ReIDTracker.swift)
    •    DetectedObject.embedding vs Dog.referenceEmbeddings 코사인 유사도.
    •    유사도 집계(평균/최댓값) 후 Threshold > 0.7일 때 dogId 부여.
    •    매칭 실패 시 dogId = nil, tempTrackId만 유지.

⸻

0-3. State Packet Generation (ios-app)
    •    [ ] YOLO + ReID → DogState 매핑 (Services/Vision/StateBuilder.swift)
    •    프레임 단위로 [DetectedObject]를 [DogState]로 변환.
    •    bbox를 화면 크기로 나눠 bboxNorm 계산.
    •    이전 프레임 좌표와 비교해 speedPx, directionRad 계산.
    •    [ ] PairState 생성 규칙 (Services/Vision/PairBuilder.swift)
    •    한 패킷 내 DogState들에서 (i,j) 조합 생성.
    •    dog_i_id < dog_j_id 규칙으로 정렬/정규화.
    •    distanceNorm 계산 (정규화된 bbox 중심 거리).
    •    (옵션) 너무 먼 쌍은 스킵 (distanceNorm > 0.7 등).
    •    [ ] EnvironmentState 수집 (Services/Vision/EnvSampler.swift)
    •    조도(lux), 소음(db), crowding 추정 로직 구현 (가능한 범위 내).
    •    [ ] DeviceStatePacket 생성 (OnAirViewModel)
    •    1초마다 최신 프레임/상태를 모아 DeviceStatePacket 생성.
    •    EventUploader로 전달.
    •    [ ] 전송 로직 (Services/Network/EventUploader.swift)
    •    Buffering: 1초 단위 패킷 큐잉.
    •    Batch Upload: 10초 단위 [DeviceStatePacket] 묶어 POST /events/batch.
    •    네트워크 불가 시 로컬 디스크에 임시 저장 후 재시도.

⸻

0-4. On-Device Behavior + Stress Head (ios-app)
    •    [ ] Behavior Classifier 경량 모델 설계 (ai-models/behavior_head/)
    •    입력 피처: 최근 N프레임 bbox 이동, 속도, 방향, (옵션) 포즈 요약.
    •    출력: behavior_probs (play/rest/chase/avoid/freeze/face_off…).
    •    [ ] 학습 데이터셋 준비 (ai-models/data/behavior/)
    •    수동 라벨링: 짧은 시퀀스(2~5초)에 대해 행동 태그 부여.
    •    VLM 자동 라벨링: Gemini 2.5 Pro로 대량 초기 라벨 생성.
    •    데이터 증강: 속도 조정, 노이즈 추가 등.
    •    [ ] 모델 학습 (ai-models/train_behavior.py)
    •    아키텍처: 간단한 MLP (2~3 hidden layers, 64~128 units) 또는 1D-CNN.
    •    손실 함수: Cross-Entropy Loss (multi-class classification).
    •    학습 파라미터: batch_size=32, epochs=50~100, lr=1e-3.
    •    검증: Validation accuracy > 85% 목표.
    •    [ ] CoreML 변환 및 통합 (ai-models/export_behavior.py)
    •    PyTorch → CoreML 변환.
    •    모델 파일: `BehaviorClassifier.mlmodel`.
    •    통합: `ios-app/MyDogCare/Resources/Models/`에 복사.
    •    [ ] BehaviorHead.swift 구현 (Services/Vision/BehaviorHead.swift)
    •    입력: 최근 N프레임의 `[DetectedObject]` 히스토리.
    •    전처리: bbox 좌표 → 속도/방향 벡터 계산.
    •    추론: CoreML 모델 실행 → behavior_probs 반환.
    •    DogState 업데이트: `state.behaviorProbs = behaviorHead.predict(history)`.
    •    [ ] Stress Proxy 헤드 설계
    •    입력: behavior_probs + 속도/정지 패턴.
    •    출력: stressProxy (0~1).
    •    [ ] Stress 모델 학습 (ai-models/train_stress.py)
    •    옵션 A: 규칙 기반 베이스라인
    •    예: `stress = 0.7 * tension_score + 0.3 * speed_variance`.
    •    옵션 B: 작은 회귀 네트워크 학습
    •    라벨: 수의사/행동학자의 주석 또는 VLM 추정치.
    •    손실: MSE Loss.
    •    [ ] CoreML 변환 및 통합 (ai-models/export_stress.py)
    •    모델 파일: `StressProxy.mlmodel`.
    •    통합: `ios-app/MyDogCare/Resources/Models/`.
    •    [ ] StressHead.swift 구현 (Services/Vision/StressHead.swift)
    •    입력: `behaviorProbs` + 움직임 통계.
    •    추론: CoreML 모델 또는 규칙 기반 계산.
    •    DogState 업데이트: `state.stressProxy = stressHead.predict(behaviorProbs, motionStats)`.
    •    [ ] 통합 테스트 (OnAirView)
    •    YOLO → ReID → BehaviorHead → StressHead 전체 파이프라인 검증.
    •    UI에서 `behaviorProbs`와 `stressProxy` 실시간 표시 확인.

⸻

🏁 Phase 1: Local Foundation & Dual Mode (앱 내실 다지기)

목표
앱을 Camera Mode (Sender) / **Viewer Mode (Receiver)**로 분리하고,
On Air 화면을 사람이 보기에도 직관적인 모니터링 화면으로 만든다.

⸻

1-1. Dual Mode UI (ios-app)
    •    [ ] Mode Switcher (Views/Settings/ModeSelectionView.swift)
    •    앱 첫 실행 혹은 설정에서 “Camera Mode” vs “Viewer Mode” 선택.
    •    Camera Mode:
    •    OnAirView를 루트로 설정.
    •    UIApplication.shared.isIdleTimerDisabled = true.
    •    Viewer Mode:
    •    기존 MainView (Chat, Calendar, List) 루트 유지.

⸻

1-2. Dog Profile Sync (Services/Sync/DogSyncManager.swift)
    •    [ ] Down-sync (GET /dogs)
    •    앱 시작 시 서버로부터 dogs 목록 수신.
    •    로컬 Core Data와 비교해 누락/변경 사항 반영.
    •    photo_url을 로컬 DogPhotoStore로 다운로드/캐시.
    •    [ ] Up-sync (POST /dogs)
    •    AddDogView에서 save 시 서버에 프로필 업로드.
    •    multipart/form-data 요청:
    •    JSON: { name, breed, birthdate, sex, ... }
    •    파일: 프로필 사진
    •    응답의 id, photo_url을 로컬 Dog 엔티티에 반영.

⸻

1-3. Care Calendar (The Body) ✅
    •    [ ] 로컬 DB 설계 (Models/CareEvent.swift)
    •    [ ] 캘린더 UI 구현 (Views/CareCalendarView.swift)

⸻

1-4. On Air UI Overhaul (ios-app)
    •    [ ] Bounding Box Overlay (Views/OnAir/OverlayView.swift)
    •    YOLO/DeviceStatePacket 좌표 → 화면 좌표 변환.
    •    각 강아지에 대해:
    •    박스 그리기.
    •    상단 라벨: Name (Confidence%) (없으면 temp ID).
    •    하단/옆 라벨: Dominant Action (“play”, “rest”, …).
    •    다견일 경우 색/레이블을 dog별 고정.

⸻

🌉 Phase 2: Backend Infrastructure (The “Memory”)

목표
온디바이스에서 올라오는 패킷을 **시계열 팩트(dog_states, pair_relations)**와
사건(risk_events), 증거(clips) 로 저장하여 블랙박스 메모리를 구성한다.  ￼

⸻

2-1. Server Setup (backend/)
    •    [ ] FastAPI Project Init
    •    poetry init & deps: fastapi, uvicorn[standard], sqlalchemy, asyncpg, pydantic-settings, alembic.
    •    [ ] Docker Compose
    •    timescaledb
    •    redis
    •    milvus (Vector DB)
    •    minio (S3 호환 스토리지)
    •    (옵션) pgadmin/adminer

⸻

2-2. Database Schema (backend/models.py / alembic/)

2-2-1. Dogs (Profile)
    •    [ ] dogs 테이블 생성
    •    id: UUID (PK)
    •    owner_id: UUID
    •    name: TEXT
    •    breed: TEXT
    •    birthdate: DATE
    •    sex: TEXT
    •    weight_kg: REAL
    •    profile_photo_url: TEXT
    •    created_at: TIMESTAMPTZ DEFAULT now()

⸻

2-2-2. Dog States (Hypertable)
    •    [ ] dog_states Hypertable 생성
    •    주요 컬럼:
    •    id: BIGSERIAL (PK)
    •    t: TIMESTAMPTZ NOT NULL
    •    device_id: TEXT NOT NULL
    •    session_id: TEXT NOT NULL
    •    dog_id: UUID
    •    temp_track_id: INTEGER
    •    bbox_cx, bbox_cy, bbox_w, bbox_h: REAL
    •    speed_px: REAL
    •    direction_rad: REAL
    •    behavior_probs: JSONB
    •    dominant_action: TEXT
    •    stress_proxy: REAL
    •    environment_lux: REAL
    •    environment_db: REAL
    •    created_at: TIMESTAMPTZ DEFAULT now()
    •    Timescale 설정: create_hypertable('dog_states', 't')
    •    인덱스: (dog_id, t DESC), (device_id, t DESC)

⸻

2-2-3. Pair Relations (Hypertable)
    •    [ ] pair_relations Hypertable 생성
    •    주요 컬럼:
    •    id: BIGSERIAL (PK)
    •    t: TIMESTAMPTZ
    •    device_id: TEXT
    •    session_id: TEXT
    •    dog_i_id: UUID
    •    dog_j_id: UUID
    •    distance_norm: REAL
    •    relative_angle: REAL
    •    affinity: REAL
    •    tension: REAL
    •    interaction_tags: TEXT[]
    •    created_at: TIMESTAMPTZ DEFAULT now()
    •    Timescale 설정
    •    인덱스: (dog_i_id, dog_j_id, t DESC), (t DESC)

⸻

2-2-4. Risk Events
    •    [ ] risk_events 테이블 생성
    •    risk_id: UUID (PK)
    •    device_id: TEXT
    •    session_id: TEXT
    •    t_start, t_end: TIMESTAMPTZ
    •    target_type: TEXT — "dog" | "pair" | "group"
    •    target_ids: UUID[]
    •    risk_stage: TEXT — "warning" | "escalating" | "high"
    •    risk_score: REAL
    •    trigger: TEXT
    •    trigger_behaviors: TEXT[]
    •    notes: TEXT
    •    created_at: TIMESTAMPTZ DEFAULT now()

⸻

2-2-5. Clips (Evidence Metadata)
    •    [ ] clips 테이블 생성
    •    clip_id: UUID (PK)
    •    device_id: TEXT
    •    session_id: TEXT
    •    t_start, t_end: TIMESTAMPTZ
    •    dog_ids: UUID[]
    •    risk_event_id: UUID
    •    storage_url: TEXT
    •    thumbnail_url: TEXT
    •    vector_id: TEXT
    •    tags: TEXT[]
    •    created_at: TIMESTAMPTZ DEFAULT now()

⸻

2-3. Dog Profile Sync API (backend/routers/dogs.py)
    •    [ ] POST /dogs
    •    multipart/form-data:
    •    dog JSON
    •    photo 파일
    •    S3/MinIO 업로드 후 profile_photo_url 세팅.
    •    dogs 테이블 insert/update.
    •    [ ] GET /dogs
    •    owner 기준 dogs 목록 반환.

⸻

2-4. Ingestion API (backend/routers/events.py)
    •    [ ] POST /events/batch
    •    Request Body: [DeviceStatePacket]
    •    각 packet의 dogs → dog_states insert.
    •    (옵션) relations → pair_relations insert.
    •    위험 감지 룰 기반으로 risk_events 후보 생성.
    •    asyncpg bulk insert 적용.

⸻

🧠 Phase 3: Intelligence (The “Brain”)

목표
시계열 데이터를 기반으로 차트 + 통계 + 설명 + 증거 클립까지 제공하는
LLM 기반 분석 계층을 구축한다.

⸻

3-1. Clip Recording & Upload (ios-app)
    •    [ ] Circular Buffer (Services/Vision/VideoRecorder.swift)
    •    최근 30초 영상 버퍼 유지.
    •    메모리/디스크 사용량 모니터링.
    •    [ ] Clip Trigger Logic
    •    Behavior Peak: behaviorProbs["play"] > 0.8.
    •    Risk Event: risk_score > 0.7.
    •    트리거 시:
    •    과거 10초 + 향후 20초 범위 영상 저장.
    •    관련 dog_ids, t_start, t_end, tags 함께 메타 생성.
    •    POST /clips 업로드.

⸻

3-2. Clip Processing (backend/routers/clips.py)
    •    [ ] POST /clips
    •    파일 수신 → MinIO/S3 저장 → storage_url 생성.
    •    clips 테이블 insert.
    •    [ ] Clip Embedding Worker (backend/workers/embed_clips.py)
    •    VideoMAE/CLIP 등으로 video_embed 생성.
    •    Milvus에 저장 → vector_id 획득.
    •    clips.vector_id 업데이트.

⸻

3-3. Analytics & LLM Agent (backend/agent/)

3-3-1. Analytics API
    •    [ ] /analytics/dog_timeseries
    •    Input: dog_id, metric, from, to
    •    Output: { timestamps: [...], values: [...] }
    •    [ ] /analytics/pair_timeseries
    •    Input: (dog_i_id, dog_j_id), metric, 기간
    •    Output: tension/affinity 시계열
    •    [ ] /analytics/risk_peaks
    •    Input: 대상 dog/pair/group, 기간
    •    Output: 상위 risk_events

3-3-2. LLM Planner / Analyzer / Presenter
    •    [ ] 로컬 LLM(HF) 서빙 환경 구성 (backend/llm/local_model.py)
    •    HuggingFace 기반 한국어 인스트럭션 모델 선택.
    •    gRPC/HTTP로 callable API 제공.
    •    [ ] Planner 구현
    •    사용자 질문 → Plan JSON:
    •    time_range, targets, metrics, needs
    •    Plan을 기반으로 어떤 Analytics/벡터 쿼리를 날릴지 결정.
    •    [ ] Analyzer (Data) 구현
    •    Plan에 따라 /analytics/... 호출.
    •    Pandas/NumPy로 평균/분산/피크 탐지.
    •    [ ] Analyzer (Expert) 구현
    •    Data 결과 + 도메인 힌트(수의학/행동학 프롬프트) → 해석 텍스트 생성.
    •    [ ] Presenter 응답 포맷 정의
    •    summary: String
    •    charts: [ChartSpec] — Chart.js 용
    •    stats: JSON
    •    clips: [EvidenceClip] — clip_id, thumbnail_url, reason 포함
    •    [ ] 외부 GPT Teacher(10% 샘플) 연동
    •    동일 질의/데이터에 대해 10번 중 1번만 GPT 호출.
    •    GPT 응답을 teacher label로 저장 (로컬 LLM 튜닝용).

⸻

🔁 Phase 3.5: Vision-Language Auto Labeling (Gemini 2.5 Pro)

목표
Google Gemini 2.5 Pro Vision API를 사용해서
{이미지/클립 : 풍부한 JSON 라벨} 쌍을 만들고,
이를 Behavior/Relation/Risk 모델 및 QA LLM의 학습 데이터로 사용하는 루프를 만든다.

⸻

3.5-1. VLM Annotation Schema 정의
    •    [ ] VLM Annotation 스키마 문서화 (docs/vl_annotation_schema.md)
    •    필드 예:
'''
{
  "clip_id": "uuid",
  "caption": "Two dogs are play-fighting on the couch.",
  "scene_tags": ["indoor", "play"],
  "per_dog": {
    "dog_A": { "behavior": ["play"], "emotion": ["excited"] },
    "dog_B": { "behavior": ["play"], "emotion": ["relaxed"] }
  },
  "interaction": { "type": "play", "tension_level": "low" },
  "risk_estimate": { "stage": "none", "reason": "No aggressive signals." }
}
'''

⸻

3.5-2. Gemini 2.5 Pro 라벨러 서비스
    •    [ ] Gemini 2.5 Pro VLM 호출 유틸 (backend/services/vl_labeler.py)
    •    입력: 클립 썸네일 or 짧은 샘플 프레임 + 프롬프트.
    •    출력: 위 스키마에 맞는 JSON.
    •    Rate limit / 에러 핸들링 / 재시도 구현.
    •    [ ] 라벨링 대상 샘플링 로직 (hard / uncertain)
    •    Behavior/Relation/Risk 모델의 확신도 낮은 구간.
    •    사용자 피드백 “이상함” 표시된 클립.
    •    규칙과 모델이 충돌하는 구간.
    •    이들을 vl_label_queue로 enqueue.
    •    [ ] VLM Annotation 저장 (vl_annotations 테이블)
    •    id: UUID
    •    clip_id: UUID
    •    raw_response: JSONB
    •    normalized: JSONB
    •    created_at: TIMESTAMPTZ

⸻

3.5-3. VLM → 내부 스키마 매핑
    •    [ ] VLM → 내부 필드 매핑 (backend/services/vl_to_internal_mapper.py)
    •    per_dog.behavior → behavior 레이블 후보.
    •    interaction.type / tension_level → pair_relations/ risk_events 라벨 후보.
    •    risk_estimate.stage → risk_stage 후보.
    •    scene_tags → clips.tags 보강.
    •    [ ] 학습용 pseudo-label export (ai-models/datasets/export_vlm_labels.py)
    •    vl_annotations.normalized → 모델별 학습 데이터 포맷으로 export.

⸻

💎 Phase 4: Advanced (Data Flywheel & Model Retraining)

목표
Hard example + VLM 라벨 + 사용자 피드백으로
Behavior/Relation/Risk/QA 모델을 점점 고도화하는 데이터 플라이휠 구축.

⸻

4-1. Hard Example Mining
    •    [ ] Hard Example 후보 선별 (backend/services/hard_miner.py)
    •    Behavior/Relation/Risk 확신도 낮은 구간.
    •    규칙 vs 모델 출력이 크게 다른 구간.
    •    사용자 피드백 “틀림/이상함”이 붙은 클립.
    •    [ ] Hard Example → VLM 파이프라인 연결
    •    Hard examples를 우선적으로 Gemini 2.5 Pro에 보내 라벨 생성.
    •    vl_annotations에 저장 후 매핑/학습에 사용.

⸻

4-2. 모델 재학습 파이프라인
    •    [ ] Behavior 모델 학습 데이터셋 빌더
    •    입력: VLM behavior 라벨 + 기존 수동 라벨.
    •    출력: {frame/clip_snippet, behavior_label} 포맷.
    •    [ ] Relation/Risk 모델 학습 데이터셋 빌더
    •    VLM interaction/risk_estimate 기반 라벨 생성.
    •    Time window → {features, label} 형태로 변환.
    •    [ ] Training 스크립트 (ai-models/train_behavior.py, train_relation.py, train_risk.py)
    •    기존 weight + 새 데이터로 fine-tuning.
    •    검증 후 성능 향상 시만 배포.

⸻

4-3. QA LLM 고도화
    •    [ ] Q/A 데이터셋 생성
    •    Analytics 결과 + VLM caption/설명을 사용해
“질문-답변” 쌍 자동 생성.
    •    [ ] 로컬 LLM 튜닝
    •    위 Q/A 데이터로 HF 기반 로컬 LLM fine-tuning.
    •    [ ] 외부 GPT vs 로컬 LLM 비교/Distillation
    •    동일 질문에 대해 10% 샘플에 GPT 호출.
    •    GPT답을 teacher label로 distillation.

⸻

💡 실행 가이드
    •    가장 먼저 **Priority 0 (YOLO + ReID + DeviceStatePacket)**을 단단히 깔고,
    •    그다음 **Phase 2 (Timescale/DB 스키마 + Ingestion)**를 붙이고,
    •    Phase 3(LLM + Analytics), 3.5(VLM/Gemini 오토라벨링),
    •    마지막으로 **Phase 4(모델 재학습 플라이휠)**을 순차적으로 밟으면 됩니다.

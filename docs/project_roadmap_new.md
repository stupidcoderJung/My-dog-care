# 📘 Master Implementation Guide: MyDogCare (Hybrid Edge-Cloud + Blackbox)

이 문서는 YOLO 기반 온디바이스 분석, 시계열 + 클립 기반 블랙박스 메모리,
**클라우드 LLM + VLM(Gemini 2.5 Pro)**를 결합한 하이브리드 아키텍처를 구현하기 위한
최종 마스터 체크리스트입니다.

**시스템 구성:**
- **Camera Device (Sender)**: 집에 두는 iPhone – YOLO + ReID + State Packet + Clip Trigger
- **Viewer Device (Receiver)**: 사용자가 들고 다니는 iPhone – Chat, Chart, Calendar, Report
- **Backend**: TimescaleDB + VectorDB + S3(MinIO) + LLM Agent
- **VLM(Gemini 2.5 Pro)**: 오토라벨링/학습 데이터 생성용

---

## 🏗️ Priority 0: Foundation Models (YOLO + ReID)

**목표**: 온디바이스 AI의 핵심 감지/식별 모델을 먼저 준비합니다.

### 0-1. YOLO CoreML Integration (ai-models → ios-app)
- [ ] **YOLO 모델 준비 및 변환** (ai-models/)
  - Selection: YOLOv11-nano 또는 YOLOv12-nano (속도 최우선)
  - Conversion: `ultralytics`로 .pt → .mlmodel 변환
  - Export Script: `ai-models/export_yolo.py`
  - Output: `yolo11n.mlpackage`
- [ ] **iOS 통합** (ios-app/MyDogCare/Resources/Models/)
  - 모델 파일을 Xcode 프로젝트에 추가

### 0-2. ReID CoreML Integration (ai-models → ios-app)
- [ ] **ReID 모델 준비 및 변환** (ai-models/)
  - Model: ResNet50 feature extractor (512d or 128d)
  - Export Script: `ai-models/export_reid.py`
  - Output: `ResNet50_ReID.mlmodel`
- [ ] **iOS 통합** (ios-app/MyDogCare/Resources/Models/)
  - 모델 파일을 Xcode 프로젝트에 추가

---

## 📱 Priority 1: iOS Core Data Structures

**목표**: 온디바이스 파이프라인에 필요한 Swift 데이터 구조를 정의합니다.

### 1-1. 기본 데이터 모델 정의 (ios-app/Models/)
- [ ] **DetectedObject** (DetectedObject.swift)
  - bbox: CGRect — 원본 영상 좌표
  - confidence: Float
  - classId: Int
  - trackId: Int?
  - embedding: [Float]?
- [ ] **DogState** (DogState.swift)
  - tempTrackId: Int
  - dogId: UUID?
  - bboxNorm: BBoxNorm — cx, cy, w, h (0~1)
  - speedPx: Float?
  - directionRad: Float?
  - behaviorProbs: [String: Float]
  - stressProxy: Float?
- [ ] **PairState** (PairState.swift)
  - dogIId, dogJId: UUID (i < j 규칙)
  - distanceNorm: Float
  - relativeAngle: Float?
  - affinityScore, tensionScore: Float?
  - interactionTags: [String]
- [ ] **EnvironmentState** (EnvironmentState.swift)
  - lux, decibel: Float?
  - crowding: Int?
- [ ] **DeviceStatePacket** (DeviceStatePacket.swift)
  - timestamp: Date (UTC)
  - deviceId, sessionId: String
  - fps: Float?
  - dogs: [DogState]
  - relations: [PairState]?
  - environment: EnvironmentState?

### 1-2. Dog Profile 엔티티 확장 (Core Data 또는 Models/Dog.swift)
- [ ] **기존 필드 유지**
  - id: UUID
  - name: String
  - breed, birthdate, sex: String?
  - profilePhotoURL: URL?
- [ ] **ReID용 필드 추가**
  - referenceEmbeddings: [[Float]] — 3~5장, 각 512d or 128d

---

## 🎥 Priority 2: iOS Vision Pipeline (YOLO + ReID)

**목표**: YOLO와 ReID를 사용하여 실시간 강아지 감지 및 식별 파이프라인을 구축합니다.

### 2-1. YOLO Client (Services/Vision/YOLOClient.swift)
- [ ] **CoreML 모델 로드**
  - `VNCoreMLModel(for: yolo11n().model)`
- [ ] **추론 메서드**
  - `func predict(pixelBuffer: CVPixelBuffer) -> [DetectedObject]`
  - Post-Processing: Confidence > 0.5, IOU > 0.45
  - bbox, confidence, classId 추출

### 2-2. ReID Tracker (Services/Vision/ReIDTracker.swift)
- [ ] **CoreML 모델 로드**
  - ResNet50_ReID 모델
- [ ] **임베딩 추출**
  - `func extractEmbedding(from image: CIImage) -> [Float]`
  - 224x224 리사이징 후 추론
- [ ] **강아지 식별**
  - `func identify(embedding: [Float], knownDogs: [Dog]) -> UUID?`
  - Cosine Similarity 계산 (threshold > 0.7)

### 2-3. Reference Data Management (Views/DogProfile/)
- [ ] **AddDogView 확장**
  - "AI 인식용 사진 등록(3~5장)" UI 추가
  - 각 사진에서 강아지 영역 Crop
  - ReID 모델로 임베딩 추출
  - Dog.referenceEmbeddings 배열로 저장

---

## 🅰️ Phase 0: Bootstrap (VLM Provides All Functionality)

**목표**: VLM을 사용하여 **사용자에게 완전한 기능을 제공**하면서, 동시에 온디바이스 모델 학습용 데이터를 수집합니다.

### 0-A. VLM 기반 실시간 분석 및 State Packet 생성 (ios-app)
- [✓] **VisionClient 활용** (Services/ModelRegistry.swift)
  - **Enhanced Pipeline**:
    - Camera → **YOLO 감지** → **ReID 식별** → 태깅된 이미지 → 5 프레임 → VLM
  - VLM 출력: `VisionResponse` (posture, action, emotion, health_signals)

- [ ] **VLM → DogState 매핑** (Services/Vision/VLMStateMapper.swift)
  - VLM의 `action` → `behaviorProbs` 변환
    - 예: action="play" → {"play": 1.0, "rest": 0.0}
  - VLM의 `emotion` → `stressProxy` 변환 (규칙 기반)
    - 예: emotion="relaxed" → stressProxy=0.2
    - emotion="anxious" → stressProxy=0.8
  - VLM의 `posture` → 추가 컨텍스트로 활용

- [ ] **State Builder** (Services/Vision/StateBuilder.swift)
  - YOLO bbox → bboxNorm 계산
  - 이전 프레임 대비 speedPx, directionRad 계산
  - VLM 매핑 결과를 DogState에 통합:
    ```swift
    DogState(
        dogId: ...,
        bboxNorm: ...,
        speedPx: ...,
        behaviorProbs: vlmMapper.behaviorProbs,  // VLM 기반
        stressProxy: vlmMapper.stressProxy        // VLM 기반
    )
    ```

- [ ] **Pair Builder** (Services/Vision/PairBuilder.swift)
  - DogState 조합 → PairState 생성
  - distanceNorm, relativeAngle 계산
  - (초기) affinity/tension은 null 또는 기본값

- [ ] **Environment Sampler** (Services/Vision/EnvSampler.swift)
  - lux, decibel, crowding 추정

- [ ] **Complete DeviceStatePacket** (OnAirViewModel)
  - 1초마다 완전한 DeviceStatePacket 생성:
    - dogs: [DogState] (VLM 기반 behavior/stress 포함)
    - relations: [PairState]
    - environment: EnvironmentState

- [ ] **Event Uploader** (Services/Network/EventUploader.swift)
  - Batch Upload: 10초마다 `POST /events/batch`
  - **중요**: 이 시점에 백엔드로 전송되는 패킷은 VLM 기반이지만, 온디바이스 모델과 **동일한 스키마**

### 0-B. 학습 데이터 로깅 (ios-app)
- [ ] **Data Collector** (Services/DataCollector.swift)
  - VLM 원본 응답을 로깅: `logs/vlm_raw_{date}.jsonl`
    - 각 레코드: timestamp, dog_id, bbox, VisionResponse (전체)
  - VLM → DogState 매핑 결과도 로깅
  - 주기적 서버 업로드: `POST /training_data/vlm_logs`
  - **목적**: 나중에 Behavior/Stress 모델 학습에 사용

### 0-C. Backend Storage (backend/)
- [ ] **VLM 학습 데이터 저장소**
  - S3/MinIO: `vlm_logs/` 버킷
  - DB 테이블: `vlm_training_samples`
    - Columns: id, timestamp, dog_id, raw_vlm_response (JSONB), mapped_behavior, mapped_stress, image_url, bbox_json

### 0-D. 데이터 큐레이션 (백그라운드, ai-models/data_curation/)
- [ ] **정제 스크립트** (curate_vlm_logs.py)
  - Low-confidence VLM 응답 필터링
  - 중복 제거, 이상치 제거
  - 학습 준비된 데이터셋 생성 (~10k+ 샘플)
  - **실행 시점**: Phase 6 (온디바이스 전환 시)

---

## 🎨 Priority 3: iOS UI & Dual Mode

**목표**: 사용자 인터페이스를 구축하고 Camera/Viewer 모드로 분리합니다.

### 3-1. On Air UI (ios-app/Views/OnAir/)
- [ ] **Bounding Box Overlay** (OverlayView.swift)
  - YOLO bbox → 화면 좌표 변환
  - 각 강아지별 박스 그리기
  - 라벨: Name (Confidence%), **VLM Action** (예: "Playing")
  - (옵션) Emotion 아이콘 표시
  - 다견 시 색상 구분

### 3-2. Dual Mode UI (ios-app/Views/Settings/)
- [ ] **Mode Switcher** (ModeSelectionView.swift)
  - "Camera Mode" vs "Viewer Mode" 선택
  - Camera Mode: OnAirView 루트, 화면 꺼짐 방지
  - Viewer Mode: MainView (Chat, Calendar, List) 루트

### 3-3. Dog Profile Sync (Services/Sync/DogSyncManager.swift)
- [ ] **Down-sync** (`GET /dogs`)
  - 서버에서 dogs 목록 수신 → Core Data 동기화
  - photo_url 다운로드/캐시
- [ ] **Up-sync** (`POST /dogs`)
  - AddDogView 저장 시 서버 업로드
  - multipart/form-data (JSON + 사진)

### 3-4. Care Calendar (Views/CareCalendarView.swift)
- [x] **로컬 DB 설계** (Models/CareEvent.swift)
- [ ] **캘린더 UI 구현**

---

## 🗄️ Phase 2: Backend Infrastructure

**목표**: 시계열 데이터와 클립을 저장할 백엔드 인프라를 구축합니다.

### 5-1. On Air UI (ios-app/Views/OnAir/)
- [ ] **Bounding Box Overlay** (OverlayView.swift)
  - YOLO bbox → 화면 좌표 변환
  - 각 강아지별 박스 그리기
  - 라벨: Name (Confidence%), Dominant Action
  - 다견 시 색상 구분

### 5-2. Dual Mode UI (ios-app/Views/Settings/)
- [ ] **Mode Switcher** (ModeSelectionView.swift)
  - "Camera Mode" vs "Viewer Mode" 선택
  - Camera Mode: OnAirView 루트, 화면 꺼짐 방지
  - Viewer Mode: MainView (Chat, Calendar, List) 루트

### 5-3. Dog Profile Sync (Services/Sync/DogSyncManager.swift)
- [ ] **Down-sync** (`GET /dogs`)
  - 서버에서 dogs 목록 수신 → Core Data 동기화
  - photo_url 다운로드/캐시
- [ ] **Up-sync** (`POST /dogs`)
  - AddDogView 저장 시 서버 업로드
  - multipart/form-data (JSON + 사진)

### 5-4. Care Calendar (Views/CareCalendarView.swift)
- [x] **로컬 DB 설계** (Models/CareEvent.swift)
- [ ] **캘린더 UI 구현**

---

## 🗄️ Phase 2: Backend Infrastructure

**목표**: 시계열 데이터와 클립을 저장할 백엔드 인프라를 구축합니다.

### 2-1. Server Setup (backend/)
- [ ] **FastAPI 프로젝트 초기화**
  - `poetry init` & deps: fastapi, uvicorn, sqlalchemy, asyncpg, alembic
- [ ] **Docker Compose**
  - timescaledb, redis, milvus, minio, pgadmin

### 2-2. Database Schema (backend/models.py + alembic/)
- [ ] **dogs** (Profile)
  - id, owner_id, name, breed, birthdate, sex, weight_kg, profile_photo_url
- [ ] **dog_states** (Hypertable)
  - t, device_id, session_id, dog_id, temp_track_id
  - bbox_cx, bbox_cy, bbox_w, bbox_h
  - speed_px, direction_rad
  - behavior_probs (JSONB), dominant_action, stress_proxy
  - environment_lux, environment_db
  - Timescale: `create_hypertable('dog_states', 't')`
  - 인덱스: (dog_id, t DESC), (device_id, t DESC)
- [ ] **pair_relations** (Hypertable)
  - t, device_id, session_id
  - dog_i_id, dog_j_id (i < j)
  - distance_norm, relative_angle, affinity, tension
  - interaction_tags (TEXT[])
- [ ] **risk_events**
  - risk_id, device_id, session_id
  - t_start, t_end, target_type, target_ids
  - risk_stage, risk_score, trigger_behaviors
- [ ] **clips** (Evidence)
  - clip_id, device_id, session_id
  - t_start, t_end, dog_ids, risk_event_id
  - storage_url, thumbnail_url, vector_id, tags

### 2-3. API Implementation (backend/routers/)
- [ ] **Dog Profile Sync** (dogs.py)
  - `POST /dogs`: multipart upload (JSON + photo) → S3 → DB
  - `GET /dogs`: owner별 목록 반환
- [ ] **Event Ingestion** (events.py)
  - `POST /events/batch`: [DeviceStatePacket] → dog_states/pair_relations insert
  - asyncpg bulk insert
  - 위험 감지 룰 기반 risk_events 생성

---

## 🎬 Phase 3: Clip Recording & Analytics

**목표**: 증거 클립을 녹화/저장하고, 데이터 조회 API를 구축합니다.

### 3-1. Clip Recording (ios-app)
- [ ] **Circular Buffer** (Services/Vision/VideoRecorder.swift)
  - 최근 30초 영상 유지
- [ ] **Trigger Logic**
  - Behavior Peak: `behaviorProbs["play"] > 0.8`
  - Risk Event: `risk_score > 0.7`
  - 과거 10초 + 향후 20초 저장 → `POST /clips`

### 3-2. Clip Processing (backend/)
- [ ] **Upload API** (routers/clips.py)
  - `POST /clips`: 파일 수신 → MinIO 저장 → clips 테이블
- [ ] **Embedding Worker** (workers/embed_clips.py)
  - VideoMAE/CLIP로 임베딩 추출 → Milvus 저장

### 3-3. Analytics API (backend/agent/)
- [ ] **Time-Series Queries**
  - `/analytics/dog_timeseries`: dog_id, metric, 기간 → {timestamps, values}
  - `/analytics/pair_timeseries`: (dog_i, dog_j), metric → 시계열
  - `/analytics/risk_peaks`: 대상, 기간 → 상위 risk_events

---

## 🤖 Phase 4: LLM Agent

**목표**: LLM 기반 대화형 분석 에이전트를 구축합니다.

### 4-1. LLM Serving (backend/llm/)
- [ ] **HuggingFace 로컬 LLM 서빙** (local_model.py)
  - 한국어 인스트럭션 모델 선택
  - gRPC/HTTP API 제공

### 4-2. Agent Components (backend/agent/)
- [ ] **Planner**
  - 사용자 질문 → Plan JSON (time_range, targets, metrics)
- [ ] **Analyzer (Data)**
  - Plan 기반 `/analytics/*` 호출
  - Pandas/NumPy 통계 처리
- [ ] **Analyzer (Expert)**
  - 통계 + 도메인 프롬프트 → 해석 생성
- [ ] **Presenter**
  - 응답 포맷: summary, charts (Chart.js), stats, clips (Evidence)

### 4-3. GPT Teacher (10% Sampling)
- [ ] **외부 GPT 연동**
  - 동일 질의 10번 중 1번만 GPT 호출
  - GPT 응답을 teacher label로 저장

---

## 🏷️ Phase 5: VLM Auto-Labeling (Gemini 2.5 Pro)

**목표**: Gemini 2.5 Pro를 사용한 자동 라벨링 파이프라인을 구축합니다.

### 5-1. Annotation Schema (docs/vl_annotation_schema.md)
- [ ] **스키마 정의**
  - Fields: clip_id, caption, scene_tags, per_dog (behavior, emotion), interaction, risk_estimate

### 5-2. VLM Labeler Service (backend/services/)
- [ ] **Gemini 2.5 Pro 호출 유틸** (vl_labeler.py)
  - 입력: 클립/썸네일 + 프롬프트
  - 출력: 구조화된 JSON
  - Rate limit, 재시도 처리
- [ ] **샘플링 로직** (hard_miner.py)
  - Low-confidence, 사용자 피드백, 규칙 충돌 구간 선별
  - vl_label_queue 적재
- [ ] **Annotation 저장** (vl_annotations 테이블)
  - id, clip_id, raw_response (JSONB), normalized (JSONB)

### 5-3. Label Export (ai-models/datasets/)
- [ ] **VLM → Internal 매핑** (vl_to_internal_mapper.py)
  - per_dog.behavior → behavior 라벨
  - interaction → pair_relations/risk_events 라벨
- [ ] **학습 데이터 Export** (export_vlm_labels.py)
  - vl_annotations → 모델별 학습 포맷

---

## 🔄 Phase 6: On-Device Migration & Data Flywheel

**목표**: VLM이 생성한 데이터로 온디바이스 모델을 학습하여 VLM을 교체하고, 지속적 개선 루프를 구축합니다.

### 6-1. Behavior & Stress 모델 학습 (ai-models/)

#### 6-1-1. Behavior Classifier
- [ ] **학습 데이터셋 준비** (ai-models/data/behavior/)
  - VLM 로그에서 추출: action 라벨 + bbox 궤적
  - 데이터 증강: 속도 조정, 노이즈 추가
- [ ] **모델 학습** (train_behavior.py)
  - 아키텍처: MLP (2~3 layers, 64~128 units) 또는 1D-CNN
  - 입력: N-프레임 bbox 이동, 속도, 방향
  - 출력: behavior_probs (play/rest/chase/avoid/freeze/face_off)
  - 손실: Cross-Entropy Loss
  - 학습 파라미터: batch_size=32, epochs=50~100, lr=1e-3
  - 목표: Validation accuracy > 85%
- [ ] **CoreML 변환** (export_behavior.py)
  - PyTorch → CoreML
  - Output: `BehaviorClassifier.mlmodel`

#### 6-1-2. Stress Proxy Head
- [ ] **학습 데이터셋 준비** (ai-models/data/stress/)
  - VLM 로그에서 추출: emotion 라벨
  - emotion → stress 매핑 라벨 생성
- [ ] **모델 학습** (train_stress.py)
  - 옵션 A: 규칙 기반 베이스라인
  - 옵션 B: 회귀 네트워크 (MSE Loss)
  - 입력: behavior_probs + 움직임 통계
  - 출력: stressProxy (0~1)
- [ ] **CoreML 변환** (export_stress.py)
  - Output: `StressProxy.mlmodel`

### 6-2. iOS 온디바이스 배포 (ios-app/)
- [ ] **BehaviorHead.swift** (Services/Vision/)
  - CoreML 모델 로드: `BehaviorClassifier.mlmodel`
  - `func predict(history: [DetectedObject]) -> [String: Float]`
  - DogState.behaviorProbs 업데이트
- [ ] **StressHead.swift** (Services/Vision/)
  - CoreML 모델 로드: `StressProxy.mlmodel`
  - `func predict(behaviorProbs, motionStats) -> Float`
  - DogState.stressProxy 업데이트
- [ ] **VLMStateMapper 제거 및 전환**
  - VLMStateMapper.swift 비활성화
  - StateBuilder에서 BehaviorHead, StressHead 호출로 변경:
    ```swift
    // Before (VLM 기반)
    let behaviorProbs = vlmMapper.behaviorProbs(from: vlmResponse)
    
    // After (온디바이스)
    let behaviorProbs = behaviorHead.predict(history: frameHistory)
    ```
- [ ] **VisionClient 비활성화**
  - OnAirView에서 VisionClient 호출 제거
  - YOLO → ReID → BehaviorHead → StressHead 파이프라인으로 완전 전환
- [ ] **통합 테스트**
  - 전체 파이프라인 검증
  - UI에서 behaviorProbs, stressProxy 실시간 표시 확인

### 6-3. Hard Example Mining
- [ ] **후보 선별** (backend/services/hard_miner.py)
  - Behavior/Relation/Risk 낮은 확신도
  - 규칙 vs 모델 불일치
  - 사용자 피드백 "틀림"
- [ ] **VLM 파이프라인 연결**
  - Hard examples → Gemini 2.5 Pro → vl_annotations

### 6-4. 지속적 모델 재학습 (ai-models/)
- [ ] **Dataset Builders**
  - VLM labels + Hard example labels → 학습 포맷
  - 기존 데이터 + 신규 데이터 병합
- [ ] **Incremental Training**
  - train_behavior.py, train_stress.py
  - 기존 weight + 신규 데이터 fine-tuning
  - A/B 테스트: 신규 모델 vs 기존 모델
  - 성능 향상 시만 배포
- [ ] **자동화 파이프라인**
  - 주기적(월 1회) 재학습 스케줄
  - 성능 모니터링 대시보드

### 6-5. QA LLM Fine-Tuning
- [ ] **Q/A Dataset 생성**
  - Analytics 결과 + VLM caption → (질문, 답변) 쌍
- [ ] **로컬 LLM 튜닝**
  - Q/A 데이터로 HF 모델 fine-tuning
- [ ] **GPT Distillation**
  - GPT 답변을 teacher label로 사용

---

## 📌 실행 가이드

**권장 순서 (사용자 기능 우선):**

### ✅ **Stage 1: MVP with VLM (사용자에게 완전한 기능 제공)**

1. **Priority 0**: Foundation Models (YOLO + ReID 준비)
2. **Priority 1**: iOS Data Structures 정의
3. **Priority 2**: iOS Vision Pipeline (YOLO + ReID만 구축)
4. **Phase 0 (Bootstrap - VLM로 모든 기능 제공)**:
   - VLM이 Behavior/Stress 데이터를 **직접 생성**
   - VisionResponse에 posture, action, emotion, health_signals 포함
   - 이 데이터를 DogState.behaviorProbs, stressProxy로 매핑
   - **State Packet 생성**: VLM 출력 → DeviceStatePacket (완전한 형태)
   - 데이터 저장: VLM 분석 결과를 로깅하여 나중에 모델 학습용으로 활용
5. **Priority 5**: iOS UI & Dual Mode (On Air UI, Bounding Box Overlay)
6. **Phase 2**: Backend Infrastructure (TimescaleDB, API)
7. **Phase 3**: Clip Recording & Analytics
8. **Phase 4**: LLM Agent (사용자 질의 응답)

**→ 이 시점에서 사용자는 완전한 서비스 이용 가능 (VLM 기반)**

### 🔄 **Stage 2: 백그라운드 최적화 (온디바이스 전환)**

9. **Phase 5**: VLM Auto-Labeling (Gemini 2.5 Pro로 추가 라벨링)
10. **Phase 6: Data Flywheel & On-Device Migration**:
    - **Step 1**: VLM이 생성한 데이터 큐레이션 (~10k+ 샘플)
    - **Step 2**: Behavior Classifier 학습 (ai-models/train_behavior.py)
    - **Step 3**: Stress Proxy Head 학습 (ai-models/train_stress.py)
    - **Step 4**: CoreML 변환 (export_behavior.py, export_stress.py)
    - **Step 5**: iOS 배포 (BehaviorHead.swift, StressHead.swift)
    - **Step 6**: State Packet Generation 온디바이스 전환
      - YOLO → ReID → **BehaviorHead** → **StressHead** → StateBuilder → EventUploader
    - **Step 7**: VLM 비활성화 (VisionClient 사용 중단)
    - **Step 8**: 지속적 모델 재학습 (Hard examples + VLM labels)

---

## 🔑 **핵심 의존성 및 전략**

### **Phase 0의 역할 (중요):**
```
Camera → YOLO → ReID → 태깅된 이미지 → VLM
                                        ↓
                            VisionResponse (posture, action, emotion)
                                        ↓
                            VLM → DogState 매핑:
                            • action → behaviorProbs (예: {"play": 0.8})
                            • emotion → stressProxy (예: 규칙 기반 0~1 매핑)
                                        ↓
                            DeviceStatePacket (완전한 형태)
                                        ↓
                            Backend 저장 + 로컬 로깅 (학습 데이터용)
```

### **VLM → DogState 매핑 예시:**
```swift
// VisionResponse (VLM 출력)
let response = VisionResponse(
    dogs: [
        DogAnalysis(
            name: "Buddy",
            posture: "sitting",
            action: "idle",      // ← behavior로 매핑
            emotion: "relaxed",  // ← stress로 매핑
            health_signals: ["none"]
        )
    ]
)

// DogState (DeviceStatePacket용)
let dogState = DogState(
    dogId: buddyUUID,
    bboxNorm: ...,
    behaviorProbs: ["idle": 1.0],  // VLM action → behavior
    stressProxy: 0.2               // VLM emotion "relaxed" → low stress
)
```

### **Stage 1 완료 시점:**
- ✅ 사용자는 실시간 강아지 모니터링 가능
- ✅ On Air 화면에서 강아지 이름, 행동, 감정 표시
- ✅ Chat에서 질문하면 차트 + 분석 + 클립 제공
- ✅ 모든 데이터는 VLM이 생성 (백그라운드에서 학습용 로깅)

### **Stage 2 목적:**
- 🎯 VLM API 비용 절감 (온디바이스 모델로 전환)
- 🎯 응답 속도 향상 (네트워크 불필요)
- 🎯 오프라인 동작 가능
- 🎯 지속적 모델 개선 (Data Flywheel)

### **병렬 작업 가능:**
- Backend 구축 (Phase 2)은 iOS Vision Pipeline (Priority 2) 완료 후 바로 시작 가능
- VLM Auto-Labeling (Phase 5)는 Phase 0 실행 중에도 병렬 진행 가능
- UI 작업 (Priority 5)은 Phase 0와 병렬 가능


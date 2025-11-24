# AI 통합 및 데이터 파이프라인 비전 (하이브리드 엣지-클라우드 + 블랙박스 + VLM)

## 🎯 프로젝트 비전
**MyDogCare**는 **멀티모달 반려견 메모리 서비스 (블랙박스 + 시계열 분석)**입니다.
온디바이스 AI(YOLO + ReID)를 사용하여 실시간으로 여러 마리의 강아지를 추적하고, 중요한 순간을 "증거 클립"으로 기록하며, 매초의 데이터를 구조화된 시계열로 저장합니다. 사용자는 자연어로 **차트, 전문가 분석, 증거 영상**을 함께 조회할 수 있습니다.

**핵심 아키텍처**:
*   **듀얼 디바이스 구성**:
    *   **카메라 디바이스 (Sender)**: 집에 두는 전용 iPhone으로 "On Air" 모드 실행 (YOLO + ReID + State Packet + Clip Trigger).
    *   **뷰어 디바이스 (Receiver)**: 사용자가 들고 다니는 개인 iPhone으로 채팅, 차트, 캘린더, 리포트 확인.
*   **블랙박스 메모리**: 단순 통계가 아닌 **시계열 팩트 + 비디오 증거**.
*   **AI 분석가**: 다중 전문가 에이전트 (데이터 분석가 + 수의사 + 행동학자)로 **차트**, **전문적 조언**, **증거 클립**을 제공.
*   **VLM (Gemini 2.5 Pro)**: 자동 라벨링 및 학습 데이터 생성용 (실시간 질의에는 직접 사용하지 않음).

---

## 🏗️ 아키텍처 개요

### 1. 온디바이스 (카메라 모드)
*   **역할**: 눈 & 반사신경.
*   **기술 스택**: CoreML (YOLOv11/v12), Swift, **DeepSORT**, ReID, 경량 Behavior/Stress 헤드.
*   **파이프라인**:
    1.  **감지 및 추적**: 
        *   **YOLO 감지**: YOLOv11-nano로 강아지 감지
        *   **DeepSORT 추적**: 강력한 추적을 위한 2단계 파이프라인
            *   **1단계**: Kalman Filter + IoU 매칭 (ReID 없음)
            *   **2단계**: 선택적 ReID (미확정 트랙만)
            *   **3단계**: Temporal Voting으로 최종 업데이트 (10프레임 확정)
            *   **결과**: 신원 확정 후 99% ReID 절감
    2.  **행동 및 스트레스 분석**: 경량 온디바이스 모델:
        *   **행동 분류기**: 최근 프레임 히스토리(bbox 궤적, 속도, 방향)를 분석하여 행동 확률 예측.
        *   **스트레스 프록시 헤드**: 행동 패턴 및 움직임 통계로부터 스트레스 수준 (0~1) 추정.
    3.  **상태 로깅**: 매초 `DeviceStatePacket` 생성:
        *   `dogs: [DogState]` — 정규화된 bbox, 속도, 방향, 행동 확률, 스트레스 수치.
        *   `relations: [PairState]` — 강아지 쌍 간 거리, 친화도, 긴장도.
        *   `environment: EnvironmentState` — 조도, 데시벨, 혼잡도.
    4.  **클립 트리거 (블랙박스)**:
        *   **행동 피크**: 놀이/추격 확률 급상승 (> 0.8).
        *   **관계 변화**: 긴장도 또는 친화도 급변.
        *   **위험 이벤트**: `risk_score` 임계치 초과.
    4.  **업로드**: 상태 패킷(10초마다 배치) 및 증거 클립(MP4)을 서버로 전송.

### 2. 백엔드 서버 (기억)
*   **역할**: 중앙 집중식 저장 및 인덱싱.
*   **기술 스택**: Python (FastAPI), TimescaleDB, S3/MinIO, Vector DB (Milvus), Redis.
*   **데이터 저장소**:
    *   **사실 (TimescaleDB Hypertables)**:
        *   `dog_states`: 개별 강아지 시계열 (bbox, 속도, 행동, 스트레스).
        *   `pair_relations`: 강아지 쌍 시계열 (거리, 친화도, 긴장도).
        *   `risk_events`: 감지된 위험 사건.
    *   **증거 (S3/MinIO)**: 비디오 클립(`.mp4`) 및 썸네일.
    *   **의미 (Vector DB)**: 의미론적 검색을 위한 클립 임베딩.

### 3. LLM 레이어 (두뇌)
*   **역할**: 계획(Planner), 분석(Analyzer - 데이터+수의학+행동학), 발표(Presenter).
*   **워크플로우**:
    1.  **Planner**: 사용자 질문 -> 검색 계획 (시간 범위, 필터, 메트릭, 의미론적 쿼리).
    2.  **Analyzer (Data)**: TimescaleDB SQL 실행으로 통계 집계 및 이상 징후 탐지.
    3.  **Analyzer (Expert)**: 수의학/행동학 지식으로 통계 해석.
    4.  **Analyzer (Evidence)**: Vector DB에서 진단을 뒷받침할 관련 비디오 클립 검색.
    5.  **Presenter**: 요약 + **차트 (Chart.js Spec)** + **증거 카드** (Top-3 클립) 생성.

### 4. VLM 레이어 (Gemini 2.5 Pro - "선생님")
*   **역할**: 자동 라벨링 및 학습 데이터 생성.
*   **워크플로우**:
    1.  **Hard Example Mining**: 낮은 신뢰도 감지 또는 흥미로운 클립 선택.
    2.  **VLM 주석**: Gemini 2.5 Pro에 구조화된 프롬프트로 요청:
        *   캡션, 장면 태그, 개별 강아지 행동/감정, 상호작용 유형, 위험 추정.
    3.  **라벨 저장**: Behavior/Relation/Risk 모델 및 QA LLM 파인튜닝용 학습 데이터로 저장.
    4.  **지속적 개선**: 축적된 라벨로 분기별 모델 재학습.

---

## 📊 상세 데이터 전략 요약

### 온디바이스 데이터 구조
*   `DetectedObject`: YOLO 출력 (bbox, confidence, trackId - DeepSORT 트랙 ID, embedding - 2048d 벡터, dogId - 확정 신원, dogName - 강아지 이름).
*   `DogState`: 정규화된 상태 (bbox, 속도, 행동 확률, 스트레스).
*   `PairState`: 강아지 쌍 관계 (거리, 친화도, 긴장도).
*   `DeviceStatePacket`: 매초 생성되는 종합 패킷.

### 서버 데이터 스키마 (TimescaleDB)
*   `dog_states` (Hypertable): 개별 강아지 시계열.
*   `pair_relations` (Hypertable): 강아지 쌍 관계 시계열.
*   `risk_events`: 위험 사건 기록.
*   `clips`: 증거 영상 메타데이터.

---

## 🚀 구현 로드맵 (요약)

### Phase 0: Bootstrap (VLM 데이터 수집) - **초기 1달**
**목적**: Behavior/Stress 모델 학습을 위한 데이터를 VLM 실시간 사용으로 수집.
*   **강화된 파이프라인**: 카메라 → **YOLO 감지** → **ReID 식별** → 태깅된 이미지 스트리밍 → 5 프레임 → VLM 분석
    *   **이유**: VLM에게 사전 식별된 강아지 정보(name, bbox)를 컨텍스트로 제공하여 더 정확한 행동 분석.
    *   **구현**: OnAirView가 YOLO+ReID 처리 후 감지된 강아지 이름을 이미지에 오버레이, 태깅된 프레임을 VisionClient로 전송.
*   **VLM 사용**: 기존 `VisionClient.swift`가 태깅된 프레임 분석 및 `VisionResponse` 출력 (posture, action, emotion).
*   **데이터 로깅**: VLM 분석 결과를 `vlm_analysis_{date}.jsonl` 형태로 저장 및 백엔드 업로드.
*   **백엔드 저장**: TimescaleDB `vlm_training_samples` 테이블 + S3/MinIO 이미지.
*   **큐레이션**: Low-confidence 필터링, 중복 제거, ~10k 학습 샘플 준비.
*   **전환**: 1달 후 → Behavior/Stress 모델 학습 → 디바이스 배포 → VLM 비활성화.

### Priority 0: 온디바이스 지능 (카메라 모드)
*   **핵심 모델**: 
    *   **YOLO**: YOLOv11/v12-nano 객체 감지 (CoreML)
    *   **DeepSORT 추적기**: 고급 다중 객체 추적
        *   **KalmanFilter**: 위치 예측을 위한 상수 속도 모델
        *   **Track**: Temporal Voting을 사용한 개별 트랙 관리
        *   **2단계 파이프라인**: IoU 매칭 → 선택적 ReID → 최종 업데이트
        *   **성능**: 10프레임 확정 후 99% ReID 절감
    *   **ReID**: ResNet50 특징 추출기 (CoreML, Int8 양자화)
        *   **강력한 매칭**: Voting (Top-3) + Margin Check (5%)
        *   **최적화**: 확정 트랙은 ReID 건너뛰기
    *   **행동 분류기**: 경량 MLP/1D-CNN 행동 분류
        *   입력: 최근 N프레임 bbox 궤적 (모션 벡터)
        *   출력: `behaviorProbs` - {"play": 0.8, "rest": 0.1, "chase": 0.05, ...}
        *   구현 위치: `Services/Vision/BehaviorHead.swift`
    *   **스트레스 프록시 헤드**: 소형 회귀 모델
        *   입력: 행동 확률 + 움직임 통계
        *   출력: `stressProxy` (0~1)
        *   구현: 간단한 MLP 또는 규칙 기반 + 보정 네트워크
*   **데이터 구조**: `DetectedObject`, `DogState`, `PairState`, `DeviceStatePacket`.
*   **상태 파이프라인**: YOLO -> DeepSORT (IoU → ReID → Update) -> Behavior/Stress Head -> StateBuilder -> EventUploader.

### Phase 1: 로컬 기반 & 듀얼 모드
*   **듀얼 모드 UI**: 카메라 모드 vs 뷰어 모드 전환기.
*   **강아지 프로필 동기화**: 백엔드와 Up/Down 동기화.
*   **On Air UI**: 라벨 및 액션이 포함된 바운딩 박스 오버레이.

### Phase 2: 백엔드 인프라 (기억)
*   **서버 설정**: FastAPI + Docker Compose (TimescaleDB, Milvus, MinIO, Redis).
*   **데이터베이스 스키마**: `dog_states` 및 `pair_relations` Hypertables.
*   **수집 API**: 비동기 대량 삽입을 사용하는 `POST /events/batch`.

### Phase 3: 지능 (두뇌)
*   **클립 녹화**: 트리거 기반 녹화가 포함된 순환 버퍼.
*   **분석 API**: 차트용 시계열 쿼리.
*   **LLM 에이전트**: Planner + Analyzer (Data + Expert) + Presenter.

### Phase 3.5: VLM 자동 라벨링 (Gemini 2.5 Pro)
*   **주석 스키마**: 클립을 위한 구조화된 JSON 라벨.
*   **Hard Example Mining**: 불확실한 감지 선택.
*   **학습 데이터 루프**: 라벨 저장 -> 모델 재학습.

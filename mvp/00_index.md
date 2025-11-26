# MVP Stage 1: On-Air 기능 업그레이드 - 전체 계획

## 목표
Camera → YOLO → ReID → 태깅된 이미지 → VLM → VisionResponse → DogState 매핑 → DeviceStatePacket 생성

**핵심 가치**: 사용자가 On Air 화면에서 실시간으로 강아지의 이름, 행동, 감정을 볼 수 있고, 모든 데이터가 백엔드에 저장되어 Chat에서 질의 가능.

---

## 📋 전체 작업 순서

### ✅ 완료된 작업
- [x] **YOLO 모델 준비** (yolo11n.mlpackage)
- [x] **ReID 모델 준비** (ResNet50_ReID.mlmodel)
- [x] **VisionClient 구현** (Services/ModelRegistry.swift)
- [x] **기본 OnAirView** (Views/OnAirView.swift)

### 🚧 진행할 작업 (MVP Stage 1)

1. **✅ [mvp/01_yolo_reid_integration](./01_yolo_reid_integration/)** - YOLO + ReID 통합 (완료)
2. **✅ [mvp/02_vlm_tagged_input](./02_vlm_tagged_input/)** - VLM에 태깅된 이미지 전달 (완료)
3. **✅ [mvp/03_vlm_state_mapper](./03_vlm_state_mapper/)** - VLM → DogState 매핑 (완료)
4. **✅ [mvp/04_state_packet_builder](./04_state_packet_builder/)** - State Packet 생성 (완료)
5. **✅ [mvp/05_event_uploader](./05_event_uploader/)** - 백엔드 전송 (완료)
6. **[mvp/06_onair_ui_upgrade](./06_onair_ui_upgrade/)** - On-Air UI 업그레이드 (대기)

---

## 📊 데이터 흐름

```
Camera Frame (CVPixelBuffer)
    ↓
YOLOClient.predict()
    ↓
[DetectedObject] (bbox, confidence)
    ↓
DeepSortTracker.matchWithoutReID() (Phase 1: IoU 매칭)
    ↓
ReIDTracker.identify() (Phase 2: 필요한 것만 실행)
    ↓
DeepSortTracker.finalizeWithReID() (Phase 3: 최종 업데이트)
    ↓
[DetectedObject with trackId, dogId, dogName] (추적 + 신원 확정)
    ↓
이미지에 강아지 이름 오버레이 (draw text on image)
    ↓
VisionClient.analyzeStream(taggedImages: [UIImage])
    ↓
VisionResponse (posture, action, emotion)
    ↓
VLMStateMapper.mapToDogState()
    ↓
DogState (behaviorProbs, stressProxy)
    ↓
StateBuilder.build() + PairBuilder.build()
    ↓
DeviceStatePacket (완전한 형태)
    ↓
EventUploader.upload() → POST /events/batch
```

---

## 🔑 핵심 의존성

### iOS 내부
- **Models**: DetectedObject, DogState, PairState, DeviceStatePacket
- **Services**: YOLOClient, DeepSortTracker, KalmanFilter, Track, ReIDTracker, VisionClient, VLMStateMapper, StateBuilder, EventUploader
- **Views**: OnAirView, OverlayView

### 참고 문서
- [Project Roadmap](../docs/project_roadmap_new.md) - 전체 프로젝트 계획
- [AI Integration Plan](../ai_integration_plan.md) - 아키텍처 개요
- [Vision Pipeline Plans](../ios-app/MyDogCare/docs/plan/) - YOLO/ReID 구현 가이드

---

## 🎯 성공 기준

### Stage 1 완료 시:
1. ✅ On-Air 화면에서 실시간으로 강아지 이름이 바운딩 박스 위에 표시
2. ✅ 각 강아지의 행동 ("Playing", "Resting" 등) 표시
3. ✅ (옵션) 감정 아이콘 (😊 relaxed, 😰 anxious 등) 표시
4. ✅ 매초 DeviceStatePacket이 생성되어 로컬 로그에 저장
5. ✅ 10초마다 배치로 백엔드에 업로드
6. ✅ 네트워크 오류 시 로컬에 임시 저장 후 재시도

### 테스트 시나리오:
- [ ] 강아지 1마리 감지: 이름, 행동, 감정 표시
- [ ] 강아지 2마리 감지: 각각 구분되어 표시
- [ ] 등록되지 않은 강아지: "Unknown Dog" 표시
- [ ] 네트워크 끊김: 로컬 저장 → 복구 시 자동 업로드

---

## 📁 디렉터리 구조

```
mvp/
├── 00_index.md                  (이 파일)
├── 01_yolo_reid_integration/
│   └── plan.md
├── 02_vlm_tagged_input/
│   └── plan.md
├── 03_vlm_state_mapper/
│   └── plan.md
├── 04_state_packet_builder/
│   └── plan.md
├── 05_event_uploader/
│   └── plan.md
└── 06_onair_ui_upgrade/
    └── plan.md
```

---

## 🚀 시작하기

**권장 순서대로 진행하세요:**
1. 각 디렉터리의 `plan.md` 파일을 순서대로 읽고 이해
2. 참고 문서와 기존 코드를 확인
3. 체크리스트를 따라 구현
4. 각 단계 완료 후 다음 단계로 진행

**병렬 작업 가능:**
- Step 01-02는 순차적으로 진행
- Step 03-04는 02 완료 후 병렬 가능
- Step 05는 04 완료 후 진행
- Step 06은 전체 완료 후 UI 통합

**예상 소요 시간:**
- Step 01: 2-3시간
- Step 02: 1-2시간
- Step 03: 2-3시간
- Step 04: 3-4시간
- Step 05: 2-3시간
- Step 06: 2-3시간
- **Total: ~15시간** (테스트 포함)

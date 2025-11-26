# 아키텍처 문서 - AI Models

## 개요
MyDogCare의 AI 모델 개발 및 배포를 위한 파이프라인 아키텍처

## 시스템 아키텍처

### 컴포넌트 다이어그램
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   PyTorch      │    │     ONNX         │    │    CoreML       │
│   Models        │───▶│   Intermediate   │───▶│   Deployment     │
│                 │    │   Format         │    │   Format         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   YOLOv11       │    │   ResNet50       │    │   iOS Apps       │
│   (Detection)   │    │   (ReID)         │    │   (Inference)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 핵심 컴포넌트

### 1. 모델 학습 파이프라인
- **YOLOv11-nano**: 실시간 객체 탐지 모델
- **ResNet50**: 개체 재식별(ReID) 특징 추출기
- **Behavior Classifier**: 행동 분류 모델 (향후)
- **Stress Proxy**: 스트레스 추정 모델 (향후)

### 2. 모델 변환 파이프라인
- **PyTorch → ONNX**: 프레임워크 독립성 확보
- **ONNX → CoreML**: iOS 최적화
- **최적화 기법**: 
  - 양자화 (Int8 for ReID)
  - FP16 (YOLO)
  - NMS 내장 (YOLO)

### 3. 배포 파이프라인
- **자동화**: 스크립트 기반 변환
- **버전 관리**: 모델 버전 추적
- **검증**: 변환 후 정확도 검증

## 기술 스택

### 개발 환경
| 기술 | 버전 | 용도 |
|------|------|------|
| Python | 3.11+ | 개발 언어 |
| PyTorch | 2.2.2 | 모델 학습 |
| Ultralytics | 8.3.230+ | YOLO 프레임워크 |
| CoreML Tools | 9.0 | 모델 변환 |
| ONNX | 1.16.0+ | 중간 포맷 |

### 모델 최적화
| 기법 | 대상 | 효과 |
|------|------|------|
| Int8 양자화 | ReID | 4x 크기 감소 |
| FP16 변환 | YOLO | 메모리 절약 |
| NMS 내장 | YOLO | 추론 속도 향상 |
| Pruning | 전체 | 모델 경량화 |

## 데이터 흐름

### 1. 학습 데이터 흐름
```
원본 데이터셋 → 전처리 → 데이터 증강 → 모델 학습 → 검증
```

### 2. 모델 배포 흐름
```
학습된 모델 → ONNX 변환 → CoreML 변환 → iOS 앱 통합
```

### 3. 추론 데이터 흐름
```
카메라 프레임 → YOLO 탐지 → ReID 식별 → 상태 분석
```

## 성능 요구사양

### 모델 성능
| 모델 | 입력 크기 | 정확도 | 속도 | 크기 |
|------|----------|--------|------|------|
| YOLOv11-nano | 640x640 | mAP@0.5 | 30+ FPS | ~20MB |
| ResNet50-ReID | 224x224 | Top-1 | 100+ FPS | ~25MB |

### 하드웨어 요구사양
- **학습**: CUDA 지원 GPU (권장)
- **변환**: CPU 8GB+ RAM
- **추론**: iOS Neural Engine (A12+)

## 개발 워크플로우

### 1. 모델 개발 단계
```bash
# 1. 환경 설정
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 2. 모델 학습
python train_yolo.py --data dogs.yaml --epochs 100
python train_reid.py --dataset dog_reid

# 3. 모델 변환
python export_yolo.py
python export_reid.py
```

### 2. 검증 단계
```bash
# 정확도 검증
python validate_models.py

# 속도 테스트
python benchmark_inference.py
```

### 3. 배포 단계
```bash
# CoreML 모델 생성
python export_yolo.py  # yolo11n.mlpackage
python export_reid.py  # ResNet50_ReID.mlmodel

# iOS 앱에 복사
cp *.mlmodel ../ios-app/Resources/Models/
```

## 모델 관리

### 버전 관리
- **모델 버전**: v1.0.0 형식
- **체크포인트**: 학습 중간 결과 저장
- **메타데이터**: 모델 성능 기록

### 모델 레지스트리
```python
# ModelRegistry 예시
models = {
    "yolo_v11": {
        "version": "1.0.0",
        "path": "yolo11n.mlpackage",
        "accuracy": 0.85,
        "size": "20MB"
    },
    "reid_resnet50": {
        "version": "1.0.0", 
        "path": "ResNet50_ReID.mlmodel",
        "accuracy": 0.92,
        "size": "25MB"
    }
}
```

## 품질 보증

### 1. 모델 검증
- **정확도 테스트**: 테스트셋 기반 평가
- **속도 벤치마크**: 실기기 성능 측정
- **메모리 사용**: RAM/VRAM 사용량 모니터링

### 2. 변환 검증
- **추론 일치성**: PyTorch vs CoreML 결과 비교
- **성능 저하**: 변환 후 성능 변화 측정
- **호환성**: iOS 버전 호환성 확인

## 문제 해결

### 일반적인 문제
1. **모델 변환 실패**
   - 원인: 버전 호환성 문제
   - 해결: CoreML Tools 버전 확인

2. **성능 저하**
   - 원인: 양자화로 인한 정확도 손실
   - 해결: 양자화 파라미터 튜닝

3. **메모리 부족**
   - 원인: 대용량 모델 로딩
   - 해결: 모델 경량화 또는 배치 처리

## 향후 개선 방향

### 1. 자동화 강화
- CI/CD 파이프라인 통합
- 자동 모델 성능 모니터링
- 자동 배포 시스템

### 2. 성능 최적화
- 모델 압축 기법 적용
- 하드웨어 가속 최적화
- 추론 파이프라인 최적화

### 3. 확장성
- 다중 모델 지원
- A/B 테스트 프레임워크
- 실시간 모델 업데이트
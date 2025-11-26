# 통합 아키텍처

## 개요
MyDogCare의 4개 부분(ai-models, backend, ios-app, mvp) 간의 통합 아키텍처

## 통합 지점

### 1. AI 모델 → iOS 앱
**타입**: 모델 배포
**프로토콜**: 파일 기반 배포

#### 흐름
```
ai-models/export_yolo.py → yolo11n.mlpackage
ai-models/export_reid.py → ResNet50_ReID.mlmodel
                              ↓
                    수동으로 iOS 프로젝트에 복사
                              ↓
            ios-app/Resources/Models/ (Core ML 모델)
```

#### 상세 정보
- **모델 형식**: CoreML (.mlmodel, .mlpackage)
- **배포 방식**: 수동 파일 복사
- **버전 관리**: 현재 자동화되지 않음
- **용량**: YOLO(~20MB), ReID(~25MB, Int8 양자화)

#### 개선 필요사항
- 자동화된 모델 배포 파이프라인
- 버전 관리 시스템
- 모델 업데이트 확인 메커니즘

### 2. iOS 앱 → 백엔드
**타입**: REST API
**프로토콜**: HTTP/JSON

#### 흐름
```
ios-app/Services/Network/EventUploader.swift
                              ↓ HTTP POST
backend/routers/events.py (/events/batch)
                              ↓
                    DuckDB (dog_states, pair_relations)
```

#### 상세 정보
- **엔드포인트**: `POST /events/batch`
- **데이터 형식**: DeviceStatePacket 배열
- **전송 주기**: 1초 간격 (실시간)
- **오프라인 지원**: 버퍼링 및 재전송

#### API 계약
```typescript
interface DeviceStatePacket {
  timestamp: string;
  deviceId: string;
  sessionId: string;
  dogs: DogState[];
  relations?: PairRelation[];
  environment?: EnvironmentData;
}
```

### 3. 백엔드 → AI 서비스
**타입**: LLM API 호출
**프로토콜**: HTTP/JSON

#### 흐름
```
사용자 질의 → backend/routers/chat.py
                              ↓ LLM API 호출
NVIDIA API (Qwen3-Next-80B)
                              ↓
           SQL 생성 → DuckDB 쿼리 → 결과 분석
```

#### 상세 정보
- **LLM**: Qwen3-Next-80B (NVIDIA API)
- **도구**: SQL 실행 도구 등록
- **데이터베이스**: DuckDB 시계열 데이터
- **기능**: 자연어 → SQL → 분석 결과

### 4. MVP → 전체 시스템
**타입**: 문서화 및 계획
**프로토콜**: Markdown 문서

#### 흐름
```
mvp/00_index.md → 전체 개발 로드맵
mvp/*/plan.md → 단계별 구현 계획
                              ↓
                개발 방향성 및 우선순위 제공
```

## 데이터 흐름 아키텍처

### 실시간 데이터 파이프라인
```
iOS 카메라 → VisionService → YOLO/ReID → 상태 분석
                              ↓
                    EventUploader → HTTP POST
                              ↓
                    Backend API → DuckDB 저장
                              ↓
                    시계열 데이터 축적
```

### AI 분석 파이프라인
```
사용자 질의 → Chat API → LLM → SQL 생성
                              ↓
                    DuckDB 쿼리 실행 → 데이터 분석
                              ↓
                    자연어 응답 + 시각화 데이터
```

## 기술 통합 상세

### 1. 모델 통합
| 구성요소 | 기술 | 역할 |
|---------|------|------|
| YOLO | PyTorch → CoreML | 실시간 객체 탐지 |
| ReID | PyTorch → CoreML | 개체 재식별 |
| 배포 | 수동 파일 복사 | iOS 앱에 모델 통합 |

### 2. API 통합
| 구성요소 | 기술 | 역할 |
|---------|------|------|
| 통신 프로토콜 | HTTP/JSON | REST API 통신 |
| 데이터 형식 | DeviceStatePacket | 구조화된 데이터 전송 |
| 오류 처리 | 재시도 로직 | 네트워크 장애 대응 |

### 3. AI 통합
| 구성요소 | 기술 | 역할 |
|---------|------|------|
| LLM | Qwen3-Next-80B | 자연어 이해 |
| 도구 실행 | SQL Executor | 데이터베이스 쿼리 |
| 데이터베이스 | DuckDB | 시계열 데이터 분석 |

## 보안 고려사항

### 1. API 보안
- **현재 상태**: 인증 없음
- **필요 사항**: API 키, JWT 토큰
- **구현 계획**: Clerk 인증 서비스 통합

### 2. 데이터 전송 보안
- **현재 상태**: HTTP 평문 전송
- **필요 사항**: HTTPS 암호화
- **구현 계획**: TLS/SSL 적용

### 3. 모델 보안
- **현재 상태**: 앱 번들에 포함
- **필요 사항**: 모델 암호화, 난독화
- **구현 계획**: 모델 파일 보호

## 성능 최적화

### 1. 데이터 전송
- **배치 처리**: 여러 패킷을 한 번에 전송
- **압축**: JSON 데이터 압축 고려
- **캐싱**: 반복 데이터 전송 최소화

### 2. AI 추론
- **모델 최적화**: Int8 양자화, FP16
- **프레임 스트라이딩**: 매 프레임 처리 방지
- **배치 추론**: 여러 프레임을 한 번에 처리

### 3. 데이터베이스
- **인덱싱**: 시계열 데이터 쿼리 최적화
- **파티셔닝**: 대용량 데이터 분할 저장
- **압축**: 오래된 데이터 압축 저장

## 장애 처리 및 복원

### 1. 네트워크 장애
- **오프라인 모드**: 로컬 데이터 저장
- **재전송 로직**: 네트워크 복구 시 데이터 전송
- **동기화**: 온라인 시 데이터 일치 확인

### 2. 모델 장애
- **폴백 모델**: 기본 모델 제공
- **다운로드**: 원격 모델 다운로드
- **검증**: 모델 무결성 검사

### 3. 서비스 장애
- **헬스 체크**: 서비스 상태 모니터링
- **장애 알림**: 사용자에게 상태 알림
- **부분 기능**: 핵심 기능만 제공

## 향후 개선 방향

### 1. 자동화
- CI/CD 파이프라인 구축
- 자동 모델 배포
- 자동 테스트 및 배포

### 2. 확장성
- 마이크로서비스 아키텍처
- 로드 밸런싱
- 데이터베이스 클러스터링

### 3. 모니터링
- 실시간 성능 모니터링
- 로그 집계 및 분석
- 알림 시스템 강화
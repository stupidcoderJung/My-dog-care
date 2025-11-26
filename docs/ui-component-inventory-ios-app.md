# UI 컴포넌트 인벤토리 - iOS App

## 개요
SwiftUI 기반 MyDogCare iOS 애플리케이션의 UI 컴포넌트 구조

## 뷰 컴포넌트 분류

### 1. 메인 네비게이션
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| MainView | `Views/MainView.swift` | 앱의 메인 탭 네비게이션 | ✅ 구현됨 |
| ContentView | `ContentView.swift` | 루트 뷰 컨테이너 | ✅ 구현됨 |

### 2. 강아지 관리
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| DogListView | `Views/DogListView.swift` | 강아지 목록 표시 | ✅ 구현됨 |
| DogDetailView | `Views/DogDetailView.swift` | 강아지 상세 정보 | ✅ 구현됨 |
| AddDogView | `Views/AddDogView.swift` | 강아지 추가 | ✅ 구현됨 |
| AsyncAvatarView | `Views/AsyncAvatarView.swift` | 비동기 아바타 이미지 | ✅ 구현됨 |

### 3. 케어 및 캘린더
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| CareCalendarView | `Views/CareCalendarView.swift` | 케어 캘린더 | ✅ 구현됨 |
| AddCareEventSheet | `Views/AddCareEventSheet.swift` | 케어 이벤트 추가 | ✅ 구현됨 |

### 4. AI 채팅 및 분석
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| ChatView | `Views/ChatView.swift` | AI 채팅 인터페이스 | ✅ 구현됨 |
| GraphWebView | `Views/GraphWebView.swift` | 데이터 시각화 | ✅ 구현됨 |

### 5. 컴퓨터 비전
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| OnAirView | `Views/OnAirView.swift` | 실시간 모니터링 | ✅ 구현됨 |
| DetectionOverlay | `Views/Vision/DetectionOverlay.swift` | 객체 탐지 오버레이 | ✅ 구현됨 |

### 6. 유틸리티
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| SettingsView | `Views/SettingsView.swift` | 앱 설정 | ✅ 구현됨 |
| LoadingView | `Views/LoadingView.swift` | 로딩 인디케이터 | ✅ 구현됨 |
| ImagePicker | `Views/ImagePicker.swift` | 이미지 선택 | ✅ 구현됨 |

## 뷰모델

### 뷰모델 컴포넌트
| 컴포넌트 | 파일 | 용도 | 상태 |
|-----------|------|------|------|
| AuthViewModel | `ViewModels/AuthViewModel.swift` | 인증 상태 관리 | ✅ 구현됨 |

## 서비스 레이어

### 비즈니스 로직 서비스
| 서비스 | 파일 | 용도 | 상태 |
|--------|------|------|------|
| CameraManager | `Services/CameraManager.swift` | 카메라 제어 | ✅ 구현됨 |
| ChatService | `Services/ChatService.swift` | 채팅 통신 | ✅ 구현됨 |
| ClerkAuthService | `Services/ClerkAuthService.swift` | 인증 서비스 | ✅ 구현됨 |
| DogPhotoStore | `Services/DogPhotoStore.swift` | 강아지 사진 저장 | ✅ 구현됨 |
| ModelRegistry | `Services/ModelRegistry.swift` | AI 모델 관리 | ✅ 구현됨 |

### 컴퓨터 비전 서비스
| 서비스 | 파일 | 용도 | 상태 |
|--------|------|------|------|
| VisionService | `Services/Vision/VisionService.swift` | 메인 비전 서비스 | ✅ 구현됨 |
| YOLOClient | `Services/Vision/YOLOClient.swift` | YOLO 객체 탐지 | ✅ 구현됨 |
| ReIDTracker | `Services/Vision/ReIDTracker.swift` | 개체 재식별 | ✅ 구현됨 |
| DeepSortTracker | `Services/Vision/Tracking/DeepSortTracker.swift` | 다중 객체 추적 | ✅ 구현됨 |
| KalmanFilter | `Services/Vision/Tracking/KalmanFilter.swift` | 움직임 예측 | ✅ 구현됨 |
| Track | `Services/Vision/Tracking/Track.swift` | 추적 상태 | ✅ 구현됨 |
| StatePacketBuilder | `Services/Vision/StatePacketBuilder.swift` | 상태 패킷 생성 | ✅ 구현됨 |
| PairBuilder | `Services/Vision/PairBuilder.swift` | 관계 분석 | ✅ 구현됨 |
| VLMStateMapper | `Services/Vision/VLMStateMapper.swift` | VLM 결과 매핑 | ✅ 구현됨 |
| ImageTagger | `Services/Vision/ImageTagger.swift` | 이미지 태깅 | ✅ 구현됨 |

### 네트워크 서비스
| 서비스 | 파일 | 용도 | 상태 |
|--------|------|------|------|
| EventUploader | `Services/Network/EventUploader.swift` | 이벤트 업로드 | ✅ 구현됨 |

## 데이터 모델

### Core Data 모델
| 모델 | 파일 | 용도 | 상태 |
|------|------|------|------|
| PersistenceController | `Models/PersistenceController.swift` | Core Data 관리 | ✅ 구현됨 |

### 데이터 구조체
| 모델 | 파일 | 용도 | 상태 |
|------|------|------|------|
| Dog | `Models/Dog.swift` | 강아지 데이터 | ✅ 구현됨 |
| DogState | `Models/DogState.swift` | 강아지 상태 | ✅ 구현됨 |
| DeviceStatePacket | `Models/DeviceStatePacket.swift` | 디바이스 상태 패킷 | ✅ 구현됨 |
| DetectedObject | `Models/DetectedObject.swift` | 탐지된 객체 | ✅ 구현됨 |
| EnvironmentState | `Models/EnvironmentState.swift` | 환경 상태 | ✅ 구현됨 |
| PairState | `Models/PairState.swift` | 강아지 관계 | ✅ 구현됨 |
| CareEvent | `Models/CareEvent.swift` | 케어 이벤트 | ✅ 구현됨 |
| ChatMessage | `Models/ChatMessage.swift` | 채팅 메시지 | ✅ 구현됨 |

## 디자인 시스템

### 색상 및 테마
- **AccentColor**: `Assets.xcassets/AccentColor.colorset/`
- **AppIcon**: `Assets.xcassets/AppIcon.appiconset/`

### 리소스
| 리소스 | 위치 | 용도 |
|--------|------|------|
| Core ML 모델 | `Resources/Models/` | YOLO, ReID 모델 |
| 에셋 | `Assets.xcassets/` | 이미지, 색상, 아이콘 |

## 아키텍처 패턴

### MVVM + Combine
- **Model**: Core Data + Swift 구조체
- **View**: SwiftUI 뷰
- **ViewModel**: Combine 기반 상태 관리
- **Service**: 비즈니스 로직 분리

### 의존성 주입
- 서비스들은 뷰모델과 뷰에 주입됨
- 프로토콜 기반 인터페이스 사용

### 상태 관리
- `@Published` 프로퍼티티 사용
- Combine 프레임워크로 반응형 프로그래밍
- Core Data를 통한 영속성

## 재사용 가능 컴포넌트

### 공통 UI 컴포넌트
1. **AsyncAvatarView**: 비동기 이미지 로딩
2. **LoadingView**: 로딩 상태 표시
3. **ImagePicker**: 이미지 선택 및 처리

### 비즈니스 로직 컴포넌트
1. **ModelRegistry**: AI 모델 생명주기 관리
2. **StatePacketBuilder**: 데이터 포맷팅
3. **EventUploader**: 오프라인 지원 업로드

## 향후 개선 사항

### 추가 필요 컴포넌트
1. **차트 컴포넌트**: 데이터 시각화 개선
2. **알림 컴포넌트**: 푸시 알림 처리
3. **설정 세부화**: 더 상세한 설정 옵션

### 코드 품질 개선
1. **단위 테스트**: 각 컴포넌트 테스트
2. **접근성**: VoiceOver 및 동적 타입 지원
3. **다크모드**: 시스템 테마 완전 지원
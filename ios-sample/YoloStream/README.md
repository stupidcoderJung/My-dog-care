# YoloStream iOS 앱 개요

## 1. Xcode 프로젝트 생성
1. Xcode에서 **App** 템플릿 선택 → Product Name을 `yolostream`으로 지정하면 현재 폴더 구조와 맞습니다.
2. Interface는 SwiftUI, Language는 Swift 선택.
3. 프로젝트를 `ios/YoloStream/yolostream` 경로로 저장했다면, 이 리포지토리 구조와 동일하게 유지됩니다.

## 2. CoreML 모델 추가
1. `python/export_coreml.py`로 생성한 `YOLO12n.mlpackage` (또는 `.mlmodel`)를 Xcode 프로젝트에 드래그하여 추가.
2. Targets에서 앱을 선택하고 “Add to targets” 체크.

## 3. 권한 설정
- `Info.plist`에 `NSCameraUsageDescription` 키와 사용자 안내 문구를 추가.

## 4. 소스 코드 구조
- `yolostreamApp.swift`: 앱 엔트리 포인트(`YoloStreamApp`).
- `ContentView.swift`: 카메라 프리뷰와 감지 오버레이.
- `CameraView.swift`, `CameraSessionCoordinator.swift`: 카메라 캡처 및 세션 관리.
- `YOLOProcessor.swift`: Vision + CoreML 추론 로직.
- `DetectionViewModel.swift`, `DetectionOverlayView.swift`: 감지 결과 상태 관리 및 UI 렌더링.
- `FrameRenderer.swift`, `FrameStreamingController.swift`, `MJPEGStreamServer.swift`: MJPEG 스트리밍 구현.

## 5. 빌드 설정
- “Signing & Capabilities”에서 개발자 계정을 연결.
- “Background Modes”에서 `Audio, AirPlay, and Picture in Picture`를 제외하고 기본값 유지(스트리밍 시 필요에 따라 조정).

## 6. 실행
- 실기기 연결 후 `Cmd + R`로 빌드/실행하여 카메라 권한을 허용.
- 추론 결과가 오버레이에 표시되는지 확인.
- 동일 Wi-Fi에서 `http://<iPhone-로컬-IP>:8080/`으로 접속하면 라벨이 입혀진 MJPEG 스트림을 확인할 수 있습니다(브라우저 또는 VLC/ffmpeg 지원).

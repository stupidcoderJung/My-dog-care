# MyDogCare

SwiftUI 기반의 반려견 케어 앱 예제 프로젝트입니다. Clerk 인증 SDK를 사용하여 사용자를 인증하고, 간단한 로딩 화면, 메인 페이지, 설정 페이지를 제공합니다.

## 주요 화면

- **LoadingView**: Clerk 세션을 복원하거나 초기화할 때 표시되는 로딩 화면.
- **SignInView**: 이메일과 비밀번호로 Clerk 계정에 로그인할 수 있는 화면.
- **MainView**: 오늘의 일정과 활동 요약을 보여주는 메인 대시보드.
- **SettingsView**: 계정 정보, 기본 설정, 로그아웃 기능을 제공.

## Clerk 설정

1. [Clerk Dashboard](https://dashboard.clerk.com) 에서 iOS 애플리케이션을 생성하고 Publishable Key를 발급받습니다.
2. `MyDogCare/Services/ClerkAuthService.swift` 파일에서 `YOUR_PUBLISHABLE_KEY` 값을 실제 Publishable Key로 교체합니다.
3. Xcode에서 프로젝트를 열고 `Signing & Capabilities`에서 팀과 번들 식별자를 설정합니다.
4. 시뮬레이터 또는 기기에서 실행하면, 앱 시작 시 Clerk가 세션을 초기화하고 로그인 화면이 나타납니다.

## Swift Package Manager

프로젝트는 Clerk iOS SDK를 Swift Package Manager 의존성으로 사용하도록 설정되어 있습니다. Xcode 14 이상에서 프로젝트를 열면 패키지가 자동으로 받아집니다.

## 빌드 대상

- iOS 16.0 이상

## 참고

- 이 프로젝트는 예시 목적의 UI와 더미 데이터를 포함하고 있습니다.
- 실제 서비스에 사용할 때에는 알림, 데이터 저장 로직 등을 요구사항에 맞게 확장하세요.

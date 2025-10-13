# Stay AWAKE 🚗💤

졸음 감지 및 알림 시스템을 통해 안전한 운전을 도와주는 Flutter 앱입니다.

## 📱 주요 기능

- **실시간 졸음 감지**: 카메라를 통한 얼굴 인식 및 눈 깜빡임 분석 (EAR - Eye Aspect Ratio)
- **스마트워치 연동**: 심박수 데이터 기반 졸음 상태 분석
- **다단계 알림 시스템**: 깨어있음 → 졸음 → 잠듦 상태별 알림
- **경보음 알림**: 졸음 감지 시 즉각적인 경보음 출력
- **실시간 차트**: 심박수 데이터 시각화
- **백그라운드 실행**: 시스템 오버레이를 통한 백그라운드 모니터링

## 🛠 기술 스택

- **Framework**: Flutter 3.8.1+
- **State Management**: Provider
- **Camera**: camera 패키지
- **Audio**: 경보음 출력을 위한 오디오 시스템
- **Health Data**: health 패키지 (스마트워치 심박수 연동)
- **Charts**: fl_chart
- **Permissions**: permission_handler

## 📋 사전 요구사항

### 1. 개발 환경
- Flutter SDK 3.8.1 이상
- Dart SDK 포함
- Android Studio 또는 VS Code
- iOS 개발 시: Xcode (macOS만 해당)

### 2. 플랫폼별 최소 버전
- **Android**: API 21 (Android 5.0) 이상
- **iOS**: iOS 12.0 이상

## 🚀 설치 및 실행 방법

### 1. 저장소 클론
```bash
git clone https://github.com/your-username/stay_awake.git
cd stay_awake
```

### 2. Flutter 환경 확인
```bash
flutter doctor
```
> 모든 항목이 ✓ 표시되어야 합니다. 문제가 있다면 해결 후 진행하세요.

### 3. 종속성 설치
```bash
flutter pub get
```

### 4. 플랫폼별 설정

#### Android 설정
1. `android/app/src/main/AndroidManifest.xml` 권한 확인:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

2. 최소 SDK 버전 확인 (`android/app/build.gradle`):
```gradle
minSdkVersion 21
```

#### iOS 설정
1. `ios/Runner/Info.plist` 권한 추가:
```xml
<key>NSCameraUsageDescription</key>
<string>졸음 감지를 위해 카메라 접근이 필요합니다.</string>
<key>NSHealthShareUsageDescription</key>
<string>스마트워치 심박수 데이터 모니터링을 위해 Health 데이터 접근이 필요합니다.</string>
```

### 5. 앱 실행

#### 디버그 모드
```bash
# Android
flutter run

# iOS (macOS에서만 가능)
flutter run -d ios

# 특정 디바이스 선택
flutter devices  # 사용 가능한 디바이스 목록 확인
flutter run -d [device_id]
```

#### 릴리즈 빌드
```bash
# Android APK
flutter build apk --release

# iOS (macOS에서만 가능)
flutter build ios --release
```

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── providers/               # 상태 관리 (Provider 패턴)
│   ├── auth_provider.dart
│   └── drowsiness_provider.dart
├── screens/                 # 화면 위젯들
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   └── home_screen.dart
├── services/               # 비즈니스 로직 및 API
├── widgets/               # 재사용 가능한 위젯들
│   └── camera_preview_widget.dart
└── ...
```

## 🔧 개발 환경 설정

### VS Code 확장 프로그램 (권장)
- Flutter
- Dart
- Flutter Widget Snippets

### Android Studio 플러그인 (권장)
- Flutter
- Dart

## 📱 테스트

### 단위 테스트 실행
```bash
flutter test
```

### 통합 테스트 (디바이스 연결 필요)
```bash
flutter drive --target=test_driver/app.dart
```

## 🐛 문제 해결

### 자주 발생하는 문제들

#### 1. 카메라 권한 문제
- **해결방법**: 앱 설정에서 카메라 권한을 수동으로 허용

#### 2. iOS 시뮬레이터에서 카메라 미작동
- **해결방법**: 실제 디바이스에서 테스트 또는 시뮬레이터 모드 활성화

#### 3. 건강 데이터 연동 실패
- **Android**: Health Connect 앱 설치 및 권한 설정
- **iOS**: 건강 앱에서 권한 허용

#### 4. 빌드 오류 발생
```bash
# 클린 빌드
flutter clean
flutter pub get
flutter run
```

#### 5. 패키지 버전 충돌
```bash
# 종속성 업그레이드
flutter pub upgrade
```

## 🔐 권한 설정

앱 최초 실행 시 다음 권한들이 요청됩니다:

1. **카메라**: 얼굴 인식 및 졸음 감지
2. **건강 데이터**: 스마트워치 심박수 모니터링
3. **시스템 오버레이**: 백그라운드 알림

## 🤝 기여 방법

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 확인하세요.

## 📞 문의

프로젝트 관련 문의사항이나 버그 리포트는 GitHub Issues를 통해 남겨주세요.

---

**⚠️ 주의사항**
- 운전 중 사용 시 안전을 위해 미리 설정을 완료하고 시작하세요
- 본 앱은 보조 도구이며, 운전자의 주의력을 완전히 대체할 수 없습니다
- 실제 디바이스에서 테스트하는 것을 강력히 권장합니다

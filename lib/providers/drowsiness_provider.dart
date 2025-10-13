import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../services/camera_service.dart';
import '../services/face_analysis_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../overlay/overlay_launcher.dart';

enum DrowsinessLevel {
  awake,    // 깨어있음
  drowsy,   // 졸음
  sleeping  // 잠듦
}

enum OverlayMode { none, systemOverlay, inApp }

class HeartRateData {
  final DateTime time;
  final double value;

  HeartRateData(this.time, this.value);
}

class DrowsinessProvider with ChangeNotifier {
  bool _overlayActiveCache = false;
  OverlayMode _overlayMode = OverlayMode.none;
  OverlayMode get overlayMode => _overlayMode;
  bool get isSystemOverlay => _overlayMode == OverlayMode.systemOverlay;
  bool get isInAppOverlay => _overlayMode == OverlayMode.inApp;
  DrowsinessLevel _currentLevel = DrowsinessLevel.awake;
  bool _isMonitoring = false;
  bool _isCameraReady = false;
  bool _isWatchConnected = false;
  double _heartRate = 72.0;
  double _blinkRate = 15.0;
  double _drowsinessScore = 0.0;
  double _eyeAspectRatio = 0.5;
  int _alertCount = 0;
  DateTime? _sessionStartTime;
  List<HeartRateData> _heartRateHistory = [];

  // 카메라 관련 서비스
  final CameraService _cameraService = CameraService.instance;
  final FaceAnalysisService _faceAnalysisService = FaceAnalysisService.instance;

  // Getters
  DrowsinessLevel get currentLevel => _currentLevel;
  bool get isMonitoring => _isMonitoring;
  bool get isCameraReady => _isCameraReady;
  bool get isWatchConnected => _isWatchConnected;
  bool get isSimulatorMode => _cameraService.isSimulatorMode;
  double get heartRate => _heartRate;
  double get blinkRate => _blinkRate;
  double get drowsinessScore => _drowsinessScore;
  double get eyeAspectRatio => _eyeAspectRatio;
  int get alertCount => _alertCount;
  DateTime? get sessionStartTime => _sessionStartTime;
  List<HeartRateData> get heartRateHistory => _heartRateHistory;
  CameraController? get cameraController => _cameraService.controller;

  Future<void> resumeOverlayIfNeeded() async {
    if (_overlayMode == OverlayMode.systemOverlay && _isMonitoring) {
      await OverlayLauncher.ensureVisible();
    }
  }

  Future<bool> isSystemOverlayActive() async {
    try {
      final active = await FlutterOverlayWindow.isActive();
      _overlayActiveCache = active;
      return active;
    } catch (_) {
      return _overlayActiveCache;
    }
  }

  // 오버레이 시작 (Provider의 카메라/스트리밍엔 전혀 손대지 않음)
  Future<void> startSystemOverlay() async {
    final ok = await OverlayLauncher.ensureVisible(); // 이미 활성화면 ensureVisible
    _overlayActiveCache = ok;
    notifyListeners();
  }

// 오버레이 중지
  Future<void> stopSystemOverlay() async {
    await OverlayLauncher.closeOverlay();
    _overlayActiveCache = false;
    notifyListeners();
  }
  // 카메라 초기화
  Future<bool> initializeCamera() async {
    try {
      final success = await _cameraService.initializeCamera();
      _isCameraReady = success;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('카메라 초기화 실패: $e');
      _isCameraReady = false;
      notifyListeners();
      return false;
    }
  }

  // 모니터링 시작/중지
  Future<void> toggleMonitoring({bool useSystemOverlay = false}) async {
    if (!_isMonitoring) {
      if (useSystemOverlay) {
        // 1) 시스템 오버레이 모드 시작: 앱 내부 카메라는 반드시 꺼둠
        await _releaseCameraResources(); // 혹시 켜져있다면 정리
        _overlayMode = OverlayMode.systemOverlay;
        try {
          await OverlayLauncher.openOverlay();
          _isMonitoring = true;
          _sessionStartTime = DateTime.now();
          _alertCount = 0;
          _faceAnalysisService.reset();
          notifyListeners();
        } catch (e) {
          debugPrint('오버레이 시작 실패: $e');
          _overlayMode = OverlayMode.none;
        }
        return;
      } else {
        // 2) 기존 in-app 모니터링 시작 (현재 코드 그대로)
        debugPrint('졸음감지 시작 - 카메라 활성화');
        final cameraInitialized = await initializeCamera();
        if (!cameraInitialized) {
          debugPrint('카메라 초기화 실패로 모니터링을 시작할 수 없습니다.');
          return;
        }
        _overlayMode = OverlayMode.inApp;
        _isMonitoring = true;
        _sessionStartTime = DateTime.now();
        _alertCount = 0;
        _faceAnalysisService.reset();
        await _startDrowsinessDetection(); // 기존 함수
        notifyListeners();
        return;
      }
    } else {
      // === 중지 공통 ===
      debugPrint('졸음감지 중지');
      if (_overlayMode == OverlayMode.systemOverlay) {
        try {
          await OverlayLauncher.closeOverlay();
        } catch (e) {
          debugPrint('오버레이 닫기 실패: $e');
        }
      } else {
        // in-app 이었다면 스트리밍/카메라 정지
        await _cameraService.stopStreaming();
        if (_cameraService.isSimulatorMode) {
          _stopSimulatorMode();
        }
        await _releaseCameraResources();
      }

      _overlayMode = OverlayMode.none;
      _isMonitoring = false;
      _sessionStartTime = null;
      _currentLevel = DrowsinessLevel.awake;
      _drowsinessScore = 0.0;
      notifyListeners();
    }
  }

  // 카메라 리소스 해제 (졸음 감지 중지 시)
  Future<void> _releaseCameraResources() async {
    try {
      await _cameraService.dispose();
      _isCameraReady = false;
      notifyListeners(); // UI 업데이트를 위해 추가
      debugPrint('졸음 감지 중지 - 카메라 리소스 해제 완료');
    } catch (e) {
      debugPrint('카메라 리소스 해제 실패: $e');
    }
  }

  // 화면 종료 시 카메라 정리 (외부에서 호출)
  Future<void> cleanupForScreenExit() async {
    if (_isMonitoring) {
      await toggleMonitoring(); // 모니터링 중지 및 카메라 해제
    } else if (_isCameraReady) {
      // 모니터링은 중지되어 있지만 카메라가 활성화된 경우
      await _releaseCameraResources();
    }
  }

  // 시뮬레이터 모드용 타이머
  Timer? _simulatorTimer;

  // 졸음 감지 시작 (실제 카메라 스트리밍 또는 시뮬레이터 모드)
  Future<void> _startDrowsinessDetection() async {
    if (!_isCameraReady || _cameraService.controller == null) {
      // 시뮬레이터 모드인 경우
      if (_cameraService.isSimulatorMode) {
        _startSimulatorMode();
        return;
      }
      return;
    }

    try {
      await _cameraService.startStreaming(_onCameraImageAvailable);
      debugPrint('실시간 졸음 감지 시작');
    } catch (e) {
      debugPrint('졸음 감지 시작 실패: $e');
      // 실패 시 시뮬레이터 모드로 폴백
      _startSimulatorMode();
    }
  }

  // 시뮬레이터 모드 시작
  void _startSimulatorMode() {
    debugPrint('시뮬레이터 모드로 졸음 감지 시작');

    // 30fps 시뮬레이션 (33ms 간격)
    _simulatorTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!_isMonitoring) {
        timer.cancel();
        return;
      }

      // 시뮬레이터용 가상 분석 수행
      final analysisResult = _faceAnalysisService.analyzeSimulatorFrame();

      // 분석 결과 업데이트
      _eyeAspectRatio = analysisResult.eyeAspectRatio;
      _drowsinessScore = analysisResult.drowsinessScore;

      // 졸음 상태 판단
      if (analysisResult.isFaceDetected) {
        if (_faceAnalysisService.isDrowsy(_drowsinessScore)) {
          if (_drowsinessScore > 0.85) {
            _currentLevel = DrowsinessLevel.sleeping;
          } else {
            _currentLevel = DrowsinessLevel.drowsy;
          }
          _triggerAlert();
        } else {
          _currentLevel = DrowsinessLevel.awake;
        }
      }

      // 눈 깜빡임 빈도 업데이트 (분석 결과 기반)
      _updateBlinkRateFromAnalysis(analysisResult);

      notifyListeners();
    });
  }

  // 시뮬레이터 모드 중지
  void _stopSimulatorMode() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    debugPrint('시뮬레이터 모드 중지');
  }

  // 졸음 감지 결과를 기반으로 UI 업데이트
  void updateUIBasedOnDrowsiness() {
    // 졸음 상태에 따른 UI 업데이트 로직 추가
    // 예: 경고 메시지 표시, 화면 색상 변경 등
    switch (_currentLevel) {
      case DrowsinessLevel.awake:
        debugPrint('졸음 상태: 깨어있음');
        // UI 업데이트 코드
        break;
      case DrowsinessLevel.drowsy:
        debugPrint('졸음 상태: 졸음');
        // UI 업데이트 코드
        break;
      case DrowsinessLevel.sleeping:
        debugPrint('졸음 상태: 잠듦');
        // UI 업데이트 코드
        break;
    }
  }

  // 카메라 이미지 콜백
  void _onCameraImageAvailable(CameraImage image) {
    if (!_isMonitoring) return;

    try {
      // 얼굴 분석 수행
      final analysisResult = _faceAnalysisService.analyzeFrame(image);

      // 분석 결과 업데이트
      _eyeAspectRatio = analysisResult.eyeAspectRatio;
      _drowsinessScore = analysisResult.drowsinessScore;

      // 졸음 상태 판단
      if (analysisResult.isFaceDetected) {
        if (_faceAnalysisService.isDrowsy(_drowsinessScore)) {
          if (_drowsinessScore > 0.85) {
            _currentLevel = DrowsinessLevel.sleeping;
          } else {
            _currentLevel = DrowsinessLevel.drowsy;
          }
          _triggerAlert();
        } else {
          _currentLevel = DrowsinessLevel.awake;
        }
      }

      // 눈 깜빡임 빈도 업데이트 (분석 결과 기반)
      _updateBlinkRateFromAnalysis(analysisResult);

      notifyListeners();
    } catch (e) {
      debugPrint('이미지 분석 중 오류: $e');
    }
  }

  // 분석 결과로부터 눈 깜빡임 빈도 계산
  void _updateBlinkRateFromAnalysis(FaceAnalysisResult result) {
    if (result.eyeAspectRatio < 0.25) {
      _blinkRate = (_blinkRate * 0.9) + (5.0 * 0.1);
    } else {
      _blinkRate = (_blinkRate * 0.9) + (15.0 * 0.1);
    }
    _blinkRate = _blinkRate.clamp(1.0, 30.0);
  }

  // 심박수 업데이트
  void updateHeartRate(double newHeartRate) {
    _heartRate = newHeartRate;
    _heartRateHistory.add(HeartRateData(DateTime.now(), newHeartRate));

    if (_heartRateHistory.length > 100) {
      _heartRateHistory.removeAt(0);
    }

    notifyListeners();
  }

  // 눈 깜빡임 율 업데이트
  void updateBlinkRate(double newBlinkRate) {
    _blinkRate = newBlinkRate;
    _analyzeDrowsiness();
    notifyListeners();
  }

  // 졸음 상태 분석
  void _analyzeDrowsiness() {
    if (_blinkRate < 5 && _heartRate < 60) {
      _currentLevel = DrowsinessLevel.sleeping;
      _triggerAlert();
    } else if (_blinkRate < 10 || _heartRate < 65) {
      _currentLevel = DrowsinessLevel.drowsy;
      _triggerAlert();
    } else {
      _currentLevel = DrowsinessLevel.awake;
    }
  }

  // 알림 트리거
  void _triggerAlert() {
    if (_currentLevel != DrowsinessLevel.awake) {
      _alertCount++;
      debugPrint('졸음 감지! 알림 횟수: $_alertCount, 졸음 점수: ${_drowsinessScore.toStringAsFixed(2)}');
    }
  }

  // 카메라 전환 (전면/후면)
  Future<void> switchCamera() async {
    if (_isCameraReady) {
      await _cameraService.switchCamera();
      notifyListeners();
    }
  }

  // 리소스 정리
  @override
  Future<void> dispose() async {
    _isMonitoring = false;
    _stopSimulatorMode();
    await _cameraService.dispose();
    _isCameraReady = false;
    super.dispose();
  }

  // 통계 데이터 초기화
  void resetStatistics() {
    _alertCount = 0;
    _heartRateHistory.clear();
    notifyListeners();
  }

  // 스마트 워치 연동 상태 토글
  void toggleWatchConnection() {
    _isWatchConnected = !_isWatchConnected;
    notifyListeners();
  }

  // 스마트 워치 연결
  void connectWatch() {
    _isWatchConnected = true;
    notifyListeners();
  }

  // 스마트 워치 연결 해제
  void disconnectWatch() {
    _isWatchConnected = false;
    notifyListeners();
  }
}

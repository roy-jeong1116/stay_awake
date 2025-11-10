import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../services/camera_service.dart';
import '../services/face_analysis_service.dart';
import '../services/health_service.dart';

enum DrowsinessLevel {
  awake,    // 깨어있음
  drowsy,   // 졸음
  sleeping  // 잠듦
}

class HeartRateData {
  final DateTime time;
  final double value;

  HeartRateData(this.time, this.value);
}

class DrowsinessProvider with ChangeNotifier {
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
  final HealthService _healthService = HealthService();
  
  // 심박수 모니터링 구독
  StreamSubscription<HealthMetrics>? _heartRateSubscription;
  StreamSubscription<DeviceConnectionStatus>? _connectionSubscription;

  // Getters
  DrowsinessLevel get currentLevel => _currentLevel;
  bool get isMonitoring => _isMonitoring;
  bool get isCameraReady => _isCameraReady;
  bool get isWatchConnected => _isWatchConnected;
  bool get isSimulatorMode => _cameraService.isSimulatorMode;
  DeviceConnectionStatus get watchConnectionStatus => _healthService.connectionStatus;
  HealthPermissionStatus get healthPermissionStatus => _healthService.permissionStatus;
  double get heartRate => _heartRate;
  double get blinkRate => _blinkRate;
  double get drowsinessScore => _drowsinessScore;
  double get eyeAspectRatio => _eyeAspectRatio;
  int get alertCount => _alertCount;
  DateTime? get sessionStartTime => _sessionStartTime;
  List<HeartRateData> get heartRateHistory => _heartRateHistory;
  CameraController? get cameraController => _cameraService.controller;

  // 초기화
  Future<bool> initialize() async {
    try {
      // Health Service 초기화
      final healthInitialized = await _healthService.initialize();
      if (!healthInitialized) {
        debugPrint('Health Service 초기화 실패');
      }
      
      // 연결 상태 모니터링 시작
      _connectionSubscription = _healthService.connectionStream?.listen((status) {
        _isWatchConnected = status == DeviceConnectionStatus.connected;
        notifyListeners();
      });
      
      return true;
    } catch (e) {
      debugPrint('초기화 실패: $e');
      return false;
    }
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
  Future<void> toggleMonitoring() async {
    if (!_isMonitoring) {
      // 모니터링 시작 - 카메라 초기화 및 활성화
      debugPrint('졸음감지 시작 - 카메라 활성화');
      final cameraInitialized = await initializeCamera();
      if (!cameraInitialized) {
        debugPrint('카메라 초기화 실패로 모니터링을 시작할 수 없습니다.');
        return;
      }

      _isMonitoring = true;
      _sessionStartTime = DateTime.now();
      _alertCount = 0;
      _faceAnalysisService.reset();

      // 스마트워치 심박수 모니터링 시작
      await _startHeartRateMonitoring();

      // 카메라 스트리밍 시작 (시뮬레이터 모드 지원)
      await _startDrowsinessDetection();
    } else {
      // 모니터링 중지 - 카메라 해제
      debugPrint('졸음감지 중지 - 카메라 해제');
      _isMonitoring = false;
      _sessionStartTime = null;
      _currentLevel = DrowsinessLevel.awake;
      _drowsinessScore = 0.0;

      // 심박수 모니터링 중지
      await _stopHeartRateMonitoring();

      // 카메라 스트리밍 중지
      await _cameraService.stopStreaming();

      // 시뮬레이터 모드인 경우 타이머 정리
      if (_cameraService.isSimulatorMode) {
        _stopSimulatorMode();
      }

      // 졸음 감지 중지 시 카메라 리소스 완전 해제
      await _releaseCameraResources();
    }
    notifyListeners();
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

  // 개선된 졸음 상태 분석 (심박수 + 얼굴 인식 데이터 통합)
  void _analyzeDrowsiness() {
    double combinedScore = 0.0;
    
    // 심박수 기반 졸음 점수 (40% 가중치)
    double heartRateScore = _calculateHeartRateDrowsinessScore();
    combinedScore += heartRateScore * 0.4;
    
    // 얼굴 분석 기반 점수 (60% 가중치)
    combinedScore += _drowsinessScore * 0.6;
    
    // 눈 깜빡임 추가 보정
    if (_blinkRate < 5) {
      combinedScore += 0.3; // 매우 느린 깜빡임
    } else if (_blinkRate < 10) {
      combinedScore += 0.1; // 느린 깜빡임
    }
    
    // 졸음 상태 판정
    if (combinedScore >= 0.8) {
      _currentLevel = DrowsinessLevel.sleeping;
      _triggerAlert();
    } else if (combinedScore >= 0.5) {
      _currentLevel = DrowsinessLevel.drowsy;
      _triggerAlert();
    } else {
      _currentLevel = DrowsinessLevel.awake;
    }
    
    // 통합 졸음 점수 업데이트
    _drowsinessScore = combinedScore.clamp(0.0, 1.0);
  }
  
  // 심박수 기반 졸음 점수 계산
  double _calculateHeartRateDrowsinessScore() {
    if (_heartRate <= 0) return 0.0;
    
    // 정상 휴식 심박수 범위: 60-80 BPM
    // 졸음 상태에서는 심박수가 더 낮아짐: 50-65 BPM
    
    if (_heartRate < 50) {
      return 0.9; // 비정상적으로 낮음 (매우 졸림)
    } else if (_heartRate < 55) {
      return 0.7; // 매우 낮음 (졸림)
    } else if (_heartRate < 60) {
      return 0.5; // 낮음 (약간 졸림)
    } else if (_heartRate < 65) {
      return 0.3; // 정상 하한 (정상)
    } else if (_heartRate <= 80) {
      return 0.1; // 정상 범위 (깨어있음)
    } else if (_heartRate <= 90) {
      return 0.0; // 정상 상한 (완전히 깨어있음)
    } else {
      return 0.2; // 높음 (스트레스/흥분 상태)
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
    await _stopHeartRateMonitoring();
    await _connectionSubscription?.cancel();
    await _healthService.dispose();
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

  // 심박수 모니터링 시작
  Future<void> _startHeartRateMonitoring() async {
    try {
      final connected = await _healthService.connectToWearables();
      if (connected) {
        final monitoringStarted = await _healthService.startHeartRateMonitoring();
        if (monitoringStarted) {
          // 심박수 데이터 구독
          _heartRateSubscription = _healthService.heartRateStream?.listen((metrics) {
            if (metrics.isValid) {
              updateHeartRate(metrics.heartRate);
              debugPrint('심박수 업데이트: ${metrics.heartRate.toStringAsFixed(1)} BPM');
            }
          });
          debugPrint('심박수 모니터링 시작됨');
        } else {
          debugPrint('심박수 모니터링 시작 실패');
        }
      } else {
        debugPrint('스마트워치 연결 실패');
      }
    } catch (e) {
      debugPrint('심박수 모니터링 시작 중 오류: $e');
    }
  }

  // 심박수 모니터링 중지
  Future<void> _stopHeartRateMonitoring() async {
    try {
      await _heartRateSubscription?.cancel();
      _heartRateSubscription = null;
      await _healthService.stopHeartRateMonitoring();
      debugPrint('심박수 모니터링 중지됨');
    } catch (e) {
      debugPrint('심박수 모니터링 중지 중 오류: $e');
    }
  }

  // 스마트워치 수동 연결
  Future<bool> connectToSmartwatch() async {
    try {
      final connected = await _healthService.connectToWearables();
      if (connected) {
        _isWatchConnected = true;
        notifyListeners();
        debugPrint('스마트워치 연결 성공');
        return true;
      } else {
        _isWatchConnected = false;
        notifyListeners();
        debugPrint('스마트워치 연결 실패');
        return false;
      }
    } catch (e) {
      debugPrint('스마트워치 연결 중 오류: $e');
      _isWatchConnected = false;
      notifyListeners();
      return false;
    }
  }

  // 스마트 워치 연결 해제
  void disconnectWatch() {
    _healthService.disconnect();
    _isWatchConnected = false;
    notifyListeners();
  }

  // Health 권한 요청
  Future<bool> requestHealthPermissions() async {
    try {
      return await _healthService.requestPermissions();
    } catch (e) {
      debugPrint('Health 권한 요청 실패: $e');
      return false;
    }
  }

  // 수동 심박수 측정
  Future<double?> measureHeartRateOnce() async {
    try {
      final metrics = await _healthService.measureHeartRateOnce();
      if (metrics.isValid) {
        updateHeartRate(metrics.heartRate);
        return metrics.heartRate;
      }
      return null;
    } catch (e) {
      debugPrint('수동 심박수 측정 실패: $e');
      return null;
    }
  }
}

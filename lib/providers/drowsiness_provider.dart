import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:math' as math; // clamp 함수를 위해 math import
import '../services/camera_service.dart';
// import '../services/face_analysis_service.dart'; // --- OLD (TFLite로 대체) ---
import '../services/health_service.dart';
import 'package:stay_awake/services/tflite_service.dart'; // --- NEW ---

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
  double _blinkRate = 15.0; // (TFLite가 이 값을 반환하지 않으므로, 현재는 사용되지 않음)
  double _drowsinessScore = 0.0; // 보정된 졸음 점수 (0.0 ~ 1.0)
  double _eyeAspectRatio = 0.5; // (TFLite가 이 값을 반환하지 않으므로, 현재는 사용되지 않음)
  int _alertCount = 0;
  DateTime? _sessionStartTime;
  List<HeartRateData> _heartRateHistory = [];

  // 카메라 관련 서비스
  final CameraService _cameraService = CameraService.instance;
  // final FaceAnalysisService _faceAnalysisService = FaceAnalysisService.instance; // --- OLD ---
  final HealthService _healthService = HealthService();

  // --- NEW (TFLite 서비스 및 추론 플래그) ---
  final TFLiteService _tfliteService = TFLiteService();
  bool _isDetecting = false;
  // --- END NEW ---

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
  double get drowsinessScore => _drowsinessScore; // (UI에서는 숨겨짐)
  double get eyeAspectRatio => _eyeAspectRatio;
  int get alertCount => _alertCount;
  DateTime? get sessionStartTime => _sessionStartTime;
  List<HeartRateData> get heartRateHistory => _heartRateHistory;
  CameraController? get cameraController => _cameraService.controller;

  // (initialize, initializeCamera 등 상단 코드는 동일)
  // ...
  Future<bool> initialize() async {
    try {
      final healthInitialized = await _healthService.initialize();
      if (!healthInitialized) {
        debugPrint('Health Service 초기화 실패');
      }
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

  Future<void> toggleMonitoring() async {
    if (!_isMonitoring) {
      debugPrint('졸음감지 시작 - 카메라 활성화');
      final cameraInitialized = await initializeCamera();
      if (!cameraInitialized) {
        debugPrint('카메라 초기화 실패로 모니터링을 시작할 수 없습니다.');
        return;
      }
      _isMonitoring = true;
      _sessionStartTime = DateTime.now();
      _alertCount = 0;
      await _startHeartRateMonitoring();
      await _startDrowsinessDetection();
    } else {
      debugPrint('졸음감지 중지 - 카메라 해제');
      _isMonitoring = false;
      _sessionStartTime = null;
      _currentLevel = DrowsinessLevel.awake;
      _drowsinessScore = 0.0;
      await _stopHeartRateMonitoring();
      await _cameraService.stopStreaming();
      if (_cameraService.isSimulatorMode) {
        _stopSimulatorMode();
      }
      await _releaseCameraResources();
    }
    notifyListeners();
  }

  Future<void> _releaseCameraResources() async {
    try {
      await _cameraService.dispose();
      _isCameraReady = false;
      notifyListeners();
      debugPrint('졸음 감지 중지 - 카메라 리소스 해제 완료');
    } catch (e) {
      debugPrint('카메라 리소스 해제 실패: $e');
    }
  }

  Future<void> cleanupForScreenExit() async {
    if (_isMonitoring) {
      await toggleMonitoring();
    } else if (_isCameraReady) {
      await _releaseCameraResources();
    }
  }

  Timer? _simulatorTimer;

  Future<void> _startDrowsinessDetection() async {
    if (!_isCameraReady || _cameraService.controller == null) {
      if (_cameraService.isSimulatorMode) {
        _startSimulatorMode();
        return;
      }
      return;
    }

    try {
      await _cameraService.startStreaming(_onCameraImageAvailable);
      debugPrint('실시간 TFLite 졸음 감지 시작');
    } catch (e) {
      debugPrint('졸음 감지 시작 실패: $e');
      _startSimulatorMode();
    }
  }

  void _startSimulatorMode() {
    debugPrint('--- 경고: TFLite는 시뮬레이터 모드를 지원하지 않습니다. ---');
  }

  void _stopSimulatorMode() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    debugPrint('시뮬레이터 모드 중지');
  }

  void updateUIBasedOnDrowsiness() {}

  // ⚡️⚡️⚡️ --- (핵심 수정) TFLite 추론 콜백 --- ⚡️⚡️⚡️
  void _onCameraImageAvailable(CameraImage image) {
    if (!_isMonitoring) return;
    if (_isDetecting) return;
    _isDetecting = true;

    _tfliteService.runInference(image).then((results) {

      if (results != null) {

        // 1. 라벨 순서 확인 (예: [깨어있음 확률, 졸음 확률])
        double rawDrowsyScore = results[1]; // '졸음' 확률 (0.0 ~ 1.0)

        // (디버깅용) 콘솔에 원본값 전체를 출력합니다.
        print("TFLite 원본 [깨어있음, 졸음]: $results");

        // 2. (요청) 0.0 ~ 0.5 범위를 0 ~ 100점으로 스케일링
        const double MAX_RAW_FOR_SCALING = 0.5; // 원본값 0.5 (50%)를 100점으로 간주
        double scaledScore = (rawDrowsyScore / MAX_RAW_FOR_SCALING) * 100.0;

        // 0~100 사이로 값을 제한 (0.5를 넘는 원본값은 100으로 처리)
        scaledScore = scaledScore.clamp(0.0, 100.0);

        // 3. (요청) 스케일링된 점수를 0.0~1.0 범위로 _drowsinessScore에 저장
        // (UI에서 이 값을 * 100 해서 %로 사용했기 때문 - 지금은 UI에서 숨겨짐)
        _drowsinessScore = scaledScore / 100.0;

        // 4. (요청) 스케일링된 점수 30점을 임계값으로 사용
        const double SCALED_THRESHOLD = 40.0; // 새 점수(0~100) 기준 30점

        // 5. 졸음 상태 판단
        // (Sleeping 임계값은 70점 정도로 임의 설정, 필요시 조정)
        const double SCALED_SLEEPING_THRESHOLD = 75.0;

        if (scaledScore > SCALED_SLEEPING_THRESHOLD) {
          _currentLevel = DrowsinessLevel.sleeping;
          _triggerAlert(scaledScore); // 보정 점수 전달
        } else if (scaledScore > SCALED_THRESHOLD) {
          _currentLevel = DrowsinessLevel.drowsy;
          _triggerAlert(scaledScore); // 보정 점수 전달
        } else {
          _currentLevel = DrowsinessLevel.awake;
        }

        notifyListeners(); // 상태 변경 알림
      }

    }).catchError((e) {
      debugPrint('TFLite 추론 중 오류: $e');
    }).whenComplete(() {
      _isDetecting = false; // 다음 프레임 받을 준비
    });
  }

  // --- (OLD: TFLite로 대체되어 사용되지 않음) ---
  // ...

  // 심박수 업데이트
  void updateHeartRate(double newHeartRate) {
    _heartRate = newHeartRate;
    _heartRateHistory.add(HeartRateData(DateTime.now(), newHeartRate));

    if (_heartRateHistory.length > 100) {
      _heartRateHistory.removeAt(0);
    }
    notifyListeners();
  }

  // (사용되지 않음)
  void updateBlinkRate(double newBlinkRate) {
    _blinkRate = newBlinkRate;
    notifyListeners();
  }

  // --- (OLD: TFLite가 단독으로 판단하므로 주석 처리) ---
  // ...

  // 알림 트리거
  void _triggerAlert(double scaledScore) { // 보정 점수를 받도록 수정
    if (_currentLevel != DrowsinessLevel.awake) {
      _alertCount++;
      // TFLite 원본 점수 대신 보정된 점수를 출력
      debugPrint('졸음 감지! 알림 횟수: $_alertCount, 보정 점수: ${scaledScore.toStringAsFixed(1)}');
    }
  }

  // 카메라 전환 (전면/후면)
  Future<void> switchCamera() async {
    if (_isCameraReady) {
      await _cameraService.switchCamera();
      notifyListeners();
    }
  }

  // (리소스 정리, 통계 초기화 등 나머지 코드는 동일)
  // ...
  @override
  Future<void> dispose() async {
    _isMonitoring = false;
    _stopSimulatorMode();
    await _stopHeartRateMonitoring();
    await _connectionSubscription?.cancel();
    await _healthService.dispose();
    await _cameraService.dispose();
    _tfliteService.dispose();
    _isCameraReady = false;
    super.dispose();
  }

  void resetStatistics() {
    _alertCount = 0;
    _heartRateHistory.clear();
    notifyListeners();
  }

  void toggleWatchConnection() {
    _isWatchConnected = !_isWatchConnected;
    notifyListeners();
  }

  void connectWatch() {
    _isWatchConnected = true;
    notifyListeners();
  }

  Future<void> _startHeartRateMonitoring() async {
    try {
      final connected = await _healthService.connectToWearables();
      if (connected) {
        final monitoringStarted = await _healthService.startHeartRateMonitoring();
        if (monitoringStarted) {
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

  void disconnectWatch() {
    _healthService.disconnect();
    _isWatchConnected = false;
    notifyListeners();
  }

  Future<bool> requestHealthPermissions() async {
    try {
      return await _healthService.requestPermissions();
    } catch (e) {
      debugPrint('Health 권한 요청 실패: $e');
      return false;
    }
  }

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
import 'package:flutter/material.dart';

enum DrowsinessLevel {
  awake,    // 깨어있음
  drowsy,   // 졸음
  sleeping  // 잠듦
}

class DrowsinessProvider with ChangeNotifier {
  DrowsinessLevel _currentLevel = DrowsinessLevel.awake;
  bool _isMonitoring = false;
  bool _isWatchConnected = false; // 스마트 워치 연동 상태
  double _heartRate = 72.0;
  double _blinkRate = 15.0;
  int _alertCount = 0;
  DateTime? _sessionStartTime;
  List<HeartRateData> _heartRateHistory = [];

  // Getters
  DrowsinessLevel get currentLevel => _currentLevel;
  bool get isMonitoring => _isMonitoring;
  bool get isWatchConnected => _isWatchConnected; // 스마트 워치 연동 상태 getter
  double get heartRate => _heartRate;
  double get blinkRate => _blinkRate;
  int get alertCount => _alertCount;
  DateTime? get sessionStartTime => _sessionStartTime;
  List<HeartRateData> get heartRateHistory => _heartRateHistory;

  // 모니터링 시작/중지
  void toggleMonitoring() {
    _isMonitoring = !_isMonitoring;
    if (_isMonitoring) {
      _sessionStartTime = DateTime.now();
      _alertCount = 0;
      _startDrowsinessDetection();
    } else {
      _sessionStartTime = null;
      _currentLevel = DrowsinessLevel.awake;
    }
    notifyListeners();
  }

  // 졸음 감지 시뮬레이션 (실제 구현에서는 AI 모델 결과를 사용)
  void _startDrowsinessDetection() {
    // 실제 구현에서는 카메라와 센서 데이터를 분석
    // 여기서는 데모용 시뮬레이션
  }

  // 심박수 업데이트
  void updateHeartRate(double newHeartRate) {
    _heartRate = newHeartRate;
    _heartRateHistory.add(HeartRateData(DateTime.now(), newHeartRate));

    // 최근 100개 데이터만 유지
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
    // 간단한 졸음 감지 로직 (실제로는 더 복합적인 AI 분석)
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
      // 실제 구현에서는 음성 알림, 진동 등을 실행
    }
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

  // 스마트 워치 연결 시뮬레이션 (실제 구현에서는 Bluetooth 연결 로직)
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

class HeartRateData {
  final DateTime time;
  final double value;

  HeartRateData(this.time, this.value);
}

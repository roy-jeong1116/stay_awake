import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

enum HealthPermissionStatus {
  unknown,
  authorized,
  denied,
  notDetermined,
}

enum DeviceConnectionStatus {
  disconnected,
  connecting,
  connected,
  failed,
}

class HealthMetrics {
  final double heartRate;
  final DateTime timestamp;
  final bool isValid;

  HealthMetrics({
    required this.heartRate,
    required this.timestamp,
    this.isValid = true,
  });

  factory HealthMetrics.invalid() {
    return HealthMetrics(
      heartRate: 0.0,
      timestamp: DateTime.now(),
      isValid: false,
    );
  }
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  Health? _health;
  Timer? _heartRateTimer;
  StreamController<HealthMetrics>? _heartRateController;
  StreamController<DeviceConnectionStatus>? _connectionController;
  
  HealthPermissionStatus _permissionStatus = HealthPermissionStatus.unknown;
  DeviceConnectionStatus _connectionStatus = DeviceConnectionStatus.disconnected;
  bool _isMonitoring = false;
  DateTime? _lastDataTime;
  
  // Getters
  HealthPermissionStatus get permissionStatus => _permissionStatus;
  DeviceConnectionStatus get connectionStatus => _connectionStatus;
  bool get isMonitoring => _isMonitoring;
  DateTime? get lastDataTime => _lastDataTime;
  
  Stream<HealthMetrics>? get heartRateStream => _heartRateController?.stream;
  Stream<DeviceConnectionStatus>? get connectionStream => _connectionController?.stream;

  // 초기화
  Future<bool> initialize() async {
    try {
      _health = Health();
      _heartRateController = StreamController<HealthMetrics>.broadcast();
      _connectionController = StreamController<DeviceConnectionStatus>.broadcast();
      
      debugPrint('Health Service 초기화 완료');
      return true;
    } catch (e) {
      debugPrint('Health Service 초기화 실패: $e');
      return false;
    }
  }

  // 권한 요청
  Future<bool> requestPermissions() async {
    try {
      _updatePermissionStatus(HealthPermissionStatus.notDetermined);
      
      // 기본 권한 확인
      var healthPermission = await Permission.sensors.request();
      
      if (healthPermission != PermissionStatus.granted) {
        debugPrint('센서 권한이 거부됨');
        _updatePermissionStatus(HealthPermissionStatus.denied);
        return false;
      }

      // Health 데이터 타입 정의
      List<HealthDataType> types = [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
      ];

      // Health 권한 요청
      bool? healthPermissionGranted = await _health?.requestAuthorization(types);
      
      if (healthPermissionGranted == true) {
        _updatePermissionStatus(HealthPermissionStatus.authorized);
        debugPrint('Health 데이터 권한 획득 성공');
        return true;
      } else {
        _updatePermissionStatus(HealthPermissionStatus.denied);
        debugPrint('Health 데이터 권한 거부됨');
        return false;
      }
    } catch (e) {
      debugPrint('권한 요청 중 오류: $e');
      _updatePermissionStatus(HealthPermissionStatus.denied);
      return false;
    }
  }

  // 스마트워치 연결 시작
  Future<bool> connectToWearables() async {
    try {
      _updateConnectionStatus(DeviceConnectionStatus.connecting);
      
      // 권한 확인
      if (_permissionStatus != HealthPermissionStatus.authorized) {
        final permissionGranted = await requestPermissions();
        if (!permissionGranted) {
          _updateConnectionStatus(DeviceConnectionStatus.failed);
          return false;
        }
      }

      // 연결 시뮬레이션 (실제로는 Health 앱과의 연동)
      await Future.delayed(const Duration(seconds: 2));
      
      // Health 데이터 접근 가능한지 확인
      bool hasData = await _checkHealthDataAvailability();
      
      if (hasData) {
        _updateConnectionStatus(DeviceConnectionStatus.connected);
        debugPrint('스마트워치 연결 성공');
        return true;
      } else {
        _updateConnectionStatus(DeviceConnectionStatus.failed);
        debugPrint('Health 데이터를 사용할 수 없음');
        return false;
      }
    } catch (e) {
      debugPrint('스마트워치 연결 실패: $e');
      _updateConnectionStatus(DeviceConnectionStatus.failed);
      return false;
    }
  }

  // Health 데이터 가용성 확인
  Future<bool> _checkHealthDataAvailability() async {
    try {
      DateTime now = DateTime.now();
      DateTime yesterday = now.subtract(const Duration(days: 1));
      
      List<HealthDataPoint> heartRateData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: yesterday,
        endTime: now,
      ) ?? [];

      return heartRateData.isNotEmpty;
    } catch (e) {
      debugPrint('Health 데이터 가용성 확인 실패: $e');
      return false;
    }
  }

  // 심박수 모니터링 시작
  Future<bool> startHeartRateMonitoring() async {
    try {
      if (_isMonitoring) {
        debugPrint('이미 심박수 모니터링 중');
        return true;
      }

      if (_connectionStatus != DeviceConnectionStatus.connected) {
        final connected = await connectToWearables();
        if (!connected) {
          debugPrint('스마트워치 연결 실패로 모니터링 시작 불가');
          return false;
        }
      }

      _isMonitoring = true;
      
      // 실시간 심박수 데이터 수집 시작 (5초마다)
      _heartRateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _fetchLatestHeartRate();
      });

      debugPrint('심박수 모니터링 시작');
      return true;
    } catch (e) {
      debugPrint('심박수 모니터링 시작 실패: $e');
      return false;
    }
  }

  // 최신 심박수 데이터 가져오기
  Future<void> _fetchLatestHeartRate() async {
    try {
      DateTime now = DateTime.now();
      DateTime fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      List<HealthDataPoint> heartRateData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: fiveMinutesAgo,
        endTime: now,
      ) ?? [];

      HealthMetrics metrics;
      
      if (heartRateData.isNotEmpty) {
        // 가장 최근 데이터 사용
        var latestData = heartRateData.last;
        double heartRate = (latestData.value as NumericHealthValue).numericValue.toDouble();
        
        // 정상 범위 확인 (30-200 BPM)
        if (heartRate >= 30 && heartRate <= 200) {
          metrics = HealthMetrics(
            heartRate: heartRate,
            timestamp: latestData.dateTo,
            isValid: true,
          );
          _lastDataTime = latestData.dateTo;
        } else {
          metrics = HealthMetrics.invalid();
        }
      } else {
        // 실제 데이터가 없으면 시뮬레이션 데이터 생성
        metrics = _generateSimulatedHeartRate();
      }

      // 스트림으로 데이터 전송
      _heartRateController?.add(metrics);
      
    } catch (e) {
      debugPrint('심박수 데이터 가져오기 실패: $e');
      _heartRateController?.add(HealthMetrics.invalid());
    }
  }

  // 시뮬레이션 심박수 데이터 생성 (개발/테스트용)
  HealthMetrics _generateSimulatedHeartRate() {
    Random random = Random();
    
    // 시간대별로 다른 심박수 패턴 생성
    DateTime now = DateTime.now();
    int hour = now.hour;
    
    double baseHeartRate;
    if (hour >= 22 || hour <= 6) {
      // 야간: 낮은 심박수 (졸음 시뮬레이션)
      baseHeartRate = 55 + random.nextDouble() * 15; // 55-70
    } else if (hour >= 7 && hour <= 9) {
      // 아침: 보통 심박수
      baseHeartRate = 65 + random.nextDouble() * 20; // 65-85
    } else {
      // 일반 시간: 정상 심박수
      baseHeartRate = 70 + random.nextDouble() * 25; // 70-95
    }
    
    // 약간의 랜덤 변화 추가
    double variation = (random.nextDouble() - 0.5) * 10;
    double finalHeartRate = (baseHeartRate + variation).clamp(50.0, 120.0);
    
    return HealthMetrics(
      heartRate: finalHeartRate,
      timestamp: DateTime.now(),
      isValid: true,
    );
  }

  // 심박수 모니터링 중지
  Future<void> stopHeartRateMonitoring() async {
    _isMonitoring = false;
    _heartRateTimer?.cancel();
    _heartRateTimer = null;
    debugPrint('심박수 모니터링 중지');
  }

  // 스마트워치 연결 해제
  Future<void> disconnect() async {
    await stopHeartRateMonitoring();
    _updateConnectionStatus(DeviceConnectionStatus.disconnected);
    debugPrint('스마트워치 연결 해제');
  }

  // 수동으로 심박수 측정
  Future<HealthMetrics> measureHeartRateOnce() async {
    try {
      if (_connectionStatus != DeviceConnectionStatus.connected) {
        return HealthMetrics.invalid();
      }

      DateTime now = DateTime.now();
      DateTime oneMinuteAgo = now.subtract(const Duration(minutes: 1));

      List<HealthDataPoint> heartRateData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: oneMinuteAgo,
        endTime: now,
      ) ?? [];

      if (heartRateData.isNotEmpty) {
        var latestData = heartRateData.last;
        double heartRate = (latestData.value as NumericHealthValue).numericValue.toDouble();
        
        return HealthMetrics(
          heartRate: heartRate,
          timestamp: latestData.dateTo,
          isValid: heartRate >= 30 && heartRate <= 200,
        );
      } else {
        // 시뮬레이션 데이터 반환
        return _generateSimulatedHeartRate();
      }
    } catch (e) {
      debugPrint('심박수 측정 실패: $e');
      return HealthMetrics.invalid();
    }
  }

  // 과거 심박수 데이터 가져오기
  Future<List<HealthMetrics>> getHistoricalHeartRate({
    DateTime? startTime,
    DateTime? endTime,
    int maxPoints = 100,
  }) async {
    try {
      startTime ??= DateTime.now().subtract(const Duration(hours: 24));
      endTime ??= DateTime.now();

      List<HealthDataPoint> heartRateData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      ) ?? [];

      List<HealthMetrics> metrics = heartRateData
          .where((data) {
            double heartRate = (data.value as NumericHealthValue).numericValue.toDouble();
            return heartRate >= 30 && heartRate <= 200;
          })
          .map((data) => HealthMetrics(
            heartRate: (data.value as NumericHealthValue).numericValue.toDouble(),
            timestamp: data.dateTo,
            isValid: true,
          ))
          .toList();

      // 최대 포인트 수 제한
      if (metrics.length > maxPoints) {
        int step = metrics.length ~/ maxPoints;
        metrics = metrics.where((element) {
          int index = metrics.indexOf(element);
          return index % step == 0;
        }).toList();
      }

      return metrics;
    } catch (e) {
      debugPrint('과거 심박수 데이터 가져오기 실패: $e');
      return [];
    }
  }

  // 상태 업데이트 메소드
  void _updatePermissionStatus(HealthPermissionStatus status) {
    _permissionStatus = status;
  }

  void _updateConnectionStatus(DeviceConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      _connectionController?.add(status);
    }
  }

  // 리소스 정리
  Future<void> dispose() async {
    await stopHeartRateMonitoring();
    await _heartRateController?.close();
    await _connectionController?.close();
    _heartRateController = null;
    _connectionController = null;
    debugPrint('Health Service 리소스 정리 완료');
  }
}
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

enum EyeState {
  open,
  closed,
  unknown
}

class FaceAnalysisResult {
  final EyeState leftEye;
  final EyeState rightEye;
  final double eyeAspectRatio;
  final bool isFaceDetected;
  final double drowsinessScore;

  FaceAnalysisResult({
    required this.leftEye,
    required this.rightEye,
    required this.eyeAspectRatio,
    required this.isFaceDetected,
    required this.drowsinessScore,
  });
}

class FaceAnalysisService {
  static FaceAnalysisService? _instance;
  static FaceAnalysisService get instance => _instance ??= FaceAnalysisService._();
  FaceAnalysisService._();

  // 눈 감김 감지를 위한 임계값
  static const double _eyeClosedThreshold = 0.25;
  static const double _drowsinessThreshold = 0.7;

  // 연속된 프레임에서 눈 감김 상태 추적
  final List<double> _recentEyeRatios = [];
  final int _maxHistoryLength = 30; // 약 1초간의 프레임 (30fps 기준)

  int _consecutiveClosedFrames = 0;
  final int _maxClosedFrames = 45; // 1.5초간 눈을 감고 있으면 졸음으로 판단

  // 카메라 이미지 분석
  FaceAnalysisResult analyzeFrame(CameraImage image) {
    try {
      // 실제 구현에서는 ML Kit나 TensorFlow Lite를 사용하여 얼굴 인식
      // 여기서는 시뮬레이션된 분석 결과를 반환

      final fakeAnalysis = _simulateFaceDetection();

      // 눈 감김 비율 기록
      _recentEyeRatios.add(fakeAnalysis.eyeAspectRatio);
      if (_recentEyeRatios.length > _maxHistoryLength) {
        _recentEyeRatios.removeAt(0);
      }

      // 연속된 눈 감김 프레임 카운트
      if (fakeAnalysis.eyeAspectRatio < _eyeClosedThreshold) {
        _consecutiveClosedFrames++;
      } else {
        _consecutiveClosedFrames = 0;
      }

      // 졸음 점수 계산
      final drowsinessScore = _calculateDrowsinessScore();

      return FaceAnalysisResult(
        leftEye: fakeAnalysis.leftEye,
        rightEye: fakeAnalysis.rightEye,
        eyeAspectRatio: fakeAnalysis.eyeAspectRatio,
        isFaceDetected: fakeAnalysis.isFaceDetected,
        drowsinessScore: drowsinessScore,
      );
    } catch (e) {
      debugPrint('얼굴 분석 실패: $e');
      return FaceAnalysisResult(
        leftEye: EyeState.unknown,
        rightEye: EyeState.unknown,
        eyeAspectRatio: 0.0,
        isFaceDetected: false,
        drowsinessScore: 0.0,
      );
    }
  }

  // 졸음 점수 계산 (0.0 = 깨어있음, 1.0 = 완전히 졸림)
  double _calculateDrowsinessScore() {
    if (_recentEyeRatios.isEmpty) return 0.0;

    // 최근 프레임들의 평균 눈 감김 비율
    final avgEyeRatio = _recentEyeRatios.reduce((a, b) => a + b) / _recentEyeRatios.length;

    // 연속된 눈 감김 프레임 비율
    final consecutiveRatio = _consecutiveClosedFrames / _maxClosedFrames.toDouble();

    // 눈이 감긴 프레임의 비율
    final closedFrameRatio = _recentEyeRatios
        .where((ratio) => ratio < _eyeClosedThreshold)
        .length / _recentEyeRatios.length.toDouble();

    // 종합적인 졸음 점수 계산
    final drowsinessScore = (
      (1.0 - avgEyeRatio) * 0.4 +
      consecutiveRatio * 0.4 +
      closedFrameRatio * 0.2
    ).clamp(0.0, 1.0);

    return drowsinessScore;
  }

  // 시뮬레이션된 얼굴 감지 (실제로는 ML 모델 사용)
  FaceAnalysisResult _simulateFaceDetection() {
    // 실제 구현에서는 ML Kit Face Detection이나 TensorFlow Lite 모델 사용
    // 여기서는 랜덤한 값으로 시뮬레이션

    final random = DateTime.now().millisecondsSinceEpoch % 1000 / 1000.0;
    final eyeRatio = 0.2 + (random * 0.6); // 0.2 ~ 0.8 사이의 값

    final leftEye = eyeRatio > _eyeClosedThreshold ? EyeState.open : EyeState.closed;
    final rightEye = eyeRatio > _eyeClosedThreshold ? EyeState.open : EyeState.closed;

    return FaceAnalysisResult(
      leftEye: leftEye,
      rightEye: rightEye,
      eyeAspectRatio: eyeRatio,
      isFaceDetected: true,
      drowsinessScore: 0.0, // 이후 _calculateDrowsinessScore()에서 계산됨
    );
  }

  // 분석 상태 리셋
  void reset() {
    _recentEyeRatios.clear();
    _consecutiveClosedFrames = 0;
  }

  // 졸음 감지 여부
  bool isDrowsy(double drowsinessScore) {
    return drowsinessScore > _drowsinessThreshold;
  }

  // 시뮬레이터용 프레임 분석 (카메라가 없는 환경에서 사용)
  FaceAnalysisResult analyzeSimulatorFrame() {
    try {
      // 시뮬레이터에서는 더 다양한 패턴의 데이터 생성
      final fakeAnalysis = _simulateAdvancedFaceDetection();

      // 눈 감김 비율 기록
      _recentEyeRatios.add(fakeAnalysis.eyeAspectRatio);
      if (_recentEyeRatios.length > _maxHistoryLength) {
        _recentEyeRatios.removeAt(0);
      }

      // 연속된 눈 감김 프레임 카운트
      if (fakeAnalysis.eyeAspectRatio < _eyeClosedThreshold) {
        _consecutiveClosedFrames++;
      } else {
        _consecutiveClosedFrames = 0;
      }

      // 졸음 점수 계산
      final drowsinessScore = _calculateDrowsinessScore();

      return FaceAnalysisResult(
        leftEye: fakeAnalysis.leftEye,
        rightEye: fakeAnalysis.rightEye,
        eyeAspectRatio: fakeAnalysis.eyeAspectRatio,
        isFaceDetected: fakeAnalysis.isFaceDetected,
        drowsinessScore: drowsinessScore,
      );
    } catch (e) {
      debugPrint('시뮬레이터 얼굴 분석 실패: $e');
      return FaceAnalysisResult(
        leftEye: EyeState.unknown,
        rightEye: EyeState.unknown,
        eyeAspectRatio: 0.0,
        isFaceDetected: false,
        drowsinessScore: 0.0,
      );
    }
  }

  // 향상된 시뮬레이션 (더 현실적인 졸음 패턴)
  FaceAnalysisResult _simulateAdvancedFaceDetection() {
    final now = DateTime.now();
    final seconds = now.second;
    final milliseconds = now.millisecond;

    // 시간에 따른 패턴 생성 (더 현실적인 졸음 시뮬레이션)
    double eyeRatio;

    // 10초마다 졸음 패턴 시뮬레이션
    if (seconds % 20 < 10) {
      // 정상 상태 (깨어있음)
      eyeRatio = 0.4 + (milliseconds % 500) / 1000.0; // 0.4 ~ 0.9
    } else if (seconds % 20 < 15) {
      // 졸음 상태
      eyeRatio = 0.1 + (milliseconds % 300) / 1000.0; // 0.1 ~ 0.4
    } else {
      // 매우 졸린 상태
      eyeRatio = 0.05 + (milliseconds % 200) / 1000.0; // 0.05 ~ 0.25
    }

    // 가끔 깜빡임 시뮬레이션
    if (milliseconds < 50) {
      eyeRatio = 0.1; // 깜빡임
    }

    final leftEye = eyeRatio > _eyeClosedThreshold ? EyeState.open : EyeState.closed;
    final rightEye = eyeRatio > _eyeClosedThreshold ? EyeState.open : EyeState.closed;

    return FaceAnalysisResult(
      leftEye: leftEye,
      rightEye: rightEye,
      eyeAspectRatio: eyeRatio,
      isFaceDetected: true,
      drowsinessScore: 0.0, // 이후 _calculateDrowsinessScore()에서 계산됨
    );
  }
}

import 'dart:async';
import 'package:camera/camera.dart';
import '../cam/camera_service.dart';
import '../ml/vision_tflite.dart';

class CamInferController {
  final _cam = CameraService();
  late final VisionTFLite _vision;
  StreamSubscription<CameraImage>? _sub;

  Future<void> init({
    String model = 'assets/models/drowsiness_cam.tflite',
    int timeSteps = 1,
    int stride = 1,
  }) async {
    await _cam.init(lens: CameraLensDirection.front);
    _vision = VisionTFLite(
      assetPath: model,
      threads: 2,
      nnapi: true,
      timeSteps: timeSteps,
      stride: stride,
    );
    await _vision.init();
  }

  Future<void> start(void Function(Map<String, dynamic>) onResult) async {
    // 카메라 스트림 시작
    await _cam.start();

    // FPS 다운샘플 (원한다면)
    int skip = 0, every = 2;

    _sub = _cam.stream.listen((img) async {
      if ((skip++ % every) != 0) return;

      final feat = _vision.preprocess(img);
      Map<String, dynamic>? res;
      if (_vision.timeSteps <= 1) {
        res = _vision.inferSingle(feat);
      } else {
        res = _vision.pushAndInferSequence(feat);
      }
      if (res != null) onResult(res);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _cam.stop();
  }

  Future<void> dispose() async {
    await stop();
    _vision.dispose();
    await _cam.dispose();
  }
  CameraController get camera => _cam.controller;
  bool get cameraReady => _cam.isReady;
}

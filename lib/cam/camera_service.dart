import 'dart:async';
import 'package:camera/camera.dart';

class CameraService {
  late CameraController controller;
  bool _ready = false;
  bool _streaming = false;

  final _streamCtrl = StreamController<CameraImage>.broadcast();
  Stream<CameraImage> get stream => _streamCtrl.stream;

  Future<void> init({CameraLensDirection lens = CameraLensDirection.front}) async {
    final cams = await availableCameras();
    final cam = cams.firstWhere(
          (c) => c.lensDirection == lens,
      orElse: () => cams.first,
    );

    controller = CameraController(
      cam,
      // 성능 위해 낮은 해상도로 시작 → 필요 시 높이기
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _ready = true;
  }

  bool get isReady => _ready;

  Future<void> start() async {
    if (!_ready || _streaming) return;
    _streaming = true;
    await controller.startImageStream((CameraImage img) {
      if (!_streamCtrl.isClosed) {
        _streamCtrl.add(img);
      }
    });
  }

  Future<void> stop() async {
    if (!_streaming) return;
    _streaming = false;
    await controller.stopImageStream();
  }

  Future<void> dispose() async {
    await stop();
    await _streamCtrl.close();
    await controller.dispose();
  }
}

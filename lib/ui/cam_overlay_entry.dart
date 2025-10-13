import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// 오버레이가 별도 Flutter 엔진에서 뜸.
/// 반드시 최상단에 @pragma('vm:entry-point') 필요!
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _OverlayRoot(),
    );
  }
}

class _OverlayRoot extends StatefulWidget {
  const _OverlayRoot({super.key});
  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot> {
  CameraController? _controller;
  String _status = 'booting...';
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      // 보통 전면 카메라 우선
      final front = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // 추론용
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _status = 'running';
        _starting = false;
      });

      // 필요 시 여기서 imageStream 받아 추론 로직 연결 가능
      // await _controller!.startImageStream((CameraImage image) { ... });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'error: $e';
        _starting = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller?.value.isInitialized == true;
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: SafeArea(
        child: Container(
          width: 180,
          height: 240,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ready
                      ? CameraPreview(_controller!)
                      : Center(
                    child: _starting
                        ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(_status, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _status,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

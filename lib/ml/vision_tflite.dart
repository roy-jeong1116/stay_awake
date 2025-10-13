// lib/ml/vision_tflite.dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;


class VisionTFLite {
  final String assetPath;
  final int threads;
  final bool nnapi;

  late Interpreter _interpreter;
  late Tensor _in;
  late Tensor _out;

  final int timeSteps;       // 시퀀스 길이 (단일 프레임 모델이면 1)
  final int stride;          // 시퀀스 모델일 때 몇 프레임마다 추론할지
  final List<Float32List> _frameBuf = [];

  VisionTFLite({
    required this.assetPath,
    this.threads = 2,
    this.nnapi = true,
    this.timeSteps = 1,
    this.stride = 1,
  });

  Future<void> init() async {
    final opts = InterpreterOptions()
      ..threads = threads
      ..useNnApiForAndroid = nnapi; // Android 가속
    _interpreter = await Interpreter.fromAsset(assetPath, options: opts);
    _in = _interpreter.getInputTensors().first;
    _out = _interpreter.getOutputTensors().first;
  }

  /// YUV420 -> RGB -> resize -> normalize -> Float32List
  Float32List preprocess(CameraImage image) {
    // 1) YUV420 → RGB(Image)
    final rgb = _yuv420toImageColor(image);

    // 2) 모델 입력 크기
    final shape = _in.shape; // [1,H,W,3] 또는 [1,T,H,W,3]
    final int H = shape.length == 5 ? shape[1] : shape[1];
    final int W = shape.length == 5 ? shape[2] : shape[2];

    // 3) 리사이즈
    final resized = img.copyResize(
      rgb,
      width: W,
      height: H,
      interpolation: img.Interpolation.average,
    );

    // 4) RGB 바이트 추출 (image 4.x)
    final bytes = resized.getBytes(order: img.ChannelOrder.rgb); // Uint8List, 길이 = H*W*3

    // 5) 정규화 (훈련과 동일해야 함) — 여기선 [0,1] 가정
    final floats = Float32List(H * W * 3);
    for (int i = 0; i < bytes.length; i++) {
      floats[i] = bytes[i] / 255.0;
    }
    return floats;
  }


  /// 단일 프레임 모델 추론: input [1,H,W,3]
  Map<String, dynamic> inferSingle(Float32List tensorHW3) {
    final shape = _in.shape; // [1,H,W,3]
    final input = [tensorHW3.buffer.asFloat32List()];
    final output = List.generate(_out.shape[0], (_) => List.filled(_out.shape[1], 0.0));
    _interpreter.run(input, output);
    return _postprocess(output);
  }

  /// 시퀀스 모델 추론: 입력 [1,T,H,W,3] (프레임 버퍼 채워서 호출)
  Map<String, dynamic>? pushAndInferSequence(Float32List tensorHW3) {
    _frameBuf.add(tensorHW3);
    if (_frameBuf.length < timeSteps) return null;
    if ((_frameBuf.length - timeSteps) % stride != 0) return null;

    final H = _in.shape[1], W = _in.shape[2];
    final seq = Float32List(timeSteps * H * W * 3);
    int off = 0;
    for (int t = _frameBuf.length - timeSteps; t < _frameBuf.length; t++) {
      final f = _frameBuf[t];
      seq.setRange(off, off + f.length, f);
      off += f.length;
    }
    final input = [ [ seq ] ]; // [1, T*H*W*3] 처럼 보이지만 실제론 인터프리터가 shape대로 해석
    final output = List.generate(_out.shape[0], (_) => List.filled(_out.shape[1], 0.0));
    _interpreter.run(input, output);
    return _postprocess(output);
  }

  Map<String, dynamic> _postprocess(dynamic output) {
    // 보통 [1,C] softmax
    final probs = (output as List).first.cast<num>().map((e)=>e.toDouble()).toList();
    final idx = probs.indexed.reduce((a,b)=> a.$2>b.$2 ? a : b).$1;
    // 3클래스라면 p2+0.5*p1 같은 소프트 점수도 가능
    double scoreSoft = probs.length>=3 ? (probs[2] + 0.5*probs[1]) : (probs.length>=2 ? probs[1] : probs[idx]);
    return {
      'y': idx,
      'probs': probs,
      'scoreSoft': scoreSoft,
    };
  }

  void dispose() => _interpreter.close();

  // --------- YUV420 → RGB(Image) ----------
  img.Image _yuv420toImageColor(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);
    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final bytesY = planeY.bytes;
    final bytesU = planeU.bytes;
    final bytesV = planeV.bytes;

    final int strideY = planeY.bytesPerRow;
    final int strideU = planeU.bytesPerRow;
    final int strideV = planeV.bytesPerRow;

    for (int y = 0; y < height; y++) {
      final int uvRow = (y / 2).floor();
      for (int x = 0; x < width; x++) {
        final int uvCol = (x / 2).floor();
        final int indexY = y * strideY + x;
        final int indexU = uvRow * strideU + uvCol * planeU.bytesPerPixel!;
        final int indexV = uvRow * strideV + uvCol * planeV.bytesPerPixel!;

        final int Y = bytesY[indexY];
        final int U = bytesU[indexU];
        final int V = bytesV[indexV];

        // YUV → RGB (BT.601 근사)
        double R = Y + 1.402 * (V - 128);
        double G = Y - 0.344136 * (U - 128) - 0.714136 * (V - 128);
        double B = Y + 1.772 * (U - 128);
        R = R.clamp(0, 255);
        G = G.clamp(0, 255);
        B = B.clamp(0, 255);

        rgbImage.setPixelRgb(x, y, R.toInt(), G.toInt(), B.toInt());
      }
    }
    return rgbImage;
  }
}

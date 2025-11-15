import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

// ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
// (fp32 모델로 변경)

// 1. 모델 파일 경로
const String MODEL_FILE = "assets/models/drowsy_fp32.tflite"; // <-- fp32로 변경

// 2. 모델 입력 이미지 크기
const int INPUT_SIZE = 224;

// ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★


// Isolate에서 이미지 처리를 수행하기 위해 top-level 함수로 분리
Future<List<List<List<List<double>>>>> _preprocessImage(CameraImage cameraImage) async {

  // 1. CameraImage(YUV/BGRA)를 img.Image(RGB)로 변환
  img.Image? rgbImage = _convertCameraImage(cameraImage);

  // 2. 모델 입력 크기에 맞게 리사이즈
  img.Image resizedImage = img.copyResize(
      rgbImage!,
      width: INPUT_SIZE,
      height: INPUT_SIZE
  );

  // 3. Float32 List로 변환 및 정규화
  // 모델 입력 형태인 [1, 224, 224, 3]에 맞게 List 생성
  var inputTensor = List.generate(1, (i) =>
      List.generate(INPUT_SIZE, (j) =>
          List.generate(INPUT_SIZE, (k) =>
              List.generate(3, (l) => 0.0)
          )
      )
  );

  for (var y = 0; y < INPUT_SIZE; y++) {
    for (var x = 0; x < INPUT_SIZE; x++) {
      var pixel = resizedImage.getPixel(x, y);

      // ★★★★★ (fp32 모델용 정규화 방식으로 변경) ★★★★★
      // (0, 255) 범위를 (-1, 1) 범위로 변경합니다.
      // (BGR 순서는 유지합니다)
      inputTensor[0][y][x][0] = (pixel.b - 127.5) / 127.5; // B
      inputTensor[0][y][x][1] = (pixel.g - 127.5) / 127.5; // G
      inputTensor[0][y][x][2] = (pixel.r - 127.5) / 127.5; // R
      // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    }
  }

  return inputTensor;
}

// CameraImage를 img.Image로 변환하는 헬퍼 함수
img.Image? _convertCameraImage(CameraImage image) {
  if (image.format.group == ImageFormatGroup.yuv420) {
    // Android (YUV420)
    return _convertYUV420(image);
  } else if (image.format.group == ImageFormatGroup.bgra8888) {
    // iOS (BGRA8888)
    return _convertBGRA8888(image);
  } else {
    // 지원하지 않는 형식
    return null;
  }
}

// YUV420 to RGB 변환
img.Image _convertYUV420(CameraImage image) {
  final int width = image.width;
  final int height = image.height;
  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

  final img.Image rgbImage = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final int index = y * width + x;

      final int yValue = image.planes[0].bytes[index];
      final int uValue = image.planes[1].bytes[uvIndex];
      final int vValue = image.planes[2].bytes[uvIndex];

      final int r = (yValue + 1.402 * (vValue - 128)).round();
      final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
      final int b = (yValue + 1.772 * (uValue - 128)).round();

      rgbImage.setPixelRgb(x, y,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255)
      );
    }
  }
  return rgbImage;
}

// BGRA8888 to RGB 변환
img.Image _convertBGRA8888(CameraImage image) {
  return img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.planes[0].bytes.buffer,
    order: img.ChannelOrder.bgra,
  );
}


// -----------------------------------------------------------------
// TFLite 서비스 클래스
// -----------------------------------------------------------------

class TFLiteService {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;
  TensorType? _outputType;

  TFLiteService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // 모델 로드
      _interpreter = await Interpreter.fromAsset(MODEL_FILE);

      // 모델의 입/출력 정보 가져오기
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      _outputType = _interpreter!.getOutputTensor(0).type;

      print('TFLite 모델 로드 성공 ($MODEL_FILE)');
      print('Input Shape: $_inputShape');
      print('Output Shape: $_outputShape');
      print('Output Type: $_outputType');

    } catch (e) {
      print('TFLite 모델 로드 실패: $e');
    }
  }

  Future<List<dynamic>?> runInference(CameraImage cameraImage) async {
    if (_interpreter == null) {
      print('인터프리터가 초기화되지 않았습니다.');
      return null;
    }

    // 1. 이미지 전처리 (UI 스레드 부하를 줄이기 위해 Isolate에서 실행)
    var inputTensor = await compute(_preprocessImage, cameraImage);

    // 2. 추론을 위한 출력 버퍼 준비
    // 예: [1, 2] (깨어있음, 졸음) Float32
    var output = List.generate(
        _outputShape![0],
            (i) => List.filled(_outputShape![1], 0.0)
    );

    // 3. 추론 실행
    try {
      _interpreter!.run(inputTensor, output);
    } catch (e) {
      print('추론 실행 오류: $e');
      return null;
    }

    // 4. 결과 반환 (배치 중 첫 번째 결과)
    return output[0] as List<dynamic>;
  }

  void dispose() {
    _interpreter?.close();
    print('TFLite 인터프리터 해제됨');
  }
}
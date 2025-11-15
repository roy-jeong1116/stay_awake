import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/drowsiness_provider.dart';
import 'dart:io';

class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DrowsinessProvider>(
      builder: (context, provider, child) {
        // --- 1. 카메라가 준비되지 않았을 때의 로딩 위젯 ---
        if (!provider.isCameraReady || provider.cameraController == null) {
          return Container(
            // height: 300, // 고정 높이 대신 AspectRatio 사용
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            // 카메라가 로드되지 않았을 때는 기본 16:9 비율을 보여줌
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      provider.isMonitoring
                          ? Icons.camera_alt_outlined
                          : Icons.videocam_off_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.isMonitoring
                          ? '카메라를 초기화하는 중...'
                          : '카메라가 비활성화됨',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    if (!provider.isMonitoring) ...[
                      const SizedBox(height: 4),
                      Text(
                        '졸음 감지를 시작하면 카메라가 활성화됩니다',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // --- 2. 시뮬레이터 모드인 경우 ---
        // (TFLite는 실제 기기에서만 작동하므로 이 부분은 TFLite 적용 시 사용되지 않음)
        if (provider.isSimulatorMode) {
          return _buildSimulatorPreview(provider);
        }

        // --- 3. (핵심 수정) 실제 카메라 미리보기 ---
        // 카메라 컨트롤러에서 실제 비율을 가져옵니다.
        final controller = provider.cameraController!;
        final cameraAspectRatio = controller.value.aspectRatio;

        return Container(
          // height: 300, // <-- 이 고정 높이를 제거!
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.hardEdge,
          child: AspectRatio(
            // AspectRatio 위젯으로 감싸서 카메라의 실제 비율을 강제합니다.
            aspectRatio: cameraAspectRatio,
            child: Stack(
              children: [
                // 카메라 미리보기
                CameraPreview(controller),

                // 오버레이 정보
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildOverlayInfo(provider),
                ),

                // 상태 표시기
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildStatusIndicator(provider),
                ),

                // 카메라 전환 버튼
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildCameraSwitchButton(provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // (이하 나머지 코드는 동일)

  // 시뮬레이터용 데모 화면
  Widget _buildSimulatorPreview(DrowsinessProvider provider) {
    // (TFLite는 시뮬레이터에서 작동하지 않으므로, 이 코드는 TFLite 사용 시 의미가 없음)
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade100,
            Colors.blue.shade50,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 시뮬레이터 배경
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.computer,
                  size: 64,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  '시뮬레이터 모드 (TFLite 비활성)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TFLite 추론은 실제 기기에서만 작동합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          // 오버레이 정보
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildOverlayInfo(provider),
          ),

          // 상태 표시기
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildStatusIndicator(provider),
          ),

          // 시뮬레이터 모드 표시
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayInfo(DrowsinessProvider provider) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TFLite가 EAR 값을 반환하지 않으므로 이 부분은 의미가 없을 수 있습니다.
          // TFLite 모델이 EAR 값을 출력하지 않는다면 이 Row를 제거하거나 주석 처리하세요.
          /* Row(
            children: [
              Icon(
                Icons.remove_red_eye,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'EAR: ${provider.eyeAspectRatio.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          */

          // ⬇️⬇️⬇️ EAR를 표시하던 아래 Row와 SizedBox를 삭제했습니다. ⬇️⬇️⬇️
          /*
          Row(
            children: [
              Icon(
                Icons.remove_red_eye,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'EAR: ${provider.eyeAspectRatio.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          */
          // ⬆️⬆️⬆️ 여기까지 삭제 ⬆️⬆️⬆️

          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              // TFLite의 확률값(0.0 ~ 1.0)을 %로 표시
              Text(
                '졸음도: ${(provider.drowsinessScore * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(DrowsinessProvider provider) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (provider.currentLevel) {
      case DrowsinessLevel.awake:
        statusColor = Colors.green;
        statusText = '깨어있음';
        statusIcon = Icons.visibility;
        break;
      case DrowsinessLevel.drowsy:
        statusColor = Colors.orange;
        statusText = '졸음';
        statusIcon = Icons.warning;
        break;
      case DrowsinessLevel.sleeping:
        statusColor = Colors.red;
        statusText = '잠듦';
        statusIcon = Icons.bedtime;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (provider.isMonitoring) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              // 간단한 깜빡임 효과 (필요시)
              // child: AnimatedContainer(
              //   duration: const Duration(milliseconds: 500),
              //   decoration: BoxDecoration(
              //     color: Colors.white.withOpacity(0.5),
              //     shape: BoxShape.circle,
              //   ),
              // ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraSwitchButton(DrowsinessProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: provider.isMonitoring ? null : () {
          provider.switchCamera();
        },
        icon: const Icon(
          Icons.flip_camera_ios,
          color: Colors.white,
          size: 20,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }
}
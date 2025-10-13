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
        if (!provider.isCameraReady) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
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
          );
        }

        // 시뮬레이터 모드인 경우 데모 화면 표시
        if (provider.isSimulatorMode) {
          return _buildSimulatorPreview(provider);
        }

        // 실제 카메라 미리보기
        if (provider.cameraController == null) {
          return _buildSimulatorPreview(provider);
        }

        return Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 카메라 미리보기
              CameraPreview(provider.cameraController!),

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
        );
      },
    );
  }

  // 시뮬레이터용 데모 화면
  Widget _buildSimulatorPreview(DrowsinessProvider provider) {
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
                  Platform.isIOS ? 'iOS 시뮬레이터 모드' : 'Android 에뮬레이터 모드',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '데모 졸음 감지가 실행 중입니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                // 애니메이션 점들
                if (provider.isMonitoring)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) =>
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 500 + (index * 200)),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
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
                color: Colors.orange.withValues(alpha: 0.9),
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
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
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
        color: statusColor.withValues(alpha: 0.9),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraSwitchButton(DrowsinessProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
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

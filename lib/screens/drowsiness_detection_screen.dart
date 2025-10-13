import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drowsiness_provider.dart';
import '../widgets/camera_preview_widget.dart';

class DrowsinessDetectionScreen extends StatefulWidget {
  const DrowsinessDetectionScreen({super.key});

  @override
  State<DrowsinessDetectionScreen> createState() => _DrowsinessDetectionScreenState();
}

class _DrowsinessDetectionScreenState extends State<DrowsinessDetectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 화면 진입 시 카메라 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DrowsinessProvider>(context, listen: false);
      provider.initializeCamera();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // 화면 종료 시 카메라 리소스 정리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DrowsinessProvider>(context, listen: false);
      provider.cleanupForScreenExit();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '졸음 감지',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<DrowsinessProvider>(
        builder: (context, provider, child) {
          // 활성화 상태에 따라 애니메이션 제어
          if (provider.isMonitoring) {
            _pulseController.repeat(reverse: true);
          } else {
            _pulseController.stop();
            _pulseController.reset();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 카메라 미리보기 섹션
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: Color(0xFFFF6B6B),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '실시간 졸음 감지',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 카메라 미리보기
                        const CameraPreviewWidget(),

                        const SizedBox(height: 16),

                        // 졸음 감지 활성화/비활성화 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleDrowsinessDetection(provider),
                            icon: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: provider.isMonitoring ? _pulseAnimation.value : 1.0,
                                  child: Icon(
                                    provider.isMonitoring ? Icons.stop : Icons.play_arrow,
                                    size: 24,
                                  ),
                                );
                              },
                            ),
                            label: Text(
                              provider.isMonitoring ? '졸음 감지 중지' : '졸음 감지 시작',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: provider.isMonitoring
                                ? Colors.red.shade400
                                : Color(0xFFFF6B6B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: provider.isMonitoring ? 8 : 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 상태 정보 카드들
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        title: '현재 상태',
                        value: _getStatusText(provider.currentLevel),
                        icon: _getStatusIcon(provider.currentLevel),
                        color: _getStatusColor(provider.currentLevel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusCard(
                        title: '알림 횟수',
                        value: '${provider.alertCount}회',
                        icon: Icons.notifications,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        title: '눈 깜빡임',
                        value: '${provider.blinkRate.toStringAsFixed(1)}/분',
                        icon: Icons.remove_red_eye,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusCard(
                        title: '졸음도',
                        value: '${(provider.drowsinessScore * 100).toStringAsFixed(1)}%',
                        icon: Icons.psychology,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // 졸음 감지 토글 함수
  Future<void> _toggleDrowsinessDetection(DrowsinessProvider provider) async {
    if (!provider.isCameraReady && !provider.isMonitoring) {
      // 카메라가 준비되지 않은 경우 먼저 초기화
      final success = await provider.initializeCamera();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('카메라 초기화에 실패했습니다. 카메라 권한을 확인해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    await provider.toggleMonitoring();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.isMonitoring
              ? '졸음 감지가 시작되었습니다.'
              : '졸음 감지가 중지되었습니다.',
          ),
          backgroundColor: provider.isMonitoring ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  // 상태 카드 위젯
  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상태 텍스트 반환
  String _getStatusText(DrowsinessLevel level) {
    switch (level) {
      case DrowsinessLevel.awake:
        return '깨어있음';
      case DrowsinessLevel.drowsy:
        return '졸음';
      case DrowsinessLevel.sleeping:
        return '잠듦';
    }
  }

  // 상태 아이콘 반환
  IconData _getStatusIcon(DrowsinessLevel level) {
    switch (level) {
      case DrowsinessLevel.awake:
        return Icons.visibility;
      case DrowsinessLevel.drowsy:
        return Icons.warning;
      case DrowsinessLevel.sleeping:
        return Icons.bedtime;
    }
  }

  // 상태 색상 반환
  Color _getStatusColor(DrowsinessLevel level) {
    switch (level) {
      case DrowsinessLevel.awake:
        return Colors.green;
      case DrowsinessLevel.drowsy:
        return Colors.orange;
      case DrowsinessLevel.sleeping:
        return Colors.red;
    }
  }
}

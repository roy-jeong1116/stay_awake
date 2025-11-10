import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drowsiness_provider.dart';
import '../providers/auth_provider.dart';
import 'drowsiness_detection_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'STAY ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'AWAKE',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.camera_alt, color: Colors.black),
          tooltip: '졸음감지 현황',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DrowsinessDetectionScreen(),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: Icon(
              Icons.logout,
              color: Colors.black,
            ),
            tooltip: '로그아웃',
          ),
        ],
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

          return Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 스마트 워치 연동 상태 표시
                    _buildWatchConnectionStatus(provider),
                    SizedBox(height: 20),

                    // 메인 원형 인디케이터 - 고정된 크기 컨테이너로 감싸기
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: _buildMainIndicator(provider),
                    ),
                    SizedBox(height: 40),

                    // 상태 텍스트
                    _getStatusWidget(
                        provider.currentLevel, provider.isMonitoring),
                    SizedBox(height: 60),
                  ],
                ),
              ),
              // 하단 버튼들을 화면 하단에 고정
              Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.bar_chart,
                      label: '차트 보기',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StatisticsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.settings,
                      label: '환경설정',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 졸음감지 현황 토글 함수
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
              ? '졸음감지가 시작되었습니다.'
              : '졸음감지가 중지되었습니다.',
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

  void _showLogoutDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('로그아웃'),
        content: Text('정말로 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // 다이얼로그 닫기
              authProvider.logout(); // 로그아웃 실행
              print('로그아웃 실행됨: ${authProvider.isLoggedIn}'); // 디버그용
              // 모든 화면을 제거하고 로그인 화면으로 이동
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFFFF6B6B),
            ),
            child: Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainIndicator(DrowsinessProvider provider) {
    Color indicatorColor;
    IconData iconData;

    if (provider.isMonitoring) {
      indicatorColor = Color(0xFFFF6B6B); // 앱 테마 색상으로 통일
      iconData = Icons.visibility;
    } else {
      indicatorColor = Colors.grey.shade300;
      iconData = Icons.visibility_off;
    }

    return GestureDetector(
      onTap: () async {
        await _toggleDrowsinessDetection(provider);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 애니메이션이 적용된 외부 glow 효과
          if (provider.isMonitoring) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 280 * _pulseAnimation.value,
                  height: 280 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        indicatorColor.withValues(alpha: 0.2 * (2 - _pulseAnimation.value)),
                        indicatorColor.withValues(alpha: 0.1 * (2 - _pulseAnimation.value)),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 240 * _pulseAnimation.value,
                  height: 240 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        indicatorColor.withValues(alpha: 0.3 * (2 - _pulseAnimation.value)),
                        indicatorColor.withValues(alpha: 0.15 * (2 - _pulseAnimation.value)),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.8, 1.0],
                    ),
                  ),
                );
              },
            ),
          ],
          // 메인 원형 버튼
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: indicatorColor,
                width: provider.isMonitoring ? 4 : 8,
              ),
              color: Colors.white,
              boxShadow: [
                if (provider.isMonitoring) ...[
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: 0.2),
                    blurRadius: 80,
                    spreadRadius: 15,
                  ),
                ] else ...[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ],
            ),
            child: AnimatedScale(
              duration: Duration(milliseconds: 300),
              scale: provider.isMonitoring ? 1.0 : 0.95,
              child: Icon(
                iconData,
                size: 80,
                color: indicatorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(0xFFFF6B6B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              size: 30,
              color: Color(0xFFFF6B6B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  Widget _getStatusWidget(DrowsinessLevel level, bool isMonitoring) {
    if (!isMonitoring) {
      return Column(
        children: [
          Text(
            '졸음감지 비활성 상태입니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '버튼을 눌러 졸음감지를 시작하세요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Text(
            '졸음감지 활성화 상태입니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '버튼을 누르면 졸음감지가 해제됩니다',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildWatchConnectionStatus(DrowsinessProvider provider) {
    // 실제 HealthService 연결 상태 사용
    final isConnected = provider.isWatchConnected;

    return GestureDetector(
      onTap: () {
        // 워치 연결 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DrowsinessDetectionScreen(),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 워치 아이콘 (불빛 효과 없음)
          Icon(
            isConnected ? Icons.watch : Icons.watch_off_outlined,
            color: isConnected ? Colors.green : Colors.grey,
            size: 20,
          ),
          SizedBox(width: 8),
          // 연동 상태 텍스트
          Text(
            isConnected ? '워치 연동됨' : '워치 연동 안됨',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isConnected ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

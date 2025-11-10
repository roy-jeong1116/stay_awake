import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/drowsiness_provider.dart';
import '../services/health_service.dart';

class SmartwatchWidget extends StatefulWidget {
  const SmartwatchWidget({super.key});

  @override
  State<SmartwatchWidget> createState() => _SmartwatchWidgetState();
}

class _SmartwatchWidgetState extends State<SmartwatchWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    return Consumer<DrowsinessProvider>(
      builder: (context, provider, child) {
        // 스마트워치 연결 상태에 따라 애니메이션 제어
        if (provider.isWatchConnected) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: provider.isWatchConnected ? _pulseAnimation.value : 1.0,
                          child: Icon(
                            Icons.watch,
                            color: _getConnectionColor(provider.watchConnectionStatus),
                            size: 24,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '스마트워치 연동',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    _buildConnectionStatus(provider.watchConnectionStatus),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 연결 상태별 UI
                if (provider.watchConnectionStatus == DeviceConnectionStatus.connected)
                  _buildConnectedUI(provider)
                else if (provider.watchConnectionStatus == DeviceConnectionStatus.connecting)
                  _buildConnectingUI()
                else
                  _buildDisconnectedUI(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  // 연결된 상태 UI
  Widget _buildConnectedUI(DrowsinessProvider provider) {
    return Column(
      children: [
        // 심박수 표시
        Row(
          children: [
            Expanded(
              child: _buildHeartRateCard(provider),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHeartRateStatus(provider),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 심박수 차트
        if (provider.heartRateHistory.isNotEmpty) ...[
          Text(
            '심박수 추이',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _buildHeartRateChart(provider.heartRateHistory),
          ),
          const SizedBox(height: 16),
        ],
        
        // 액션 버튼들
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _measureHeartRate(provider),
                icon: const Icon(Icons.favorite, size: 20),
                label: const Text('측정'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => provider.disconnectWatch(),
                icon: const Icon(Icons.bluetooth_disabled, size: 20),
                label: const Text('연결 해제'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 연결 중 UI
  Widget _buildConnectingUI() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          '스마트워치에 연결 중...',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // 연결되지 않은 상태 UI
  Widget _buildDisconnectedUI(DrowsinessProvider provider) {
    return Column(
      children: [
        Icon(
          Icons.watch_off,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          '스마트워치가 연결되지 않았습니다',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _connectToSmartwatch(provider),
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('스마트워치 연결'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 심박수 카드
  Widget _buildHeartRateCard(DrowsinessProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            color: Colors.red.shade400,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.heartRate.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          Text(
            'BPM',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 심박수 상태
  Widget _buildHeartRateStatus(DrowsinessProvider provider) {
    String status;
    Color statusColor;
    
    if (provider.heartRate < 60) {
      status = '낮음';
      statusColor = Colors.blue;
    } else if (provider.heartRate <= 80) {
      status = '정상';
      statusColor = Colors.green;
    } else if (provider.heartRate <= 100) {
      status = '높음';
      statusColor = Colors.orange;
    } else {
      status = '매우 높음';
      statusColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.health_and_safety,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          Text(
            '상태',
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 심박수 차트
  Widget _buildHeartRateChart(List<HeartRateData> history) {
    List<FlSpot> spots = [];
    
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].value));
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red.shade400,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.shade100.withOpacity(0.3),
            ),
          ),
        ],
        minY: 50,
        maxY: 120,
      ),
    );
  }

  // 연결 상태 표시
  Widget _buildConnectionStatus(DeviceConnectionStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case DeviceConnectionStatus.connected:
        color = Colors.green;
        text = '연결됨';
        break;
      case DeviceConnectionStatus.connecting:
        color = Colors.orange;
        text = '연결 중';
        break;
      case DeviceConnectionStatus.failed:
        color = Colors.red;
        text = '연결 실패';
        break;
      default:
        color = Colors.grey;
        text = '연결 안됨';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 연결 상태별 색상
  Color _getConnectionColor(DeviceConnectionStatus status) {
    switch (status) {
      case DeviceConnectionStatus.connected:
        return Colors.green;
      case DeviceConnectionStatus.connecting:
        return Colors.orange;
      case DeviceConnectionStatus.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 스마트워치 연결
  Future<void> _connectToSmartwatch(DrowsinessProvider provider) async {
    final permissionGranted = await provider.requestHealthPermissions();
    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('건강 데이터 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final connected = await provider.connectToSmartwatch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connected ? '스마트워치 연결 성공' : '스마트워치 연결 실패'),
          backgroundColor: connected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // 수동 심박수 측정
  Future<void> _measureHeartRate(DrowsinessProvider provider) async {
    final heartRate = await provider.measureHeartRateOnce();
    if (mounted) {
      if (heartRate != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('심박수: ${heartRate.toStringAsFixed(0)} BPM'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('심박수 측정에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
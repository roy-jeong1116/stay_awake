import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/drowsiness_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '차트 조회',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<DrowsinessProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 선택 영역
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '2월 5일 (월)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // 졸음 빈도 차트
                _buildSectionTitle('졸음 빈도'),
                SizedBox(height: 20),
                Container(
                  height: 200,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _buildDrowsinessChart(provider),
                ),
                SizedBox(height: 30),

                // 심박수 차트
                _buildSectionTitle('심박수'),
                SizedBox(height: 20),
                Container(
                  height: 200,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _buildHeartRateChart(provider),
                ),
                SizedBox(height: 30),

                // 통계 요약
                _buildStatsSummary(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDrowsinessChart(DrowsinessProvider provider) {
    // 시간대별 졸음 빈도 데모 데이터
    List<FlSpot> spots = [
      FlSpot(10, 0),
      FlSpot(11, 1),
      FlSpot(12, 2),
      FlSpot(13, 1),
      FlSpot(14, 3),
      FlSpot(15, 4),
      FlSpot(16, 2),
      FlSpot(17, 1),
      FlSpot(18, 0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}:00',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFFFF6B6B),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Color(0xFFFF6B6B).withValues(alpha: 0.1),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Color(0xFFFF6B6B),
                  strokeColor: Colors.white,
                  strokeWidth: 2,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateChart(DrowsinessProvider provider) {
    // 심박수 데모 데이터
    List<FlSpot> spots = [
      FlSpot(10, 72),
      FlSpot(11, 75),
      FlSpot(12, 73),
      FlSpot(13, 68),
      FlSpot(14, 65),
      FlSpot(15, 62),
      FlSpot(16, 70),
      FlSpot(17, 74),
      FlSpot(18, 76),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}:00',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFFFF6B6B),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Color(0xFFFF6B6B).withValues(alpha: 0.1),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Color(0xFFFF6B6B),
                  strokeColor: Colors.white,
                  strokeWidth: 2,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(DrowsinessProvider provider) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 요약',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('총 알림 횟수', '${provider.alertCount}회'),
              _buildStatItem('평균 심박수', '${provider.heartRate.toInt()}bpm'),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('모니터링 시간', provider.sessionStartTime != null
                ? '${DateTime.now().difference(provider.sessionStartTime!).inMinutes}분'
                : '0분'),
              _buildStatItem('상태', _getCurrentStatusText(provider.currentLevel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getCurrentStatusText(DrowsinessLevel level) {
    switch (level) {
      case DrowsinessLevel.awake:
        return '정상';
      case DrowsinessLevel.drowsy:
        return '주의';
      case DrowsinessLevel.sleeping:
        return '위험';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drowsiness_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundAlertEnabled = true;
  bool _vibrationEnabled = true;
  bool _backgroundModeEnabled = false;
  bool _heartRateMonitoring = true;
  double _sensitivity = 0.7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 알림 설정
            _buildSectionTitle('알림 설정'),
            SizedBox(height: 15),
            _buildSettingCard([
              _buildSwitchTile(
                '음성 알림',
                '졸음 감지 시 음성으로 알림',
                _soundAlertEnabled,
                (value) {
                  setState(() {
                    _soundAlertEnabled = value;
                  });
                },
              ),
              Divider(height: 1),
              _buildSwitchTile(
                '진동 알림',
                '졸음 감지 시 진동으로 알림',
                _vibrationEnabled,
                (value) {
                  setState(() {
                    _vibrationEnabled = value;
                  });
                },
              ),
            ]),
            
            SizedBox(height: 30),
            
            // 감지 설정
            _buildSectionTitle('감지 설정'),
            SizedBox(height: 15),
            _buildSettingCard([
              _buildSwitchTile(
                '심박수 모니터링',
                '스마트워치 연동 시 심박수 데이터 사용',
                _heartRateMonitoring,
                (value) {
                  setState(() {
                    _heartRateMonitoring = value;
                  });
                },
              ),
              Divider(height: 1),
              _buildSliderTile(
                '감지 민감도',
                '졸음 감지의 민감도를 조절합니다',
                _sensitivity,
                (value) {
                  setState(() {
                    _sensitivity = value;
                  });
                },
              ),
            ]),
            
            SizedBox(height: 30),
            
            // 기능 설정
            _buildSectionTitle('기능 설정'),
            SizedBox(height: 15),
            _buildSettingCard([
              _buildSwitchTile(
                '백그라운드 모드',
                '다른 앱 사용 중에도 졸음 감지',
                _backgroundModeEnabled,
                (value) {
                  setState(() {
                    _backgroundModeEnabled = value;
                  });
                },
              ),
              Divider(height: 1),
              _buildActionTile(
                '오버레이 권한',
                '다른 앱 위에 표시하기 위한 권한',
                '설정하기',
                () {
                  _requestOverlayPermission();
                },
              ),
            ]),
            
            SizedBox(height: 30),
            
            // 데이터 관리
            _buildSectionTitle('데이터 관리'),
            SizedBox(height: 15),
            _buildSettingCard([
              _buildActionTile(
                '통계 데이터 초기화',
                '저장된 모든 통계 데이터를 삭제합니다',
                '초기화',
                () {
                  _showResetDialog();
                },
              ),
              Divider(height: 1),
              _buildActionTile(
                '데이터 내보내기',
                '통계 데이터를 파일로 내보냅니다',
                '내보내기',
                () {
                  _exportData();
                },
              ),
            ]),
            
            SizedBox(height: 30),
            
            // 앱 정보
            _buildSectionTitle('앱 정보'),
            SizedBox(height: 15),
            _buildSettingCard([
              _buildInfoTile('버전', '1.0.0'),
              Divider(height: 1),
              _buildActionTile(
                '개인정보 처리방침',
                '',
                '',
                () {},
              ),
              Divider(height: 1),
              _buildActionTile(
                '이용약관',
                '',
                '',
                () {},
              ),
            ]),
          ],
        ),
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

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Color(0xFFFF6B6B),
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text('낮음', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Expanded(
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Color(0xFFFF6B6B),
                  inactiveColor: Colors.grey.shade300,
                ),
              ),
              Text('높음', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    String actionText,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: actionText.isNotEmpty
          ? Text(
              actionText,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  void _requestOverlayPermission() {
    // 실제 구현에서는 system_alert_window 패키지를 사용하여 권한 요청
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('오버레이 권한'),
        content: Text('다른 앱 위에 표시하기 위한 권한이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 권한 요청 로직
            },
            child: Text('설정하기'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('데이터 초기화'),
        content: Text('모든 통계 데이터가 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<DrowsinessProvider>(context, listen: false)
                  .resetStatistics();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('데이터가 초기화되었습니다.')),
              );
            },
            child: Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    // 실제 구현에서는 파일 시스템에 데이터 저장
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('데이터 내보내기 기능은 준비 중입니다.')),
    );
  }
}

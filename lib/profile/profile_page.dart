import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../grade/score.dart';

class ProfilePage extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const ProfilePage({super.key, required this.client, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StudentInfo? _info;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // 先访问基本信息页，获取 Cookie
      await widget.client.get(
        Uri.parse('http://ehall.yibinu.edu.cn/appShow?appId=5314637135076659'),
      );

      final resp = await widget.client.get(
        Uri.parse(
            'http://ehall.yibinu.edu.cn/jwapp/sys/xsjbxxgl/modules/xsjbxx/cxxsjbxxlb.do?*json=1'),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': 'ehall.yibinu.edu.cn',
          'Referer': 'http://ehall.yibinu.edu.cn/appShow?appId=5314637135076659',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );

      if (resp.statusCode == 404) {
        throw Exception('个人信息接口不可用（404），请稍后再试');
      }
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final rows = (j['datas'] as Map<String, dynamic>?)?
              ['cxxsjbxxlb']?['rows'] as List<dynamic>?;
      if (rows == null || rows.isEmpty) {
        throw Exception('未获取到个人信息');
      }

      if (!mounted) return;
      setState(() {
        _info = StudentInfo.fromJson(rows[0] as Map<String, dynamic>);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('获取个人信息失败',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadProfile();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final info = _info!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 头像
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, size: 48, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(info.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(info.studentId,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 32),

          // 信息卡片
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoItem(Icons.business, '学院', info.department),
                  const Divider(),
                  _infoItem(Icons.school, '专业', info.major),
                  const Divider(),
                  _infoItem(Icons.group, '班级', info.className),
                  const Divider(),
                  _infoItem(Icons.calendar_today, '年级', info.grade),
                  const Divider(),
                  _infoItem(Icons.timer, '学制', '${info.duration}年'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
